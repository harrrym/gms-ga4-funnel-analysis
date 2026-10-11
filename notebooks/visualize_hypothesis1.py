"""
원인 가설 검증(docs/07_hypothesis1_verification.md) 핵심 발견을 차트로 저장한다.
"평상시" 기준선은 블랙프라이데이 주(11/23~11/30, 프로모션 기간)를 제외한 값을 메인으로 쓴다
(민감도 체크 결과 결론 방향은 유지되지만 수치가 달라서 블프 제외 쪽을 기준으로 채택, docs/07 참고).
데이터: data/110,112(가격), 117,118,119(카테고리, 블프제외 cleaned), 106,107(카테고리유형 전환/지연, 블프제외),
        93,102(Hats 베스트셀러 주간 담기/구매, 기간풀링과 무관해 영향 없음)

사용법:
    python notebooks/visualize_hypothesis1.py
"""
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
OUT_DIR = PROJECT_ROOT / "reports" / "charts"
OUT_DIR.mkdir(parents=True, exist_ok=True)

plt.rcParams["font.family"] = "Malgun Gothic"
plt.rcParams["axes.unicode_minus"] = False

DECLINE_START, DECLINE_END = "2020-12-14", "2021-01-11"
BASELINE_COLOR = "#94a3b8"
DECLINE_COLOR = "#dc2626"


def read_csv(name):
    return pd.read_csv(DATA_DIR / f"{name}.csv", encoding="utf-8-sig")


def plot_stage_price_trend():
    # data/110(노출·결제시작, 전체 이벤트 단순평균), data/112(담김, 유저별 첫 add_to_cart) - 블프 제외 "평상시" 기준.
    price110 = read_csv("110_stage_price_trend_excl_bf")
    price112 = read_csv("112_cart_price_excl_bf")

    def get110(event_name, period):
        row = price110[(price110["event_name"] == event_name) & (price110["period"] == period)]
        return row["avg_price"].iloc[0]

    def get112(period):
        return price112[price112["period"] == period]["avg_price"].iloc[0]

    stages = ["노출\n(view_item)", "담김\n(add_to_cart)", "결제시작\n(begin_checkout)"]
    baseline = [
        get110("view_item", "평상시(블프제외)"),
        get112("평상시(블프제외)"),
        get110("begin_checkout", "평상시(블프제외)"),
    ]
    decline = [
        get110("view_item", "하락구간"),
        get112("하락구간"),
        get110("begin_checkout", "하락구간"),
    ]

    x = np.arange(len(stages))
    width = 0.32

    fig, ax = plt.subplots(figsize=(8, 5.5))
    bars1 = ax.bar(x - width / 2, baseline, width, label="평상시(블프제외)", color=BASELINE_COLOR)
    bars2 = ax.bar(x + width / 2, decline, width, label="하락구간", color=DECLINE_COLOR)

    for bars in (bars1, bars2):
        for b in bars:
            ax.annotate(f"${b.get_height():.2f}", (b.get_x() + b.get_width() / 2, b.get_height()),
                        textcoords="offset points", xytext=(0, 4), ha="center", fontsize=9)

    ax.set_xticks(x)
    ax.set_xticklabels(stages)
    ax.set_ylabel("가중평균 단가 ($)")
    ax.set_title("단계별 가중평균 단가")
    ax.legend()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "hypothesis1_stage_price_trend.png", dpi=150)
    plt.close(fig)


def plot_category_survival_ratio():
    cart = read_csv("117_cart_category_excl_bf_cleaned")
    checkout = read_csv("118_checkout_category_excl_bf_cleaned")

    cart_pivot = cart.pivot_table(index="category_clean", columns="period", values="pct", aggfunc="sum")
    checkout_pivot = checkout.pivot_table(index="category_clean", columns="period", values="pct", aggfunc="sum")

    survival_baseline = (checkout_pivot["평상시(블프제외)"] / cart_pivot["평상시(블프제외)"]) * 100
    survival_decline = (checkout_pivot["하락구간"] / cart_pivot["하락구간"]) * 100
    change = (survival_decline - survival_baseline).drop(index="기타/미분류", errors="ignore").dropna().sort_values()

    colors = [DECLINE_COLOR if v < 0 else "#2563eb" for v in change]

    fig, ax = plt.subplots(figsize=(9, 8))
    ax.barh(change.index, change.values, color=colors)
    ax.axvline(0, color="black", linewidth=0.8)
    ax.set_xlabel("생존비율 변화 (하락구간 - 평상시(블프제외), %p)")
    ax.set_title("카테고리별 생존비율 변화")
    fig.tight_layout()
    fig.savefig(OUT_DIR / "hypothesis1_category_survival_ratio.png", dpi=150)
    plt.close(fig)


def plot_category_type_conversion():
    df = read_csv("106_category_type_conversion_excl_bf")
    pivot = df.pivot(index="user_type", columns="period", values="cart_to_checkout_rate")
    pivot = pivot.loc[["그외형", "저관여형"]][["평상시(블프제외)", "하락구간"]]

    x = np.arange(len(pivot.index))
    width = 0.32

    fig, ax = plt.subplots(figsize=(7, 5.5))
    bars1 = ax.bar(x - width / 2, pivot["평상시(블프제외)"], width, label="평상시(블프제외)", color=BASELINE_COLOR)
    bars2 = ax.bar(x + width / 2, pivot["하락구간"], width, label="하락구간", color=DECLINE_COLOR)

    for bars in (bars1, bars2):
        for b in bars:
            ax.annotate(f"{b.get_height():.1f}%", (b.get_x() + b.get_width() / 2, b.get_height()),
                        textcoords="offset points", xytext=(0, 4), ha="center", fontsize=9)

    ax.set_xticks(x)
    ax.set_xticklabels(["그외형\n(의류·가방·음용기 등)", "저관여형\n(문구·브랜드기념품 등)"])
    ax.set_ylabel("cart→checkout 전환율 (%)")
    ax.set_title("카테고리 유형별 전환율 (p=0.035)")
    ax.legend()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "hypothesis1_category_type_conversion.png", dpi=150)
    plt.close(fig)


