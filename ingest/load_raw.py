"""Incremental loader: ECB + Bundesbank REST APIs -> Snowflake FINANCE_DB.RAW.

Run:  python ingest/load_raw.py
For every series it finds the newest period already in RAW (the "watermark"),
asks the API only for newer data, and appends those rows.
"""
import io
from datetime import datetime, timezone

import pandas as pd
import requests
from requests.adapters import HTTPAdapter
from snowflake.connector.pandas_tools import write_pandas
from urllib3.util.retry import Retry

from snowflake_conn import get_connection

# ---------------------------------------------------------------- config
ECB_BASE = "https://data-api.ecb.europa.eu/service/data"
BBK_BASE = "https://api.statistiken.bundesbank.de/rest/data"

# One entry per API call. first_period = where the initial (history) load starts.
SERIES = [
    {"source": "ECB", "flow": "EXR", "key": "D.USD+GBP+CHF+JPY+CNY.EUR.SP00.A", "first_period": "2015-01-01"},
    {"source": "ECB", "flow": "FM", "key": "B.U2.EUR.4F.KR.DFR.LEV", "first_period": "1999-01-01"},
    {"source": "ECB", "flow": "HICP", "key": "M.DE+U2.N.000000.4D0.ANR", "first_period": "2015-01"},
    {"source": "BBK", "flow": "BBSSY", "key": "D.REN.EUR.A610.000000WT0202.A", "first_period": "2015-01-01"},
    {"source": "BBK", "flow": "BBSSY", "key": "D.REN.EUR.A630.000000WT1010.A", "first_period": "2015-01-01"},
]

TABLES = {"ECB": "RAW_ECB_OBSERVATIONS", "BBK": "RAW_BBK_OBSERVATIONS"}

# ---------------------------------------------------------------- HTTP
def make_session() -> requests.Session:
    """Session that retries on temporary server errors (429/5xx) with backoff."""
    retry = Retry(total=3, backoff_factor=2, status_forcelist=[429, 500, 502, 503, 504])
    session = requests.Session()
    session.mount("https://", HTTPAdapter(max_retries=retry))
    return session


def fetch_csv(session, s: dict, start_period: str) -> pd.DataFrame:
    """Call the API for one series and return the raw CSV as a DataFrame (all strings)."""
    if s["source"] == "ECB":
        url = f"{ECB_BASE}/{s['flow']}/{s['key']}"
        params = {"format": "csvdata", "startPeriod": start_period}
    else:
        url = f"{BBK_BASE}/{s['flow']}/{s['key']}"
        params = {"format": "sdmx_csv", "startPeriod": start_period}

    # Ask for English like a browser does; without it the Bundesbank answers in German with ';'
    headers = {"Accept-Language": "en"}
    resp = session.get(url, params=params, headers=headers, timeout=60)
    if resp.status_code == 404:  # both APIs answer 404 when there is no data in the range
        return pd.DataFrame()
    resp.raise_for_status()
    # utf-8-sig removes the invisible BOM character the Bundesbank puts before the header
    text = resp.content.decode("utf-8-sig")
    # Detect the delimiter from the header line (',' or ';') instead of assuming it
    header_line = text.split("\n", 1)[0]
    sep = ";" if header_line.count(";") > header_line.count(",") else ","
    return pd.read_csv(io.StringIO(text), sep=sep, dtype=str, keep_default_na=False)

def to_raw_rows(df: pd.DataFrame, source: str, loaded_at) -> pd.DataFrame:
    """Keep the few columns we need, in one common shape for both sources."""
    if df.empty:
        return df
    key_col = "KEY" if source == "ECB" else "BBK_ID"
    out = pd.DataFrame(
        {
            "SERIES_KEY": df[key_col],
            "PERIOD": df["TIME_PERIOD"],
            "OBS_VALUE": df["OBS_VALUE"].str.strip(),
            "OBS_STATUS": df.get("OBS_STATUS", ""),
        }
    )
    # Bundesbank sends weekend/holiday rows with value "." -> not an observation, drop
    out = out[~out["OBS_VALUE"].isin(["", "."])]
    out["SOURCE"] = source
    out["LOADED_AT"] = loaded_at
    return out.reset_index(drop=True)


# ---------------------------------------------------------------- Snowflake
def ensure_tables(cur):
    for table in TABLES.values():
        cur.execute(
            f"""CREATE TABLE IF NOT EXISTS {table} (
                SERIES_KEY STRING,
                PERIOD     STRING,
                OBS_VALUE  STRING,
                OBS_STATUS STRING,
                SOURCE     STRING,
                LOADED_AT  TIMESTAMP_TZ
            )"""
        )


def get_watermarks(cur, table: str) -> dict:
    """Newest period already loaded, per series key: {series_key: '2026-10-20', ...}"""
    cur.execute(f"SELECT SERIES_KEY, MAX(PERIOD) FROM {table} GROUP BY SERIES_KEY")
    return dict(cur.fetchall())


def series_keys(s: dict) -> list:
    """Expand 'D.USD+GBP.EUR...' into the individual series keys the API returns."""
    parts = [p.split("+") for p in s["key"].split(".")]
    keys = [""]
    for options in parts:
        keys = [f"{k}.{o}" if k else o for k in keys for o in options]
    return [f"{s['flow']}.{k}" for k in keys]


# ---------------------------------------------------------------- main
def main():
    loaded_at = pd.Timestamp(datetime.now(timezone.utc))
    session = make_session()

    with get_connection(schema="RAW") as conn:
        cur = conn.cursor()
        ensure_tables(cur)
        total = 0

        for s in SERIES:
            table = TABLES[s["source"]]
            marks = get_watermarks(cur, table)
            keys = series_keys(s)
            known = [marks[k] for k in keys if k in marks]
            # all keys of this call loaded before -> start at the OLDEST of their watermarks;
            # any key new -> full history from first_period
            start = min(known) if len(known) == len(keys) else s["first_period"]

            raw = fetch_csv(session, s, start)
            rows = to_raw_rows(raw, s["source"], loaded_at)
            # keep only periods newer than that key's watermark -> re-runs add no duplicates
            if not rows.empty:
                wm = rows["SERIES_KEY"].map(marks).fillna("")
                rows = rows[rows["PERIOD"] > wm]

            if rows.empty:
                print(f"{s['source']} {s['flow']}/{s['key']}: up to date (from {start})")
                continue

            write_pandas(conn, rows, table, use_logical_type=True)
            total += len(rows)
            print(
                f"{s['source']} {s['flow']}/{s['key']}: +{len(rows)} rows "
                f"({rows['PERIOD'].min()} .. {rows['PERIOD'].max()})"
            )

        print(f"Done. {total} new rows loaded.")


if __name__ == "__main__":
    main()