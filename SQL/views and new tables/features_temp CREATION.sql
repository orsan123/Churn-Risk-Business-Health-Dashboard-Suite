use corporate_card_data;

-------------------------------------------------------------------------------------------------
-- COPY OF (features --> features_temp) for dashboard (contains activation_14d_txns.. etc) ------
-------------------------------------------------------------------------------------------------

-- features_temp NOW has 

--      transactions in the first 30 day since kyb approval (each company)
--      first transaction date of each company
-- 	-	TXNS IN THE FIRST 14 DAYS 
--  -   TXNS IN THE FIRST 30 DAYS 
--  -   TXNS IN THE FIRST 45 DAYS 
--      txns in the first 60 days 
--      days since first_transaction
--  -    is_early_stage  
--      transaction volume in the first 60 days since the first succesful transaction
--      last_transaction date of each company
--      churn flag --> if this certain company churned

--      lifecycle bucket
--      lifecycle bucket sort


CREATE OR REPLACE VIEW features_temp AS
WITH first_txn AS (
        SELECT 
        company_id,
        MIN(transaction_date) as first_txn_date
        FROM qf
        GROUP BY company_id
    ),

last_date AS (
    SELECT MAX(transaction_date) as last_txn_date
    FROM transactions_f
)
    SELECT 
    companies_final.company_id,
    companies_final.company_name,

    ft.first_txn_date, -- first transaction of each company

    DATEDIFF(last_date.last_txn_date,ft.first_txn_date) as days_since_first_txn, -- days since the company made it's first transaction

    SUM(CASE 
            WHEN qf.transaction_date >= ft.first_txn_date 
            AND qf.transaction_date <= ft.first_txn_date + INTERVAL 14 DAY
            THEN  1
            ELSE  0
        END) AS activation_14d_txns,  -- transctions in the first 14 days 

    SUM(CASE 
            WHEN qf.transaction_date >= ft.first_txn_date 
            AND qf.transaction_date <= ft.first_txn_date + INTERVAL 30 DAY
            THEN  1
            ELSE  0
        END) AS activation_30d_txns,  -- transctions in the first 30 days 

    SUM(CASE 
            WHEN qf.transaction_date >= ft.first_txn_date 
            AND qf.transaction_date <= ft.first_txn_date + INTERVAL 45 DAY
            THEN  1
            ELSE  0
        END) AS activation_45d_txns,  -- transctions in the first 45 days 

    SUM(CASE 
            WHEN qf.transaction_date >= ft.first_txn_date 
            AND qf.transaction_date <= ft.first_txn_date + INTERVAL 60 DAY
            THEN  1
            ELSE  0
        END) AS activation_60d_txns,  -- transctions in the first 60 days 

    SUM(CASE 
            WHEN qf.transaction_date >= ft.first_txn_date 
            AND qf.transaction_date <= ft.first_txn_date + INTERVAL 60 DAY
            THEN  qf.amount
            ELSE  0
        END) AS activation_60d_volume, -- transaction_volume in the first 60 days for each company

    MAX(qf.transaction_date) AS last_txn_date, -- last transaction date of each company

    DATEDIFF(last_date.last_txn_date,MAX(qf.transaction_date)) as days_since_last_txn, -- days since the company made it's first transaction

    CASE 
        WHEN DATEDIFF(last_date.last_txn_date, ft.first_txn_date) IS NOT NULL 
            AND DATEDIFF(last_date.last_txn_date, ft.first_txn_date) BETWEEN 0 AND 60
        THEN  1
        ELSE  0
    END as is_early_stage, -- is_early_stage shows us if the company is in its early stages or not

    CASE 
        WHEN ft.first_txn_date IS NULL THEN 'not_activated'
        WHEN MAX(qf.transaction_date) >= last_date.last_txn_date - INTERVAL 30 DAY  
        THEN 'unchurned'  
        ELSE 'churned'
    END as churn_flag, -- churn flag shows us if the company is a churned or an unchurned company

    CASE 
        WHEN DATEDIFF(last_date.last_txn_date,ft.first_txn_date) BETWEEN 0 AND 14 THEN '0-14'
        WHEN DATEDIFF(last_date.last_txn_date,ft.first_txn_date) BETWEEN 15 AND 30 THEN '15-30'
        WHEN DATEDIFF(last_date.last_txn_date,ft.first_txn_date) BETWEEN 31 AND 45 THEN '31-45'
        WHEN DATEDIFF(last_date.last_txn_date,ft.first_txn_date) BETWEEN 46 AND 60 THEN '46-60'
        ELSE  NULL
    END AS life_cycle_bucket, 

    CASE 
        WHEN DATEDIFF(last_date.last_txn_date,ft.first_txn_date) BETWEEN 0 AND 14 THEN 1
        WHEN DATEDIFF(last_date.last_txn_date,ft.first_txn_date) BETWEEN 15 AND 30 THEN 2
        WHEN DATEDIFF(last_date.last_txn_date,ft.first_txn_date) BETWEEN 31 AND 45 THEN 3
        WHEN DATEDIFF(last_date.last_txn_date,ft.first_txn_date) BETWEEN 46 AND 60 THEN 4
        ELSE  NULL
    END AS life_cycle_bucket_sort


FROM companies_final
LEFT JOIN qf  ON companies_final.company_id = qf.company_id
LEFT JOIN first_txn ft ON companies_final.company_id = ft.company_id
CROSS JOIN last_date

GROUP BY 
    companies_final.company_id,
    companies_final.company_name,
    companies_final.company_size, 
    companies_final.kyb_approval_date,
    ft.first_txn_date,
    last_date.last_txn_date;
    