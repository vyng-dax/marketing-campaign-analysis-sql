-- =============================================================================
-- Marketing Campaign Performance Analysis
-- =============================================================================
-- Dataset: public-domain Marketing Campaign Results
-- Publisher: Maven Analytics
-- Origin: Jack Daoud / iFood Data Business Analyst test, circulated via Kaggle
-- Download used: https://raw.githubusercontent.com/amankharwal/Website-data/master/marketing_campaign.csv
--
-- This is a practice CRM / campaign dataset about a consumer brand. It is not
-- confidential employer data and it is not a SaaS subscription event log.
--
-- Grain: one row per customer (ID).
-- Currency: the file does not name a currency. Income and Mnt* amounts are
--           reported in recorded units, not converted and not labeled USD.
--
-- What this file does NOT compute
-- --------------------------------
-- CAC, ROI, and ROAS are not computed. Z_CostContact = 3 and Z_Revenue = 11
-- on every row (verified below). Constants cannot support campaign-level
-- return metrics. Product amounts are spend by category, not by channel.
-- Channel columns are purchase COUNTS, not revenue.
--
-- How missing values and outliers are handled
-- -------------------------------------------
-- No row is silently dropped from the customer base.
-- * 24 blank Income values are treated as NULL and excluded only from
--   income statistics, income correlations, and income quartiles.
-- * 3 implausible Year_Birth values (1893, 1899, 1900) stay in the base
--   file and are excluded only from age statistics.
-- * One Income value of 666666 (ID 9432) is flagged as an extreme outlier.
--   Income totals are reported both including and excluding it.
--
-- Age definition
-- --------------
-- age_at_enrollment = year(Dt_Customer) - Year_Birth.
-- Enrollment years in this file run from 2012-07-30 to 2014-06-29, so the
-- reference year is each customer's own enrollment year, not a later
-- assumed snapshot (for example 2015). Age as of calendar year 2014 is
-- not used as the primary figure.
--
-- How to load the semicolon-delimited CSV and run this script
-- -----------------------------------------------------------
-- The source file is delimited by semicolons, not commas, and it begins
-- with a UTF-8 BOM on the ID header. It also has no trailing newline after
-- the last record, so `wc -l` (which counts newline characters) is not a
-- reliable customer count. Use SQL COUNT(*) .
--
-- Recommended (Python; strips the BOM and creates a TEXT table named raw):
--
--   python3 sql/run_analysis.py
--
-- From the project root, with the SQLite CLI installed:
--
--   sqlite3 :memory: \
--     ".mode csv" \
--     ".separator ;" \
--     ".headers on" \
--     ".import data/marketing_campaign.csv raw" \
--     ".read sql/campaign_analysis.sql"
--
-- If the CLI import keeps a BOM on the first column name (visible as
-- something other than ID in PRAGMA table_info(raw)), rename that column
-- to ID before running this file, or use the Python runner instead.
--
-- SQLite CSV import stores empty cells as empty strings, not SQL NULL.
-- Income is converted with NULLIF(TRIM(Income), '') so blanks are NULL
-- and are skipped by AVG/MIN/MAX rather than coerced to 0.
-- =============================================================================

DROP TABLE IF EXISTS customers;

