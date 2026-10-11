"""
Revenue 단계: ARPU/ARPPU 주간 추이를 차트로 저장한다.

사용법:
    python notebooks/visualize_revenue.py
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

CRISIS_START = pd.Timestamp("2020-12-28")
CRISIS_END = pd.Timestamp("2021-01-04")


def plot_arpu_arppu_trend():
    df = pd.read_csv(DATA_DIR / "49_clean_arpu_arppu.csv")
    df = df[df["week_start"].notna()].copy()
    df["week_start"] = pd.to_datetime(df["week_start"])
    df = df[df["week_start"] != pd.Timestamp("2020-10-26")]

    fig, axes = plt.subplots(2, 1, figsize=(11, 8), sharex=True)

    ax = axes[0]
    ax.plot(df["week_start"], df["arpu"], marker="o", color="#2563eb", linewidth=2)
    ax.axvspan(CRISIS_START, CRISIS_END, color="#fecaca", alpha=0.5, label="OMTM 문제구간")
    ax.set_ylabel("ARPU ($)")
    ax.set_title("주간 ARPU 추이 (전체 유저 기준 평균매출)")
    ax.legend(loc="upper right", fontsize=8)

    ax = axes[1]
    ax.plot(df["week_start"], df["arppu"], marker="o", color="#16a34a", linewidth=2)
    ax.axvspan(CRISIS_START, CRISIS_END, color="#fecaca", alpha=0.5)
    ax.set_ylabel("ARPPU ($)")
    ax.set_xlabel("주 시작일")
    ax.set_title("주간 ARPPU 추이 (구매자 기준 평균매출)")
    fig.autofmt_xdate()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "arpu_arppu_trend.png", dpi=150)
    plt.close(fig)


CHANNEL_ORDER = ["google/organic", "식별불가/기타", "direct", "google/cpc", "self-referral"]
CHANNEL_COLORS = {"google/organic": "#2563eb", "식별불가/기타": "#9ca3af", "direct": "#60a5fa",
                   "google/cpc": "#dc2626", "self-referral": "#f59e0b"}


def plot_channel_revenue():
    df = pd.read_csv(DATA_DIR / "50_clean_channel_revenue.csv").set_index("channel").loc[CHANNEL_ORDER].reset_index()
    colors = [CHANNEL_COLORS[c] for c in df["channel"]]

    fig, axes = plt.subplots(1, 2, figsize=(13, 5.5))

    ax = axes[0]
    ax.bar(df["channel"], df["total_revenue_7d"], color=colors)
    ax.set_ylabel("7일 어트리뷰션 매출 ($)")
    ax.set_title("채널별 7일 윈도우 매출 (절대량)")
    ax.tick_params(axis="x", rotation=20)
    for i, v in enumerate(df["total_revenue_7d"]):
        ax.text(i, v + 800, f"${v:,.0f}", ha="center", fontsize=8.5)

    ax = axes[1]
    ax.bar(df["channel"], df["revenue_per_new_user"], color=colors)
    ax.set_ylabel("신규유저 1인당 7일 매출 ($)")
    ax.set_title("채널별 신규유저당 매출 (품질)")
    ax.tick_params(axis="x", rotation=20)
    for i, v in enumerate(df["revenue_per_new_user"]):
        ax.text(i, v + 0.015, f"${v:.3f}", ha="center", fontsize=8.5)

    fig.tight_layout()
    fig.savefig(OUT_DIR / "channel_revenue.png", dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    plot_arpu_arppu_trend()
    plot_channel_revenue()
    print(f"차트 2개 저장됨: {OUT_DIR}")
