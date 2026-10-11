"""담김 단가 상승(평상시 vs 하락구간)의 유저 단위 검정 + Hats 제외 민감도. 입력: data/180_user_cart_price_rows_v3.csv"""
import sys
from pathlib import Path
import numpy as np, pandas as pd
from scipy import stats
sys.path.insert(0, str(Path(__file__).resolve().parent))
from category_mapping import CATEGORY_MAP

d = pd.read_csv(Path(__file__).resolve().parent.parent / "data" / "180_user_cart_price_rows_v3.csv", encoding="utf-8-sig")
d = d.dropna(subset=["price"]).copy()
d["cat"] = d["raw_category"].map(CATEGORY_MAP).fillna("기타/미분류")
d["is_hats"] = d["cat"] == "Apparel/Hats"
B, D = "평상시", "하락구간"

def user_level(df):
    return df.groupby(["period", "user_pseudo_id"])["price"].mean().reset_index()

def report(label, df):
    u = user_level(df)
    a, b = u[u.period == B]["price"], u[u.period == D]["price"]
    t = stats.ttest_ind(b, a, equal_var=False)
    mw = stats.mannwhitneyu(b, a, alternative="two-sided")
    diff = b.mean() - a.mean()
    se = np.sqrt(a.var(ddof=1) / len(a) + b.var(ddof=1) / len(b))
    print(f"[{label}] 유저 n={len(a):,}/{len(b):,}  유저평균 ${a.mean():.2f} -> ${b.mean():.2f} ({diff:+.2f}, {diff/a.mean()*100:+.1f}%)  "
          f"중앙값 ${a.median():.2f} -> ${b.median():.2f}")
    print(f"    Welch t={t.statistic:.2f} p={t.pvalue:.3g} | Mann-Whitney p={mw.pvalue:.3g} | 차이 95%CI [{diff-1.96*se:+.2f}, {diff+1.96*se:+.2f}]")

report("전체 아이템", d)
report("Hats 제외", d[~d.is_hats])
print()
for p in (B, D):
    s = d[d.period == p]
    h = s[s.is_hats]
    print(f"{p}: 아이템행 {len(s):,} 중 Hats {len(h):,} ({len(h)/len(s)*100:.1f}%), Hats 평균단가 ${h.price.mean():.2f}, 비Hats 평균단가 ${s[~s.is_hats].price.mean():.2f}")
u_all = user_level(d)
for p in (B, D):
    s = d[d.period == p]
    print(f"{p}: Hats만 담은 유저 {(s.groupby('user_pseudo_id')['is_hats'].all()).sum():,}명 / Hats 하나라도 담은 유저 {(s.groupby('user_pseudo_id')['is_hats'].any()).sum():,}명")
