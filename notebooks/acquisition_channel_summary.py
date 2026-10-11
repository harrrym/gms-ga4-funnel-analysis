"""
sql/06_acquisition_channel_breakdown.sql 결과를 식별 가능/불가능으로 분류해 비중을 계산한다.

분류 기준:
- 식별 가능: source/medium이 둘 다 <Other>가 아니고, (data deleted)도 아닌 경우
  (direct)/(none)도 "채널 정보는 없지만 값 자체는 식별됨"으로 식별 가능에 포함한다.
- 식별 불가: source 또는 medium이 <Other>이거나 (data deleted)인 경우

사용법:
    python notebooks/acquisition_channel_summary.py
"""
from pathlib import Path

import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"


def classify(row) -> str:
    if row["source"] == "(data deleted)" or row["medium"] == "(data deleted)":
        return "삭제됨"
    if row["source"] == "<Other>" or row["medium"] == "<Other>":
        return "식별불가(<Other>)"
    return "식별가능"


def main():
    df = pd.read_csv(DATA_DIR / "06_acquisition_channel_breakdown.csv")
    df["category"] = df.apply(classify, axis=1)

    summary = (
        df.groupby("category")["new_users"]
        .sum()
        .reset_index()
        .assign(pct=lambda d: (d["new_users"] / d["new_users"].sum() * 100).round(2))
        .sort_values("new_users", ascending=False)
    )

    out_path = DATA_DIR / "06b_channel_identifiability_summary.csv"
    summary.to_csv(out_path, index=False, encoding="utf-8-sig")
    print(summary.to_string(index=False))
    print(f"\n저장됨: {out_path}")


if __name__ == "__main__":
    main()
