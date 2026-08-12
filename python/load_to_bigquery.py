import os
import json
import pandas as pd
from google.cloud import bigquery
from google.oauth2 import service_account

csv_folder_path = r'/content/sample_data/nnkb'
print(os.listdir(csv_folder_path))

project_id = "jda-k1"
dataset_id = "practice_data_pipeline"

# Service account key is kept outside this repo.
# Set GOOGLE_APPLICATION_CREDENTIALS to the path of the JSON key before running.
key_file = os.environ["GOOGLE_APPLICATION_CREDENTIALS"]
with open(key_file) as f:
    key_path = json.load(f)

credentials = service_account.Credentials.from_service_account_info(key_path)
client = bigquery.Client(credentials=credentials, project=project_id)
print("Connected BigQuery successfully!")

job_config = bigquery.LoadJobConfig(
    write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    autodetect=True,
)

for file in os.listdir(csv_folder_path):
    if file.endswith(".csv"):
        file_path = os.path.join(csv_folder_path, file)
        print(file_path)

        # Read file CSV
        df = pd.read_csv(file_path)

        # Create table from file
        table_name = os.path.splitext(file)[0].lower()
        table_ref = f"{project_id}.{dataset_id}.{table_name}"

        # Load in BigQuery
        print(f"Loading {file} in {table_ref} ...")
        job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
        job.result()

        print(f"Loaded {job.output_rows} in {table_ref}")
