"""
A/B 표본 크기 계산 (docs/11 가설 A1~B2). 입력은 sql/229~232의 결과 CSV(data/).

조건: 유의수준 0.05(양측), 검정력 0.8, 50:50 분할, 두 비율 비교(정규근사).
n(그룹당) = (z_a/2 * sqrt(2*p̄*q̄) + z_b * sqrt(p1*q1 + p2*q2))^2 / (p2 - p1)^2, p2 = p1 * (1 + MDE).
필요 일수 = 누적 진입 유저 수가 2n(+ 후속 관찰 7일)에 처음 도달하는 날. 기간 안에서 도달하지 못하면
기간 끝 5일 평균 진입 수로 외삽하고 (외삽) 표시한다.
"""
import math
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import norm

DATA = Path(__file__).resolve().parent.parent / "data"
ALPHA, POWER = 0.05, 0.8
ZA, ZB = norm.ppf(1 - ALPHA / 2), norm.ppf(POWER)
MDES = [0.10, 0.20, 0.30]


def n_per_group(p1, mde):
    p2 = p1 * (1 + mde)
    pbar = (p1 + p2) / 2
    num = (ZA * math.sqrt(2 * pbar * (1 - pbar)) + ZB * math.sqrt(p1 * (1 - p1) + p2 * (1 - p2))) ** 2
    return math.ceil(num / (p2 - p1) ** 2)


def days_needed(daily, total_needed, tail_days=5):
    """daily: 진입일 순서의 일별 신규 진입 유저 수(Series). 누적이 total_needed에 도달하는 일수와 외삽 여부."""
    cum = daily.cumsum().to_numpy()
    n_days = len(cum)
    hit = np.where(cum >= total_needed)[0]
    if len(hit):
        return int(hit[0]) + 1, False
    tail = daily.iloc[-tail_days:].mean()
    return n_days + math.ceil((total_needed - cum[-1]) / tail), True


def summarize(label, daily, users, events, follow_up=0, window=None):
    """한 시나리오: 기준값 p, 전체 진입 수, 일평균, 끝 5일 평균, MDE별 n과 필요 일수."""
    p = events / users
    rows = []
    for mde in MDES:
        n = n_per_group(p, mde)
        d, extrap = days_needed(daily, 2 * n)
        rows.append(dict(시나리오=label, 기준값=f"{p*100:.2f}%", MDE=f"{int(mde*100)}%",
                         그룹당_n=n, 전체_필요=2 * n, 진입_일수=d, 외삽=extrap,
                         총_실험_일수=d + follow_up,
                         기간내_가능=(None if window is None else (d + follow_up) <= window)))
    info = dict(시나리오=label, 기준값=p, 기간_총_진입=int(users), 일수=len(daily),
                일평균=users / len(daily), 끝5일평균=daily.iloc[-5:].mean())
    return pd.DataFrame(rows), info


RANGES = {
    "A": ("2020-12-19", "2021-01-11"),
    "B": ("2020-12-01", "2020-12-13"),
    "R": ("2021-01-12", "2021-01-24"),
}


def per_day(df, rng, day_col="d", val="users"):
    """일별 신규 진입 수. 진입이 0인 날도 0으로 채워 기간 전체 일수를 유지한다."""
    s = df.groupby(day_col)[val].sum()
    s.index = pd.to_datetime(s.index)
    return s.reindex(pd.date_range(*RANGES[rng]), fill_value=0)


