"""
Revenue/Activation 공통: 핵심 구매 퍼널 6단계(view_item~purchase) 발생 건수를 선 그래프로 저장한다.

사용법:
    python notebooks/visualize_funnel.py
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

FUNNEL_STEPS = ["view_item", "add_to_cart", "begin_checkout", "add_shipping_info", "add_payment_info", "purchase"]
STEP_LABELS_KR = {
    "view_item": "상품조회",
    "add_to_cart": "장바구니",
    "begin_checkout": "결제시작",
    "add_shipping_info": "배송정보",
    "add_payment_info": "결제정보",
    "purchase": "구매완료",
}


def plot_funnel_steps():
    df = pd.read_csv(DATA_DIR / "16_distinct_event_names.csv")
    counts = df.set_index("event_name").loc[FUNNEL_STEPS, "event_count"]

    fig, ax = plt.subplots(figsize=(10, 5.5))
    x = range(len(FUNNEL_STEPS))
    ax.plot(x, counts.values, marker="o", markersize=8, linewidth=2, color="#2563eb")

    base = counts.iloc[0]
    for i, (step, count) in enumerate(counts.items()):
        pct_of_first = count / base * 100
        label = f"{count:,}건\n({pct_of_first:.1f}%)"
        ax.annotate(label, (i, count), textcoords="offset points", xytext=(0, 12),
                    ha="center", fontsize=9)
        if i > 0:
            prev = counts.iloc[i - 1]
            drop_pct = (1 - count / prev) * 100
            mid_y = (prev + count) / 2
            ax.annotate(f"-{drop_pct:.1f}%", (i - 0.5, mid_y), ha="center", fontsize=8.5,
                        color="#dc2626")

    ax.set_xticks(list(x))
    ax.set_xticklabels([f"{STEP_LABELS_KR[s]}\n({s})" for s in FUNNEL_STEPS])
    ax.set_ylabel("이벤트 발생 건수")
    ax.set_title("핵심 구매 퍼널 6단계 발생 건수 (전체 3개월)")
    ax.margins(y=0.18)
    fig.tight_layout()
    fig.savefig(OUT_DIR / "purchase_funnel_steps.png", dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    plot_funnel_steps()
    print(f"차트 저장됨: {OUT_DIR / 'purchase_funnel_steps.png'}")
