
 Olist Customer Retention & RFM Analysis

SQL, Python (pandas), Power Query and Power BI analysis of the Olist Brazilian e-commerce dataset (about 99K orders). The project finds out why customers stop buying and which group is worth winning back first.

 Business question
Why do customers stop buying, and which customer segment should the business save first?

 Key findings
1. Retention is the main problem. Only 3.00% of customers (2,801 of 93,357) ever place a second order. Month-1 retention across cohorts is only 0.48%.
2. Best win-back target: "At Risk - High Value". 13,784 customers (14.8% of customers) generated R$4.24M, which is 27.5% of revenue. Average spend is R$308, and their last order was about 393 days ago.
3. Late delivery hurts reviews. About 8% of customers received their first order late. Their average review is 2.56 versus 4.29 for on-time orders.
4. Late delivery has a small effect on repeat buying. The repeat rate is 2.55% for late orders versus 3.05% for on-time orders. Repeat purchase is low either way, so fixing delivery alone will not fix retention. This is an association, not proof of cause.

 Recommendation
- Priority 1: Win-back campaign (personalized discount email) for At Risk - High Value customers.
- Priority 2: Second-purchase offer for New Big Spenders (14,404 customers, bought about 91 days ago) before they go quiet.
- Support: Reduce late deliveries to protect review scores.
- Skip: The Lost segment (22,564 customers, average spend only R$73).

 Tools used
| Tool | Used for |
|---|---|
| MySQL | Loading, cleaning, joins, CTEs, window functions, cohort and RFM queries |
| Python (pandas) | [Validation of the SQL results, optional statistical test] |
| Power Query | Data type fixes and the `cohort_label` column |
| Power BI | Interactive dashboard |

 Dataset
[Olist Brazilian E-Commerce dataset on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). Tables used: customers, orders, order payments, order reviews. The raw files are not included here because of their size. Download them from Kaggle.

 Method
Data cleaning
- Kept only orders with status `delivered`.
- Used `customer_unique_id` (not `customer_id`) to identify repeat buyers.
- Summed payments per order, and excluded orders with a total value of 0.
- Excluded orders with a delivery date earlier than the purchase date.
- Kept the latest review per order.
- Checked row counts after loading (99,441 / 99,441 / 103,886 / 99,224) and checked for duplicates and nulls. The raw tables were not modified.

Cohort retention: customers grouped by month of first purchase (cohorts 2017-01 to 2018-06), tracking the share who ordered again in each following month.

RFM segmentation: Recency and Monetary scored 1 to 5 with `NTILE(5)`. Frequency scored by rule (1 order = 1, 2 orders = 3, 3 or more = 5), because most customers buy only once. Seven segments: Champions, Loyal - At Risk, New Big Spenders, New Customers, At Risk - High Value, Needs Attention, Lost.

Delivery impact: compared the first order of each customer (late versus on time) on review score and repeat rate.

<img width="1397" height="756" alt="Olist retention" src="https://github.com/user-attachments/assets/b2e704a7-95a1-4817-93f2-ff36af18fc6c" />
<img width="930" height="806" alt="image" src="https://github.com/user-attachments/assets/b17bf255-c538-42cd-b370-6121bf9ee2c7" />
<img width="932" height="811" alt="image" src="https://github.com/user-attachments/assets/b3196c65-205f-402c-ba31-cf5ffb47107d" />
<img width="927" height="810" alt="image" src="https://github.com/user-attachments/assets/ae92ed00-58d3-4496-82da-6304e55a57e2" />




Dashboard file: `dashboard/olist_retention_dashboard.pbix`

 Repository structure
```
olist-customer-retention-rfm/
├── sql/               load, clean, cohort, RFM, delivery queries
├── python/            pandas notebook
├── exports/           cohort.csv, rfm_summary.csv, delivery_impact.csv, KPI.csv
├── dashboard/         .pbix, PDF and screenshots
└── README.md
```

 Limitations
- Olist data covers 2016 to 2018. Later months in the cohort table include fewer cohorts, so counts fall partly because newer cohorts have not reached those months yet.
- Findings show association, not cause.
- 611 customers had no review or delivery date, so they are excluded from the delivery analysis.

 Author
HARIPRIYA K T
haripriyarajeev03@gmail.com
