"""
docs/04, docs/07 차트 최종본 (v3 기준선: 평상시=12/1~12/13, 하락구간=12/14~1/11).

charts/, charts_v2/의 이전 버전을 대체한다 (이전 버전은 reports/charts/_archive/로 이동).
공통 규칙: 범례에 날짜 직접 표기, 기간 색 고정(평상시=회색/하락구간=빨강/블프=주황),
제목은 결론형 문장, 부제목에 집계 기준과 검정명 표기.

사용법:
    python notebooks/visualize_v3.py
"""
import sys
from pathlib import Path

import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
from category_mapping import CATEGORY_MAP

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
OUT_DIR = PROJECT_ROOT / "reports" / "charts_v3"
OUT_DIR.mkdir(parents=True, exist_ok=True)
OUT_DIR_VER2 = PROJECT_ROOT / "reports" / "charts_ver2"  # docs/09용 OMTM 재정의 차트
OUT_DIR_VER2.mkdir(parents=True, exist_ok=True)

plt.rcParams["font.family"] = "Malgun Gothic"
plt.rcParams["axes.unicode_minus"] = False

# ---- 기간 정의 (notebooks/period_config.py와 동일한 날짜. CSV의 period 컬럼은 짧은 라벨을 쓴다) ----
BASELINE = "평상시"
DECLINE = "하락구간"
POST = "사후구간"

BASELINE_RANGE = ("2020-12-01", "2020-12-13")
DECLINE_RANGE = ("2020-12-14", "2021-01-11")
BF_RANGE = ("2020-11-23", "2020-11-30")
NOV_UNRELIABLE_RANGE = ("2020-11-01", "2020-11-22")  # 추적 불완전(상품 정보 0개) 구간

LEGEND = {
    BASELINE: "12월 초(12/1~12/13)",
    DECLINE: "하락구간(12/14~1/11)",
    "BF": "블프구간(11/23~11/30)",
    "NOV": "11월 초(추적 불완전, 기준 제외)",
}

PERIOD_COLORS = {
    BASELINE: "#94a3b8",
    DECLINE: "#dc2626",
    "BF": "#f59e0b",
}

_CATEGORIES = sorted(set(CATEGORY_MAP.values()))
_palette = [plt.get_cmap("tab20")(i) for i in range(20)] + [plt.get_cmap("tab20b")(i) for i in range(20)]
CATEGORY_COLORS = {cat: _palette[i % len(_palette)] for i, cat in enumerate(_CATEGORIES)}
CATEGORY_COLORS["기타/미분류"] = "#cbd5e1"


def read_csv(name):
    return pd.read_csv(DATA_DIR / f"{name}.csv", encoding="utf-8-sig")


def _shade_common(ax, with_nov=False):
    ax.axvspan(pd.Timestamp(BASELINE_RANGE[0]), pd.Timestamp(BASELINE_RANGE[1]),
               color=PERIOD_COLORS[BASELINE], alpha=0.15, label=LEGEND[BASELINE])
    ax.axvspan(pd.Timestamp(DECLINE_RANGE[0]), pd.Timestamp(DECLINE_RANGE[1]),
               color=PERIOD_COLORS[DECLINE], alpha=0.10, label=LEGEND[DECLINE])
    ax.axvspan(pd.Timestamp(BF_RANGE[0]), pd.Timestamp(BF_RANGE[1]),
               color=PERIOD_COLORS["BF"], alpha=0.25, label=LEGEND["BF"])
    if with_nov:
        ax.axvspan(pd.Timestamp(NOV_UNRELIABLE_RANGE[0]), pd.Timestamp(NOV_UNRELIABLE_RANGE[1]),
                   facecolor="#94a3b8", edgecolor="#64748b", hatch="//", alpha=0.18,
                   label=LEGEND["NOV"])


def _grouped_bar(ax, labels, baseline_vals, decline_vals, fmt="{:.2f}%"):
    x = np.arange(len(labels))
    width = 0.32
    bars1 = ax.bar(x - width / 2, baseline_vals, width, label=LEGEND[BASELINE], color=PERIOD_COLORS[BASELINE])
    bars2 = ax.bar(x + width / 2, decline_vals, width, label=LEGEND[DECLINE], color=PERIOD_COLORS[DECLINE])
    for bars in (bars1, bars2):
        for b in bars:
            ax.annotate(fmt.format(b.get_height()), (b.get_x() + b.get_width() / 2, b.get_height()),
                        textcoords="offset points", xytext=(0, 4), ha="center", fontsize=9)
    ax.set_xticks(x)
    ax.set_xticklabels(labels)
    return bars1, bars2


# ---------------------------------------------------------------------------
# problem_
# ---------------------------------------------------------------------------

def plot_problem_checkout_conversion_trend():
    df = read_csv("36_checkout_user_level_cohort")
    df["cohort_week"] = pd.to_datetime(df["cohort_week"])
    df = df[df["cohort_week"] >= "2020-11-01"]

    fig, ax = plt.subplots(figsize=(12, 6))
    _shade_common(ax, with_nov=True)
    last = df["cohort_week"].max()  # 1/25 주: 관측 종료(1/31)까지 7일 미만 -> 우측 절단
    main, tail = df[df["cohort_week"] < last], df[df["cohort_week"] >= df["cohort_week"].sort_values().iloc[-2]]
    ax.plot(main["cohort_week"], main["cart_to_checkout_rate"], marker="o", color="#1e293b",
            linewidth=2, zorder=5, label="cart→checkout 전환율")
    ax.plot(tail["cohort_week"], tail["cart_to_checkout_rate"], color="#1e293b", linewidth=2,
            linestyle="--", alpha=0.35, zorder=5)
    ax.plot(df[df["cohort_week"] == last]["cohort_week"], df[df["cohort_week"] == last]["cart_to_checkout_rate"],
            marker="o", color="#1e293b", alpha=0.3, zorder=5)
    for _, row in df.iterrows():
        faded = row["cohort_week"] == last
        ax.annotate(f"{row['cart_to_checkout_rate']:.1f}%",
                    (row["cohort_week"], row["cart_to_checkout_rate"]),
                    textcoords="offset points", xytext=(0, 8), ha="center", fontsize=7.5,
                    alpha=0.4 if faded else 1.0)
    last_row = df[df["cohort_week"] == last].iloc[0]
    ax.annotate("관측 기간 부족\n(1/31 종료, 7일 미만)", (last, last_row["cart_to_checkout_rate"]),
                textcoords="offset points", xytext=(-4, -34), ha="center", fontsize=7.5,
                color="#64748b", alpha=0.9)

    ax.set_xlim(pd.Timestamp("2020-11-01"), pd.Timestamp("2021-01-31"))
    ax.set_ylabel("cart→checkout 전환율 (%)")
    ax.set_title("담기→결제시작 전환율은 12/14부터 크게 떨어졌다가 1/18 주에 회복세를 보였다", fontsize=13)
    ax.set_xlabel("")
    fig.text(0.5, 0.925, "집계 기준: 유저 코호트(첫 add_to_cart 시점), 주간(cohort_week) · sql/36",
              ha="center", fontsize=9, color="#555555")
    handles, labels_ = ax.get_legend_handles_labels()
    by_label = dict(zip(labels_, handles))
    ax.legend(by_label.values(), by_label.keys(), loc="lower left", fontsize=8.5)
    ax.tick_params(axis="x", rotation=45)
    fig.tight_layout(rect=(0, 0, 1, 0.93))
    fig.savefig(OUT_DIR / "problem_checkout_conversion_trend.png", dpi=150)
    plt.close(fig)


