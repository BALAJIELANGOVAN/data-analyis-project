"""
Load the modelled star-schema CSVs into BigQuery.

Part of the Olist Marketplace Analytics project. The dimensional model is built
in SQL, exported to CSV, and re-loaded here — a workaround for a BigQuery
environment that was read-only for table creation.

WRITE_TRUNCATE makes the job idempotent: a re-run replaces each table rather
than appending, so the loaded data always matches the source CSVs exactly.

Credentials
-----------
Set GOOGLE_APPLICATION_CREDENTIALS to the path of a service account JSON key.

    export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"

In Colab, store the path in Secrets (key icon, left sidebar) and read it with:

    from google.colab import userdata
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = userdata.get("GCP_KEY_PATH")

The key file is never committed. See .gitignore.

Known limitation
----------------
This script uses autodetect for schema inference. BigQuery infers column types
from a sample of each file, and it inferred several incorrectly — those types
were corrected downstream in Power Query. Declaring an explicit schema per table
would fix the cause rather than the symptom, and is the change to make next.
"""

import os

import pandas as pd
from google.cloud import bigquery
from google.oauth2 import service_account

PROJECT_ID = "jda-k1"
DATASET_ID = "practice_data_pipeline"
CSV_FOLDER_PATH = "/content/sample_data/nnkb"


def get_client() -> bigquery.Client:
    """Authenticate with BigQuery using a service account key held outside the repo."""
    key_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if not key_path:
        raise RuntimeError(
            "GOOGLE_APPLICATION_CREDENTIALS is not set. Point it at your service "
            "account JSON key file before running this script."
        )

    credentials = service_account.Credentials.from_service_account_file(key_path)
    return bigquery.Client(credentials=credentials, project=PROJECT_ID)


def load_csv_folder(client: bigquery.Client, folder_path: str) -> None:
    """Load every CSV in a folder into BigQuery, one table per file.

    Table names are taken from the file names, lowercased.
    """
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        autodetect=True,
    )

    csv_files = [f for f in os.listdir(folder_path) if f.endswith(".csv")]
    if not csv_files:
        print(f"No CSV files found in {folder_path}")
        return

    for file_name in csv_files:
        file_path = os.path.join(folder_path, file_name)
        table_name = os.path.splitext(file_name)[0].lower()
        table_ref = f"{PROJECT_ID}.{DATASET_ID}.{table_name}"

        df = pd.read_csv(file_path)
        print(f"Loading {file_name} ({len(df):,} rows) into {table_ref} ...")

        job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
        job.result()

        print(f"Loaded {job.output_rows:,} rows into {table_ref}")


if __name__ == "__main__":
    bq_client = get_client()
    print("Connected to BigQuery")
    load_csv_folder(bq_client, CSV_FOLDER_PATH)
