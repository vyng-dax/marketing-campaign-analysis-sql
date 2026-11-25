# Case study: Marketing campaign performance on a public CRM dataset

**Role target:** Marketing analyst / data analyst at a SaaS or technology company
**What this is:** A practice analysis of a public-domain consumer-brand CRM campaign file, used to show campaign comparison, product mix, channel mix, customer profiling, and careful data-quality work.
**What this is not:** A SaaS subscription event log, a paid-media ROI study, or confidential data from Vy Nguyen's employer.

**Dataset:** Marketing Campaign Results, published by Maven Analytics. Origin: Jack Daoud / iFood Data Business Analyst test, circulated via Kaggle. File analyzed: `data/marketing_campaign.csv` (semicolon-delimited; downloaded from [this public raw file](https://raw.githubusercontent.com/amankharwal/Website-data/master/marketing_campaign.csv)).

---

## Problem

The file records 2,240 customers (confirmed with `SELECT COUNT(*)`; Maven's page also describes 2,240 records). For each customer it includes demographics, income, recency, spend by six product categories, purchase counts by channel, flags for five historical campaigns, and a last-campaign response flag.

A hiring manager on a growth, CRM, or marketing-analytics team typically wants to know:

1. Is the data trustworthy enough to brief a stakeholder?
2. Which campaigns actually landed?
3. Where does spend concentrate, and which channels carry purchase volume?
4. Which customer traits line up with a higher chance of accepting the latest offer?

Those are the questions this project answers from the columns that exist. The file does not contain varying campaign cost or incremental revenue — `Z_CostContact` is 3 and `Z_Revenue` is 11 on every row — so CAC, ROI, and ROAS are not computed.

## Approach

The analysis is reproducible SQL in SQLite, then a Google Sheets dashboard built from the verified aggregates.

- Loaded the file with the correct separator (`;`) and stripped the UTF-8 BOM on the `ID` header. Empty income cells were converted to NULL so they would not be treated as zero.
- Profiled row count, duplicate IDs, blanks, birth years, and income extremes before computing any rate. No row was silently dropped.
- Defined age as year of `Dt_Customer` minus `Year_Birth`. Enrollment dates in the file run from 30 July 2012 to 29 June 2014, so the reference year is each customer's enrollment year, not a later assumed snapshot.
- Compared acceptance counts and rates for Campaigns 1–5 and the last campaign (`Response`), including the share of customers who accepted at least one offer.
- Totaled category spend and channel purchase counts separately, and did not treat channel counts as revenue.
- Related web purchases to income, recency, web visits, children at home, and campaign acceptance with group-by averages and Pearson correlation (product-moment formula; no p-values).
- Segmented last-campaign response by income quartile, education, recency, household, and whether the customer had accepted an earlier campaign.

## Findings

### The file is usable, with a few issues that must be named

- 2,240 customers and 2,240 distinct IDs; no duplicate keys.
- 24 customers (1.07%) have no income. They stay in the customer base and are excluded only from income statistics. One of those 24 accepted the last campaign, which is why income-quartile response counts sum to 333 rather than 334.
- Three birth years are implausible: 1893, 1899, and 1900 (enrollment ages 121, 114, and 113). The next oldest birth year is 1940. Those three rows stay in the base file and are excluded only from age statistics.
- One income of 666,666 (ID 9432) sits far above the next value of 162,397 and is the only income above 200,000. Including it, mean income is 52,247.25 and the median is 51,381.50 (n = 2,216). Excluding it, the mean is 51,969.86 and the median is 51,373 (n = 2,215). That customer accepted no campaigns, so campaign rates do not depend on whether the value is kept.

The typical customer, after those documented filters, is about 43 years old at enrollment (mean 44.13, median 43, n = 2,237), most often has a Graduation-level education (50.31%), and more often than not has a child at home (1,602 / 2,240 = 71.52%). Median income among known values is 51,381.50 recorded units.

### The last campaign outperformed the five earlier ones

Among Campaigns 1–5, Campaign 4 was the most successful at 7.46% (167 / 2,240). Campaign 2 was the weakest at 1.34% (30 / 2,240). Campaigns 3 and 5 each had 163 accepts (7.28%), and Campaign 1 had 144 (6.43%).

The last campaign (`Response`) reached 14.91% (334 / 2,240) — roughly double the best historical campaign. 20.67% of customers (463) accepted at least one of Campaigns 1–5, and 27.19% (609) accepted at least one offer including the last campaign. Nobody accepted all six flags; 10 customers accepted five.

Prior acceptance is a strong descriptive split: customers who had already accepted one of Campaigns 1–5 responded to the last campaign at 40.60% (188 / 463), versus 8.22% (146 / 1,777) among those who had not.

### Wines dominate category spend; the store dominates purchase counts

Wines account for 680,816 of 1,356,988 recorded category-spend units (50.17%), then meat at 27.56%. Gold, fish, sweets, and fruits together are 22.27%. Average category spend per customer is 605.80 units; the median is 396, so a smaller group of higher spenders pulls the mean up.

Store purchases total 12,970 events (average 5.79 per customer), web 9,150 (4.08), and catalog 5,963 (2.66). Of the 28,083 web + catalog + store events, the store is 46.18%, web 32.58%, and catalog 21.23%. Catalog also has 586 customers with no purchase. Deal purchases (5,208; average 2.33) are reported separately because they can overlap the other channels. These figures are counts, not channel revenue, so they do not support a claim that the store "earns more."

### Web purchases rise with income and fall with young children at home — not with recency or extra web visits

Web purchases have a moderate positive correlation with income (r = 0.388 on 2,216 customers with income; r = 0.459 after also excluding the 666,666 outlier). Correlation with `Kidhome` is negative (r = −0.362): customers with a kid at home average 2.87 web purchases versus 4.97 without a kid. Correlation with recency is essentially zero (r = −0.011), and correlation with monthly web visits is slightly negative (r = −0.056). More browsing, in this file, is not the same as more buying.

Customers who accepted at least one campaign average 5.06 web purchases versus 3.72 among those who accepted none (r = 0.205 with the count of accepted campaigns).

### Last-campaign response is concentrated

Among the 2,216 customers with income, last-campaign response is 10.47% in the bottom income quartile (58 / 554) and 26.90% in the top quartile (149 / 554). The share who accepted any campaign is 14.62% in Q1 and 49.28% in Q4. Average web purchases peak in Q3 (5.64) rather than Q4 (5.29), so income lines up more sharply with campaign acceptance than with web-purchase volume.

By education, PhD customers have the highest last-campaign rate at 20.78% (101 / 486) and Basic the lowest at 3.70% (2 / 54). Recency matters for the last campaign even though it does not move historical web-purchase counts: response is 26.79% when recency is 0–24 days and 7.32% when it is 74–99 days. Customers with no child at home responded at 26.49%, versus 10.30% among those with at least one child.

Only 21 customers complained (0.94%). Their last-campaign rate (3 / 21 = 14.29%) is almost the same as that of non-complainers (331 / 2,219 = 14.92%). That comparison is too small to lean on.

## Recommendations

These are analysis-backed next steps, not claimed business outcomes. The file does not show what happened after a change, so no lift, savings, or revenue impact is stated.

1. **Treat prior acceptors and recent buyers as the first audience to test for the next CRM offer.** The last campaign's 14.91% overall rate hides a 40.60% versus 8.22% gap by prior acceptance and a 26.79% versus 7.32% gap by recency. A clean test would measure incremental response in those segments rather than assuming the historical gap will repeat.
2. **Do not spend equally across the five historical campaign patterns.** Campaign 2's 1.34% acceptance is far below Campaign 4's 7.46%. The file does not say why (offer, creative, timing, and audience are not in the columns), so the useful action is to recover those campaign definitions if they still exist, not to invent an explanation.
3. **Keep wines and the store in the center of merchandising reviews, and investigate the catalog separately.** Wines are half of recorded category spend, and the store is the largest purchase-count channel. The catalog's lower volume and 586 zero-purchase customers are a reason to ask whether the catalog list is stale — not a reason to declare it unprofitable, because the file has no catalog cost or catalog revenue.
4. **Use income and household as targeting hypotheses, not as proven causes.** Higher-income customers and customers without children at home accepted more often in this file. Any targeting rule built on that pattern should be tested, because these are associations in an observational CRM extract.
5. **Do not compute ROI from `Z_CostContact` and `Z_Revenue`.** They do not vary. A future dataset would need actual offer cost, channel cost, and incremental revenue before return metrics are honest.

## Impact

The impact of this project is an analysis a hiring manager can audit: a documented customer count, explicit handling of missing and extreme values, campaign rates with numerators and denominators, a product mix and a channel mix that are not over-claimed as revenue, and a dashboard whose percentages are formulas on top of those counts. It does not claim that a brand saved money or grew sales, because this public file cannot show that.

## Dashboard and repository

- Dashboard: [Marketing Campaign Performance (Public Dataset)](https://docs.google.com/spreadsheets/d/1Qd10AabancK7F5-9seEwkyQqBPWSW5H0HnFvIK_liOA/edit) (spreadsheetId `1Qd10AabancK7F5-9seEwkyQqBPWSW5H0HnFvIK_liOA`).
- SQL: `sql/campaign_analysis.sql`, runnable via `python3 sql/run_analysis.py`.
- Narrative and reproduction notes: `README.md`.
