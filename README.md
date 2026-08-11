# Asian Paints — Cash Conversion Cycle (CCC) Analysis
asian_paints_working_capital_analysis/power_bi/screenshot_of_pbi.png
## The business question
Birla Opus (Aditya Birla Group) entered India's decorative paints market
aggressively starting FY2024-25, undercutting on price and pressuring Asian
Paints' dealer network and market share. This project asks: **did Asian
Paints loosen its working capital discipline — extending dealer credit,
building inventory — to defend its position, and is that reversing now that
margins are recovering?**

## What the metrics mean (full forms)

| Abbreviation | Full name | Formula | What it measures |
|---|---|---|---|
| **DIO** | Days Inventory Outstanding | (Average Inventory / COGS) × days in period | How many days, on average, inventory sits before being sold |
| **DSO** | Days Sales Outstanding | (Average Trade Receivables / Revenue) × days in period | How many days, on average, it takes to collect cash from dealers after a sale |
| **DPO** | Days Payable Outstanding | (Average Trade Payables / COGS) × days in period | How many days, on average, the company takes to pay its own suppliers |
| **CCC** | Cash Conversion Cycle | DIO + DSO − DPO | How many days cash is tied up in operations before it's converted back to cash. A rising CCC means cash is taking longer to come back — working capital is "loosening." A falling CCC means the opposite. |

**COGS proxy** = Cost of Materials Consumed + Purchases of Stock-in-Trade +
Change in Inventories (of finished goods, stock-in-trade, and work-in-progress).
Indian P&L statements under Ind AS don't report a single "Cost of Goods Sold"
line, so this is a proxy built from the three P&L line items that together
represent the cost of what was actually sold in the period.

## Data source and a key discovery
Data comes from Asian Paints' **standalone quarterly financial results**
filings (audited/reviewed under SEBI LODR Regulation 33), sourced from the
company's investor relations page and BSE/NSE filings, covering FY23 Q1
through FY26 Q4 (16 quarters).

**Why this project works at half-yearly, not quarterly, granularity:**
Early in this project the plan was to compute CCC every quarter, to pinpoint
exactly when Asian Paints' working capital behavior changed relative to
Birla Opus's market entry. While collecting the quarterly filings, it became
clear that Asian Paints — like most Indian listed companies — only publishes
a **full balance sheet** (with Inventory, Trade Receivables, and Trade
Payables broken out as separate line items) **half-yearly** (with the Q2 and
Q4 results) and annually, not with the Q1 and Q3 filings. Q1 and Q3 filings
contain only the P&L statement.

This was confirmed directly by inspecting the actual Q1 FY26 and Q2 FY26
standalone results filings: the Q2 filing contains a full "Audited Standalone
Balance Sheet"; the Q1 filing does not. Because of this, the analysis was
restructured to work at **half-year (H1/H2) granularity** instead of
quarterly, aggregating P&L figures across the two quarters in each half and
using the half-year-end balance sheet snapshot (30 September for H1, 31 March
for H2).

## Methodology: why the averaging approach is valid here
The standard DIO/DSO/DPO formula uses the *average* balance
(opening + closing) / 2, matched to the *same period* as the P&L figures used
in the denominator. This only works cleanly if the gap between the opening
and closing balance sheet dates equals the length of the P&L period.

Because Asian Paints' balance sheet snapshots are exactly six months apart
(30 September and 31 March each year), and because the P&L figures used here
are summed across exactly six months (two quarters) to match, the averaging
is period-matched and methodologically sound — this was verified explicitly
before building the analysis, not assumed. (An earlier draft attempted to
average a March balance with a September balance while using only a single
quarter's P&L — a three-month figure divided against a six-month average gap
— which would have artificially inflated every ratio. That mismatch was
caught and corrected before any conclusions were drawn.)

## Database structure
Two Postgres tables:

- **`quarterly_financials`** — the raw source data, one row per quarter
  (16 rows, FY23 Q1 – FY26 Q4). Balance sheet columns (`inventory`,
  `trade_recievables`, `trade_payables`) are `NULL` for Q1 and Q3 by design —
  this reflects the actual reporting gap described above, not missing data
  collection.
- **`half_yearly_financials`** — the derived table used for analysis (8 rows,
  FY23 H2 – FY26 H2), with P&L figures summed across each half-year's two
  quarters and balance sheet figures taken from the half-year-end filing.

The `half_yearly_financials` table was populated directly (not via a SQL
`INSERT ... SELECT` aggregation from `quarterly_financials`, though that is
a natural next step / alternative approach for the same result).

## The CCC calculation query
`02_ccc_analysis_query.sql` computes DIO, DSO, DPO, and CCC for each
half-year using a three-stage CTE (Common Table Expression) pipeline:

1. **`lagged`** — uses the window function `LAG(...) OVER (ORDER BY balance_sheet_date)`
   to pull each period's *prior* period's closing Inventory, Trade
   Receivables, and Trade Payables into the same row. The first row (FY23 H1)
   has no prior period in this dataset, so its `LAG()` values — and
   therefore its final DIO/DSO/DPO/CCC — come back `NULL`. This is expected
   and correct, not an error: there is no six-months-earlier balance sheet
   available to average against for the very first period in the series.
