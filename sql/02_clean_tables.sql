-- =====================================================
-- 02_clean_tables.sql
-- Project : Bank Loan & Customer Analytics (Berka dataset)
-- Author  : Srijai Nimmagadda
-- Purpose : Build clean, typed, English-labelled tables with keys
--           from the raw staging tables
-- =====================================================

USE berka_bank;

-- Drop clean tables if re-running (children first, because of foreign keys)
DROP TABLE IF EXISTS trans, standing_order, loan, card, disp, client, account, district;

-- ---------- 1. DISTRICT ----------
CREATE TABLE district (
    district_id            INT PRIMARY KEY,
    district_name          VARCHAR(50),
    region                 VARCHAR(50),
    inhabitants            INT,
    n_cities               INT,
    urban_ratio            DECIMAL(5,1),
    avg_salary             INT,
    unemployment_95        DECIMAL(5,2),
    unemployment_96        DECIMAL(5,2),
    entrepreneurs_per_1000 INT,
    crimes_95              INT,
    crimes_96              INT
);
INSERT INTO district
SELECT CAST(A1 AS UNSIGNED), TRIM(A2), TRIM(A3), CAST(A4 AS UNSIGNED), CAST(A9 AS UNSIGNED),
       CAST(A10 AS DECIMAL(5,1)), CAST(A11 AS UNSIGNED),
       CAST(NULLIF(TRIM(A12), '?') AS DECIMAL(5,2)),    -- '?' = missing value in the source
       CAST(A13 AS DECIMAL(5,2)), CAST(A14 AS UNSIGNED),
       CAST(NULLIF(TRIM(A15), '?') AS UNSIGNED),
       CAST(A16 AS UNSIGNED)
FROM raw_district;

-- ---------- 2. ACCOUNT ----------
CREATE TABLE account (
    account_id          INT PRIMARY KEY,
    district_id         INT,
    statement_frequency VARCHAR(30),
    open_date           DATE,
    FOREIGN KEY (district_id) REFERENCES district(district_id)
);
INSERT INTO account
SELECT CAST(account_id AS UNSIGNED), CAST(district_id AS UNSIGNED),
       CASE TRIM(frequency)
            WHEN 'POPLATEK MESICNE'   THEN 'Monthly'
            WHEN 'POPLATEK TYDNE'     THEN 'Weekly'
            WHEN 'POPLATEK PO OBRATU' THEN 'After transaction'
       END,
       STR_TO_DATE(LEFT(TRIM(date), 6), '%y%m%d')
FROM raw_account;

-- ---------- 3. CLIENT (decode gender + birth date from birth_number) ----------
CREATE TABLE client (
    client_id   INT PRIMARY KEY,
    gender      CHAR(1),
    birth_date  DATE,
    district_id INT,
    FOREIGN KEY (district_id) REFERENCES district(district_id)
);
INSERT INTO client
SELECT CAST(client_id AS UNSIGNED),
       IF(CAST(MID(birth_number, 3, 2) AS UNSIGNED) > 50, 'F', 'M'),
       STR_TO_DATE(CONCAT('19', LEFT(birth_number, 2),
                          LPAD(CAST(MID(birth_number, 3, 2) AS UNSIGNED)
                               - IF(CAST(MID(birth_number, 3, 2) AS UNSIGNED) > 50, 50, 0), 2, '0'),
                          RIGHT(birth_number, 2)), '%Y%m%d'),
       CAST(district_id AS UNSIGNED)
FROM raw_client;

-- ---------- 4. DISP (links clients to accounts) ----------
CREATE TABLE disp (
    disp_id    INT PRIMARY KEY,
    client_id  INT,
    account_id INT,
    disp_type  VARCHAR(20),              -- OWNER or DISPONENT (authorised user)
    FOREIGN KEY (client_id)  REFERENCES client(client_id),
    FOREIGN KEY (account_id) REFERENCES account(account_id)
);
INSERT INTO disp
SELECT CAST(disp_id AS UNSIGNED), CAST(client_id AS UNSIGNED), CAST(account_id AS UNSIGNED), TRIM(type)
FROM raw_disp;

-- ---------- 5. CARD ----------
CREATE TABLE card (
    card_id     INT PRIMARY KEY,
    disp_id     INT,
    card_type   VARCHAR(20),
    issued_date DATE,
    FOREIGN KEY (disp_id) REFERENCES disp(disp_id)
);
INSERT INTO card
SELECT CAST(card_id AS UNSIGNED), CAST(disp_id AS UNSIGNED), TRIM(type),
       STR_TO_DATE(LEFT(TRIM(issued), 6), '%y%m%d')
FROM raw_card;

-- ---------- 6. LOAN (with status labels + default flag) ----------
CREATE TABLE loan (
    loan_id         INT PRIMARY KEY,
    account_id      INT,
    loan_date       DATE,
    amount          DECIMAL(12,2),
    duration_months INT,
    monthly_payment DECIMAL(12,2),
    status          CHAR(1),
    status_desc     VARCHAR(60),
    is_default      TINYINT,              -- 1 = bad loan (B or D)
    FOREIGN KEY (account_id) REFERENCES account(account_id)
);
INSERT INTO loan
SELECT CAST(loan_id AS UNSIGNED), CAST(account_id AS UNSIGNED),
       STR_TO_DATE(LEFT(TRIM(date), 6), '%y%m%d'),
       CAST(amount AS DECIMAL(12,2)), CAST(duration AS UNSIGNED), CAST(payments AS DECIMAL(12,2)),
       TRIM(status),
       CASE TRIM(status)
            WHEN 'A' THEN 'Finished - repaid'
            WHEN 'B' THEN 'Finished - not repaid'
            WHEN 'C' THEN 'Running - OK'
            WHEN 'D' THEN 'Running - client in debt'
       END,
       IF(TRIM(status) IN ('B', 'D'), 1, 0)