def plot_lag_days_by_type():
    df = read_csv("107_lag_days_by_type_excl_bf")
    pivot = df.pivot(index="user_type", columns="period", values="pct_lag_7d_plus")
    pivot = pivot.loc[["그외형", "저관여형"]][["평상시(블프제외)", "하락구간"]]

    x = np.arange(len(pivot.index))
    width = 0.32

    fig, ax = plt.subplots(figsize=(7, 5.5))
    bars1 = ax.bar(x - width / 2, pivot["평상시(블프제외)"], width, label="평상시(블프제외)", color=BASELINE_COLOR)
    bars2 = ax.bar(x + width / 2, pivot["하락구간"], width, label="하락구간", color=DECLINE_COLOR)

    for bars in (bars1, bars2):
        for b in bars:
            ax.annotate(f"{b.get_height():.2f}%", (b.get_x() + b.get_width() / 2, b.get_height()),
                        textcoords="offset points", xytext=(0, 4), ha="center", fontsize=9)

    ax.set_xticks(x)
    ax.set_xticklabels(["그외형\n(의류·가방·음용기 등)", "저관여형\n(문구·브랜드기념품 등)"])
    ax.set_ylabel("담기→결제시작 지연 7일 이상 비율 (%)")
    ax.set_title("카테고리 유형별 지연일수 (p=1.9e-10)")
    ax.legend()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "hypothesis1_lag_days_by_type.png", dpi=150)
    plt.close(fig)


def plot_hats_weekly_trend():
    cart = read_csv("102_leather_strap_hat_weekly_cart")
    purchase = read_csv("93_leather_strap_hat_weekly")

    cart["week_start"] = pd.to_datetime(cart["week_start"])
    purchase["week_start"] = pd.to_datetime(purchase["week_start"])

    weeks = sorted(cart["week_start"].unique())
    fig, axes = plt.subplots(1, 2, figsize=(13, 5.5), sharey=False)

    for ax, item in zip(axes, ["Google Leather Strap Hat Black", "Google Leather Strap Hat Blue"]):
        c = cart[cart["item_name"] == item].set_index("week_start")["cart_adds"].reindex(weeks, fill_value=0)
        p = purchase[purchase["item_name"] == item].set_index("week_start")["purchases"].reindex(weeks, fill_value=0)

        ax.plot(weeks, c.values, marker="o", color="#2563eb", label="담기(add_to_cart)")
        ax.plot(weeks, p.values, marker="o", color=DECLINE_COLOR, label="구매(purchase)")
        ax.axvspan(pd.Timestamp(DECLINE_START), pd.Timestamp(DECLINE_END), color="red", alpha=0.08)
        ax.set_title(item.replace("Google Leather Strap Hat ", ""))
        ax.tick_params(axis="x", rotation=45)
        ax.set_ylabel("건수")

    axes[0].legend(loc="upper right")
    fig.suptitle("Hats 주간 추이: 담기 유지, 구매 0")
    fig.tight_layout()
    fig.savefig(OUT_DIR / "hypothesis1_hats_weekly_trend.png", dpi=150)
    plt.close(fig)


def _donut(ax, labels, sizes, title, top_n=7):
    order = np.argsort(sizes)[::-1]
    labels = np.array(labels)[order]
    sizes = np.array(sizes)[order]

    if len(labels) > top_n:
        top_labels, top_sizes = list(labels[:top_n]), list(sizes[:top_n])
        rest = sizes[top_n:].sum()
        top_labels.append("기타")
        top_sizes.append(rest)
        labels, sizes = top_labels, top_sizes

    cmap = plt.get_cmap("tab20")
    colors = [cmap(i) for i in range(len(labels))]
    wedges, _, _ = ax.pie(
        sizes, colors=colors, startangle=90, wedgeprops=dict(width=0.4),
        autopct=lambda p: f"{int(p)}%", pctdistance=0.8,
        textprops=dict(fontsize=7, color="black"),
    )
    ax.legend(wedges, [f"{l} ({s:.1f}%)" for l, s in zip(labels, sizes)],
              loc="center left", bbox_to_anchor=(1.0, 0.5), fontsize=8, frameon=False)
    ax.set_title(title, fontsize=11)


def plot_category_donuts_by_stage(name, csv_name, category_col="category_clean"):
    df = read_csv(csv_name)
    fig, axes = plt.subplots(1, 2, figsize=(13, 6))
    for ax, period in zip(axes, ["평상시(블프제외)", "하락구간"]):
        sub = df[df["period"] == period]
        _donut(ax, sub[category_col].values, sub["pct"].values, period)
    fig.suptitle(f"{name} 카테고리 비중")
    fig.tight_layout()
    fig.savefig(OUT_DIR / f"hypothesis1_{name}_category_donut.png", dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    plot_stage_price_trend()
    plot_category_survival_ratio()
    plot_category_type_conversion()
    plot_lag_days_by_type()
    plot_hats_weekly_trend()
    plot_category_donuts_by_stage("cart", "117_cart_category_excl_bf_cleaned")
    plot_category_donuts_by_stage("checkout", "118_checkout_category_excl_bf_cleaned")
    plot_category_donuts_by_stage("purchase", "119_purchase_category_excl_bf_cleaned")
    print(f"차트 8개 저장됨: {OUT_DIR}")
