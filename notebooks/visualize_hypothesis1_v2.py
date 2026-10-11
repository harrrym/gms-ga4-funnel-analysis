"""
docs/07 시각화 v2. v1(visualize_hypothesis1.py, reports/charts/)은 그대로 보존하고,
이 스크립트는 reports/charts_v2/에 별도로 저장한다 (나중에 비교용).

v1 대비 바뀐 것:
1. "평상시" 기준 구간을 코드 상단 변수(BASELINE_LABEL/DECLINE_RANGE/BF_RANGE)로 분리.
   값 자체는 v1에서 이미 적용한 "블프 제외" 정의와 동일 — 즉 숫자는 안 바뀌고 구조만 바뀐다.
   (주의: 실제 BigQuery 집계는 여전히 sql/102~119의 고정 쿼리 결과를 읽는다. 쿼리 자체를
   이 변수로 매번 다시 돌리는 템플릿화는 안 했다 - 일회성 분석 스크립트에 과한 엔지니어링이라 판단.)
2. 카테고리 색을 CATEGORY_COLORS 딕셔너리로 고정 - 모든 차트에서 같은 카테고리=같은 색.
   기간 색은 PERIOD_COLORS로 통일 (평상시=회색, 하락구간=빨강, 블프구간=주황).
3. 장바구니 카테고리 비중은 도넛 대신 "비중 변화(%p) 가로 막대"로 교체 (카테고리별 고정색 사용).
   결제시작/구매 도넛은 유지하되 wedge 색을 고정 매핑으로 교체(기존엔 순위별 tab20 색이라
   왼쪽/오른쪽 도넛에서 같은 색이 다른 카테고리를 가리키는 문제가 있었음).
4. Hats 주간 추이(라인차트)는 기준선과 무관해 재계산하지 않고, 블프 주 배경 음영만 추가.

사용법:
    python notebooks/visualize_hypothesis1_v2.py
"""
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
from category_mapping import CATEGORY_MAP

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
OUT_DIR = PROJECT_ROOT / "reports" / "charts_v2"
OUT_DIR.mkdir(parents=True, exist_ok=True)

plt.rcParams["font.family"] = "Malgun Gothic"
plt.rcParams["axes.unicode_minus"] = False

# ---- 기준선 정의 (변수 하나로 관리) ----
DECLINE_RANGE = ("2020-12-14", "2021-01-11")
BF_RANGE = ("2020-11-23", "2020-11-30")  # 프로모션 기간이라 "평상시"에서 제외

BASELINE_LABEL = "평상시(블프제외)"
DECLINE_LABEL = "하락구간"
BF_LABEL = "블프구간"

PERIOD_COLORS = {
    BASELINE_LABEL: "#94a3b8",  # 회색
    DECLINE_LABEL: "#dc2626",   # 빨강(강조)
    BF_LABEL: "#f59e0b",        # 주황
}

# ---- 카테고리 색 고정 매핑 (모든 차트 공통) ----
_CATEGORIES = sorted(set(CATEGORY_MAP.values()))
_palette = [plt.get_cmap("tab20")(i) for i in range(20)] + [plt.get_cmap("tab20b")(i) for i in range(20)]
CATEGORY_COLORS = {cat: _palette[i % len(_palette)] for i, cat in enumerate(_CATEGORIES)}
CATEGORY_COLORS["기타/미분류"] = "#cbd5e1"


def read_csv(name):
    return pd.read_csv(DATA_DIR / f"{name}.csv", encoding="utf-8-sig")


