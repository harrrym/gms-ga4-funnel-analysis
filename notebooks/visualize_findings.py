"""
지금까지의 분석 결과(구매전환율 추세, AARRR 단계별 낙폭, 구매퍼널 붕괴)를 차트로 저장한다.

사용법:
    python notebooks/visualize_findings.py
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

PROBLEM_START, PROBLEM_END = "2020-12-28", "2021-01-04"


def _exclude_partial_week(df: pd.DataFrame) -> pd.DataFrame:
    return df[df["week_start"] != "2020-10-26"].copy()


def plot_conversion_trend():
    df = _exclude_partial_week(pd.read_csv(DATA_DIR / "01_health_check_weekly.csv"))
    df["week_start"] = pd.to_datetime(df["week_start"])
    median = df["conversion_rate_pct"].median()

    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(df["week_start"], df["conversion_rate_pct"], marker="o", color="#2563eb")
    ax.axhline(median, color="gray", linestyle="--", linewidth=1, label=f"기준선(중앙값) {median:.2f}%")
    ax.axvspan(pd.Timestamp(PROBLEM_START), pd.Timestamp(PROBLEM_END), color="red", alpha=0.12, label="문제구간")

    ax.set_title("주간 구매전환율 추세 (2020-11 ~ 2021-01)")
    ax.set_ylabel("구매전환율 (%)")
    ax.set_xlabel("주 시작일")
    ax.legend()
    fig.autofmt_xdate()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "conversion_trend.png", dpi=150)
    plt.close(fig)


def plot_aarrr_comparison():
    conv = _exclude_partial_week(pd.read_csv(DATA_DIR / "01_health_check_weekly.csv"))
    retention = _exclude_partial_week(pd.read_csv(DATA_DIR / "02_retention_candidate_check.csv"))
    activation = _exclude_partial_week(pd.read_csv(DATA_DIR / "05_activation_weekly.csv"))

    def deviation_at_worst(df, col):
        median = df[col].median()
        mask = df["week_start"].between(PROBLEM_START, PROBLEM_END)
        worst = df.loc[mask, col].min()
        return (worst - median) / median * 100

    rows = [
        ("Acquisition\n(세션수)", deviation_at_worst(conv, "session_count")),
        ("Activation\n(첫세션 상품조회율)", deviation_at_worst(activation, "activation_rate_pct")),
        ("Retention\n(재방문율 근사)", deviation_at_worst(retention, "returning_user_rate_pct")),
        ("Revenue\n(구매전환율)", deviation_at_worst(conv, "conversion_rate_pct")),
    ]
    labels = [r[0] for r in rows]
    values = [r[1] for r in rows]

    fig, ax = plt.subplots(figsize=(9, 5))
    bars = ax.bar(labels, values, color="#dc2626")
    ax.axhline(0, color="black", linewidth=0.8)
    ax.set_title("AARRR 단계별 문제구간 최대 낙폭 (기준선 대비 %)")
    ax.set_ylabel("기준선 대비 편차 (%)")
    for bar, v in zip(bars, values):
        ax.annotate(f"{v:.1f}%", (bar.get_x() + bar.get_width() / 2, v),
                    textcoords="offset points", xytext=(0, -14 if v < 0 else 6), ha="center")
    fig.tight_layout()
    fig.savefig(OUT_DIR / "aarrr_comparison.png", dpi=150)
    plt.close(fig)


def plot_funnel_collapse():
    df = pd.read_csv(DATA_DIR / "04_funnel_diagnosis_by_device.csv")
    df = df[df["device_category"].isin(["desktop", "mobile"])]

    stages = ["view_to_cart_cr", "cart_to_checkout_cr", "checkout_to_purchase_cr"]
    stage_labels = ["조회→장바구니", "장바구니→결제시작", "결제시작→구매완료"]

    fig, axes = plt.subplots(1, 2, figsize=(11, 5), sharey=True)
    for ax, device in zip(axes, ["desktop", "mobile"]):
        sub = df[df["device_category"] == device].set_index("period")
        baseline_vals = [sub.loc["평상시", s] for s in stages]
        problem_vals = [sub.loc["문제구간", s] for s in stages]

        x = range(len(stages))
        width = 0.35
        ax.bar([i - width / 2 for i in x], baseline_vals, width, label="평상시", color="#2563eb")
        ax.bar([i + width / 2 for i in x], problem_vals, width, label="문제구간", color="#dc2626")
        ax.set_xticks(list(x))
        ax.set_xticklabels(stage_labels, rotation=15)
        ax.set_title(device)
        ax.set_ylabel("단계별 전환율 (%)")
        ax.legend()

    fig.suptitle("구매 퍼널 단계별 전환율: 평상시 vs 문제구간 (디바이스별)")
    fig.tight_layout()
    fig.savefig(OUT_DIR / "funnel_collapse.png", dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    plot_conversion_trend()
    plot_aarrr_comparison()
    plot_funnel_collapse()
    print(f"차트 3개 저장됨: {OUT_DIR}")
