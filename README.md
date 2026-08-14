# Olist Marketplace Analytics

End-to-end analysis of the Olist Brazilian e-commerce marketplace: 99,433 orders and R$15.42M of trading revenue between September 2016 and August 2018.

**[View the interactive dashboard →](https://bennguyennuk.github.io/olist-marketplace-analytics/)**

---

## The question

**Business scenario:** an operations team needs to understand why review scores declined while revenue continued to grow, and which issues should be investigated first. The scenario is hypothetical — this is a self-directed portfolio project and no real stakeholder commissioned it.

One in eight delivered orders receives a negative review. Counting them is straightforward. Locating where they concentrate, and deciding which of them to investigate first, is not — the starting extract reports the volume without the operational context needed to rank it.

This project measures which operational factors are most closely associated with negative reviews, sizes each one by revenue at risk, and ranks the candidate interventions.

**A note on what this analysis can and cannot show.** Every relationship below is observational. The data supports statements about association and about how strongly two things move together; it does not support a claim that one causes the other, and none is made here.

## What the analysis found

**Transit duration is the factor most closely associated with negative reviews.** On-time delivery runs at 93.23% overall, but the negative review rate on delivered orders is 12.77% — and it tracks total transit duration more closely than it tracks binary lateness. Orders arriving within 7 days draw a 7.55% negative review rate; at 15 to 21 days it is 12.12%, at 26 to 35 days 40.16%, and beyond 35 days 71.98%.

**Almost none of these customers return.** Repeat purchase behaviour after a negative review is close to zero, which is what gives a service problem its revenue exposure.

Full findings, prioritisation and the estimated sizing are on the [Recommendations page](https://bennguyennuk.github.io/olist-marketplace-analytics/) of the dashboard. The prioritisation is analyst judgement and is labelled as such; no recommendation here was implemented.

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
/sql                    nine SQL transformation queries — eight build the star schema, one analyses it
/python                 BigQuery load job
```

The nine files in `/sql` are transformation `SELECT` queries, not executable DDL: each one returns the shape of a table, and the tables themselves are materialised by the load job described above. Files `01`–`08` build the two fact tables, five dimensions and the monthly aggregate. `09_mom_revenue_growth.sql` reads that monthly aggregate and demonstrates a `LAG()` window function with explicit guards for non-consecutive months, months below a 100-order floor, and division by zero. It is a read-only analytical query and does not feed the dashboard, whose month-over-month chart is calculated in DAX against the same aggregate and the same 100-order floor.

**The Power BI file is not in this repository.** No `.pbix`, `.pbit`, DAX export or Power Query export is published here, so the semantic model and its measures cannot be inspected from GitHub. The SQL, the Python load job and the dashboard are the publicly inspectable parts of this project.

## Data quality findings and treatment

The dashboard's headline numbers are not the interesting part of this project. These are. Each finding below is labelled with what was actually done about it — several are mitigated downstream or carried as known limitations rather than corrected at source.

**1 — Category revenue was computed at the wrong grain.** *Corrected.* The measure summed at order grain, so any order spanning multiple categories inflated every category it touched. Rebuilt at item grain. The item-level and order-level bases now reconcile to a residual of R$1,379, which is published rather than hidden.

**2 — `is_late` returns 0 for undelivered orders instead of NULL.** *Known limitation — mitigated downstream.* Orders still in transit are counted as not-late by that column, which would flatter any on-time rate read off it directly. The column is unchanged in `06_fact_orders.sql`, where the behaviour is documented in the file header; every on-time calculation is instead scoped to `order_status = 'delivered'` on both sides of the ratio, as in `08_agg_order_monthly.sql`. The fix at source — returning NULL for undelivered orders — has not been made.

**3 — Negative review rate had two competing definitions.** *Definition standardised.* Measured across all orders it is 14.64%; across delivered orders only, 12.77%. Both are defensible and they answer different questions. Both bases are now published side by side with the denominator stated.

**4 — `ANY_VALUE` produces non-deterministic output.** *Known limitation.* In `dim_geolocation` and `dim_customers`, the same query returns different city values between runs. Harmless at state grain, wrong at city grain. The behaviour is documented in both file headers; the deterministic rewrite has not been made, and no analysis on this dashboard reads city at that grain.

**5 — Distinct customer count depended on which key was used.** *Definition standardised.* `customer_id` is per-order; `customer_unique_id` is per-person. A raw count returned 98,020 against a true 96,088. Every per-customer metric depends on getting this right.

**6 — `agg_orders_monthly` averages an average.** *Known limitation — headline measure handled elsewhere.* `AVG(avg_review_score)` weights a month with 50 orders the same as a month with 5,000. The aggregate keeps the unweighted form for trend shape and says so in its header; the review-weighted figure used for headline numbers is calculated in DAX instead.

**7 — Repeat Customer Rate returned identical values across every slice.** *Model relationship corrected.* Caused by relationship directionality in the semantic model, not by the DAX. The measure was correct; the model was not.

**8 — Payment method shares summed above 100%.** *Visual replaced.* Orders can carry more than one payment method. The visual implied a partition of something that is not partitioned, and was replaced rather than patched.

**9 — Cross-filtering failed from the product and seller dimensions to order-grain measures.** *Model relationship corrected.* Resolved with `TREATAS` to bridge the inactive relationship between `fact_order_items` and `fact_orders`.

Three of the nine were corrected at source or in the semantic model (1, 7, 9); three were resolved by standardising a definition or replacing a visual (3, 5, 8); three remain open in the published SQL (2, 4, 6) and are carried as documented limitations rather than quietly resolved.

Standard time intelligence also could not be used for month-over-month growth on this model, so the calculation was rebuilt with index-based logic.

## Method and definitions

Every KPI on the dashboard carries a written definition and a stated grain on the [Method page](https://bennguyennuk.github.io/olist-marketplace-analytics/). Known limitations are published on the same page rather than in a footnote.

Every figure on the dashboard is read back out of the published Power BI measures rather than recomputed in the browser, so the dashboard and the model do not drift apart. Because the `.pbix` is not published here, that correspondence is something the process guarantees, not something a reader can verify from this repository.

## How this was built

The pipeline, SQL star schema, Power BI model, DAX measures and analysis are my own work. The dashboard was built in Power BI first, and that report is the analytical artefact — every number on this page is read out of its published measures.

The HTML version exists for presentation only. The Power BI report is functional but not attractive, so the web version was AI-generated over pre-computed JSON exported from the same measures. It is a skin, not a second analysis.

## Stack

SQL (BigQuery) · Python (pandas) · Power BI (DAX, Power Query, star schema modelling)

The HTML dashboard renders with Chart.js. That code was AI-generated and is not part of my stack.

## Data

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — Kaggle. Coverage 4 Sep 2016 – 17 Oct 2018; trading analysis restricted to Sep 2016 – Aug 2018, where months are complete.