def plot_problem_funnel():
    df = read_csv("160_single_cohort_funnel_v3").set_index("period")
    stages = ["cart→checkout", "checkout→purchase\n(코호트 내)"]
    baseline = [df.loc[BASELINE, "cart_to_checkout_rate"], df.loc[BASELINE, "checkout_to_purchase_rate_within_cohort"]]
    decline = [df.loc[DECLINE, "cart_to_checkout_rate"], df.loc[DECLINE, "checkout_to_purchase_rate_within_cohort"]]

    fig, ax = plt.subplots(figsize=(8.5, 6))
    _grouped_bar(ax, stages, baseline, decline)
    ax.annotate("", xy=(0, baseline[0] - 4), xytext=(0, baseline[0] + 1),
                arrowprops=dict(arrowstyle="-|>", color="#dc2626", lw=2))
    ax.annotate("", xy=(1, decline[1] - 4), xytext=(1, baseline[1] + 1),
                arrowprops=dict(arrowstyle="-|>", color="#16a34a", lw=2))
    ax.set_ylabel("전환율 (%)")
    ax.set_ylim(0, 72)
    n_b, n_d = int(df.loc[BASELINE, "cart_users"]), int(df.loc[DECLINE, "cart_users"])
    ax.set_title("담기→결제시작은 크게 떨어졌지만 결제시작→구매는 오히려 좋아졌다", fontsize=12.5)
    fig.text(0.5, 0.93,
              f"집계 기준: 단일 코호트(첫 add_to_cart 유저, n={n_b:,}/{n_d:,}) · "
              "cart→checkout χ²=174.50 p=7.72e-40, checkout→purchase χ²=36.96 p=1.2e-9",
              ha="center", fontsize=8.3, color="#555555")
    ax.legend(loc="upper center", fontsize=9)
    fig.tight_layout(rect=(0, 0, 1, 0.91))
    fig.savefig(OUT_DIR / "problem_funnel.png", dpi=150)
    plt.close(fig)



# ---------------------------------------------------------------------------
# problem_ (docs/09: OMTM 일별 추이, 단계별 지수)
# ---------------------------------------------------------------------------

# docs/09 기간 구분 (기준선 / 선행 신호 구간 / 하락구간 / 회복기)
P9 = {
    "base": ("12월 초 기준선(12/1~12/13)", ("2020-12-01", "2020-12-13"), "#94a3b8", 0.18),
    "lead": ("선행 신호 구간(12/14~12/18)", ("2020-12-14", "2020-12-18"), "#3b82f6", 0.13),
    "decl": ("하락구간(12/19~1/11)", ("2020-12-19", "2021-01-11"), "#dc2626", 0.10),
    "rec": ("회복기(1/12~1/31)", ("2021-01-12", "2021-01-31"), "#16a34a", 0.10),
}


def _shade_periods9(ax):
    for key in ("base", "lead", "decl", "rec"):
        label, (a, b), color, alpha = P9[key]
        ax.axvspan(pd.Timestamp(a), pd.Timestamp(b) + pd.Timedelta(days=1), color=color, alpha=alpha, label=label)


def _daily_funnel():
    d = read_csv("207_daily_session_funnel_list_exposure")
    d["session_date"] = pd.to_datetime(d["session_date"])
    d = d.set_index("session_date")
    d.columns = ["s0", "s1", "s2", "s3", "s4"]
    return d


def _stage_rates(x):
    return pd.DataFrame({"OMTM": x.s4 / x.s0, "①": x.s1 / x.s0, "②": x.s2 / x.s1,
                         "③": x.s3 / x.s2, "④": x.s4 / x.s3})


def plot_problem_omtm_daily():
    d = _daily_funnel()
    daily = d.s4 / d.s0 * 100
    ma = _stage_rates(d.rolling(7).sum())["OMTM"] * 100
    base = d.loc[P9["base"][1][0]:P9["base"][1][1]]
    base_rate = base.s4.sum() / base.s0.sum() * 100

    fig, ax = plt.subplots(figsize=(12, 6.6))
    _shade_periods9(ax)
    ax.plot(daily.index, daily.values, color="#94a3b8", linewidth=1, marker="o", markersize=2.5, alpha=0.7,
            label="일별 구매전환율", zorder=3)
    ax.plot(ma.index, ma.values, color="#1e293b", linewidth=2.4, label="7일 이동평균", zorder=5)
    ax.axhline(base_rate, color="#475569", linestyle=":", linewidth=1.2, label=f"12월 초 평균 {base_rate:.2f}%")

    for date, text, dy in (("2020-12-20", "하락 시작\n(12/19~20)", 0.75), ("2021-01-07", "바닥\n(1/7, 0.52%)", 0.62),
                           ("2021-01-22", "절반 회복\n(1/22)", 0.45)):
        t = pd.Timestamp(date)
        ax.annotate(text, (t, ma.loc[t]), xytext=(t, ma.loc[t] + dy), ha="center", fontsize=8.5, color="#1e293b",
                    arrowprops=dict(arrowstyle="-", color="#475569", lw=0.8))

    ax.set_xlim(pd.Timestamp("2020-11-01"), pd.Timestamp("2021-01-31"))
    ax.set_ylim(0, 3.0)
    ax.set_ylabel("구매전환율 (%)")
    ax.set_title("구매전환율, 12/19부터 급락", fontsize=14)
    fig.text(0.5, 0.945, "집계 기준: 세션 단위(구매 세션/전체 세션), 세션 첫 이벤트 날짜 기준, 7일 이동평균은 7일 합계의 비율 · sql/207",
             ha="center", fontsize=9, color="#555555")
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.16), ncol=3, fontsize=8.5, frameon=False)
    ax.tick_params(axis="x", rotation=45)
    fig.tight_layout(rect=(0, 0, 1, 0.94))
    fig.savefig(OUT_DIR_VER2 / "problem_omtm_daily.png", dpi=150, bbox_inches="tight")
    plt.close(fig)