def plot_stage_price_trend():
    price110 = read_csv("110_stage_price_trend_excl_bf")
    price112 = read_csv("112_cart_price_excl_bf")

    def get110(event_name, period):
        return price110[(price110["event_name"] == event_name) & (price110["period"] == period)]["avg_price"].iloc[0]

    def get112(period):
        return price112[price112["period"] == period]["avg_price"].iloc[0]

    stages = ["노출\n(view_item)", "담김\n(add_to_cart)", "결제시작\n(begin_checkout)"]
    baseline = [get110("view_item", BASELINE_LABEL), get112(BASELINE_LABEL), get110("begin_checkout", BASELINE_LABEL)]
    decline = [get110("view_item", DECLINE_LABEL), get112(DECLINE_LABEL), get110("begin_checkout", DECLINE_LABEL)]

    x = np.arange(len(stages))
    width = 0.32

    fig, ax = plt.subplots(figsize=(8, 5.5))
    bars1 = ax.bar(x - width / 2, baseline, width, label=BASELINE_LABEL, color=PERIOD_COLORS[BASELINE_LABEL])
    bars2 = ax.bar(x + width / 2, decline, width, label=DECLINE_LABEL, color=PERIOD_COLORS[DECLINE_LABEL])

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

    survival_baseline = (checkout_pivot[BASELINE_LABEL] / cart_pivot[BASELINE_LABEL]) * 100
    survival_decline = (checkout_pivot[DECLINE_LABEL] / cart_pivot[DECLINE_LABEL]) * 100
    change = (survival_decline - survival_baseline).drop(index="기타/미분류", errors="ignore").dropna().sort_values()

    colors = [CATEGORY_COLORS.get(c, "#999999") for c in change.index]

    fig, ax = plt.subplots(figsize=(9, 8))
    ax.barh(change.index, change.values, color=colors)
    ax.axvline(0, color="black", linewidth=0.8)
    ax.set_xlabel("생존비율 변화 (%p)")
    ax.set_title("카테고리별 생존비율 변화")
    fig.tight_layout()
    fig.savefig(OUT_DIR / "hypothesis1_category_survival_ratio.png", dpi=150)
    plt.close(fig)


def plot_category_type_conversion():
    df = read_csv("106_category_type_conversion_excl_bf")
    pivot = df.pivot(index="user_type", columns="period", values="cart_to_checkout_rate")
    pivot = pivot.loc[["그외형", "저관여형"]][[BASELINE_LABEL, DECLINE_LABEL]]

    x = np.arange(len(pivot.index))
    width = 0.32

    fig, ax = plt.subplots(figsize=(7, 5.5))
    bars1 = ax.bar(x - width / 2, pivot[BASELINE_LABEL], width, label=BASELINE_LABEL, color=PERIOD_COLORS[BASELINE_LABEL])
    bars2 = ax.bar(x + width / 2, pivot[DECLINE_LABEL], width, label=DECLINE_LABEL, color=PERIOD_COLORS[DECLINE_LABEL])

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
    pivot = pivot.loc[["그외형", "저관여형"]][[BASELINE_LABEL, DECLINE_LABEL]]

    x = np.arange(len(pivot.index))
    width = 0.32

    fig, ax = plt.subplots(figsize=(7, 5.5))
    bars1 = ax.bar(x - width / 2, pivot[BASELINE_LABEL], width, label=BASELINE_LABEL, color=PERIOD_COLORS[BASELINE_LABEL])
    bars2 = ax.bar(x + width / 2, pivot[DECLINE_LABEL], width, label=DECLINE_LABEL, color=PERIOD_COLORS[DECLINE_LABEL])

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
    # 기준선과 무관한 주별 추이라 재계산하지 않음. 블프 주 배경 음영만 추가.
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
        ax.plot(weeks, p.values, marker="o", color=PERIOD_COLORS[DECLINE_LABEL], label="구매(purchase)")
        ax.axvspan(pd.Timestamp(DECLINE_RANGE[0]), pd.Timestamp(DECLINE_RANGE[1]),
                   color=PERIOD_COLORS[DECLINE_LABEL], alpha=0.08, label="하락구간")
        ax.axvspan(pd.Timestamp(BF_RANGE[0]), pd.Timestamp(BF_RANGE[1]),
                   color=PERIOD_COLORS[BF_LABEL], alpha=0.15, label="블프구간")
        ax.set_title(item.replace("Google Leather Strap Hat ", ""))
        ax.tick_params(axis="x", rotation=45)
        ax.set_ylabel("건수")

    handles, labels = axes[0].get_legend_handles_labels()
    axes[0].legend(handles, labels, loc="upper right", fontsize=8)
    fig.suptitle("Hats 주간 추이: 담기 유지, 구매 0 (블프 주 표시)")
    fig.tight_layout()
    fig.savefig(OUT_DIR / "hypothesis1_hats_weekly_trend.png", dpi=150)
    plt.close(fig)