CREATE TABLE customers AS
SELECT
    ID,
    CAST(Year_Birth AS INTEGER) AS Year_Birth,
    Education,
    Marital_Status,
    CAST(NULLIF(TRIM(Income), '') AS REAL) AS Income,
    CAST(Kidhome AS INTEGER) AS Kidhome,
    CAST(Teenhome AS INTEGER) AS Teenhome,
    Dt_Customer,
    CAST(substr(Dt_Customer, 1, 4) AS INTEGER) AS enroll_year,
    CAST(substr(Dt_Customer, 1, 4) AS INTEGER)
        - CAST(Year_Birth AS INTEGER) AS age_at_enrollment,
    CAST(Recency AS INTEGER) AS Recency,
    CAST(MntWines AS INTEGER) AS MntWines,
    CAST(MntFruits AS INTEGER) AS MntFruits,
    CAST(MntMeatProducts AS INTEGER) AS MntMeatProducts,
    CAST(MntFishProducts AS INTEGER) AS MntFishProducts,
    CAST(MntSweetProducts AS INTEGER) AS MntSweetProducts,
    CAST(MntGoldProds AS INTEGER) AS MntGoldProds,
    CAST(MntWines AS INTEGER)
        + CAST(MntFruits AS INTEGER)
        + CAST(MntMeatProducts AS INTEGER)
        + CAST(MntFishProducts AS INTEGER)
        + CAST(MntSweetProducts AS INTEGER)
        + CAST(MntGoldProds AS INTEGER) AS total_mnt,
    CAST(NumDealsPurchases AS INTEGER) AS NumDealsPurchases,
    CAST(NumWebPurchases AS INTEGER) AS NumWebPurchases,
    CAST(NumCatalogPurchases AS INTEGER) AS NumCatalogPurchases,
    CAST(NumStorePurchases AS INTEGER) AS NumStorePurchases,
    CAST(NumWebVisitsMonth AS INTEGER) AS NumWebVisitsMonth,
    CAST(AcceptedCmp1 AS INTEGER) AS AcceptedCmp1,
    CAST(AcceptedCmp2 AS INTEGER) AS AcceptedCmp2,
    CAST(AcceptedCmp3 AS INTEGER) AS AcceptedCmp3,
    CAST(AcceptedCmp4 AS INTEGER) AS AcceptedCmp4,
    CAST(AcceptedCmp5 AS INTEGER) AS AcceptedCmp5,
    CAST(Complain AS INTEGER) AS Complain,
    CAST(Z_CostContact AS INTEGER) AS Z_CostContact,
    CAST(Z_Revenue AS INTEGER) AS Z_Revenue,
    CAST(Response AS INTEGER) AS Response
FROM raw;


-- -----------------------------------------------------------------------------
-- 1. Row count, duplicates, missing values, outliers
-- -----------------------------------------------------------------------------

SELECT '1a. Customer count (SQL COUNT(*); do not use wc -l)' AS section;

SELECT COUNT(*) AS customer_count
FROM customers;

SELECT '1b. Duplicate IDs' AS section;

SELECT
    COUNT(*) AS customer_count,
    COUNT(DISTINCT ID) AS distinct_ids,
    COUNT(*) - COUNT(DISTINCT ID) AS duplicate_id_rows
FROM customers;

SELECT '1c. Blank / NULL scan on raw text columns (only Income is blank)' AS section;

SELECT
    SUM(CASE WHEN NULLIF(TRIM(ID), '') IS NULL THEN 1 ELSE 0 END) AS blank_ID,
    SUM(CASE WHEN NULLIF(TRIM(Year_Birth), '') IS NULL THEN 1 ELSE 0 END) AS blank_Year_Birth,
    SUM(CASE WHEN NULLIF(TRIM(Education), '') IS NULL THEN 1 ELSE 0 END) AS blank_Education,
    SUM(CASE WHEN NULLIF(TRIM(Marital_Status), '') IS NULL THEN 1 ELSE 0 END) AS blank_Marital_Status,
    SUM(CASE WHEN NULLIF(TRIM(Income), '') IS NULL THEN 1 ELSE 0 END) AS blank_Income,
    SUM(CASE WHEN NULLIF(TRIM(Kidhome), '') IS NULL THEN 1 ELSE 0 END) AS blank_Kidhome,
    SUM(CASE WHEN NULLIF(TRIM(Teenhome), '') IS NULL THEN 1 ELSE 0 END) AS blank_Teenhome,
    SUM(CASE WHEN NULLIF(TRIM(Dt_Customer), '') IS NULL THEN 1 ELSE 0 END) AS blank_Dt_Customer,
    SUM(CASE WHEN NULLIF(TRIM(Recency), '') IS NULL THEN 1 ELSE 0 END) AS blank_Recency,
    SUM(CASE WHEN NULLIF(TRIM(MntWines), '') IS NULL THEN 1 ELSE 0 END) AS blank_MntWines,
    SUM(CASE WHEN NULLIF(TRIM(Response), '') IS NULL THEN 1 ELSE 0 END) AS blank_Response
FROM raw;

SELECT '1c-detail. The 24 customers with missing Income (kept in the base file)' AS section;

SELECT ID, Year_Birth, Education, Marital_Status, Dt_Customer
FROM customers
WHERE Income IS NULL
ORDER BY CAST(ID AS INTEGER);

SELECT '1d. Year_Birth values that imply age 110+ at enrollment (kept in the base file; excluded from age stats only)' AS section;