def plot_problem_stage_index():
    d = _daily_funnel()
    base_rates = _stage_rates(d.loc[P9["base"][1][0]:P9["base"][1][1]].sum().to_frame().T).iloc[0]
    idx = _stage_rates(d.rolling(7).sum()) / base_rates * 100

    series = [("OMTM", "OMTM (구매 세션/세션)", "#111827", 3.0),
              ("①", "① 방문→목록 노출", "#2563eb", 1.7),
              ("②", "② 목록 노출→담기", "#7c3aed", 2.2),
              ("③", "③ 담기→결제시작", "#16a34a", 1.7),
              ("④", "④ 결제시작→구매", "#92400e", 1.7)]
    nov_end = pd.Timestamp("2020-12-06")  # 7일 이동평균 창이 11월을 벗어나는 첫 날

    fig, ax = plt.subplots(figsize=(12.5, 7.4))
    ax.axvspan(pd.Timestamp("2020-11-01"), pd.Timestamp("2020-12-01"), facecolor="none", edgecolor="#64748b",
               hatch="//", alpha=0.25, label="11월(담기 추적 불완전: ②③ 흐리게)")
    _shade_periods9(ax)
    for key, label, color, lw in series:
        s = idx[key].dropna()
        if key in ("②", "③"):  # 담기가 들어간 지표: 11월은 추적 불완전 -> 흐리게
            ax.plot(s.loc[:nov_end].index, s.loc[:nov_end].values, color=color, linewidth=lw, alpha=0.25, linestyle="--")
            ax.plot(s.loc[nov_end:].index, s.loc[nov_end:].values, color=color, linewidth=lw, label=label, zorder=4)
        else:
            ax.plot(s.index, s.values, color=color, linewidth=lw, label=label, zorder=3)
    ax.axhline(100, color="#475569", linestyle=":", linewidth=1.2)

    ax.axvline(pd.Timestamp("2020-12-18"), color="#b45309", linestyle="--", linewidth=1.5, zorder=2, label="배송 마감 12/18")
    s2 = idx["②"].dropna()
    cps = [pd.Timestamp(x) for x in ("2020-12-16", "2020-12-19", "2020-12-24")]
    ax.plot(cps, [s2.loc[t] for t in cps], linestyle="none", marker="v", markersize=9, color="#4c1d95",
            markeredgecolor="white", zorder=6, label="② 변화점(12/16·12/19·12/24)")
    for t, ylab in zip(cps, (10, 24, 10)):
        ax.vlines(t, ylab + 6, s2.loc[t] - 3, colors="#4c1d95", linestyles=":", linewidth=0.9, zorder=2)
        ax.text(t, ylab, f"② {t.strftime('%m/%d')}", ha="center", va="center", fontsize=8, color="#4c1d95",
                bbox=dict(boxstyle="round,pad=0.2", facecolor="white", edgecolor="#4c1d95", linewidth=0.6), zorder=7)

    ax.set_xlim(pd.Timestamp("2020-11-01"), pd.Timestamp("2021-01-31"))
    ax.set_ylim(0, 150)
    ax.set_ylabel("지수 (12월 초 12/1~12/13 = 100)")
    ax.set_title("OMTM 하락은 12/19경 시작됐고, ①②는 1월 말에도 12월 초의 71~81%에 머물렀다", fontsize=13)
    fig.text(0.5, 0.945, "집계 기준: 세션 단위, 7일 이동평균(7일 합계의 비율) · ① = 목록 경로 view_item 또는 이후 단계가 있는 세션 · ② 변화점은 일별 ②의 BIC 분할 · sql/207",
             ha="center", fontsize=8.5, color="#555555")
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.13), ncol=3, fontsize=8.3, frameon=False)
    ax.tick_params(axis="x", rotation=45)
    fig.tight_layout(rect=(0, 0, 1, 0.94))
    fig.savefig(OUT_DIR_VER2 / "problem_stage_index.png", dpi=150, bbox_inches="tight")
    plt.close(fig)


# ---------------------------------------------------------------------------
# hypothesis1_
# ---------------------------------------------------------------------------

def plot_hypothesis1_stage_price_trend():
    price_stage = read_csv("168_stage_price_v3")
    price_cart = read_csv("169_cart_price_v3")

    def get_stage(event_name, period):
        return price_stage[(price_stage["event_name"] == event_name) & (price_stage["period"] == period)]["avg_price"].iloc[0]

    def get_cart(period):
        return price_cart[price_cart["period"] == period]["avg_price"].iloc[0]

    stages = ["노출\n(view_item)", "담김\n(add_to_cart)", "결제시작\n(begin_checkout)"]
    baseline = [get_stage("view_item", BASELINE), get_cart(BASELINE), get_stage("begin_checkout", BASELINE)]
    decline = [get_stage("view_item", DECLINE), get_cart(DECLINE), get_stage("begin_checkout", DECLINE)]

    fig, ax = plt.subplots(figsize=(8.5, 6))
    _grouped_bar(ax, stages, baseline, decline, fmt="${:.2f}")
    ax.set_ylabel("가중평균 단가 ($)")
    ax.set_title("노출 단가는 그대로인데, 담긴 상품 단가만 하락구간에 올랐다", fontsize=12.5)
    fig.text(0.5, 0.935, "집계 기준: 이벤트 단위 가중평균 단가 · view_item -2.4%, add_to_cart +7.8%, begin_checkout -3.4%",
              ha="center", fontsize=8.5, color="#555555")
    fig.text(0.5, 0.905, "담김 단가 상승은 모자 비중 감소에 따른 구성 효과 (모자 제외 시 변화 없음)",
              ha="center", fontsize=8.5, color="#555555")
    ax.legend(loc="upper right", fontsize=9)
    fig.tight_layout(rect=(0, 0, 1, 0.89))
    fig.savefig(OUT_DIR / "hypothesis1_stage_price_trend.png", dpi=150)
    plt.close(fig)