def plot_cart_category_change():
    # 도넛 폐기 -> "하락구간 - 평상시" 비중 변화(%p) 다이버징 가로막대로 교체.
    df = read_csv("117_cart_category_excl_bf_cleaned")
    pivot = df.pivot(index="category_clean", columns="period", values="pct")
    base = pivot[BASELINE_LABEL]
    decl = pivot[DECLINE_LABEL]
    both = pd.DataFrame({"base": base, "decl": decl}).drop(index="기타/미분류", errors="ignore").dropna()
    both["change"] = both["decl"] - both["base"]
    both = both.sort_values("change")

    colors = [CATEGORY_COLORS.get(c, "#999999") for c in both.index]

    fig, ax = plt.subplots(figsize=(10, max(6, len(both) * 0.38)))
    bars = ax.barh(both.index, both["change"], color=colors)
    ax.axvline(0, color="black", linewidth=0.8)

    xmin, xmax = ax.get_xlim()
    span = xmax - xmin
    for i, (cat, row) in enumerate(both.iterrows()):
        val = row["change"]
        label = f"{val:+.1f}%p ({row['base']:.1f}%→{row['decl']:.1f}%)"
        offset = span * 0.015
        if val >= 0:
            ax.text(val + offset, i, label, va="center", ha="left", fontsize=7)
        else:
            ax.text(val - offset, i, label, va="center", ha="right", fontsize=7)

    ax.set_xlim(xmin - span * 0.05, xmax + span * 0.05)
    ax.set_xlabel("장바구니 비중 변화: 하락구간 - 평상시 (%p)")
    ax.set_title("하락구간엔 모자(Hats)가 빠지고 세일/의류/음용기가 그 자리를 채웠다")
    fig.tight_layout()
    fig.savefig(OUT_DIR / "hypothesis1_cart_category_change.png", dpi=150)
    plt.close(fig)


def _donut_fixed_colors(ax, labels, sizes, title, top_n=7):
    order = np.argsort(sizes)[::-1]
    labels = np.array(labels)[order]
    sizes = np.array(sizes)[order]

    if len(labels) > top_n:
        top_labels, top_sizes = list(labels[:top_n]), list(sizes[:top_n])
        rest = sizes[top_n:].sum()
        top_labels.append("기타")
        top_sizes.append(rest)
        labels, sizes = top_labels, top_sizes

    colors = [CATEGORY_COLORS.get(l, "#999999") for l in labels]
    wedges, _, _ = ax.pie(
        sizes, colors=colors, startangle=90, wedgeprops=dict(width=0.4),
        autopct=lambda p: f"{int(p)}%", pctdistance=0.8,
        textprops=dict(fontsize=7, color="black"),
    )
    ax.legend(wedges, [f"{l} ({s:.1f}%)" for l, s in zip(labels, sizes)],
              loc="center left", bbox_to_anchor=(1.0, 0.5), fontsize=8, frameon=False)
    ax.set_title(title, fontsize=11)


def plot_category_donut_fixed_colors(name, csv_name, category_col="category_clean"):
    # 결제시작/구매는 도넛 유지, wedge 색만 카테고리 고정 매핑으로 교체(순위색 -> 카테고리색).
    df = read_csv(csv_name)
    fig, axes = plt.subplots(1, 2, figsize=(13, 6))
    for ax, period in zip(axes, [BASELINE_LABEL, DECLINE_LABEL]):
        sub = df[df["period"] == period]
        _donut_fixed_colors(ax, sub[category_col].values, sub["pct"].values, period)
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
    plot_cart_category_change()
    plot_category_donut_fixed_colors("checkout", "118_checkout_category_excl_bf_cleaned")
    plot_category_donut_fixed_colors("purchase", "119_purchase_category_excl_bf_cleaned")
    print(f"차트 7개 저장됨: {OUT_DIR}")
