"""
코호트별(요일/시간대/대륙/디바이스) 7일 전환율을 한 장의 차트로 저장한다.

사용법:
    python notebooks/visualize_cohorts.py
"""
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
OUT_DIR = PROJECT_ROOT / "reports" / "charts"
OUT_DIR.mkdir(parents=True, exist_ok=True)

plt.rcParams["font.family"] = "Malgun Gothic"
plt.rcParams["axes.unicode_minus"] = False

SIG_COLOR = "#dc2626"
NONSIG_COLOR = "#94a3b8"


def plot_cohort_conversion_rates():
    fig, axes = plt.subplots(2, 2, figsize=(12, 9))

    # 1) 요일 (유의함)
    weekday = pd.read_csv(DATA_DIR / "21_conversion_by_weekday.csv").sort_values("weekday_num")
    labels_kr = {"Sunday": "일", "Monday": "월", "Tuesday": "화", "Wednesday": "수",
                 "Thursday": "목", "Friday": "금", "Saturday": "토"}
    weekday["label"] = weekday["weekday"].map(labels_kr)
    ax = axes[0, 0]
    ax.bar(weekday["label"], weekday["conversion_rate_pct"], color=SIG_COLOR)
    ax.set_title("① 요일별 전환율 — 유의함 (p<0.000001)")
    ax.set_ylabel("7일 전환율 (%)")

    # 2) 시간대 (유의하지 않음, 경계선)
    hour = pd.read_csv(DATA_DIR / "22_conversion_by_hour.csv").sort_values("hour_utc")
    ax = axes[0, 1]
    ax.bar(hour["hour_utc"], hour["conversion_rate_pct"], color=NONSIG_COLOR)
    ax.set_title("② 시간대별(UTC) 전환율 — 유의하지 않음 (p=0.069)")
    ax.set_ylabel("7일 전환율 (%)")
    ax.set_xlabel("시(UTC)")
    ax.set_xticks(range(0, 24, 2))

    # 3) 대륙 (유의하지 않음)
    continent = pd.read_csv(DATA_DIR / "24_conversion_by_continent.csv")
    continent = continent[continent["continent"] != "(not set)"].sort_values("new_users", ascending=False)
    ax = axes[1, 0]
    ax.bar(continent["continent"], continent["conversion_rate_pct"], color=NONSIG_COLOR)
    ax.set_title("③ 대륙별 전환율 — 유의하지 않음 (p=0.484)")
    ax.set_ylabel("7일 전환율 (%)")
    ax.tick_params(axis="x", rotation=20)

    # 4) 디바이스 (유의하지 않음)
    device = pd.read_csv(DATA_DIR / "25_conversion_by_device.csv").sort_values("new_users", ascending=False)
    device_kr = {"desktop": "데스크톱", "mobile": "모바일", "tablet": "태블릿"}
    device["label"] = device["device_category"].map(device_kr)
    ax = axes[1, 1]
    ax.bar(device["label"], device["conversion_rate_pct"], color=NONSIG_COLOR)
    ax.set_title("④ 디바이스별 전환율 — 유의하지 않음 (p=0.287)")
    ax.set_ylabel("7일 전환율 (%)")

    fig.suptitle("코호트별 7일 구매전환율 비교 (빨강=통계적으로 유의함)", fontsize=13)
    fig.tight_layout()
    fig.savefig(OUT_DIR / "cohort_conversion_rates.png", dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    plot_cohort_conversion_rates()
    print(f"차트 저장됨: {OUT_DIR / 'cohort_conversion_rates.png'}")