FROM raw_loan;

-- ---------- 7. STANDING_ORDER ('order' is a reserved word in SQL, so renamed) ----------
CREATE TABLE standing_order (
    order_id   INT PRIMARY KEY,
    account_id INT,
    bank_to    VARCHAR(10),
    account_to VARCHAR(30),
    amount     DECIMAL(12,2),
    purpose    VARCHAR(30),
    FOREIGN KEY (account_id) REFERENCES account(account_id)
);
INSERT INTO standing_order
SELECT CAST(order_id AS UNSIGNED), CAST(account_id AS UNSIGNED),
       NULLIF(TRIM(bank_to), ''), NULLIF(TRIM(account_to), ''),
       CAST(amount AS DECIMAL(12,2)),
       CASE TRIM(k_symbol)
            WHEN 'POJISTNE' THEN 'Insurance'
            WHEN 'SIPO'     THEN 'Household payment'
            WHEN 'LEASING'  THEN 'Leasing'
            WHEN 'UVER'     THEN 'Loan payment'
       END
FROM raw_order;

-- ---------- 8. TRANS (1M+ rows, so this one takes the longest) ----------
CREATE TABLE trans (
    trans_id        INT PRIMARY KEY,
    account_id      INT,
    trans_date      DATE,
    trans_type      VARCHAR(20),          -- Credit / Withdrawal
    operation       VARCHAR(40),
    amount          DECIMAL(12,2),
    signed_amount   DECIMAL(12,2),        -- + for credits, - for withdrawals
    balance         DECIMAL(12,2),        -- balance after the transaction
    purpose         VARCHAR(30),
    partner_bank    VARCHAR(10),
    partner_account VARCHAR(30),
    FOREIGN KEY (account_id) REFERENCES account(account_id),
    INDEX idx_trans_date (trans_date)
);
INSERT INTO trans
SELECT CAST(trans_id AS UNSIGNED), CAST(account_id AS UNSIGNED),
       STR_TO_DATE(LEFT(TRIM(date), 6), '%y%m%d'),
       IF(TRIM(type) = 'PRIJEM', 'Credit', 'Withdrawal'),
       CASE TRIM(operation)
            WHEN 'VYBER KARTOU'   THEN 'Card withdrawal'
            WHEN 'VKLAD'          THEN 'Cash deposit'
            WHEN 'PREVOD Z UCTU'  THEN 'Transfer in'
            WHEN 'VYBER'          THEN 'Cash withdrawal'
            WHEN 'PREVOD NA UCET' THEN 'Transfer out'
       END,
       CAST(amount AS DECIMAL(12,2)),
       IF(TRIM(type) = 'PRIJEM', 1, -1) * CAST(amount AS DECIMAL(12,2)),
       CAST(balance AS DECIMAL(12,2)),
       CASE TRIM(k_symbol)                -- blanks, spaces and NULLs all become NULL
            WHEN 'POJISTNE'    THEN 'Insurance'
            WHEN 'SLUZBY'      THEN 'Statement fee'
            WHEN 'UROK'        THEN 'Interest credited'
            WHEN 'SANKC. UROK' THEN 'Penalty interest'
            WHEN 'SIPO'        THEN 'Household payment'
            WHEN 'DUCHOD'      THEN 'Pension'
            WHEN 'UVER'        THEN 'Loan payment'
       END,
       NULLIF(TRIM(bank), ''), NULLIF(TRIM(account), '')
FROM raw_trans;

-- =====================================================
-- VALIDATION CHECKS
-- =====================================================

-- Check 1: row counts must match the raw tables
SELECT 'district' AS table_name, COUNT(*) AS row_count FROM district UNION ALL
SELECT 'account',  COUNT(*) FROM account UNION ALL
SELECT 'client',   COUNT(*) FROM client  UNION ALL
SELECT 'disp',     COUNT(*) FROM disp    UNION ALL
SELECT 'card',     COUNT(*) FROM card    UNION ALL
SELECT 'loan',     COUNT(*) FROM loan    UNION ALL
SELECT 'standing_order', COUNT(*) FROM standing_order UNION ALL
SELECT 'trans',    COUNT(*) FROM trans;

-- Check 2: date ranges look sensible (1993-1998 for bank activity)
SELECT 'account open' AS what, MIN(open_date) AS earliest, MAX(open_date) AS latest FROM account UNION ALL
SELECT 'loan date',    MIN(loan_date),  MAX(loan_date)  FROM loan UNION ALL
SELECT 'transactions', MIN(trans_date), MAX(trans_date) FROM trans UNION ALL
SELECT 'client birth', MIN(birth_date), MAX(birth_date) FROM client;

-- Check 3: decoded gender split
SELECT gender, COUNT(*) AS clients FROM client GROUP BY gender;

-- Check 4: loan status distribution
SELECT status, status_desc, COUNT(*) AS loans, is_default
FROM loan GROUP BY status, status_desc, is_default ORDER BY status;

-- Check 5: any values that failed to translate? (should be 0 or very small)
SELECT
    SUM(trans_date IS NULL)                                      AS null_trans_dates,
    SUM(operation IS NULL)                                       AS null_operations,
    (SELECT COUNT(*) FROM account WHERE statement_frequency IS NULL) AS null_frequencies,
    (SELECT COUNT(*) FROM client  WHERE birth_date IS NULL)      AS null_birth_dates
FROM trans;

-- Finding: transactions with no operation are bank-initiated (interest credited), not data errors
-- Check 6: what are the transactions with no operation?
SELECT trans_type, purpose, COUNT(*) AS transactions
FROM trans
WHERE operation IS NULL
GROUP BY trans_type, purpose
ORDER BY transactions DESC;