def main():
    out, infos = [], []

    # A1, A2: 12/19~1/11 (24일), 결과 = 진입 이후 기간 끝까지 구매
    a = pd.read_csv(DATA / "229_ab_sample_a1a2_entries.csv")
    for g, name in [("A1", "A1 목록 방문자(하락구간)"), ("A2", "A2 전체 방문자(하락구간)")]:
        x = a[a.grp == g]
        daily = per_day(x, "A")
        r, i = summarize(name, daily, x.users.sum(), x.buyers.sum(), follow_up=0, window=24)
        out.append(r); infos.append(i)

    # A3: 7일 안 재방문 후 담기 (후속 7일 포함)
    c = pd.read_csv(DATA / "230_ab_sample_a3_cohort_daily.csv")
    for per, name in [("B", "A3 이탈자(기준선)"), ("R", "A3 이탈자(회복기)")]:
        x = c[c.period == per]
        daily = per_day(x, per)
        r, i = summarize(name, daily, x.users.sum(), x.cart7.sum(), follow_up=7)
        out.append(r); infos.append(i)

    # B1: 품절 추정 상품 노출 유저의 7일 안 구매
    b1 = pd.read_csv(DATA / "231_ab_sample_b1_stockout_exposure.csv")
    for dfn, dn in [("any", "전체 목록"), ("hats", "Hats 목록")]:
        for per, pn in [("B", "기준선"), ("R", "회복기")]:
            x = b1[(b1.def_ == dfn) & (b1.period == per)] if "def_" in b1 else b1[(b1["def"] == dfn) & (b1.period == per)]
            daily = per_day(x, per)
            r, i = summarize(f"B1 품절노출·{dn}({pn})", daily, x.users.sum(), x.buyers7.sum(), follow_up=7)
            out.append(r); infos.append(i)

    # B2: 유저 단위 7일 안 담기
    b2 = pd.read_csv(DATA / "232_ab_sample_b2_list_users.csv")
    for per, pn in [("B", "기준선"), ("R", "회복기")]:
        x = b2[b2.period == per]
        daily = per_day(x, per)
        r, i = summarize(f"B2 목록 도달 유저({pn}) 유저단위", daily, x.users.sum(), x.cart7_users.sum(), follow_up=7)
        out.append(r); infos.append(i)

        # 세션 단위 ②: 유저 단위로 배정하고 세션 단위로 분석하면 같은 유저의 세션이 묶인다.
        # 설계 효과 = 군집 보정 분산 / 이항 분산 (유저별 잔차 k_i - p*m_i로 계산, 분산분석 ICC는 군집 크기와 결과가 관련돼 있어 불안정해서 쓰지 않음)
        users = x.users.to_numpy(dtype=float)
        m = x.n_list.to_numpy(dtype=float)
        k = x.n_cart.to_numpy(dtype=float)
        N, M, K = users.sum(), (users * m).sum(), (users * k).sum()
        p = K / M
        resid2 = (users * (k - p * m) ** 2).sum() * N / (N - 1)
        de = max(1.0, resid2 / (M * p * (1 - p)))
        m_w = (users * m ** 2).sum() / M
        days = len(daily)
        sess_per_day = M / days
        for mde in MDES:
            n_s = n_per_group(p, mde)
            need = math.ceil(n_s * de)
            out.append(pd.DataFrame([dict(시나리오=f"B2 세션단위 ②({pn})", 기준값=f"{p*100:.2f}%", MDE=f"{int(mde*100)}%",
                                          그룹당_n=need, 전체_필요=2 * need, 진입_일수=math.ceil(2 * need / sess_per_day),
                                          외삽=False, 총_실험_일수=math.ceil(2 * need / sess_per_day), 기간내_가능=None)]))
        infos.append(dict(시나리오=f"B2 세션단위 ②({pn})", 기준값=p, 기간_총_진입=int(M), 일수=days,
                          일평균=sess_per_day, 끝5일평균=float("nan"),
                          유저당_세션_가중평균=m_w, 설계효과=de, 단순_n_10=n_per_group(p, 0.10)))

    res = pd.concat(out, ignore_index=True)
    inf = pd.DataFrame(infos)
    res.to_csv(DATA / "ab_sample_size_results.csv", index=False, encoding="utf-8-sig")
    inf.to_csv(DATA / "ab_sample_size_inflow.csv", index=False, encoding="utf-8-sig")
    pd.set_option("display.width", 250, "display.max_columns", 30, "display.max_rows", 200)
    print(inf.round(4).to_string(index=False))
    print()
    print(res.to_string(index=False))


if __name__ == "__main__":
    main()