SELECT
    ID,
    Year_Birth,
    Dt_Customer,
    age_at_enrollment,
    Education,
    Marital_Status,
    Income
FROM customers
WHERE Year_Birth < 1940
ORDER BY Year_Birth;

SELECT '1d-context. Next-oldest birth years after the three outliers (gap supports treating 1893/1899/1900 as implausible)' AS section;

SELECT Year_Birth, COUNT(*) AS n
FROM customers
GROUP BY Year_Birth
ORDER BY Year_Birth
LIMIT 8;

SELECT '1e. Income extremes among non-null incomes' AS section;

SELECT
    COUNT(Income) AS n_nonnull_income,
    MIN(Income) AS min_income,
    MAX(Income) AS max_income,
    AVG(Income) AS mean_income_incl_666666
FROM customers
WHERE Income IS NOT NULL;

SELECT
    ID,
    Year_Birth,
    Education,
    Marital_Status,
    Income,
    Dt_Customer,
    AcceptedCmp1,
    AcceptedCmp2,
    AcceptedCmp3,
    AcceptedCmp4,
    AcceptedCmp5,
    Response
FROM customers
WHERE Income IS NOT NULL
ORDER BY Income DESC
LIMIT 10;

SELECT '1e-sensitivity. Income mean/median with and without the 666666 outlier (ID 9432)' AS section;

SELECT
    'including_666666' AS version,
    COUNT(Income) AS n,
    AVG(Income) AS mean_income,
    (
        SELECT AVG(val)
        FROM (
            SELECT
                Income AS val,
                ROW_NUMBER() OVER (ORDER BY Income) AS rn,
                COUNT(*) OVER () AS cnt
            FROM customers
            WHERE Income IS NOT NULL
        )
        WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
    ) AS median_income
FROM customers
WHERE Income IS NOT NULL
UNION ALL
SELECT
    'excluding_666666',
    COUNT(Income),
    AVG(Income),
    (
        SELECT AVG(val)
        FROM (
            SELECT
                Income AS val,
                ROW_NUMBER() OVER (ORDER BY Income) AS rn,
                COUNT(*) OVER () AS cnt
            FROM customers
            WHERE Income IS NOT NULL
              AND Income != 666666
        )
        WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
    )
FROM customers
WHERE Income IS NOT NULL
  AND Income != 666666;

SELECT '1e-tail. How isolated is 666666 relative to other high incomes?' AS section;

SELECT
    SUM(CASE WHEN Income > 100000 THEN 1 ELSE 0 END) AS income_above_100000,
    SUM(CASE WHEN Income > 150000 THEN 1 ELSE 0 END) AS income_above_150000,
    SUM(CASE WHEN Income > 200000 THEN 1 ELSE 0 END) AS income_above_200000,
    SUM(CASE WHEN Income = 666666 THEN 1 ELSE 0 END) AS income_equals_666666
FROM customers
WHERE Income IS NOT NULL;

SELECT '1f. Z_CostContact and Z_Revenue (constants; cannot support ROI/CAC/ROAS)' AS section;

SELECT Z_CostContact, COUNT(*) AS n
FROM customers
GROUP BY Z_CostContact;

SELECT Z_Revenue, COUNT(*) AS n
FROM customers
GROUP BY Z_Revenue;

SELECT '1g. Enrollment-date range (used as the age reference)' AS section;

SELECT
    MIN(Dt_Customer) AS min_dt_customer,
    MAX(Dt_Customer) AS max_dt_customer
FROM customers;

SELECT enroll_year, COUNT(*) AS n, MIN(Dt_Customer) AS min_date, MAX(Dt_Customer) AS max_date
FROM customers
GROUP BY enroll_year
ORDER BY enroll_year;

SELECT '1h. Unusual Marital_Status labels (reported as recorded; not recoded)' AS section;

SELECT Marital_Status, COUNT(*) AS n
FROM customers
GROUP BY Marital_Status
ORDER BY n DESC;


-- -----------------------------------------------------------------------------
-- 2. Average / median customer profile
-- -----------------------------------------------------------------------------

SELECT '2a. Age at enrollment (year of Dt_Customer minus Year_Birth); 3 implausible births excluded' AS section;

