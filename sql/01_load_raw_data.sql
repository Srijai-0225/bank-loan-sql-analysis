-- =====================================================
-- 01_load_raw_data.sql
-- Project : Bank Loan & Customer Analytics (Berka dataset)
-- Author  : Srijai Nimmagadda
-- Purpose : Create the database and load all 8 raw CSV files as-is (staging layer)
-- =====================================================

SET GLOBAL local_infile = 1;

DROP DATABASE IF EXISTS berka_bank;
CREATE DATABASE berka_bank;
USE berka_bank;

-- ---------- Raw tables (all text, exactly as in the files) ----------
CREATE TABLE raw_account  (account_id VARCHAR(20), district_id VARCHAR(20), frequency VARCHAR(50), date VARCHAR(20));
CREATE TABLE raw_card     (card_id VARCHAR(20), disp_id VARCHAR(20), type VARCHAR(20), issued VARCHAR(30));
CREATE TABLE raw_client   (client_id VARCHAR(20), birth_number VARCHAR(20), district_id VARCHAR(20));
CREATE TABLE raw_disp     (disp_id VARCHAR(20), client_id VARCHAR(20), account_id VARCHAR(20), type VARCHAR(20));
CREATE TABLE raw_district (A1 VARCHAR(50), A2 VARCHAR(50), A3 VARCHAR(50), A4 VARCHAR(50), A5 VARCHAR(50),
                           A6 VARCHAR(50), A7 VARCHAR(50), A8 VARCHAR(50), A9 VARCHAR(50), A10 VARCHAR(50),
                           A11 VARCHAR(50), A12 VARCHAR(50), A13 VARCHAR(50), A14 VARCHAR(50), A15 VARCHAR(50),
                           A16 VARCHAR(50));
CREATE TABLE raw_loan     (loan_id VARCHAR(20), account_id VARCHAR(20), date VARCHAR(20), amount VARCHAR(30),
                           duration VARCHAR(20), payments VARCHAR(30), status VARCHAR(5));
CREATE TABLE raw_order    (order_id VARCHAR(20), account_id VARCHAR(20), bank_to VARCHAR(10), account_to VARCHAR(30),
                           amount VARCHAR(30), k_symbol VARCHAR(30));
CREATE TABLE raw_trans    (trans_id VARCHAR(20), account_id VARCHAR(20), date VARCHAR(20), type VARCHAR(20),
                           operation VARCHAR(40), amount VARCHAR(30), balance VARCHAR(30), k_symbol VARCHAR(30),
                           bank VARCHAR(10), account VARCHAR(30));

-- ---------- Load the files ----------
LOAD DATA LOCAL INFILE 'C:/Users/nimma/OneDrive/Desktop/bank-loan-sql-analysis/data/raw/account.csv'
INTO TABLE raw_account  FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/Users/nimma/OneDrive/Desktop/bank-loan-sql-analysis/data/raw/card.csv'
INTO TABLE raw_card     FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/Users/nimma/OneDrive/Desktop/bank-loan-sql-analysis/data/raw/client.csv'
INTO TABLE raw_client   FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/Users/nimma/OneDrive/Desktop/bank-loan-sql-analysis/data/raw/disp.csv'
INTO TABLE raw_disp     FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/Users/nimma/OneDrive/Desktop/bank-loan-sql-analysis/data/raw/district.csv'
INTO TABLE raw_district FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/Users/nimma/OneDrive/Desktop/bank-loan-sql-analysis/data/raw/loan.csv'
INTO TABLE raw_loan     FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/Users/nimma/OneDrive/Desktop/bank-loan-sql-analysis/data/raw/order.csv'
INTO TABLE raw_order    FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/Users/nimma/OneDrive/Desktop/bank-loan-sql-analysis/data/raw/trans.csv'
INTO TABLE raw_trans    FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

-- ---------- Check: row counts ----------
SELECT 'account'  AS table_name, COUNT(*) AS row_count FROM raw_account  UNION ALL
SELECT 'card',      COUNT(*) FROM raw_card     UNION ALL
SELECT 'client',    COUNT(*) FROM raw_client   UNION ALL
SELECT 'disp',      COUNT(*) FROM raw_disp     UNION ALL
SELECT 'district',  COUNT(*) FROM raw_district UNION ALL
SELECT 'loan',      COUNT(*) FROM raw_loan     UNION ALL
SELECT 'order',     COUNT(*) FROM raw_order    UNION ALL
SELECT 'trans',     COUNT(*) FROM raw_trans;