def plot_hypothesis1_cart_category_change():
    cat = read_csv("174_category_conversion_v3_cleaned")
    funnel = read_csv("160_single_cohort_funnel_v3").set_index("period")
    n_baseline = funnel.loc[BASELINE, "cart_users"]
    n_decline = funnel.loc[DECLINE, "cart_users"]

    pivot = cat.pivot(index="category_clean", columns="period", values="users")
    base_share = (pivot[BASELINE] / n_baseline) * 100
    decl_share = (pivot[DECLINE] / n_decline) * 100
    both = pd.DataFrame({"base": base_share, "decl": decl_share}).drop(index="기타/미분류", errors="ignore").dropna()
    both["change"] = both["decl"] - both["base"]
    both = both.sort_values("change")

    colors = [CATEGORY_COLORS.get(c, "#999999") for c in both.index]

    fig, ax = plt.subplots(figsize=(10.5, max(6, len(both) * 0.4)))
    ax.barh(both.index, both["change"], color=colors)
    ax.axvline(0, color="black", linewidth=0.8)

    xmin, xmax = ax.get_xlim()
    span = xmax - xmin
    for i, (cat_name, row) in enumerate(both.iterrows()):
        val = row["change"]
        label = f"{val:+.1f}%p ({row['base']:.1f}%→{row['decl']:.1f}%)"
        offset = span * 0.015
        if val >= 0:
            ax.text(val + offset, i, label, va="center", ha="left", fontsize=7.3)
        else:
            ax.text(val - offset, i, label, va="center", ha="right", fontsize=7.3)
    ax.set_xlim(xmin - span * 0.22, xmax + span * 0.22)
    ax.set_xlabel("장바구니 담은 유저 비중 변화: 하락구간 - 12월 초 (%p)")
    ax.set_title("하락구간엔 장바구니에서 모자(Hats) 비중이 크게 줄었다", fontsize=12.5)
    fig.text(0.5, 0.965,
              f"집계 기준: 유저 단위(카트 코호트 중 해당 카테고리를 담은 유저 비율), n={n_baseline:,.0f}(12월 초)/{n_decline:,.0f}(하락구간) · sql/143,174",
              ha="center", fontsize=8.2, color="#555555")
    fig.tight_layout(rect=(0, 0, 1, 0.94))
    fig.savefig(OUT_DIR / "hypothesis1_cart_category_change.png", dpi=150)
    plt.close(fig)


# ---------------------------------------------------------------------------
# hypothesis2_
# ---------------------------------------------------------------------------

def plot_hypothesis2_lag_days_by_type():
    df = read_csv("161_lag_days_v3")
    pivot = df.pivot(index="user_type", columns="period", values="pct_lag_7d_plus")
    pivot = pivot.loc[["그외형", "저관여형"]][[BASELINE, DECLINE]]

    fig, ax = plt.subplots(figsize=(7.5, 6))
    _grouped_bar(ax, ["그외형\n(의류·가방·음용기 등)", "저관여형\n(문구·브랜드기념품 등)"],
                 pivot[BASELINE], pivot[DECLINE], fmt="{:.2f}%")
    ax.set_ylabel("담기→결제시작 지연 7일 이상 비율 (%)")
    ax.set_title("그외형 상품만 결제 결정을 7일 이상 미루는 비율이 2배 넘게 늘었다", fontsize=12.3)
    fig.text(0.5, 0.93, "집계 기준: 유저 단위(전환 성공 유저) · 그외형 χ²=25.18 p=5.2e-7, 저관여형 p=0.861(무의미)",
              ha="center", fontsize=8.5, color="#555555")
    ax.legend(loc="upper right", fontsize=9)
    fig.tight_layout(rect=(0, 0, 1, 0.91))
    fig.savefig(OUT_DIR / "hypothesis2_lag_days_by_type.png", dpi=150)
    plt.close(fig)


def plot_hypothesis2_category_type_conversion():
    df = read_csv("162_category_type_conversion_v3")
    pivot = df.pivot(index="user_type", columns="period", values="cart_to_checkout_rate")
    pivot = pivot.loc[["그외형", "저관여형"]][[BASELINE, DECLINE]]

    fig, ax = plt.subplots(figsize=(7.5, 6))
    _grouped_bar(ax, ["그외형\n(의류·가방·음용기 등)", "저관여형\n(문구·브랜드기념품 등)"],
                 pivot[BASELINE], pivot[DECLINE], fmt="{:.2f}%")
    ax.set_ylabel("cart→checkout 전환율 (%)")
    ax.set_title("그외형 카테고리의 전환율이 저관여형보다 더 크게 떨어졌다", fontsize=12.5)
    fig.text(0.5, 0.93, "집계 기준: 유저 단위 · Woolf 동질성 검정 p=0.0174",
              ha="center", fontsize=8.5, color="#555555")
    ax.legend(loc="upper right", fontsize=9)
    fig.tight_layout(rect=(0, 0, 1, 0.91))
    fig.savefig(OUT_DIR / "hypothesis2_category_type_conversion.png", dpi=150)
    plt.close(fig)


def plot_hypothesis2_weekly_purchase():
    df = read_csv("140_weekly_purchases_overview")
    df["week_start"] = pd.to_datetime(df["week_start"])
    df = df[df["week_start"] >= "2020-11-01"]

    fig, ax = plt.subplots(figsize=(12, 6))
    _shade_common(ax, with_nov=False)
    ax.plot(df["week_start"], df["purchase_events"], marker="o", color="#1e293b", linewidth=2, zorder=5,
            label="구매 건수")
    for _, row in df.iterrows():
        ax.annotate(f"{int(row['purchase_events'])}", (row["week_start"], row["purchase_events"]),
                    textcoords="offset points", xytext=(0, 8), ha="center", fontsize=7.5)

    ax.axvline(pd.Timestamp("2020-12-18"), color="#7c3aed", linestyle="--", linewidth=1.6, zorder=4)
    ax.annotate("배송 마감(12/18)", xy=(pd.Timestamp("2020-12-18"), ax.get_ylim()[1] * 0.92),
                xytext=(8, 0), textcoords="offset points", color="#7c3aed", fontsize=9, va="top")

    ax.set_xlim(pd.Timestamp("2020-11-01"), pd.Timestamp("2021-01-31"))
    ax.set_ylabel("주별 구매 건수")
    ax.set_title("구매는 12/07 주 정점 후 배송 마감 무렵부터 급감했다", fontsize=13)
    fig.text(0.5, 0.925, "집계 기준: 이벤트 단위(주별 purchase 이벤트 수) · sql/140",
              ha="center", fontsize=9, color="#555555")
    handles, labels_ = ax.get_legend_handles_labels()
    by_label = dict(zip(labels_, handles))
    ax.legend(by_label.values(), by_label.keys(), loc="upper right", fontsize=8.5)
    ax.tick_params(axis="x", rotation=45)
    fig.tight_layout(rect=(0, 0, 1, 0.93))
    fig.savefig(OUT_DIR / "hypothesis2_weekly_purchase.png", dpi=150)
    plt.close(fig)


