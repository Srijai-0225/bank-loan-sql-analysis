-- =====================================================
-- 03_loan_risk_analysis.sql
-- Project : Bank Loan & Customer Analytics (Berka dataset)
-- Author  : Srijai Nimmagadda
-- Purpose : Identify loan, borrower and account-behaviour factors linked to default
-- Note    : Only transactions BEFORE each loan date are used, to avoid data leakage
-- =====================================================

USE berka_bank;

-- ---------- 0. Build one analysis table: one row per loan ----------
DROP TABLE IF EXISTS loan_profile;
CREATE TABLE loan_profile AS
SELECT
    l.loan_id, l.account_id, l.loan_date, l.amount, l.duration_months, l.monthly_payment,
    l.status, l.status_desc, l.is_default,
    c.gender,
    TIMESTAMPDIFF(YEAR, c.birth_date, l.loan_date)   AS age_at_loan,
    d.region, d.district_name, d.avg_salary, d.unemployment_96,
    a.statement_frequency,
    TIMESTAMPDIFF(MONTH, a.open_date, l.loan_date)   AS account_age_months,
    t.n_trans_before,
    t.avg_balance_before,
    t.min_balance_before,
    t.n_negative_balance_before
FROM loan l
JOIN account  a  ON a.account_id = l.account_id
JOIN disp     dp ON dp.account_id = l.account_id AND dp.disp_type = 'OWNER'   -- borrower = account owner
JOIN client   c  ON c.client_id  = dp.client_id
JOIN district d  ON d.district_id = a.district_id
LEFT JOIN (
    SELECT l2.loan_id,
           COUNT(*)              AS n_trans_before,
           AVG(tr.balance)       AS avg_balance_before,
           MIN(tr.balance)       AS min_balance_before,
           SUM(tr.balance < 0)   AS n_negative_balance_before
    FROM loan l2
    JOIN trans tr ON tr.account_id = l2.account_id
                 AND tr.trans_date < l2.loan_date          -- only history BEFORE the loan
    GROUP BY l2.loan_id
) t ON t.loan_id = l.loan_id;

-- Check: must be 682 rows (one per loan)
SELECT COUNT(*) AS loans_in_profile FROM loan_profile;


-- ---------- Q1. Portfolio KPIs ----------
SELECT
    COUNT(*)                                                         AS total_loans,
    ROUND(SUM(amount))                                               AS total_lent,
    ROUND(AVG(amount))                                               AS avg_loan,
    SUM(is_default)                                                  AS bad_loans,
    ROUND(AVG(is_default) * 100, 1)                                  AS default_rate_pct,
    ROUND(SUM(CASE WHEN is_default = 1 THEN amount END))             AS amount_in_bad_loans,
    ROUND(SUM(CASE WHEN is_default = 1 THEN amount END) / SUM(amount) * 100, 1) AS pct_amount_at_risk
FROM loan_profile;


-- ---------- Q2. Default rate by loan size and duration ----------
SELECT
    CASE WHEN amount < 50000  THEN '1. Under 50K'
         WHEN amount < 150000 THEN '2. 50K-150K'
         WHEN amount < 300000 THEN '3. 150K-300K'
         ELSE                      '4. 300K+' END                    AS amount_band,
    COUNT(*)                                                         AS loans,
    SUM(is_default)                                                  AS bad_loans,
    ROUND(AVG(is_default) * 100, 1)                                  AS default_rate_pct
FROM loan_profile
GROUP BY amount_band
ORDER BY amount_band;

SELECT duration_months, COUNT(*) AS loans, SUM(is_default) AS bad_loans,
       ROUND(AVG(is_default) * 100, 1) AS default_rate_pct
FROM loan_profile
GROUP BY duration_months
ORDER BY duration_months;


-- ---------- Q3. Default rate by borrower profile (gender, age) ----------
SELECT gender, COUNT(*) AS loans, SUM(is_default) AS bad_loans,
       ROUND(AVG(is_default) * 100, 1) AS default_rate_pct
FROM loan_profile
GROUP BY gender;

SELECT
    CASE WHEN age_at_loan < 30 THEN '1. Under 30'
         WHEN age_at_loan < 40 THEN '2. 30-39'
         WHEN age_at_loan < 50 THEN '3. 40-49'
         ELSE                       '4. 50+' END                     AS age_band,
    COUNT(*) AS loans, SUM(is_default) AS bad_loans,
    ROUND(AVG(is_default) * 100, 1) AS default_rate_pct
FROM loan_profile
GROUP BY age_band
ORDER BY age_band;


-- ---------- Q4. Default rate by region, ranked (window function) ----------
WITH region_risk AS (
    SELECT region, COUNT(*) AS loans, SUM(is_default) AS bad_loans, AVG(is_default) AS default_rate,
           ROUND(AVG(avg_salary)) AS avg_salary
    FROM loan_profile
    GROUP BY region
)
SELECT region, loans, bad_loans,
       ROUND(default_rate * 100, 1)              AS default_rate_pct,
       avg_salary,
       RANK() OVER (ORDER BY default_rate DESC)  AS risk_rank