SELECT
    COUNT(*) AS n_age,
    AVG(age_at_enrollment) AS mean_age,
    (
        SELECT AVG(val)
        FROM (
            SELECT
                age_at_enrollment AS val,
                ROW_NUMBER() OVER (ORDER BY age_at_enrollment) AS rn,
                COUNT(*) OVER () AS cnt
            FROM customers
            WHERE Year_Birth >= 1940
        )
        WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
    ) AS median_age,
    MIN(age_at_enrollment) AS min_age,
    MAX(age_at_enrollment) AS max_age
FROM customers
WHERE Year_Birth >= 1940;

SELECT '2b. Education' AS section;

SELECT
    Education,
    COUNT(*) AS n,
    1.0 * COUNT(*) / (SELECT COUNT(*) FROM customers) AS share
FROM customers
GROUP BY Education
ORDER BY n DESC;

SELECT '2c. Marital status (labels as recorded)' AS section;

SELECT
    Marital_Status,
    COUNT(*) AS n,
    1.0 * COUNT(*) / (SELECT COUNT(*) FROM customers) AS share
FROM customers
GROUP BY Marital_Status
ORDER BY n DESC;

SELECT '2d. Income (nulls excluded; 666666 included in the first row of query 1e-sensitivity)' AS section;

SELECT
    COUNT(Income) AS n_nonnull_income,
    AVG(Income) AS mean_income,
    (
        SELECT AVG(val)
        FROM (
            SELECT
                Income AS val,
                ROW_NUMBER() OVER (ORDER BY Income) AS rn,
                COUNT(*) OVER () AS cnt
            FROM customers
            WHERE Income IS NOT NULL
        )
        WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
    ) AS median_income,
    MIN(Income) AS min_income,
    MAX(Income) AS max_income
FROM customers
WHERE Income IS NOT NULL;

SELECT '2e. Children at home' AS section;

SELECT
    AVG(Kidhome) AS avg_kidhome,
    SUM(Kidhome) AS sum_kidhome,
    SUM(CASE WHEN Kidhome > 0 THEN 1 ELSE 0 END) AS customers_with_kid,
    AVG(Teenhome) AS avg_teenhome,
    SUM(Teenhome) AS sum_teenhome,
    SUM(CASE WHEN Teenhome > 0 THEN 1 ELSE 0 END) AS customers_with_teen,
    AVG(Kidhome + Teenhome) AS avg_children_at_home,
    SUM(Kidhome + Teenhome) AS sum_children_at_home,
    SUM(CASE WHEN Kidhome + Teenhome > 0 THEN 1 ELSE 0 END) AS customers_with_child
FROM customers;

SELECT Kidhome, COUNT(*) AS n
FROM customers
GROUP BY Kidhome
ORDER BY Kidhome;

SELECT Teenhome, COUNT(*) AS n
FROM customers
GROUP BY Teenhome
ORDER BY Teenhome;


-- -----------------------------------------------------------------------------
-- 3. Campaign success
-- -----------------------------------------------------------------------------

SELECT '3a. Acceptance counts and rates for Campaigns 1-5 and the last campaign (Response)' AS section;

SELECT
    'AcceptedCmp1' AS campaign,
    SUM(AcceptedCmp1) AS accepts,
    COUNT(*) AS customers,
    1.0 * SUM(AcceptedCmp1) / COUNT(*) AS acceptance_rate
FROM customers
UNION ALL
SELECT 'AcceptedCmp2', SUM(AcceptedCmp2), COUNT(*), 1.0 * SUM(AcceptedCmp2) / COUNT(*) FROM customers
UNION ALL
SELECT 'AcceptedCmp3', SUM(AcceptedCmp3), COUNT(*), 1.0 * SUM(AcceptedCmp3) / COUNT(*) FROM customers
UNION ALL
SELECT 'AcceptedCmp4', SUM(AcceptedCmp4), COUNT(*), 1.0 * SUM(AcceptedCmp4) / COUNT(*) FROM customers
UNION ALL
SELECT 'AcceptedCmp5', SUM(AcceptedCmp5), COUNT(*), 1.0 * SUM(AcceptedCmp5) / COUNT(*) FROM customers
UNION ALL
SELECT 'Response (last campaign)', SUM(Response), COUNT(*), 1.0 * SUM(Response) / COUNT(*) FROM customers;

SELECT '3b. Most successful: Campaign 4 leads Campaigns 1-5; Response leads overall' AS section;

SELECT '3c. Share who accepted at least one campaign' AS section;