# ---------------------------------------------------------------------------
# finding_stockout_
# ---------------------------------------------------------------------------

def plot_finding_stockout_hats_weekly_trend():
    cart = read_csv("102_leather_strap_hat_weekly_cart")
    purchase = read_csv("93_leather_strap_hat_weekly")
    cart["week_start"] = pd.to_datetime(cart["week_start"])
    purchase["week_start"] = pd.to_datetime(purchase["week_start"])

    weeks = pd.date_range("2020-11-01", "2021-01-25", freq="W-MON")
    fig, axes = plt.subplots(1, 2, figsize=(14, 6), sharey=False)

    crash_week = {"Google Leather Strap Hat Black": "11/30주부터 0건",
                  "Google Leather Strap Hat Blue": "12/14주부터 0건"}

    for ax, item in zip(axes, ["Google Leather Strap Hat Black", "Google Leather Strap Hat Blue"]):
        c = cart[cart["item_name"] == item].set_index("week_start")["cart_adds"].reindex(weeks, fill_value=0)
        p = purchase[purchase["item_name"] == item].set_index("week_start")["purchases"].reindex(weeks, fill_value=0)

        ax.axvspan(pd.Timestamp(NOV_UNRELIABLE_RANGE[0]), pd.Timestamp(NOV_UNRELIABLE_RANGE[1]),
                   facecolor="#94a3b8", edgecolor="#64748b", hatch="//", alpha=0.18,
                   label=LEGEND["NOV"])
        ax.axvspan(pd.Timestamp(BF_RANGE[0]), pd.Timestamp(BF_RANGE[1]),
                   color=PERIOD_COLORS["BF"], alpha=0.25, label=LEGEND["BF"])
        ax.axvspan(pd.Timestamp(BASELINE_RANGE[0]), pd.Timestamp(BASELINE_RANGE[1]),
                   color=PERIOD_COLORS[BASELINE], alpha=0.15, label=LEGEND[BASELINE])
        ax.axvspan(pd.Timestamp(DECLINE_RANGE[0]), pd.Timestamp(DECLINE_RANGE[1]),
                   color=PERIOD_COLORS[DECLINE], alpha=0.10, label=LEGEND[DECLINE])

        ax.plot(weeks, c.values, marker="o", color="#2563eb", label="담기(add_to_cart)")
        ax.plot(weeks, p.values, marker="o", color=PERIOD_COLORS[DECLINE], label="구매(purchase)")
        ax.set_title(f"{item.replace('Google Leather Strap Hat ', '')} — {crash_week[item]}", fontsize=10.5)
        ax.tick_params(axis="x", rotation=45)
        ax.set_ylabel("건수")
        ax.set_xlim(pd.Timestamp("2020-11-01"), pd.Timestamp("2021-01-25"))

    handles, labels_ = axes[0].get_legend_handles_labels()
    by_label = dict(zip(labels_, handles))
    axes[0].legend(by_label.values(), by_label.keys(), loc="upper right", fontsize=7.3)
    fig.suptitle("담기는 블프 전후 정점을 찍었지만, 품절 이후 구매는 멈췄다", fontsize=13)
    fig.text(0.5, 0.925, "집계 기준: 이벤트 단위(주별 건수), 11월 초는 add_to_cart 추적 자체가 불완전한 구간",
              ha="center", fontsize=8.5, color="#555555")
    fig.tight_layout(rect=(0, 0, 1, 0.90))
    fig.savefig(OUT_DIR / "finding_stockout_hats_weekly_trend.png", dpi=150)
    plt.close(fig)


# ---------------------------------------------------------------------------
# data_quality_
# ---------------------------------------------------------------------------

def plot_data_quality_tracking():
    cart_log = read_csv("158_weekly_purchasers_cart_check")
    items_log = read_csv("179_checkout_items_presence_weekly")
    cart_log["week_start"] = pd.to_datetime(cart_log["week_start"])
    items_log["week_start"] = pd.to_datetime(items_log["week_start"])

    fig, ax = plt.subplots(figsize=(12, 6))
    ax.axvspan(pd.Timestamp("2020-11-23"), pd.Timestamp("2020-11-30"),
               color="#16a34a", alpha=0.12, label="전환 구간(11/23~11/30)")
    ax.axvspan(pd.Timestamp(DECLINE_RANGE[0]), pd.Timestamp(DECLINE_RANGE[1]),
               color=PERIOD_COLORS[DECLINE], alpha=0.08, label=LEGEND[DECLINE])
    ax.axvspan(pd.Timestamp(BASELINE_RANGE[0]), pd.Timestamp(BASELINE_RANGE[1]),
               color=PERIOD_COLORS[BASELINE], alpha=0.15, label=LEGEND[BASELINE])

    ax.plot(cart_log["week_start"], cart_log["with_cart_pct"], marker="o", color="#2563eb",
            label="구매자 중 담기(add_to_cart) 기록 보유율")
    ax.plot(items_log["week_start"], items_log["pct_with_items"], marker="s", color="#dc2626",
            label="결제시작(begin_checkout) 중 상품 정보 있는 비율")

    ax.set_xlim(pd.Timestamp("2020-10-26"), pd.Timestamp("2021-01-31"))
    ax.set_ylabel("비율 (%)")
    ax.set_title("11월 추적은 11/23~11/30 사이에 안정화됐다", fontsize=13)
    fig.text(0.5, 0.925, "집계 기준: 구매자 단위(담기 기록 보유율, sql/158) / 결제시작 이벤트 단위(상품정보 보유율, sql/179)",
              ha="center", fontsize=8.8, color="#555555")
    ax.legend(loc="center right", fontsize=8.5)
    ax.tick_params(axis="x", rotation=45)
    fig.tight_layout(rect=(0, 0, 1, 0.93))
    fig.savefig(OUT_DIR / "data_quality_tracking.png", dpi=150)
    plt.close(fig)


