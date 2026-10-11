"""
문제 정의(cart→checkout 전환율 하락)를 차트로 저장한다.
데이터: sql/36_checkout_user_level_cohort.sql (유저 단위, 첫 add_to_cart 기준 주간 코호트)

사용법:
    python notebooks/visualize_checkout.py
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

DECLINE_START, DECLINE_END = "2020-12-14", "2021-01-11"
BASELINE_START, BASELINE_END = "2020-11-16", "2020-12-07"


def plot_checkout_conversion_trend():
    df = pd.read_csv(DATA_DIR / "36_checkout_user_level_cohort.csv")
    df["cohort_week"] = pd.to_datetime(df["cohort_week"])
    df = df[df["cohort_week"] != pd.Timestamp("2020-10-26")].copy()  # n=1인 경계 코호트 제외

    baseline_mask = df["cohort_week"].between(BASELINE_START, BASELINE_END)
    baseline = df.loc[baseline_mask, "cart_to_checkout_rate"].mean()

    fig, ax = plt.subplots(figsize=(11, 5.5))
    ax.plot(df["cohort_week"], df["cart_to_checkout_rate"], marker="o", color="#2563eb", linewidth=2)
    ax.axhline(baseline, color="gray", linestyle="--", linewidth=1,
               label=f"기준선(11/16~12/07 평균) {baseline:.1f}%")
    ax.axvspan(pd.Timestamp(DECLINE_START), pd.Timestamp(DECLINE_END), color="red", alpha=0.12, label="하락구간")

    for i, (_, row) in enumerate(df.iterrows()):
        y_offset = 12 if i % 2 == 0 else -16
        ax.annotate(f"n={int(row['users_added_to_cart']):,}",
                    (row["cohort_week"], row["cart_to_checkout_rate"]),
                    textcoords="offset points", xytext=(0, y_offset), ha="center", fontsize=8, color="#555")

    ax.set_title("코호트별 장바구니→결제시작(cart→checkout) 전환율 추이")
    ax.set_ylabel("cart→checkout 전환율 (%)")
    ax.set_xlabel("코호트 주 (첫 add_to_cart 시점)")
    ax.set_ylim(20, 60)
    ax.legend(loc="lower left")
    fig.autofmt_xdate()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "checkout_conversion_trend.png", dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    plot_checkout_conversion_trend()
    print(f"차트 1개 저장됨: {OUT_DIR}")
