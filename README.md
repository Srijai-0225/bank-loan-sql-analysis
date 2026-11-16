# Czech Bank: Loan Default Risk & Customer Analytics (SQL + Tableau)

**Analysis by [Srijai Nimmagadda](https://www.linkedin.com/in/srijai-nimmagadda)** · Data Analyst

> **Summary:** Two simple pre-loan rules (a negative balance history, or a monthly payment of 20%+ of the average balance) flag just **10% of loans** but capture **50% of all defaults**. Every account that went negative before its loan defaulted (27 of 27).

**[▶ View the interactive Tableau dashboard](TABLEAU_LINK)**

![Dashboard](images/dashboard.png)

## Key Results
- **682 loans, 103.3M lent, 11.1% default rate**; bad loans hold **15.1%** of the money lent
- Accounts with a **negative balance before the loan defaulted 100%** of the time (vs 7.5%), i.e. 35.5% of all bad loans
- **Payment burden** is the steepest risk driver: 6.0% default under 10% of balance vs 55.6% at 40%+
- **Larger loans are riskier:** 4.0% (under 50K) to 20.7% (300K+)
- **Gender and age show no meaningful difference** (10–12%): behaviour predicts risk, demographics do not
- **Top 10% of accounts bring 31.6% of all deposits**; 80% of accounts have no card, yet card holders keep up to **1.9× higher balances**
- **505 high-balance accounts with no loan and no card** (39.8M held) are cross-sell targets

## Business Questions
1. Which loan, borrower and account-behaviour characteristics are linked to default?
2. Can simple, explainable rules identify high-risk loans before they are granted?
3. Where is customer value concentrated, and who should the bank target for cross-selling?

## Dataset
The **Berka dataset** (PKDD'99 Discovery Challenge): real, anonymized data from a Czech bank, 1993–1998. 8 related tables: account, client, disp, card, loan, order, trans (1,056,320 rows) and district.
Source: [The Berka Dataset on Kaggle](https://www.kaggle.com/datasets/marceloventura/the-berka-dataset) (CC0). Raw files are included in `data/raw/`.

## Tools
MySQL 8.0 · MySQL Workbench · Tableau Public

## Project Structure
```
├── sql/
│   ├── 01_load_raw_data.sql                 # create database, load 8 raw CSVs (staging layer)
│   ├── 02_clean_tables.sql                  # typed tables, keys, English labels, validation checks
│   ├── 03_loan_risk_analysis.sql            # default-risk drivers and rule-based risk tiers
│   ├── 04_customer_transaction_analysis.sql # transaction trends, value concentration, cross-sell
│   └── 05_tableau_exports.sql               # analysis-ready extracts for Tableau
├── data/
│   ├── raw/          # original Berka CSV files
│   └── processed/    # Tableau extracts
└── images/           # dashboard screenshot
```

## Methodology
- **Staging → clean layer:** loaded raw files as text, then built typed tables with primary and foreign keys
- **Data cleaning in SQL:** converted YYMMDD dates, translated Czech codes to English, decoded gender and birth date from the encoded `birth_number` field (month + 50 for women)
- **Validation:** row counts, date ranges and null checks after every transformation
- **No data leakage:** risk features use only transactions **before** each loan date
- **SQL techniques:** multi-table joins (including a many-to-many client–account link), CTEs, window functions (`ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE`, `LAG`, running totals, moving averages), conditional aggregation

## Recommendations
1. Do not lend to accounts with a recent negative balance without extra checks.
2. Cap the monthly payment at around 20% of the applicant's average balance.
3. Apply stricter review to large loans (300K+), which default at 2× the portfolio rate.
4. Target the 505 high-balance accounts with no products for card and loan offers.

## How to Run
1. Install MySQL 8.0 and MySQL Workbench.
2. In Workbench, enable local file loading: edit the connection → Advanced → Others: `OPT_LOCAL_INFILE=1`.
3. In `sql/01_load_raw_data.sql`, change the file paths to where you cloned this repository.
4. Run the scripts in order: 01 → 05.

## Author
**Srijai Nimmagadda**
- LinkedIn: [linkedin.com/in/srijai-nimmagadda](https://www.linkedin.com/in/srijai-nimmagadda)
- Email: [nimmagaddasrijai@gmail.com](mailto:nimmagaddasrijai@gmail.com)