def plot_data_quality_tracking_ver2():
    """docs/13용: 같은 데이터, 현재 기간 정의(P9)로 음영을 다시 그린다. charts_v3 원본(이전 기간 정의)은 그대로 둔다."""
    cart_log = read_csv("158_weekly_purchasers_cart_check")
    items_log = read_csv("179_checkout_items_presence_weekly")
    cart_log["week_start"] = pd.to_datetime(cart_log["week_start"])
    items_log["week_start"] = pd.to_datetime(items_log["week_start"])

    fig, ax = plt.subplots(figsize=(12, 6))
    ax.axvspan(pd.Timestamp(BF_RANGE[0]), pd.Timestamp(BF_RANGE[1]) + pd.Timedelta(days=1),
               color=PERIOD_COLORS["BF"], alpha=0.25, label="블랙프라이데이(11/23~11/30)")
    _shade_periods9(ax)
    ax.plot(cart_log["week_start"], cart_log["with_cart_pct"], marker="o", color="#2563eb",
            label="구매자 중 장바구니 담기(add_to_cart) 기록 보유율")
    ax.plot(items_log["week_start"], items_log["pct_with_items"], marker="s", color="#dc2626",
            label="결제 시작(begin_checkout) 중 상품 정보 있는 비율")
    ax.set_xlim(pd.Timestamp("2020-10-26"), pd.Timestamp("2021-01-31"))
    ax.set_ylim(-5, 105)
    ax.set_ylabel("비율 (%)")
    ax.set_title("11월 추적은 11/23~11/30 사이에 안정화됐다", fontsize=14)
    fig.text(0.5, 0.945, "집계 기준: 구매자 단위(담기 기록 보유율, sql/158) / 결제 시작 이벤트 단위(상품 정보 보유율, sql/179)",
             ha="center", fontsize=9, color="#555555")
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.09), ncol=3, fontsize=8.5, frameon=False)
    ticks = pd.date_range("2020-11-02", "2021-01-25", freq="14D")
    ax.set_xticks(ticks)
    ax.set_xticklabels([t.strftime("%m/%d") for t in ticks])
    ax.tick_params(axis="x", rotation=0)
    fig.tight_layout(rect=(0, 0, 1, 0.94))
    fig.savefig(OUT_DIR_VER2 / "data_quality_tracking.png", dpi=150, bbox_inches="tight")
    plt.close(fig)



# ---------------------------------------------------------------------------
# cause_ (docs/10 원인 분석 차트, reports/charts_ver2/)
# ---------------------------------------------------------------------------

BF9 = ("블프구간(11/23~11/30)", ("2020-11-23", "2020-11-30"), "#f59e0b", 0.28)


def _read222():
    d = read_csv("222_h1a_daily_omtm_hats_split_from_nov")
    d["session_date"] = pd.to_datetime(d["session_date"])
    d["hats_pv"] = d["hats_pv"].astype(bool)
    return d


def _shade_bf_and_periods(ax, with_transition=False):
    label, (a, b), color, alpha = BF9
    ax.axvspan(pd.Timestamp(a), pd.Timestamp(b) + pd.Timedelta(days=1), color=color, alpha=alpha, label=label)
    for key in ("base", "lead", "decl", "rec"):
        if key == "lead" and not with_transition:
            continue
        lab, (a2, b2), c2, al2 = P9[key]
        ax.axvspan(pd.Timestamp(a2), pd.Timestamp(b2) + pd.Timedelta(days=1), color=c2, alpha=al2, label=lab)


def plot_cause_omtm_weekly_nov_jan():
    d = _read222()
    d["wk"] = d.session_date.dt.to_period("W-SUN").dt.start_time
    wk = d.groupby("wk")[["s0", "s4"]].sum()
    wkx = d[~d.hats_pv].groupby("wk")[["s0", "s4"]].sum()
    wk = wk.loc["2020-11-02":]
    wkx = wkx.loc["2020-11-02":]
    mid = wk.index + pd.Timedelta(days=3)
    nov = d[(d.session_date >= "2020-11-01") & (d.session_date <= "2020-11-22")][["s0", "s4"]].sum()
    nov_rate = nov.s4 / nov.s0 * 100

    fig, ax = plt.subplots(figsize=(12, 6.6))
    _shade_bf_and_periods(ax)
    ax.plot(mid, wk.s4 / wk.s0 * 100, color="#111827", marker="o", linewidth=2.4, zorder=5, label="OMTM 전체 (주별)")
    ax.plot(mid, wkx.s4 / wkx.s0 * 100, color="#64748b", marker="s", markersize=4, linewidth=1.6, linestyle="--", zorder=4,
            label="Hats 목록 세션 제외")
    ax.axhline(nov_rate, color="#0f766e", linestyle=":", linewidth=1.8, zorder=3, label=f"11월(블프 전, 11/1~11/22) 평균 {nov_rate:.2f}%")
    ax.axvline(pd.Timestamp("2020-12-18"), color="#b45309", linestyle="--", linewidth=1.5, zorder=2, label="배송 마감 12/18")
    for x, y in zip(mid, wk.s4 / wk.s0 * 100):
        ax.annotate(f"{y:.2f}", (x, y), textcoords="offset points", xytext=(0, 8), ha="center", fontsize=8)
    ax.set_xlim(pd.Timestamp("2020-11-01"), pd.Timestamp("2021-01-31"))
    ax.set_ylim(0, 2.5)
    ax.set_ylabel("구매전환율 (%)")
    ax.set_title("12월 초는 연말 정점이었고, 연휴 침체 후 1월 중순 평소 수준 가까이 돌아왔다", fontsize=13)
    fig.text(0.5, 0.945, "집계 기준: 세션 단위(구매 세션/전체 세션), 월요일 시작 주(11/2 주~1/25 주, 11/30 주는 블프 마지막 날 포함) · sql/222",
             ha="center", fontsize=9, color="#555555")
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.15), ncol=3, fontsize=8.5, frameon=False)
    ax.tick_params(axis="x", rotation=45)
    fig.tight_layout(rect=(0, 0, 1, 0.94))
    fig.savefig(OUT_DIR_VER2 / "cause_omtm_weekly_nov_jan.png", dpi=150, bbox_inches="tight")
    plt.close(fig)