SELECT
    SUM(CASE WHEN AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 > 0
             THEN 1 ELSE 0 END) AS accepted_any_of_cmp1_to_5,
    1.0 * SUM(CASE WHEN AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 > 0
                   THEN 1 ELSE 0 END) / COUNT(*) AS rate_any_of_cmp1_to_5,
    SUM(CASE WHEN AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 + Response > 0
             THEN 1 ELSE 0 END) AS accepted_any_including_last,
    1.0 * SUM(CASE WHEN AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 + Response > 0
                   THEN 1 ELSE 0 END) / COUNT(*) AS rate_any_including_last,
    SUM(AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 + Response) AS total_accept_events,
    COUNT(*) AS customers
FROM customers;

SELECT '3d. How many of the six campaign flags each customer accepted' AS section;

SELECT
    (AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 + Response) AS n_campaigns_accepted,
    COUNT(*) AS customers
FROM customers
GROUP BY 1
ORDER BY 1;

SELECT '3e. Last-campaign response rate among prior acceptors vs everyone else' AS section;

SELECT
    CASE WHEN AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 > 0
         THEN 'accepted_at_least_one_of_cmp1_to_5'
         ELSE 'accepted_none_of_cmp1_to_5' END AS prior_acceptance,
    COUNT(*) AS customers,
    SUM(Response) AS last_campaign_accepts,
    1.0 * SUM(Response) / COUNT(*) AS last_campaign_rate
FROM customers
GROUP BY 1;


-- -----------------------------------------------------------------------------
-- 4. Product performance (category spend in recorded units; not channel revenue)
-- -----------------------------------------------------------------------------

SELECT '4a. Totals, averages, and shares of category spend' AS section;

SELECT
    category,
    total_spend,
    1.0 * total_spend / (SELECT SUM(total_mnt) FROM customers) AS share_of_category_spend,
    1.0 * total_spend / (SELECT COUNT(*) FROM customers) AS avg_per_customer,
    min_spend,
    max_spend
FROM (
    SELECT 'Wines' AS category, SUM(MntWines) AS total_spend, MIN(MntWines) AS min_spend, MAX(MntWines) AS max_spend FROM customers
    UNION ALL
    SELECT 'Meat', SUM(MntMeatProducts), MIN(MntMeatProducts), MAX(MntMeatProducts) FROM customers
    UNION ALL
    SELECT 'Gold', SUM(MntGoldProds), MIN(MntGoldProds), MAX(MntGoldProds) FROM customers
    UNION ALL
    SELECT 'Fish', SUM(MntFishProducts), MIN(MntFishProducts), MAX(MntFishProducts) FROM customers
    UNION ALL
    SELECT 'Sweets', SUM(MntSweetProducts), MIN(MntSweetProducts), MAX(MntSweetProducts) FROM customers
    UNION ALL
    SELECT 'Fruits', SUM(MntFruits), MIN(MntFruits), MAX(MntFruits) FROM customers
)
ORDER BY total_spend DESC;

SELECT '4b. Total category spend across all customers' AS section;

SELECT
    SUM(total_mnt) AS total_category_spend,
    AVG(total_mnt) AS mean_category_spend_per_customer,
    (
        SELECT AVG(val)
        FROM (
            SELECT
                total_mnt AS val,
                ROW_NUMBER() OVER (ORDER BY total_mnt) AS rn,
                COUNT(*) OVER () AS cnt
            FROM customers
        )
        WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
    ) AS median_category_spend_per_customer,
    MIN(total_mnt) AS min_category_spend,
    MAX(total_mnt) AS max_category_spend
FROM customers;


-- -----------------------------------------------------------------------------
-- 5. Channel performance (purchase COUNTS, not revenue or ROI)
-- -----------------------------------------------------------------------------

SELECT '5a. Totals and averages. Deals can overlap the other three channels.' AS section;

SELECT
    'Web purchases' AS metric,
    SUM(NumWebPurchases) AS total_events,
    AVG(NumWebPurchases) AS avg_per_customer,
    MIN(NumWebPurchases) AS min_val,
    MAX(NumWebPurchases) AS max_val,
    SUM(CASE WHEN NumWebPurchases = 0 THEN 1 ELSE 0 END) AS customers_with_zero
FROM customers
UNION ALL
SELECT 'Catalog purchases', SUM(NumCatalogPurchases), AVG(NumCatalogPurchases), MIN(NumCatalogPurchases), MAX(NumCatalogPurchases),
       SUM(CASE WHEN NumCatalogPurchases = 0 THEN 1 ELSE 0 END) FROM customers
