# Olist Marketplace Analytics

End-to-end analysis of the Olist Brazilian e-commerce marketplace: 99,433 orders and R$15.42M of trading revenue between September 2016 and August 2018.

**[View the interactive dashboard →](https://bennguyennuk.github.io/olist-marketplace-analytics/)**

---

## The question

One in eight delivered orders receives a negative review. The marketplace's own reporting could say *how many*, but not *where they come from* or *which of them are worth fixing first*.

This project traces negative reviews back to their operational causes, sizes each cause by revenue at risk, and ranks the interventions.

## What the analysis found

**Late delivery is the dominant cause, and it is concentrated.** On-time delivery runs at 93.23% overall, but the negative review rate on delivered orders is 12.77% — and it rises sharply with transit duration rather than with lateness alone. Both effects are strong: on-time rate correlates with review score at r = +0.91, transit days at r = −0.80.

**The problem is geographic before it is operational.** Rio de Janeiro carries 2,619 negative reviews — the largest absolute volume of any state — against R$417,621 of revenue exposed. Prioritising by rate alone would have pointed somewhere else and moved less money.

**Almost none of these customers return.** Repeat purchase behaviour after a negative review is close to zero, which is what converts a service problem into a revenue problem.

Full findings, prioritisation and estimated impact are on the [Recommendations page](https://bennguyennuk.github.io/olist-marketplace-analytics/) of the dashboard.

## Pipeline

```
Kaggle CSVs
   ↓  Python (pandas, Google Colab)
BigQuery — raw layer
   ↓  SQL — dimensional modelling
Star schema: 2 fact tables, 5 dimensions, 1 aggregate
   ↓  CSV export → Python re-upload (see note)
BigQuery — modelled layer
   ↓  Power BI connector
Power Query — type conformance
   ↓
Power BI semantic model — 9 relationships, 48 measures in 7 folders
   ↓
Power BI report — the deliverable
   ↓  measures exported to pre-computed JSON
HTML dashboard — presentation layer only
```

**Note on the CSV round trip.** The BigQuery environment was read-only for table creation — no permission to persist `CREATE TABLE` output. Rather than abandon the dimensional model, the star schema was built in SQL, materialised to CSV, and re-loaded through a Python job using `WRITE_TRUNCATE`, which makes a re-run idempotent. It is a workaround, not a design choice, and it is documented here because the constraint shaped the architecture.

The load job infers schema with autodetect rather than declaring types explicitly, and BigQuery inferred several column types incorrectly. Those were corrected downstream in Power Query, which fixes the symptom rather than the cause — declaring an explicit schema per table is the change to make next.

## Repository contents

```
index.html              the dashboard, served by GitHub Pages
/sql                    star schema DDL and transformation queries
/python                 BigQuery load job
```

## Data quality defects found and fixed

The dashboard's headline numbers are not the interesting part of this project. These are.

**1 — Category revenue was computed at the wrong grain.** The measure summed at order grain, so any order spanning multiple categories inflated every category it touched. Rebuilt at item grain. The item-level and order-level bases now reconcile to a residual of R$1,379, which is published rather than hidden.

**2 — `is_late` returned 0 for undelivered orders instead of NULL.** Orders still in transit were being counted as delivered on time, silently flattering the on-time rate. Any SLA reported off that column was wrong in the favourable direction.

**3 — Negative review rate had two competing definitions.** Measured across all orders it is 14.64%; across delivered orders only, 12.77%. Both are defensible and they answer different questions. Both bases are now published side by side with the denominator stated.

**4 — `ANY_VALUE` produced non-deterministic output.** In `dim_geolocation` and `dim_customers`, the same query returned different city values between runs. Harmless at state grain, wrong at city grain.

**5 — Distinct customer count depended on which key was used.** `customer_id` is per-order; `customer_unique_id` is per-person. A raw count returned 98,020 against a true 96,088. Every per-customer metric depends on getting this right.

**6 — `agg_orders_monthly` averaged an average.** `AVG(avg_review_score)` weights a month with 50 orders the same as a month with 5,000.

**7 — Repeat Customer Rate returned identical values across every slice.** Caused by relationship directionality in the semantic model, not by the DAX. The measure was correct; the model was not.

**8 — Payment method shares summed above 100%.** Orders can carry more than one payment method. The visual implied a partition of something that is not partitioned, and was replaced rather than patched.

**9 — Cross-filtering failed from the product and seller dimensions to order-grain measures.** Resolved with `TREATAS` to bridge the inactive relationship between `fact_order_items` and `fact_orders`.

Standard time intelligence also could not be used for month-over-month growth on this model, so the calculation was rebuilt with index-based logic.

## Method and definitions

Every KPI on the dashboard carries a written definition and a stated grain on the [Method page](https://bennguyennuk.github.io/olist-marketplace-analytics/). Known limitations are published on the same page rather than in a footnote.

Every figure on the dashboard is read back out of the published Power BI measures, so the dashboard and the `.pbix` cannot drift apart.

## How this was built

The pipeline, SQL star schema, Power BI model, DAX measures and analysis are my own work. The dashboard was built in Power BI first, and that report is the analytical artefact — every number on this page is read out of its published measures.

The HTML version exists for presentation only. The Power BI report is functional but not attractive, so the web version was AI-generated over pre-computed JSON exported from the same measures. It is a skin, not a second analysis.

## Stack

SQL (BigQuery) · Python (pandas) · Power BI (DAX, Power Query, star schema modelling)

The HTML dashboard renders with Chart.js. That code was AI-generated and is not part of my stack.

## Data

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — Kaggle. Coverage 4 Sep 2016 – 17 Oct 2018; trading analysis restricted to Sep 2016 – Aug 2018, where months are complete.