def plot_cause_stage2_daily_steps():
    d = _read222()
    g = d.groupby("session_date")[["s1_pv", "s2"]].sum().loc["2020-12-01":]
    daily = g.s2 / g.s1_pv * 100
    ma = g.rolling(7).sum()
    ma = ma.s2 / ma.s1_pv * 100

    fig, ax = plt.subplots(figsize=(12, 6.6))
    for key in ("base", "lead", "decl", "rec"):
        lab, (a, b), c, al = P9[key]
        ax.axvspan(pd.Timestamp(a), pd.Timestamp(b) + pd.Timedelta(days=1), color=c, alpha=al, label=lab)
    ax.plot(daily.index, daily.values, color="#94a3b8", marker="o", markersize=3, linewidth=1, alpha=0.8, label="일별 값")
    ax.plot(ma.index, ma.values, color="#7c3aed", linewidth=2.6, zorder=5, label="7일 이동평균")
    ax.axvline(pd.Timestamp("2020-12-18"), color="#b45309", linestyle="--", linewidth=1.5, zorder=2, label="배송 마감 12/18")
    for t, yl in zip(("2020-12-16", "2020-12-19", "2020-12-24"), (3.0, 1.2, 3.0)):
        t = pd.Timestamp(t)
        ax.axvline(t, color="#4c1d95", linestyle=":", linewidth=1.0, zorder=2)
        ax.text(t, yl, t.strftime("%m/%d"), ha="center", va="center", fontsize=8.5, color="#4c1d95",
                bbox=dict(boxstyle="round,pad=0.2", facecolor="white", edgecolor="#4c1d95", linewidth=0.6), zorder=7)
    ax.set_xlim(pd.Timestamp("2020-12-01"), pd.Timestamp("2021-02-01"))
    ax.set_ylim(0, 24)
    ax.set_ylabel("목록 도달 세션 중 담기 도달 비율 (%)")
    ax.set_title("목록→장바구니 담기 비율, 배송 마감 전후 계단식 하락", fontsize=14)
    fig.text(0.5, 0.945, "집계 기준: 세션 단위, 비율 = 담기 도달 세션 / (목록 경로 page_view 또는 이후 단계가 있는 세션) · 변화점은 사전 지정(12/16·12/19·12/24, view_item 기준 같은 비율의 BIC 분할) · sql/222",
             ha="center", fontsize=8.3, color="#555555")
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.15), ncol=3, fontsize=8.5, frameon=False)
    ax.tick_params(axis="x", rotation=45)
    fig.tight_layout(rect=(0, 0, 1, 0.94))
    fig.savefig(OUT_DIR_VER2 / "cause_stage2_daily_steps.png", dpi=150, bbox_inches="tight")
    plt.close(fig)


def plot_cause_expedited_shipping_daily():
    d = read_csv("236_shipping_tier_daily")
    d["d"] = pd.to_datetime(d["d"])
    d = d.set_index("d").loc["2020-11-23":"2021-01-11"]  # shipping_tier는 11/23 주부터 99% 이상 기록. 이동평균 계산용으로 11/23부터 읽는다
    d["fast"] = d.express
    d["dom"] = d.ground + d.express
    share = d.fast / d.dom * 100
    ma = d[["fast", "dom"]].rolling(7).sum()
    ma = ma.fast / ma.dom * 100
    d = d.loc["2020-12-01":]
    share, ma = share.loc["2020-12-01":], ma.loc["2020-12-01":]
    n_fast, max_day, min_day = int(d.fast.sum()), int(d.fast.max()), int(d.fast.min())

    fig, ax = plt.subplots(figsize=(12, 6.6))
    for key in ("base", "lead", "decl"):
        lab, (a, b), c, al = P9[key]
        ax.axvspan(pd.Timestamp(a), pd.Timestamp(b) + pd.Timedelta(days=1), color=c, alpha=al, label=lab)
    x = d.index + pd.Timedelta(hours=12)
    ax.bar(x, d.two_day, width=0.8, color="#0d9488", label="2일 배송 건수 (2Day, 2nd Day Air)", zorder=3)
    ax.bar(x, d.next_day, width=0.8, bottom=d.two_day, color="#db2777", label="익일 배송 건수 (Overnight, Next Day Air)", zorder=3)
    ax.bar(x, d.three_day, width=0.8, bottom=d.two_day + d.next_day, color="#a3a3a3", label="3일 배송 건수 (3 Day Select)", zorder=3)
    ax.set_ylim(0, 20)
    ax.set_yticks(range(0, 21, 4))
    ax.set_ylabel("빠른 배송 주문 수 (건)")

    ax2 = ax.twinx()
    ax2.plot(share.index + pd.Timedelta(hours=12), share.values, color="#94a3b8", marker="o", markersize=3, linewidth=1,
             label="일별 빠른 배송 비중", zorder=6)
    ax2.plot(ma.index + pd.Timedelta(hours=12), ma.values, color="#1e293b", linewidth=2.6, label="7일 빠른 배송 비중 (7일 합계의 비율)", zorder=7)
    ax2.set_ylim(0, 25)
    ax2.set_yticks(range(0, 26, 5))
    ax2.set_ylabel("빠른 배송 비중 (%)")

    ax.axvline(pd.Timestamp("2020-12-18") + pd.Timedelta(days=1), color="#b45309", linestyle="--", linewidth=1.5, zorder=2, label="배송 마감 12/18")
    for t, txt, ha, dx in (("2020-12-19", "담기 변화점 12/19", "left", 0.15), ("2020-12-24", "12/24", "center", 0.0)):
        t = pd.Timestamp(t) + pd.Timedelta(hours=12)  # 그날 막대의 가운데
        ax.axvline(t, color="#4c1d95", linestyle=":", linewidth=1.2, zorder=9)
        ax.text(t + pd.Timedelta(days=dx), 19.0, txt, ha=ha, va="center", fontsize=8.5, color="#4c1d95",
                bbox=dict(boxstyle="round,pad=0.2", facecolor="white", edgecolor="#4c1d95", linewidth=0.6), zorder=8)
    ax.set_xlim(pd.Timestamp("2020-12-01"), pd.Timestamp("2021-01-12"))
    ax.set_title("빠른 배송 주문은 12/19와 12/24에 단계적으로 줄었고, 두 날짜는 담기 변화점과 같았다", fontsize=13)
    fig.text(0.5, 0.945, f"표본이 작다: 12/1~1/11 빠른 배송 주문 {n_fast}건(하루 {min_day}~{max_day}건)이라 일별 값이 크게 흔들린다 · 집계 기준: 주문 단위(transaction_id), 빠른 배송 = Ground·해외 제외 · sql/236",
             ha="center", fontsize=8.3, color="#555555")
    h1, l1 = ax.get_legend_handles_labels()
    h2, l2 = ax2.get_legend_handles_labels()
    ax.legend(h1 + h2, l1 + l2, loc="upper center", bbox_to_anchor=(0.5, -0.09), ncol=3, fontsize=8.3, frameon=False)
    ticks = pd.date_range("2020-12-01", "2021-01-11", freq="3D")
    ax.set_xticks(ticks + pd.Timedelta(hours=12))
    ax.set_xticklabels([t.strftime("%m/%d") for t in ticks])
    ax.tick_params(axis="x", rotation=0)
    fig.tight_layout(rect=(0, 0, 1, 0.94))
    fig.savefig(OUT_DIR_VER2 / "cause_expedited_shipping_daily.png", dpi=150, bbox_inches="tight")
    plt.close(fig)


