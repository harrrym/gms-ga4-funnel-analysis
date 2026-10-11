"""
Acquisition 단계: 채널별 신규유저 유입 추이(절대량, 비중)를 차트로 저장한다.

사용법:
    python notebooks/visualize_acquisition.py
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

CHANNEL_ORDER = ["google/organic", "direct", "식별불가/기타", "google/cpc", "self-referral"]
COLORS = ["#2563eb", "#60a5fa", "#9ca3af", "#dc2626", "#f59e0b"]


def _load_pivot():
    df = pd.read_csv(DATA_DIR / "08_acquisition_channel_weekly_trend.csv")
    df = df[df["week_start"] != "2020-10-26"]
    pivot = df.pivot(index="week_start", columns="channel", values="new_users").fillna(0)
    pivot.index = pd.to_datetime(pivot.index)
    return pivot[CHANNEL_ORDER]


def plot_channel_volume():
    pivot = _load_pivot()
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.stackplot(pivot.index, [pivot[c] for c in CHANNEL_ORDER], labels=CHANNEL_ORDER, colors=COLORS)
    ax.set_title("채널별 신규유저 유입 추이 (절대량)")
    ax.set_ylabel("신규유저 수")
    ax.set_xlabel("주 시작일")
    ax.legend(loc="upper left", fontsize=9)
    fig.autofmt_xdate()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "acquisition_channel_volume.png", dpi=150)
    plt.close(fig)


def plot_channel_share():
    pivot = _load_pivot()
    shares = pivot.div(pivot.sum(axis=1), axis=0) * 100

    fig, ax = plt.subplots(figsize=(10, 5))
    ax.stackplot(shares.index, [shares[c] for c in CHANNEL_ORDER], labels=CHANNEL_ORDER, colors=COLORS)
    ax.set_title("채널별 신규유저 비중 추이 (100% 기준)")
    ax.set_ylabel("비중 (%)")
    ax.set_xlabel("주 시작일")
    ax.set_ylim(0, 100)
    ax.legend(loc="upper left", fontsize=9)
    fig.autofmt_xdate()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "acquisition_channel_share.png", dpi=150)
    plt.close(fig)


def plot_cac_trend():
    CPC = 1.16
    AOV = 69.89  # sql/52 정제 후 주간 AOV 중앙값

    sessions = pd.read_csv(DATA_DIR / "14_cpc_sessions_weekly.csv")
    conversions = pd.read_csv(DATA_DIR / "15_cpc_weekly_conversions.csv")

    df = sessions.merge(conversions, on="week_start", how="left")
    df = df[df["week_start"] != "2020-10-26"].copy()
    df["cpc_new_conversions"] = df["cpc_new_conversions"].fillna(0)
    df["est_cac"] = (df["cpc_sessions"] * CPC) / df["cpc_new_conversions"]
    df["week_start"] = pd.to_datetime(df["week_start"])

    fig, ax = plt.subplots(figsize=(10, 5))
    colors = ["#16a34a" if v <= AOV else "#dc2626" for v in df["est_cac"]]
    ax.bar(df["week_start"], df["est_cac"], width=5, color=colors)
    ax.axhline(AOV, color="black", linestyle="--", linewidth=1.2, label=f"AOV(중앙값) ${AOV:.2f}")
    ax.set_title("google/cpc 추정 CAC 주간 추이 (업계 평균 CPC $1.16 적용)")
    ax.set_ylabel("추정 CAC (달러)")
    ax.set_xlabel("주 시작일 (신규유입 기준)")
    ax.legend()
    fig.autofmt_xdate()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "cac_trend.png", dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    plot_channel_volume()
    plot_channel_share()
    plot_cac_trend()
    print(f"차트 3개 저장됨: {OUT_DIR}")
