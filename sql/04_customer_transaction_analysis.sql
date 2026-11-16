-- =====================================================
-- 04_customer_transaction_analysis.sql
-- Project : Bank Loan & Customer Analytics (Berka dataset)
-- Author  : Srijai Nimmagadda
-- Purpose : Transaction trends, customer value concentration, card usage,
--           regional performance and cross-sell targets
-- =====================================================

USE berka_bank;

-- ---------- 0. Build one summary row per account ----------
DROP TABLE IF EXISTS account_summary;
CREATE TABLE account_summary AS
SELECT
    a.account_id, a.district_id, d.district_name, d.region, d.avg_salary,
    a.statement_frequency, a.open_date,
    lt.current_balance, lt.last_trans_date,
    ac.n_transactions,
    ROUND(ac.total_credits, 2)     AS total_credits,
    ROUND(ac.total_withdrawals, 2) AS total_withdrawals,
    ROUND(ac.avg_balance, 2)       AS avg_balance,
    COALESCE(cr.card_type, 'none') AS card_type,
    CASE WHEN l.loan_id IS NULL THEN 0 ELSE 1 END AS has_loan,
    COALESCE(l.is_default, 0)      AS loan_default
FROM account a
JOIN district d ON d.district_id = a.district_id
-- latest balance = balance after the most recent transaction (ROW_NUMBER window function)
LEFT JOIN (
    SELECT account_id, balance AS current_balance, trans_date AS last_trans_date
    FROM (
        SELECT account_id, balance, trans_date,
               ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY trans_date DESC, trans_id DESC) AS rn
        FROM trans
    ) x
    WHERE rn = 1
) lt ON lt.account_id = a.account_id
LEFT JOIN (
    SELECT account_id,
           COUNT(*) AS n_transactions,
           SUM(CASE WHEN trans_type = 'Credit'     THEN amount ELSE 0 END) AS total_credits,
           SUM(CASE WHEN trans_type = 'Withdrawal' THEN amount ELSE 0 END) AS total_withdrawals,
           AVG(balance) AS avg_balance
    FROM trans
    GROUP BY account_id
) ac ON ac.account_id = a.account_id
LEFT JOIN (
    SELECT dp.account_id,
           CASE WHEN SUM(cd.card_type = 'gold')    > 0 THEN 'gold'
                WHEN SUM(cd.card_type = 'classic') > 0 THEN 'classic'
                ELSE 'junior' END AS card_type          -- keep the highest card tier per account
    FROM card cd
    JOIN disp dp ON dp.disp_id = cd.disp_id
    GROUP BY dp.account_id
) cr ON cr.account_id = a.account_id
LEFT JOIN loan l ON l.account_id = a.account_id;

-- Check: must be 4500 rows (one per account)
SELECT COUNT(*) AS accounts_in_summary FROM account_summary;


-- ---------- Q1. Monthly transaction trend with 3-month moving average ----------
WITH monthly AS (
    SELECT DATE_FORMAT(trans_date, '%Y-%m') AS month,
           COUNT(*) AS transactions,
           ROUND(SUM(CASE WHEN trans_type = 'Credit'     THEN amount ELSE 0 END)) AS credits,
           ROUND(SUM(CASE WHEN trans_type = 'Withdrawal' THEN amount ELSE 0 END)) AS withdrawals
    FROM trans
    GROUP BY DATE_FORMAT(trans_date, '%Y-%m')
)
SELECT month, transactions, credits, withdrawals,
       credits - withdrawals AS net_flow,
       ROUND(AVG(transactions) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)) AS transactions_3m_avg
FROM monthly
ORDER BY month;


