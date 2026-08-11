WITH lagged As(
SELECT 
		fiscal_year,
        fiscal_half,
        balance_sheet_date,
        revenue,
        cogs_proxy,
        inventory,
        trade_recievables,
        trade_payables,
		LAG(inventory) OVER (ORDER BY balance_sheet_date) AS prior_inventory,
		LAG(trade_recievables) OVER (ORDER BY balance_sheet_date) AS prior_trade_recievables,
		LAG(trade_payables) OVER (ORDER BY balance_sheet_date) AS prior_trade_payables
		FROM half_yearly_financials
),

averaged AS(
SELECT
fiscal_year,
 fiscal_half,
 balance_sheet_date,
 revenue,
 cogs_proxy,
((prior_inventory + inventory)/2.00) AS average_inventory,
((prior_trade_recievables + trade_recievables)/2.00) AS average_trade_recievables,
((prior_trade_payables + trade_payables)/2.00) AS average_trade_payables

FROM lagged
),

analysis AS(
SELECT 
		fiscal_year,
        fiscal_half,
        balance_sheet_date,
        revenue,
        cogs_proxy,
		(average_inventory/cogs_proxy)*182.5 AS DIO,
		(average_trade_recievables/revenue)*182.5 AS DSO,
		(average_trade_payables/cogs_proxy)*182.5 AS DPO
FROM averaged)

SELECT 
fiscal_year,
fiscal_half,
balance_sheet_date,
ROUND(DIO::numeric,2) ,
ROUND(DSO::numeric,2),
ROUND(DPO::numeric,2),
ROUND((dio + dso - dpo)::numeric, 2) AS ccc
FROM analysis
ORDER BY balance_sheet_date