UNION ALL
SELECT 'Store purchases', SUM(NumStorePurchases), AVG(NumStorePurchases), MIN(NumStorePurchases), MAX(NumStorePurchases),
       SUM(CASE WHEN NumStorePurchases = 0 THEN 1 ELSE 0 END) FROM customers
UNION ALL
SELECT 'Deal purchases (may overlap channels)', SUM(NumDealsPurchases), AVG(NumDealsPurchases), MIN(NumDealsPurchases), MAX(NumDealsPurchases),
       SUM(CASE WHEN NumDealsPurchases = 0 THEN 1 ELSE 0 END) FROM customers
UNION ALL
SELECT 'Web visits in the month', SUM(NumWebVisitsMonth), AVG(NumWebVisitsMonth), MIN(NumWebVisitsMonth), MAX(NumWebVisitsMonth),
       SUM(CASE WHEN NumWebVisitsMonth = 0 THEN 1 ELSE 0 END) FROM customers;

SELECT '5b. Shares among web + catalog + store purchase events (deals excluded from the denominator)' AS section;

SELECT
    SUM(NumWebPurchases) AS web_purchases,
    SUM(NumCatalogPurchases) AS catalog_purchases,
    SUM(NumStorePurchases) AS store_purchases,
    SUM(NumWebPurchases + NumCatalogPurchases + NumStorePurchases) AS web_catalog_store_total,
    1.0 * SUM(NumWebPurchases) / SUM(NumWebPurchases + NumCatalogPurchases + NumStorePurchases) AS web_share,
    1.0 * SUM(NumCatalogPurchases) / SUM(NumWebPurchases + NumCatalogPurchases + NumStorePurchases) AS catalog_share,
    1.0 * SUM(NumStorePurchases) / SUM(NumWebPurchases + NumCatalogPurchases + NumStorePurchases) AS store_share,
    SUM(CASE WHEN NumWebPurchases + NumCatalogPurchases + NumStorePurchases = 0 THEN 1 ELSE 0 END) AS customers_with_zero_channel_purchases
FROM customers;


-- -----------------------------------------------------------------------------
-- 6. Web purchases related to income, recency, visits, children, and campaigns
--    Pearson r is computed with the standard product-moment formula.
--    No p-values are reported (they were not computed).
-- -----------------------------------------------------------------------------

SELECT '6a. Pearson correlation: NumWebPurchases vs selected variables' AS section;

SELECT
    'NumWebPurchases ~ Income (24 null incomes excluded)' AS pair,
    COUNT(*) AS n,
    (COUNT(*) * SUM(x * y) - SUM(x) * SUM(y)) * 1.0
        / SQRT(
            (COUNT(*) * SUM(x * x) - SUM(x) * SUM(x))
          * (COUNT(*) * SUM(y * y) - SUM(y) * SUM(y))
        ) AS pearson_r
FROM (SELECT Income AS x, NumWebPurchases AS y FROM customers WHERE Income IS NOT NULL)
UNION ALL
SELECT
    'NumWebPurchases ~ Income (nulls and 666666 excluded)',
    COUNT(*),
    (COUNT(*) * SUM(x * y) - SUM(x) * SUM(y)) * 1.0
        / SQRT(
            (COUNT(*) * SUM(x * x) - SUM(x) * SUM(x))
          * (COUNT(*) * SUM(y * y) - SUM(y) * SUM(y))
        )
FROM (SELECT Income AS x, NumWebPurchases AS y FROM customers WHERE Income IS NOT NULL AND Income != 666666)
UNION ALL
SELECT
    'NumWebPurchases ~ Recency',
    COUNT(*),
    (COUNT(*) * SUM(x * y) - SUM(x) * SUM(y)) * 1.0
        / SQRT(
            (COUNT(*) * SUM(x * x) - SUM(x) * SUM(x))
          * (COUNT(*) * SUM(y * y) - SUM(y) * SUM(y))
        )
FROM (SELECT Recency AS x, NumWebPurchases AS y FROM customers)
UNION ALL
SELECT
    'NumWebPurchases ~ NumWebVisitsMonth',
    COUNT(*),
    (COUNT(*) * SUM(x * y) - SUM(x) * SUM(y)) * 1.0
        / SQRT(
            (COUNT(*) * SUM(x * x) - SUM(x) * SUM(x))
          * (COUNT(*) * SUM(y * y) - SUM(y) * SUM(y))
        )