def plot_cause_sized_vs_nonsized():
    groups = ["사이즈 있는 의류\n(Hats 포함)", "사이즈 있는 의류\n(Hats 제외)", "사이즈 없는 상품\n(문구·음용기·가방·생활용품)"]
    vals = {"base": [13.04, 9.06, 10.35], "decl": [5.40, 5.08, 8.40], "rec": [6.12, 5.78, 8.62]}
    x = np.arange(len(groups))
    w = 0.26
    fig, ax = plt.subplots(figsize=(10.5, 6.4))
    cols = {"base": PERIOD_COLORS[BASELINE], "decl": PERIOD_COLORS[DECLINE], "rec": "#16a34a"}
    labs = {"base": P9["base"][0], "decl": P9["decl"][0], "rec": P9["rec"][0]}
    for i, k in enumerate(("base", "decl", "rec")):
        bars = ax.bar(x + (i - 1) * w, vals[k], w, color=cols[k], label=labs[k])
        for j, b in enumerate(bars):
            txt = f"{b.get_height():.2f}%"
            if k != "base":
                drop = (vals[k][j] / vals["base"][j] - 1) * 100
                txt += f"\n({drop:+.0f}%)"
            ax.annotate(txt, (b.get_x() + b.get_width() / 2, b.get_height()), textcoords="offset points", xytext=(0, 4),
                        ha="center", fontsize=9)
    ax.set_xticks(x)
    ax.set_xticklabels(groups)
    ax.set_ylim(0, 16)
    ax.set_ylabel("같은 페이지 담기율 (%)")
    ax.set_title("사이즈 있는 의류의 담기율은 Hats를 빼도 -44%로, 사이즈 없는 상품(-19%)보다 2배 이상 떨어졌다", fontsize=12.2)
    fig.text(0.5, 0.945, "집계 기준: 카테고리 목록 페이지 단위 합산(페이지 page_view 세션 중 같은 페이지에서 담은 세션). 괄호는 기준선 대비 변화율. 세션이 여러 페이지를 볼 수 있어 검정 p값은 쓰지 않음 · sql/214",
             ha="center", fontsize=8.0, color="#555555")
    ax.legend(loc="upper right", fontsize=9)
    fig.tight_layout(rect=(0, 0, 1, 0.93))
    fig.savefig(OUT_DIR_VER2 / "cause_sized_vs_nonsized.png", dpi=150, bbox_inches="tight")
    plt.close(fig)


def plot_cause_h1b_return_cart():
    labels = ["12월 초\n(12/1~12/13)", "하락구간\n(12/19~1/11)", "회복기\n(1/12~1/24)"]
    ret = [19.8, 12.9, 15.9]
    cart = [2.31, 0.86, 1.51]
    cols = [PERIOD_COLORS[BASELINE], PERIOD_COLORS[DECLINE], "#16a34a"]
    fig, axes = plt.subplots(1, 2, figsize=(11, 6))
    for ax, vals, title, fmt in ((axes[0], ret, "7일 안에 다시 방문한 비율", "{:.1f}%"), (axes[1], cart, "7일 안에 다시 와서 담은 비율", "{:.2f}%")):
        bars = ax.bar(labels, vals, color=cols, width=0.6)
        for b in bars:
            ax.annotate(fmt.format(b.get_height()), (b.get_x() + b.get_width() / 2, b.get_height()), textcoords="offset points",
                        xytext=(0, 4), ha="center", fontsize=10)
        ax.set_title(title, fontsize=11)
        ax.set_ylim(0, max(vals) * 1.25)
        ax.set_ylabel("목록을 보고 그 세션엔 안 담은 사용자 중 (%)")
    fig.suptitle("이탈 사용자, 재방문도 재방문 후 담기도 줄었다", fontsize=14)
    fig.text(0.5, 0.905, "집계 기준: 사용자 단위 코호트(기간 안 첫 '목록 page_view만 있고 담기 없는 세션', 코호트 26,303 / 39,423 / 22,583명), 이후 7일 이내 세션 · sql/216",
             ha="center", fontsize=8.5, color="#555555")
    fig.tight_layout(rect=(0, 0, 1, 0.9))
    fig.savefig(OUT_DIR_VER2 / "cause_h1b_return_cart.png", dpi=150, bbox_inches="tight")
    plt.close(fig)



if __name__ == "__main__":
    plot_problem_checkout_conversion_trend()
    plot_problem_funnel()
    plot_problem_omtm_daily()
    plot_problem_stage_index()
    plot_cause_omtm_weekly_nov_jan()
    plot_cause_stage2_daily_steps()
    plot_cause_expedited_shipping_daily()
    plot_cause_sized_vs_nonsized()
    plot_cause_h1b_return_cart()
    plot_hypothesis1_stage_price_trend()
    plot_hypothesis1_cart_category_change()
    plot_hypothesis2_lag_days_by_type()
    plot_hypothesis2_category_type_conversion()
    plot_hypothesis2_weekly_purchase()
    plot_finding_stockout_hats_weekly_trend()
    plot_data_quality_tracking()
    plot_data_quality_tracking_ver2()
    print(f"차트 9개 저장됨: {OUT_DIR} / 8개 저장됨: {OUT_DIR_VER2}")
