"""
sql/*.sql 파일을 읽어 BigQuery에서 실행하고, 결과를 data/*.csv로 저장한다.

사용법:
    python notebooks/run_query.py sql/01_health_check_weekly.sql

사전 준비:
    1. 환경변수 GCP_PROJECT_ID에 BigQuery 쿼리를 실행할 GCP 프로젝트 ID 설정
    2. gcloud auth application-default login 으로 ADC 인증
"""
import os
import sys
from pathlib import Path

import pandas as pd
from google.cloud import bigquery

PROJECT_ROOT = Path(__file__).resolve().parent.parent


def get_project_id() -> str:
    project_id = os.environ.get("GCP_PROJECT_ID")
    if not project_id:
        raise RuntimeError(
            "환경변수 GCP_PROJECT_ID가 설정되지 않았습니다.\n"
            "쿼리를 실행할 GCP 프로젝트 ID를 설정한 뒤 다시 실행하세요.\n"
            '  PowerShell: $env:GCP_PROJECT_ID = "내-프로젝트-ID"\n'
            "  bash:       export GCP_PROJECT_ID=내-프로젝트-ID\n"
            "인증은 gcloud auth application-default login 으로 ADC를 설정해야 합니다."
        )
    return project_id


def run_query(sql_path: str) -> pd.DataFrame:
    sql_file = Path(sql_path)
    query = sql_file.read_text(encoding="utf-8")

    client = bigquery.Client(project=get_project_id())
    df = client.query(query).to_dataframe()

    output_path = PROJECT_ROOT / "data" / f"{sql_file.stem}.csv"
    df.to_csv(output_path, index=False, encoding="utf-8-sig")
    print(f"결과 {len(df)}행 저장됨: {output_path}")

    return df


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("사용법: python notebooks/run_query.py <sql파일경로>")
        sys.exit(1)

    try:
        result_df = run_query(sys.argv[1])
    except RuntimeError as e:
        print(e)
        sys.exit(1)
    print(result_df.to_string(index=False))
