# ---- Base: same Python version as on the PC ----
FROM python:3.11-slim

# Print logs immediately (no buffering), so we see progress live in Docker/GitHub Actions
ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    DBT_TARGET=dev

WORKDIR /app

# ---- 1. Libraries first (this layer is cached as long as requirements.txt doesn't change) ----
COPY requirements.txt .
RUN pip install -r requirements.txt

# ---- 2. Our code ----
COPY ingest/ ingest/
COPY finance_dbt/ finance_dbt/

# ---- 3. dbt packages (dbt_utils) baked into the image ----
RUN cd finance_dbt && dbt deps

# ---- Default command: load new API data, then build + test all dbt models ----
# DBT_TARGET decides the schema: dev (PC) / ci (pull requests) / prod (daily schedule)
CMD ["sh", "-c", "python ingest/load_raw.py && cd finance_dbt && dbt build --target $DBT_TARGET"]