-- ---------- Q2. Transaction mix: how do customers use the bank? ----------
WITH mix AS (
    SELECT COALESCE(operation, 'Interest credited (by bank)') AS operation, trans_type,
           COUNT(*) AS transactions, AVG(amount) AS avg_amount, SUM(amount) AS total_amount
    FROM trans
    GROUP BY COALESCE(operation, 'Interest credited (by bank)'), trans_type
),
total AS (SELECT SUM(transactions) AS all_transactions FROM mix)
SELECT m.operation, m.trans_type, m.transactions,
       ROUND(m.transactions / t.all_transactions * 100, 1) AS pct_of_transactions,
       ROUND(m.avg_amount)   AS avg_amount,
       ROUND(m.total_amount) AS total_amount
FROM mix m CROSS JOIN total t
ORDER BY m.transactions DESC;


-- ---------- Q3. Value concentration: what share of deposits do the top 10% bring? ----------
WITH ranked AS (
    SELECT account_id, total_credits,
           NTILE(10) OVER (ORDER BY total_credits DESC) AS decile     -- 1 = top 10% of accounts
    FROM account_summary
),
total AS (SELECT SUM(total_credits) AS all_credits FROM account_summary)
SELECT r.decile,
       COUNT(*)                                          AS accounts,
       ROUND(SUM(r.total_credits))                       AS total_credits,
       ROUND(SUM(r.total_credits) / t.all_credits * 100, 1) AS pct_of_all_credits
FROM ranked r CROSS JOIN total t
GROUP BY r.decile, t.all_credits
ORDER BY r.decile;


-- ---------- Q4. Card holders vs non-card holders ----------
SELECT card_type,
       COUNT(*)                         AS accounts,
       ROUND(AVG(avg_balance))          AS avg_balance,
       ROUND(AVG(n_transactions))       AS avg_transactions,
       ROUND(AVG(total_credits))        AS avg_total_credits,
       ROUND(AVG(has_loan) * 100, 1)    AS pct_with_loan
FROM account_summary
GROUP BY card_type
ORDER BY avg_balance DESC;


-- ---------- Q5. Regional performance, ranked (DENSE_RANK) ----------
WITH region_stats AS (
    SELECT region,
           COUNT(*)                                  AS accounts,
           AVG(avg_balance)                          AS avg_balance,
           AVG(card_type <> 'none')                  AS card_penetration,
           AVG(has_loan)                             AS loan_penetration,
           AVG(avg_salary)                           AS avg_salary
    FROM account_summary
    GROUP BY region
)
SELECT region, accounts,
       ROUND(avg_balance)                 AS avg_balance,
       ROUND(card_penetration * 100, 1)   AS card_penetration_pct,
       ROUND(loan_penetration * 100, 1)   AS loan_penetration_pct,
       ROUND(avg_salary)                  AS avg_salary,
       DENSE_RANK() OVER (ORDER BY avg_balance DESC) AS balance_rank
FROM region_stats
ORDER BY balance_rank;


-- ---------- Q6. Cross-sell targets: high-balance accounts with no loan and no card ----------
WITH q AS (
    SELECT account_id, current_balance, has_loan, card_type,
           NTILE(4) OVER (ORDER BY current_balance DESC) AS balance_quartile   -- 1 = top 25%
    FROM account_summary
)
SELECT COUNT(*)                         AS target_accounts,
       ROUND(AVG(current_balance))      AS avg_current_balance,
       ROUND(SUM(current_balance))      AS total_balance_held
FROM q
WHERE balance_quartile = 1 AND has_loan = 0 AND card_type = 'none';




/* =====================================================
   KEY FINDINGS - Customer & transaction behaviour
   1. Top 10% of accounts bring 31.6% of all deposits; top 20% bring 51.1%; bottom 50% only 16.8%.
   2. 80% of accounts (3,608) have no card; gold card holders hold 1.9x the balance (61.4K vs 33.0K)
      and deposit 2.2x more than non-card accounts.
   3. Cash dominates: cash withdrawals are 41.2% of transactions; card withdrawals only 0.8%.
   4. Cross-sell: 505 top-quartile-balance accounts have no loan and no card, holding 39.8M.
   5. Regions are similar: average balances differ by only ~4%; card penetration 16.5%-24.3%.
   ===================================================== */