FROM region_risk
ORDER BY risk_rank;


-- ---------- Q5. Pre-loan average balance quartiles (NTILE window function) ----------
WITH balance_q AS (
    SELECT is_default, avg_balance_before,
           NTILE(4) OVER (ORDER BY avg_balance_before) AS balance_quartile
    FROM loan_profile
)
SELECT balance_quartile,
       COUNT(*)                          AS loans,
       ROUND(MIN(avg_balance_before))    AS from_balance,
       ROUND(MAX(avg_balance_before))    AS to_balance,
       SUM(is_default)                   AS bad_loans,
       ROUND(AVG(is_default) * 100, 1)   AS default_rate_pct
FROM balance_q
GROUP BY balance_quartile
ORDER BY balance_quartile;


-- ---------- Q6. Did the account go negative BEFORE the loan? ----------
SELECT
    CASE WHEN n_negative_balance_before > 0 THEN 'Went negative before loan'
         ELSE 'Never negative before loan' END   AS pre_loan_history,
    COUNT(*) AS loans, SUM(is_default) AS bad_loans,
    ROUND(AVG(is_default) * 100, 1) AS default_rate_pct
FROM loan_profile
GROUP BY pre_loan_history;


-- ---------- Q7. Payment burden: monthly payment vs average balance ----------
WITH burden AS (
    SELECT is_default, monthly_payment / NULLIF(avg_balance_before, 0) AS payment_to_balance
    FROM loan_profile
)
SELECT
    CASE WHEN payment_to_balance < 0.10 THEN '1. Under 10%'
         WHEN payment_to_balance < 0.20 THEN '2. 10-20%'
         WHEN payment_to_balance < 0.40 THEN '3. 20-40%'
         ELSE                                '4. 40%+' END           AS burden_band,
    COUNT(*) AS loans, SUM(is_default) AS bad_loans,
    ROUND(AVG(is_default) * 100, 1) AS default_rate_pct
FROM burden
GROUP BY burden_band
ORDER BY burden_band;


-- ---------- Q8. Loan volume by year with growth (LAG + running total) ----------
WITH yearly AS (
    SELECT YEAR(loan_date) AS loan_year, COUNT(*) AS loans, SUM(amount) AS total_lent,
           AVG(is_default) AS default_rate
    FROM loan_profile
    GROUP BY YEAR(loan_date)
)
SELECT loan_year, loans,
       ROUND(total_lent)                                                       AS total_lent,
       ROUND((total_lent - LAG(total_lent) OVER (ORDER BY loan_year))
             / LAG(total_lent) OVER (ORDER BY loan_year) * 100, 1)             AS yoy_growth_pct,
       SUM(loans) OVER (ORDER BY loan_year)                                    AS cumulative_loans,
       ROUND(default_rate * 100, 1)                                            AS default_rate_pct
FROM yearly
ORDER BY loan_year;

-- ---------- Q9. Simple rule-based risk tiers: how many bad loans would they catch? ----------
WITH flagged AS (
    SELECT is_default,
           CASE WHEN n_negative_balance_before > 0                              THEN '1. High risk'
                WHEN monthly_payment / NULLIF(avg_balance_before, 0) >= 0.20    THEN '2. Medium risk'
                ELSE                                                                 '3. Low risk' END AS risk_tier
    FROM loan_profile
),
totals AS (
    SELECT SUM(is_default) AS all_bad_loans FROM flagged
)
SELECT f.risk_tier,
       COUNT(*)                                            AS loans,
       SUM(f.is_default)                                   AS bad_loans,
       ROUND(AVG(f.is_default) * 100, 1)                   AS default_rate_pct,
       ROUND(SUM(f.is_default) / t.all_bad_loans * 100, 1) AS pct_of_all_bad_loans
FROM flagged f
CROSS JOIN totals t
GROUP BY f.risk_tier, t.all_bad_loans
ORDER BY f.risk_tier;



/* =====================================================
   KEY FINDINGS - Loan default risk
   1. 682 loans, 103.3M lent; 76 bad loans (11.1%) holding 15.1% of the money lent.
   2. Every account that went negative BEFORE its loan defaulted (27/27, 100% vs 7.5%);
      these are 35.5% of all bad loans.
   3. Payment burden is the steepest risk gradient: 6.0% default under 10% of balance vs 55.6% at 40%+.
   4. Larger loans are riskier: 4.0% (<50K) to 20.7% (300K+).
   5. Lowest pre-loan balance quartile defaults at 19.3% vs 4.7% for the highest.
   6. Gender and age show no meaningful difference (10-12%): behaviour predicts risk, demographics do not.
   7. West Bohemia (15.8%) and North Moravia (15.4%) are the riskiest regions; North Bohemia the safest (1.6%).
   8. 1998's low default rate (2.5%) reflects right-censoring: recent loans had little time to default.
      9. Two pre-loan rules (negative balance history; payment >= 20% of avg balance) flag 70 loans (10%)
      and capture 50% of all defaults; the remaining "low risk" loans default at only 6.2%.
   ===================================================== */