FROM (SELECT NumWebVisitsMonth AS x, NumWebPurchases AS y FROM customers)
UNION ALL
SELECT
    'NumWebPurchases ~ Kidhome',
    COUNT(*),
    (COUNT(*) * SUM(x * y) - SUM(x) * SUM(y)) * 1.0
        / SQRT(
            (COUNT(*) * SUM(x * x) - SUM(x) * SUM(x))
          * (COUNT(*) * SUM(y * y) - SUM(y) * SUM(y))
        )
FROM (SELECT Kidhome AS x, NumWebPurchases AS y FROM customers)
UNION ALL
SELECT
    'NumWebPurchases ~ Teenhome',
    COUNT(*),
    (COUNT(*) * SUM(x * y) - SUM(x) * SUM(y)) * 1.0
        / SQRT(
            (COUNT(*) * SUM(x * x) - SUM(x) * SUM(x))
          * (COUNT(*) * SUM(y * y) - SUM(y) * SUM(y))
        )
FROM (SELECT Teenhome AS x, NumWebPurchases AS y FROM customers)
UNION ALL
SELECT
    'NumWebPurchases ~ count of accepted campaigns (cmp1-5 + Response)',
    COUNT(*),
    (COUNT(*) * SUM(x * y) - SUM(x) * SUM(y)) * 1.0
        / SQRT(
            (COUNT(*) * SUM(x * x) - SUM(x) * SUM(x))
          * (COUNT(*) * SUM(y * y) - SUM(y) * SUM(y))
        )
FROM (
    SELECT
        (AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 + Response) AS x,
        NumWebPurchases AS y
    FROM customers
);

SELECT '6b. Average web purchases and last-campaign rate by income quartile (NTILE of non-null Income; 666666 falls in Q4)' AS section;

WITH base AS (
    SELECT
        *,
        NTILE(4) OVER (ORDER BY Income) AS income_quartile
    FROM customers
    WHERE Income IS NOT NULL
)
SELECT
    income_quartile,
    COUNT(*) AS n,
    MIN(Income) AS min_income,
    MAX(Income) AS max_income,
    AVG(Income) AS avg_income,
    AVG(NumWebPurchases) AS avg_web_purchases,
    SUM(Response) AS last_campaign_accepts,
    1.0 * SUM(Response) / COUNT(*) AS last_campaign_rate,
    SUM(CASE WHEN AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 + Response > 0
             THEN 1 ELSE 0 END) AS accepted_any,
    1.0 * SUM(CASE WHEN AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 + Response > 0
                   THEN 1 ELSE 0 END) / COUNT(*) AS accepted_any_rate
FROM base
GROUP BY income_quartile
ORDER BY income_quartile;

SELECT '6b-note. One of the 24 customers with missing Income accepted the last campaign, so quartile accepts sum to 333, not 334.' AS section;

SELECT
    COUNT(*) AS missing_income_customers,
    SUM(Response) AS missing_income_last_campaign_accepts,
    SUM(CASE WHEN AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 > 0
             THEN 1 ELSE 0 END) AS missing_income_accepted_any_of_cmp1_to_5,
    SUM(CASE WHEN AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 + Response > 0
             THEN 1 ELSE 0 END) AS missing_income_accepted_any_including_last
FROM customers
WHERE Income IS NULL;

SELECT '6c. Average web purchases by household flags' AS section;

SELECT
    CASE WHEN Kidhome > 0 THEN 'has_kid' ELSE 'no_kid' END AS kid_flag,
    COUNT(*) AS n,
    AVG(NumWebPurchases) AS avg_web_purchases,
    AVG(NumWebVisitsMonth) AS avg_web_visits,
    1.0 * SUM(Response) / COUNT(*) AS last_campaign_rate
FROM customers
GROUP BY 1;

SELECT
    CASE WHEN Teenhome > 0 THEN 'has_teen' ELSE 'no_teen' END AS teen_flag,
    COUNT(*) AS n,
    AVG(NumWebPurchases) AS avg_web_purchases,
    AVG(NumWebVisitsMonth) AS avg_web_visits,
    1.0 * SUM(Response) / COUNT(*) AS last_campaign_rate
