# Marketing Campaign Performance (Public Dataset)

SQL analysis and Google Sheets dashboard of a public-domain consumer-brand CRM campaign file. The work practices the campaign, channel, product-mix, and customer-profile questions that marketing and data analyst teams at SaaS and technology companies hire for. It is **not** a SaaS subscription event log, and it is **not** confidential data from Vy Nguyen's employer.

## Source and license

| Item | Detail |
| --- | --- |
| Dataset | Marketing Campaign Results |
| Publisher | Maven Analytics |
| Origin | Jack Daoud / iFood Data Business Analyst test, circulated via Kaggle |
| File used | `data/marketing_campaign.csv`, downloaded from [amankharwal/Website-data](https://raw.githubusercontent.com/amankharwal/Website-data/master/marketing_campaign.csv) |
| Delimiter | Semicolon (`;`), not comma |
| Encoding | UTF-8 with a BOM on the `ID` header |
| Grain | One row per customer (`ID`) |
| Currency | The file does not name a currency. Income and `Mnt*` amounts are reported in **recorded units** |

Maven Analytics describes the dataset as 2,240 records. That claim matches `SELECT COUNT(*) FROM customers` on this file: **2,240 customers**. `wc -l` also printed 2,240, but that figure counts newline characters. The file has no trailing newline after the last record, so it contains 2,241 logical lines (1 header + 2,240 customers). Do not treat `wc -l - 1` as the customer count.

This repository does not claim ownership of the upstream dataset. It is used here as a public practice file.

## Problem

A consumer brand ran several CRM campaigns and recorded who accepted each offer, what customers spent by product category, and how many purchases they made through the web, catalog, and store. The questions this analysis answers from those columns are:

- What does the typical customer look like (age, education, household, income)?
- Which campaigns were accepted most often?
- Which product categories account for the most recorded spend?
- Which purchase channels are used more, remembering that the channel fields are **counts**, not revenue?
- How do web purchases line up with income, recency, web visits, children at home, and campaign acceptance?

The file cannot answer cost efficiency. `Z_CostContact` is 3 on all 2,240 rows and `Z_Revenue` is 11 on all 2,240 rows. Those constants cannot support CAC, ROI, or ROAS.

## Methods

1. Load the semicolon-delimited CSV into SQLite as text (see [Reproduce](#how-to-reproduce)), convert types, and treat blank `Income` cells as NULL rather than zero.
2. Profile the file: row count, duplicate IDs, blanks, implausible birth years, and extreme incomes. **No row is silently dropped** from the customer base.
3. Compute the customer profile, campaign acceptance rates, product-category totals, and channel purchase counts.
4. Relate `NumWebPurchases` to income, recency, web visits, children at home, and campaign acceptance with group-by averages and Pearson correlation. Correlation uses the standard product-moment formula. No p-values are reported; they were not computed.
5. Publish the verified aggregates in a Google Sheets dashboard whose rates and shares are formula-driven from the stored counts.

### Handling rules

| Issue | What the file shows | How it is handled |
| --- | --- | --- |
| Customer count | `COUNT(*)` = 2,240; 2,240 distinct IDs; 0 duplicate IDs | 2,240 is the base for every rate unless a filter is named |
| Missing income | 24 blank `Income` values; every other column is populated | Kept in the base file. Excluded only from income statistics, income quartiles, and income correlations |
| Implausible birth years | IDs 11004 (1893), 1150 (1899), and 7829 (1900), ages 121, 114, and 113 at enrollment | Kept in the base file. Excluded only from age statistics (next oldest birth year is 1940) |
| Extreme income | ID 9432, income 666,666; next highest is 162,397; only this value exceeds 200,000 | Kept in the base file. Income mean and median are reported with and without it. The value falls in income quartile 4 and that customer accepted no campaigns |
| Unusual marital labels | Alone (3), YOLO (2), Absurd (2) | Reported as recorded; not recoded. Rates on n ≤ 3 are not treated as reliable |
| Age | `Dt_Customer` runs from 2012-07-30 to 2014-06-29 (494 enrolled in 2012, 1,189 in 2013, 557 in 2014) | Age at enrollment = year of `Dt_Customer` − `Year_Birth`. The reference year is each customer's enrollment year from the file, not a later assumed snapshot |

## Findings

All figures below come from `sql/campaign_analysis.sql`. Rates use a denominator of 2,240 unless a filter is named.

### Customer profile

- Age at enrollment, excluding the 3 implausible birth years (n = 2,237): mean **44.13**, median **43**, range 16 to 73.
- Education: Graduation 1,127 (50.31%), PhD 486 (21.70%), Master 370 (16.52%), 2n Cycle 203 (9.06%), Basic 54 (2.41%).
- Marital status, as recorded: Married 864 (38.57%), Together 580 (25.89%), Single 480 (21.43%), Divorced 232 (10.36%), Widow 77 (3.44%), Alone 3, YOLO 2, Absurd 2.
- Income, 2,216 non-null values: mean **52,247.25**, median **51,381.50**, min 1,730, max 666,666. After excluding the 666,666 outlier (n = 2,215): mean **51,969.86**, median **51,373**.
- Household: average 0.44 kids and 0.51 teens at home. 947 customers have at least one kid, 1,082 have at least one teen, and 1,602 (71.52%) have at least one child (kid or teen) at home.

### Campaign success

| Campaign | Accepts | Rate |
| --- | ---: | ---: |
| Campaign 1 (`AcceptedCmp1`) | 144 | 6.43% |
| Campaign 2 (`AcceptedCmp2`) | 30 | 1.34% |
| Campaign 3 (`AcceptedCmp3`) | 163 | 7.28% |
| Campaign 4 (`AcceptedCmp4`) | 167 | 7.46% |
| Campaign 5 (`AcceptedCmp5`) | 163 | 7.28% |
| Last campaign (`Response`) | 334 | 14.91% |

- Among Campaigns 1–5, **Campaign 4 is the most successful** (167 / 2,240). Campaign 2 is the weakest (30 / 2,240). Campaigns 3 and 5 are tied at 163 accepts.
- The last campaign has the highest acceptance of any single flag: 334 / 2,240 = **14.91%**.
- 463 customers (20.67%) accepted at least one of Campaigns 1–5. **609 customers (27.19%)** accepted at least one campaign including the last one.
- Customers who had already accepted one of Campaigns 1–5 responded to the last campaign at **40.60%** (188 / 463), versus **8.22%** (146 / 1,777) among those who had accepted none of them.

### Product performance

Category spend totals 1,356,988 recorded units (mean 605.80 per customer, median 396).

| Category | Total spend | Share | Average per customer |
| --- | ---: | ---: | ---: |
| Wines | 680,816 | 50.17% | 303.94 |
| Meat | 373,968 | 27.56% | 166.95 |
| Gold | 98,609 | 7.27% | 44.02 |
| Fish | 84,057 | 6.19% | 37.53 |
| Sweets | 60,621 | 4.47% | 27.06 |
| Fruits | 58,917 | 4.34% | 26.30 |

**Wines perform best**, followed by meat. The four remaining categories together are 22.27% of category spend.

### Channel performance

These are purchase counts, not revenue, and deal purchases can overlap the other channels.

| Metric | Total events | Average per customer | Customers with zero |
| --- | ---: | ---: | ---: |
| Store purchases | 12,970 | 5.79 | 15 |
| Web purchases | 9,150 | 4.08 | 49 |
| Catalog purchases | 5,963 | 2.66 | 586 |
| Deal purchases | 5,208 | 2.33 | 46 |
| Web visits in the month | 11,909 | 5.32 | 11 |

Among the 28,083 web + catalog + store purchase events, store is **46.18%**, web is **32.58%**, and catalog is **21.23%**. Store looks strongest and catalog looks weakest, both as a share of events and because 586 customers made no catalog purchase. Six customers have zero purchases across all three channels.

### Web purchases and related variables

Pearson r (product-moment; no p-value):

| Pair | n | r |
| --- | ---: | ---: |
| Web purchases ~ Income (nulls excluded) | 2,216 | 0.388 |
| Web purchases ~ Income (nulls and 666,666 excluded) | 2,215 | 0.459 |
| Web purchases ~ Recency | 2,240 | −0.011 |
| Web purchases ~ Web visits in the month | 2,240 | −0.056 |
| Web purchases ~ Kidhome | 2,240 | −0.362 |
| Web purchases ~ Teenhome | 2,240 | 0.155 |
| Web purchases ~ number of accepted campaigns | 2,240 | 0.205 |

- Higher income goes with more web purchases (moderate positive r). Customers with a kid at home make fewer web purchases on average (2.87 vs 4.97 without a kid).
- Recency is essentially unrelated to historical web-purchase counts (r = −0.011), and more web visits do not go with more web purchases (r = −0.056).
- Customers who accepted at least one campaign average 5.06 web purchases, versus 3.72 among those who accepted none.

### Response segments

Income quartiles use `NTILE(4)` on the 2,216 non-null incomes (554 customers each). Quartile accepts sum to 333 rather than 334 because 1 of the 24 customers with missing income accepted the last campaign.

| Income quartile | n | Income range | Last-campaign rate | Accepted any campaign |
| --- | ---: | --- | ---: | ---: |
| Q1 | 554 | 1,730–35,246 | 10.47% (58) | 14.62% (81) |
| Q2 | 554 | 35,322–51,373 | 12.45% (69) | 20.40% (113) |
| Q3 | 554 | 51,390–68,487 | 10.29% (57) | 24.91% (138) |
| Q4 | 554 | 68,627–666,666 | 26.90% (149) | 49.28% (273) |

Last-campaign response by education: PhD 20.78% (101 / 486), Master 15.41% (57 / 370), Graduation 13.49% (152 / 1,127), 2n Cycle 10.84% (22 / 203), Basic 3.70% (2 / 54).

Recency quartiles (560 customers each): last-campaign response is 26.79% when recency is 0–24 days and 7.32% when recency is 74–99 days, even though average web purchases stay near 4.0–4.13 in every recency band.

Customers with no child at home responded to the last campaign at 26.49% (638 customers) versus 10.30% among the 1,602 with at least one child.

### Complaints

21 customers complained (0.94%). Their last-campaign response rate is 14.29% (3 / 21), almost the same as 14.92% (331 / 2,219) among non-complainers. The complainer group is too small for a strong comparison.

## Caveats

- This is a public practice dataset about a consumer brand's CRM campaigns. Findings should not be presented as results from Vy Nguyen's employer or as SaaS subscription analytics.
- The file does not name a currency and does not contain campaign-level cost or incremental revenue, so no financial return is computed.
- Channel columns are purchase counts. Product amounts are spend by category, not by channel. They must not be mixed into a channel ROI.
- Age uses enrollment year from `Dt_Customer`, not a later snapshot date.
- Associations (income, education, recency, prior acceptance) are descriptive. They are not causal effects of a campaign treatment.
- Unusual marital labels and the 10+ web-visit band (12 customers) are reported but not over-interpreted.

## Dashboard

Google Sheet: [Marketing Campaign Performance (Public Dataset)](https://docs.google.com/spreadsheets/d/1Qd10AabancK7F5-9seEwkyQqBPWSW5H0HnFvIK_liOA/edit)

- spreadsheetId: `1Qd10AabancK7F5-9seEwkyQqBPWSW5H0HnFvIK_liOA`
- Tabs: Summary (formula-driven KPIs), Campaigns, Products, Channels, Customer Profile, Notes
- The Notes tab cites the public Maven Analytics / Jack Daoud / iFood source and states that this is not confidential employer data

## How to reproduce

From `portfolio/saas-marketing-campaign/`:

```bash
python3 sql/run_analysis.py
```

The runner strips the UTF-8 BOM, loads `data/marketing_campaign.csv` with delimiter `;` into a SQLite TEXT table named `raw`, and executes `sql/campaign_analysis.sql`.

If the SQLite CLI is installed:

```bash
sqlite3 :memory: \
  ".mode csv" \
  ".separator ;" \
  ".headers on" \
  ".import data/marketing_campaign.csv raw" \
  ".read sql/campaign_analysis.sql"
```

If a CLI import leaves a BOM on the first column name, rename that column to `ID` or use the Python runner instead.

## Resume bullets

- Analyzed 2,240 customer records from a public CRM campaign dataset in SQL, documenting data quality (24 missing incomes, 3 implausible birth years, one income of 666,666) without silently dropping rows.
- Compared five historical campaigns and a last-campaign offer: Campaign 4 led the historical set at 7.46% (167 / 2,240), while the last campaign reached 14.91% (334 / 2,240); 27.19% of customers accepted at least one campaign.
- Quantified product mix (wines 50.17% of 1,356,988 recorded category-spend units) and channel mix (store 46.18% of 28,083 web + catalog + store purchase events), stating clearly that channel figures are purchase counts, not revenue or ROI.
- Segmented last-campaign response by income quartile and prior acceptance: 26.90% in the top income quartile versus 10.47% in the bottom (among 2,216 customers with income), and 40.60% among prior acceptors versus 8.22% among the rest.

## Next project

A closer match for SaaS / technology analyst roles would be a public subscription or churn dataset (for example a telco or other subscription-style churn file) or a Power BI rebuild of this dashboard with lulu. That would add retention, conversion funnels, or a second visualization stack without inventing SaaS metrics from this CRM file.

What would be needed from Vy: which direction to take (churn/subscription SQL project vs Power BI rebuild), the target role title, and whether Power BI / lulu access is available.
