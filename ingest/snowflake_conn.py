"""Reusable Snowflake connection for the loader (key-pair auth, settings from .env)."""
import os

import snowflake.connector
from dotenv import load_dotenv

load_dotenv()  # reads .env locally; in GitHub Actions the values come from secrets


def get_connection(schema: str = "RAW"):
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        role=os.environ["SNOWFLAKE_ROLE"],
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
        database=os.environ["SNOWFLAKE_DATABASE"],
        schema=schema,
        authenticator="SNOWFLAKE_JWT",  # = key-pair login
        private_key_file=os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"],
    )


if __name__ == "__main__":
    # Quick self-test: python ingest/snowflake_conn.py
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute(
            "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(), "
            "CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_VERSION()"
        )
        print("Connected:", cur.fetchone())