FROM customers
GROUP BY 1;

SELECT
    CASE WHEN Kidhome + Teenhome > 0 THEN 'has_child' ELSE 'no_child' END AS child_flag,
    COUNT(*) AS n,
    AVG(NumWebPurchases) AS avg_web_purchases,
    AVG(NumStorePurchases) AS avg_store_purchases,
    AVG(NumCatalogPurchases) AS avg_catalog_purchases,
    AVG(NumDealsPurchases) AS avg_deal_purchases,
    1.0 * SUM(Response) / COUNT(*) AS last_campaign_rate
FROM customers
GROUP BY 1;

SELECT '6d. Average web purchases by campaign acceptance' AS section;

SELECT
    CASE WHEN AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 + Response > 0
         THEN 'accepted_any' ELSE 'accepted_none' END AS acceptance,
    COUNT(*) AS n,
    AVG(NumWebPurchases) AS avg_web_purchases,
    AVG(NumWebVisitsMonth) AS avg_web_visits,
    AVG(Income) AS avg_income_nonnull
FROM customers
GROUP BY 1;

SELECT '6e. Recency quartiles: web purchases stay flat; last-campaign response does not' AS section;

WITH base AS (
    SELECT
        *,
        NTILE(4) OVER (ORDER BY Recency) AS recency_quartile
    FROM customers
)
SELECT
    recency_quartile,
    COUNT(*) AS n,
    MIN(Recency) AS min_recency,
    MAX(Recency) AS max_recency,
    AVG(NumWebPurchases) AS avg_web_purchases,
    1.0 * SUM(Response) / COUNT(*) AS last_campaign_rate
FROM base
GROUP BY recency_quartile
ORDER BY recency_quartile;

SELECT '6f. Web-visit bands vs web purchases (10+ band is only 12 customers)' AS section;

SELECT
    CASE
        WHEN NumWebVisitsMonth = 0 THEN '0'
        WHEN NumWebVisitsMonth BETWEEN 1 AND 3 THEN '1-3'
        WHEN NumWebVisitsMonth BETWEEN 4 AND 6 THEN '4-6'
        WHEN NumWebVisitsMonth BETWEEN 7 AND 9 THEN '7-9'
        ELSE '10+'
    END AS visit_band,
    COUNT(*) AS n,
    AVG(NumWebPurchases) AS avg_web_purchases,
    1.0 * SUM(Response) / COUNT(*) AS last_campaign_rate,
    MIN(NumWebVisitsMonth) AS min_visits,
    MAX(NumWebVisitsMonth) AS max_visits
FROM customers
GROUP BY 1
ORDER BY min_visits;


-- -----------------------------------------------------------------------------
-- 7. Response rate by income quartile (already in 6b), education, and complain
-- -----------------------------------------------------------------------------

SELECT '7a. Last-campaign response rate by education' AS section;

SELECT
    Education,
    COUNT(*) AS n,
    AVG(NumWebPurchases) AS avg_web_purchases,
    SUM(Response) AS last_campaign_accepts,
    1.0 * SUM(Response) / COUNT(*) AS last_campaign_rate,
    SUM(CASE WHEN AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 + Response > 0
             THEN 1 ELSE 0 END) AS accepted_any,
    1.0 * SUM(CASE WHEN AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 + Response > 0
                   THEN 1 ELSE 0 END) / COUNT(*) AS accepted_any_rate
FROM customers
GROUP BY Education
ORDER BY n DESC;

SELECT '7b. Complain rate and last-campaign response among complainers' AS section;

SELECT
    Complain,
    COUNT(*) AS n,
    1.0 * COUNT(*) / (SELECT COUNT(*) FROM customers) AS share_of_customers,
    SUM(Response) AS last_campaign_accepts,
    1.0 * SUM(Response) / COUNT(*) AS last_campaign_rate
FROM customers
GROUP BY Complain
ORDER BY Complain;

SELECT '7c. Last-campaign response by marital status (Alone / YOLO / Absurd have n <= 3; rates are not reliable)' AS section;

SELECT
    Marital_Status,
    COUNT(*) AS n,
    SUM(Response) AS last_campaign_accepts,
    1.0 * SUM(Response) / COUNT(*) AS last_campaign_rate
FROM customers
GROUP BY Marital_Status
ORDER BY n DESC;

SELECT 'End of campaign_analysis.sql' AS section;
