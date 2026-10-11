"""
Retention 단계: 주간 코호트별 롤링 리텐션(재방문/재구매)을 표+그래프로 저장한다.
censoring 처리: SQL에서 이미 관찰기간이 부족한 (코호트, Day N) 조합은 NaN 처리해뒀으므로
여기서는 NaN을 그대로 결측으로 두고 그린다(선이 중간에 끊기는 코호트가 있는 게 정상).

사용법:
    python notebooks/visualize_retention.py
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

DAY_NS = [7, 14, 30]


def _plot_cohort_lines(ax, pivot, value_fmt="{:.1f}%"):
    cmap = plt.get_cmap("viridis")
    weeks = list(pivot.index)
    n = len(weeks)
    for i, week in enumerate(weeks):
        row = pivot.loc[week]
        color = cmap(i / max(n - 1, 1))
        ax.plot(DAY_NS, row.values, marker="o", markersize=5, linewidth=1.6,
                color=color, label=str(week.date()), alpha=0.85)
    ax.set_xticks(DAY_NS)
    ax.set_xlabel("첫 시점 이후 경과일 (Day N, 롤링)")


def plot_revisit_retention():
    df = pd.read_csv(DATA_DIR / "26_retention_revisit_rolling.csv")
    df["cohort_week"] = pd.to_datetime(df["cohort_week"])
    df = df[df["cohort_week"] != pd.Timestamp("2020-10-26")]
    pivot = df.pivot(index="cohort_week", columns="day_n", values="retention_pct")[DAY_NS]

    fig, ax = plt.subplots(figsize=(11, 6.5))
    _plot_cohort_lines(ax, pivot)
    ax.set_ylabel("재방문 롤링 리텐션 (%)")
    ax.set_title("주간 코호트별 재방문 롤링 리텐션 (Day 7/14/30)")
    ax.legend(title="유입 주", fontsize=7.5, ncol=2, loc="upper right")
    fig.tight_layout()
    fig.savefig(OUT_DIR / "retention_revisit_rolling.png", dpi=150)
    plt.close(fig)


def plot_repurchase_retention():
    df = pd.read_csv(DATA_DIR / "27_retention_repurchase_rolling.csv")
    df["cohort_week"] = pd.to_datetime(df["cohort_week"])
    df = df[df["cohort_week"] != pd.Timestamp("2020-10-26")]
    pivot = df.pivot(index="cohort_week", columns="day_n", values="repurchase_rate_pct")[DAY_NS]

    fig, ax = plt.subplots(figsize=(11, 6.5))
    _plot_cohort_lines(ax, pivot)
    ax.set_ylabel("재구매 롤링 리텐션 (%)")
    ax.set_title("주간 코호트(첫 구매 기준)별 재구매 롤링 리텐션 (Day 7/14/30)")
    ax.legend(title="첫 구매 주", fontsize=7.5, ncol=2, loc="upper right")
    fig.tight_layout()
    fig.savefig(OUT_DIR / "retention_repurchase_rolling.png", dpi=150)
    plt.close(fig)


def _plot_cohort_table(df, value_col, title, out_name, volume_label):
    """실무에서 흔히 쓰는 '코호트/볼륨/기간' 표 형태(초록 그라데이션, 빈 칸=관찰 안 됨)로 그린다."""
    import copy

    import numpy as np

    df = df.sort_values("cohort_week")
    pivot = df.pivot(index="cohort_week", columns="day_n", values=value_col)[DAY_NS]
    volume = df.drop_duplicates("cohort_week").set_index("cohort_week")["cohort_size"]
    volume = volume.loc[pivot.index]

    n_rows = len(pivot)
    n_cols = 2 + len(DAY_NS)  # Cohort, Volume, Day+7, Day+14, Day+30
    col_labels = ["Cohort", volume_label] + [f"Day+{d}" for d in DAY_NS]

    cmap = copy.copy(plt.get_cmap("Greens"))
    vmax = np.nanmax(pivot.values)

    fig, ax = plt.subplots(figsize=(10.5, 0.55 * n_rows + 1.4))
    ax.set_xlim(0, n_cols)
    ax.set_ylim(0, n_rows + 1)
    ax.invert_yaxis()
    ax.axis("off")
    ax.set_title(title, fontsize=18, pad=16)

    # 헤더 행
    for j, label in enumerate(col_labels):
        ax.add_patch(plt.Rectangle((j, 0), 1, 1, facecolor="#dbeafe", edgecolor="black", linewidth=0.6))
        ax.text(j + 0.5, 0.5, label, ha="center", va="center", fontsize=13, fontweight="bold")

    for i, week in enumerate(pivot.index):
        row_y = i + 1
        ax.add_patch(plt.Rectangle((0, row_y), 1, 1, facecolor="#eff6ff", edgecolor="black", linewidth=0.6))
        ax.text(0.5, row_y + 0.5, week.strftime("%y/%m/%d"), ha="center", va="center", fontsize=12)

        ax.add_patch(plt.Rectangle((1, row_y), 1, 1, facecolor="#eff6ff", edgecolor="black", linewidth=0.6))
        ax.text(1.5, row_y + 0.5, f"{int(volume.loc[week]):,}", ha="center", va="center", fontsize=12)

        for j, day_n in enumerate(DAY_NS):
            val = pivot.loc[week, day_n]
            col_x = 2 + j
            if np.isnan(val):
                ax.add_patch(plt.Rectangle((col_x, row_y), 1, 1, facecolor="white", edgecolor="black", linewidth=0.6))
            else:
                color = cmap(val / vmax * 0.85 + 0.1)
                ax.add_patch(plt.Rectangle((col_x, row_y), 1, 1, facecolor=color, edgecolor="black", linewidth=0.6))
                ax.text(col_x + 0.5, row_y + 0.5, f"{val:.1f}%", ha="center", va="center", fontsize=12)

    fig.tight_layout()
    fig.savefig(OUT_DIR / out_name, dpi=150)
    plt.close(fig)


def plot_revisit_heatmap():
    df = pd.read_csv(DATA_DIR / "26_retention_revisit_rolling.csv")
    df["cohort_week"] = pd.to_datetime(df["cohort_week"])
    df = df[df["cohort_week"] != pd.Timestamp("2020-10-26")]
    _plot_cohort_table(df, "retention_pct", "재방문 코호트 리텐션", "retention_revisit_heatmap.png", "신규유저수")


def plot_repurchase_heatmap():
    df = pd.read_csv(DATA_DIR / "27_retention_repurchase_rolling.csv")
    df["cohort_week"] = pd.to_datetime(df["cohort_week"])
    df = df[df["cohort_week"] != pd.Timestamp("2020-10-26")]
    _plot_cohort_table(df, "repurchase_rate_pct", "재구매 코호트 리텐션", "retention_repurchase_heatmap.png", "첫구매고객수")


def plot_overall_retention_curve():
    """코호트로 쪼개지 않고 전체 유저/고객 기준 롤링 리텐션 곡선(Day 1~60)을 한 장에 겹쳐 그린다."""
    revisit = pd.read_csv(DATA_DIR / "28_retention_revisit_overall.csv")
    repurchase = pd.read_csv(DATA_DIR / "29_retention_repurchase_overall.csv")

    fig, ax = plt.subplots(figsize=(10, 6))
    ax.plot(revisit["day_n"], revisit["retention_pct"], linewidth=2.2, color="#2563eb", label="재방문 (전체 신규유저 기준)")
    ax.plot(repurchase["day_n"], repurchase["repurchase_rate_pct"], linewidth=2.2, color="#16a34a", label="재구매 (전체 첫구매고객 기준)")

    for df, col, color in [(revisit, "retention_pct", "#2563eb"), (repurchase, "repurchase_rate_pct", "#16a34a")]:
        for d in (7, 14, 30):
            row = df[df["day_n"] == d]
            if not row.empty:
                val = row[col].values[0]
                ax.scatter([d], [val], color=color, zorder=5, s=28)
                ax.annotate(f"{val:.1f}%", (d, val), textcoords="offset points", xytext=(4, 6), fontsize=8, color=color)

    ax.set_xlabel("첫 시점(첫 세션 / 첫 구매) 이후 경과일 (Day N, 롤링)")
    ax.set_ylabel("롤링 리텐션 (%)")
    ax.set_title("전체 유저 기준 롤링 리텐션 곡선 (코호트 구분 없음, Day 1~60)")
    ax.set_xlim(0, 60)
    ax.set_ylim(bottom=0)
    ax.legend(loc="upper right")
    ax.grid(alpha=0.25)
    fig.tight_layout()
    fig.savefig(OUT_DIR / "retention_overall_curve.png", dpi=150)
    plt.close(fig)


def plot_repurchase_interval_distribution():
    df = pd.read_csv(DATA_DIR / "30_repurchase_interval_distribution.csv")
    bins = [0, 1, 3, 7, 14, 30, 60, 100]
    labels = ["1일", "2~3일", "4~7일", "8~14일", "15~30일", "31~60일", "61일+"]
    df["bucket"] = pd.cut(df["interval_days"], bins=bins, labels=labels, right=True, include_lowest=True)
    counts = df["bucket"].value_counts().reindex(labels)
    median_val = df["interval_days"].median()

    fig, ax = plt.subplots(figsize=(9, 5.5))
    ax.bar(labels, counts.values, color="#16a34a")
    for i, v in enumerate(counts.values):
        ax.text(i, v + 1, str(int(v)), ha="center", fontsize=9)
    ax.set_ylabel("재구매 고객 수")
    ax.set_xlabel("첫 구매 → 두 번째 구매까지 걸린 기간")
    ax.set_title(f"재구매 간격 분포 (n={len(df)}, 중앙값 {median_val:.0f}일)")
    fig.tight_layout()
    fig.savefig(OUT_DIR / "repurchase_interval_distribution.png", dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    plot_revisit_retention()
    plot_repurchase_retention()
    plot_revisit_heatmap()
    plot_repurchase_heatmap()
    plot_overall_retention_curve()
    plot_repurchase_interval_distribution()
    print(f"차트 6개 저장됨: {OUT_DIR}")