2. **`averaged`** — computes the average of each current and prior balance:
   `(prior + current) / 2`.
3. **`analysis`** — computes DIO, DSO, DPO from those averages.
4. The final outer `SELECT` computes **CCC = DIO + DSO − DPO** and rounds all
   four metrics to 2 decimal places.

## Findings

| Period | Balance sheet date | DIO | DSO | DPO | CCC |
|---|---|---|---|---|---|
| FY23 H2 | 2023-03-31 | 108.81 | 36.22 | 64.80 | 80.23 |
| FY24 H1 | 2023-09-30 | 110.81 | 39.47 | 67.52 | 82.77 |
| FY24 H2 | 2024-03-31 | 110.05 | 40.64 | 70.72 | 79.97 |
| FY25 H1 | 2024-09-30 | 113.66 | 44.18 | 75.25 | 82.59 |
| FY25 H2 | 2025-03-31 | 128.42 | 42.16 | 77.94 | **92.63** |
| FY26 H1 | 2025-09-30 | 116.35 | 39.03 | 61.82 | **93.56** |
| FY26 H2 | 2026-03-31 | 106.86 | 38.40 | 62.53 | 82.73 |

CCC sat in a stable 80–83 day band for two full years, then widened sharply
to ~92–93 days across FY25 H2 and FY26 H1, then reverted to 82.73 in FY26
H2. That widening genuinely coincides with the period Birla Opus's
competitive pressure was most acute and the "worst may be over" recovery
narrative that followed.

**But investigating each driver separately — and cross-checking against
Asian Paints' own earnings call transcripts and cash flow statements —
found the CCC widening was not one clean "fighting Birla Opus" story. It
was three largely separate, mostly coincidental causes overlapping in the
same window:**

1. **Inventory (DIO) build-up** was confirmed, in the company's own Q1 FY26
   earnings call, to be partly driven by deliberately stockpiling raw
   materials (specifically TiO₂, a key paint input) ahead of a known
   anti-dumping duty increase — a procurement/cost-hedging decision, not a
   competitive response to Birla Opus.
2. **Receivables (DSO)** rose gradually and steadily across multiple years
   (36.22 → 39.47 → 40.64 → 44.18 days from FY23 H2 through FY25 H1), not
   sharply at the moment Birla Opus entered the market. This does not
   support the original hypothesis that Asian Paints specifically extended
   dealer credit to defend market share against this one competitor — it
   looks more like a slow structural drift.
3. **The DPO crash** in FY26 H1 (77.94 → 61.82 days) — the sharpest single
   move in the whole series — was investigated via the standalone cash flow
   statement and found to be **at least ~55% explainable by a balance-sheet
   classification effect**: "Acceptances" (trade payables refinanced through
   a bank instrument) moved from the operating "trade payables" balance into
   the financing activities section of the cash flow statement between H1
   FY25 and H1 FY26 (a swing of roughly ₹745 crore, against a ₹413 crore gap
   between the balance-sheet-implied payables change and the cash flow
   statement's own trade payables adjustment line). This means a meaningful
   part of the apparent "faster supplier payment" is a reclassification, not
   genuinely different payment behavior.

**Conclusion:** the CCC widening in FY25 H2–FY26 H1 is real and measurable,
but it does not have one clean cause, and it is not well explained as
"Asian Paints loosened working capital specifically to fight Birla Opus."
The truth is closer to: three separate financial events (input-cost
hedging, gradual multi-year dealer-credit drift, and a payables financing
reclassification) happened to overlap in the same two half-years. This is a
more realistic and more useful finding than a tidy single-cause story would
have been — the original hypothesis does not survive contact with the full
evidence, and knowing *why* it doesn't is the actual value of the analysis.

## Known limitations
- **Half-yearly, not quarterly, granularity** — a direct consequence of
  Asian Paints' SEBI-mandated disclosure schedule (full balance sheet only
  at half-year and year end), not a data collection shortfall.
- **`cogs_proxy` is a constructed figure**, not a reported "COGS" line —
  Indian Ind AS P&L format does not report Cost of Goods Sold as a single
  standardized line item.
- **The averaging methodology is only valid because of the specific 6-month
  alignment** between the P&L period and the balance sheet gap in this
  dataset — this was checked, not assumed, but it means the same approach
  would need re-validation if extended to a company with a different
  reporting cadence.
- **The "Acceptances" explanation for the DPO crash is a plausibility check
  based on order-of-magnitude comparison, not a fully isolated, itemized
  causal decomposition** — it shows the acceptances swing is large enough to
  plausibly account for most of the gap, not that it has been proven to
  account for a specific portion of it.
- **FY23 H1 has no computable DIO/DSO/DPO/CCC** because there is no prior
  half-year in this dataset to average against — this is a structural
  boundary condition of the dataset, not a bug.
