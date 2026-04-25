USE corporate_card_data;

SELECT * FROM companies_final;


-- creating a view like companies_final
CREATE VIEW company_features AS
SELECT 
    company_id,
    company_name,
    company_size,
    kyb_approval_date
FROM companies_final;



-- creating a view of only succesful transactions
CREATE VIEW qualifying_txns AS
SELECT * FROM transactions_final
WHERE status = 'success'
AND transaction_type IN ('purchase','cash_withdrawal')
AND amount > 0;



-- companies and their first transaction_date
SELECT company_id, 
MIN(transaction_date) as first_txn_date
FROM qualifying_txns
GROUP BY company_id;




-- New column: first_txn_date for each company
CREATE OR REPLACE VIEW company_features AS 
SELECT 
    companies_final.company_id,
    companies_final.company_name,
    companies_final.company_size,
    companies_final.kyb_approval_date,
    temp.first_txn_date
FROM companies_final
LEFT JOIN (
    SELECT company_id, 
    MIN(transaction_date) as first_txn_date
    FROM qualifying_txns
    GROUP BY company_id
) temp  
ON companies_final.company_id = temp.company_id;



-- how many transactions each company completed in the first 30 days after the kyb approval date.
SELECT company_features.company_id,
       COUNT(qualifying_txns.transaction_id) AS kyb_txn_30d
FROM
qualifying_txns
left join company_features
on qualifying_txns.company_id = company_features.company_id
WHERE transaction_date >= kyb_approval_date
AND transaction_date < kyb_approval_date + INTERVAL  30 DAY
GROUP BY company_features.company_id
ORDER BY kyb_txn_30d DESC;



-- company_features VIEW has:
--      transactions in the first 30 day since kyb approval (each company)
--      first transaction date of each company
--      last_transaction date of each company

CREATE OR REPLACE VIEW company_features AS
SELECT 
    companies_final.company_id,
    companies_final.company_name,
    companies_final.company_size, 
    companies_final.kyb_approval_date, 

    SUM(
        CASE 
            WHEN transaction_date >= kyb_approval_date
            AND transaction_date < kyb_approval_date + INTERVAL 30 DAY
            THEN  1
            ELSE  0
        END
    ) as kyb_30d_txns,

    MIN(qt.transaction_date) as first_txn_date,
    MAX(qt.transaction_date) AS last_txn_date

FROM companies_final
LEFT JOIN qualifying_txns qt  
ON companies_final.company_id = qt.company_id

GROUP BY 
    companies_final.company_id,
    companies_final.company_name,
    companies_final.company_size, 
    companies_final.kyb_approval_date;



-- company_features VIEW now has:
--      transactions in the first 30 day since kyb approval (each company)
--      first transaction date of each company
--      transactions in the first 60 days since the first succesful transaction
--      last_transaction date of each company

CREATE OR REPLACE VIEW company_features AS
    WITH first_txn AS (
        SELECT 
        company_id,
        MIN(transaction_date) as first_txn_date
        FROM qualifying_txns
        GROUP BY company_id
    )
    SELECT 
    companies_final.company_id,
    companies_final.company_name,
    companies_final.company_size, 
    companies_final.kyb_approval_date, 

    SUM(
        CASE 
            WHEN qt.transaction_date >= companies_final.kyb_approval_date
            AND qt.transaction_date < companies_final.kyb_approval_date + INTERVAL 30 DAY
            THEN  1
            ELSE  0
        END
    ) as kyb_30d_txns, -- transactions in the first 30 days since kyb approval

    ft.first_txn_date, -- first transaction of each company

    SUM(CASE 
        WHEN qt.transaction_date > ft.first_txn_date 
        AND qt.transaction_date <= ft.first_txn_date + INTERVAL 60 DAY
        THEN  1
        ELSE  0
    END) AS activation_60d_txns, -- transctions in the first 60 days since the first transaction


    MAX(qt.transaction_date) AS last_txn_date -- last transaction date of each company

FROM companies_final
LEFT JOIN qualifying_txns qt  ON companies_final.company_id = qt.company_id
LEFT JOIN first_txn ft ON companies_final.company_id = ft.company_id

GROUP BY 
    companies_final.company_id,
    companies_final.company_name,
    companies_final.company_size, 
    companies_final.kyb_approval_date,
    ft.first_txn_date;



-- company_features VIEW now has:
--      transactions in the first 30 day since kyb approval (each company)
--      first transaction date of each company
--      transactions in the first 60 days since the first succesful transaction
--      last_transaction date of each company
--      churn flag --> if this certain company churned

CREATE OR REPLACE VIEW company_features AS
WITH first_txn AS (
        SELECT 
        company_id,
        MIN(transaction_date) as first_txn_date
        FROM qualifying_txns
        GROUP BY company_id
    ),
last_date AS (
    SELECT MAX(transaction_date) as last_txn_date
    FROM transactions_final
)
    SELECT 
    companies_final.company_id,
    companies_final.company_name,
    companies_final.company_size, 
    companies_final.kyb_approval_date, 

    SUM(CASE 
            WHEN qt.transaction_date >= companies_final.kyb_approval_date
            AND qt.transaction_date < companies_final.kyb_approval_date + INTERVAL 30 DAY
            THEN  1
            ELSE  0
        END) as kyb_30d_txns, -- transactions in the first 30 days since kyb approval

    ft.first_txn_date, -- first transaction of each company

    SUM(CASE 
            WHEN qt.transaction_date > ft.first_txn_date 
            AND qt.transaction_date <= ft.first_txn_date + INTERVAL 60 DAY
            THEN  1
            ELSE  0
        END) AS activation_60d_txns, -- transctions in the first 60 days since the first transaction


    MAX(qt.transaction_date) AS last_txn_date, -- last transaction date of each company

    CASE 
        WHEN ft.first_txn_date IS NULL THEN 'not_activated'
        WHEN MAX(qt.transaction_date) >= last_date.last_txn_date - INTERVAL 30 DAY  
        THEN 'unchurned'  
        ELSE 'churned'
    END as churn_flag -- churn flag shows us if the company is a churned or an unchurned company

FROM companies_final
LEFT JOIN qualifying_txns qt  ON companies_final.company_id = qt.company_id
LEFT JOIN first_txn ft ON companies_final.company_id = ft.company_id
CROSS JOIN last_date

GROUP BY 
    companies_final.company_id,
    companies_final.company_name,
    companies_final.company_size, 
    companies_final.kyb_approval_date,
    ft.first_txn_date,
    last_date.last_txn_date;


-- company_features VIEW now has:
--      transactions in the first 30 day since kyb approval (each company)
--      first transaction date of each company
--      transactions in the first 60 days since the first successful transaction
--      TRANSACTION VOLUME IN THE FIRST 60 DAYS SINCE THE FIRST SUCCESSFUL TRANSACTION
-- 		DAYS SINCE FIRST TRANSACTION
--      last_transaction date of each company
--      churn flag --> if this certain company churned

CREATE OR REPLACE VIEW company_features AS
WITH first_txn AS (
        SELECT 
        company_id,
        MIN(transaction_date) as first_txn_date
        FROM qualifying_txns
        GROUP BY company_id
    ),
last_date AS (
    SELECT MAX(transaction_date) as last_txn_date
    FROM transactions_final
)
    SELECT 
    companies_final.company_id,
    companies_final.company_name,
    companies_final.company_size, 
    companies_final.kyb_approval_date, 

    SUM(CASE 
            WHEN qt.transaction_date >= companies_final.kyb_approval_date
            AND qt.transaction_date < companies_final.kyb_approval_date + INTERVAL 30 DAY
            THEN  1
            ELSE  0
        END) as kyb_30d_txns, -- transactions in the first 30 days since kyb approval

    ft.first_txn_date, -- first transaction of each company
    

    SUM(CASE 
            WHEN qt.transaction_date >= ft.first_txn_date 
            AND qt.transaction_date <= ft.first_txn_date + INTERVAL 60 DAY
            THEN  1
            ELSE  0
        END) AS activation_60d_txns, -- transctions in the first 60 days since the first transaction
        
	SUM(CASE 
            WHEN qt.transaction_date >= ft.first_txn_date 
            AND qt.transaction_date <= ft.first_txn_date + INTERVAL 60 DAY
            THEN  qt.amount
            ELSE  0
        END) AS activation_60d_volume, -- transaction_volume in the first 60 days for each company


    DATEDIFF(last_date.last_txn_date,ft.first_txn_date) as days_since_first_txn, -- days since the company made it's first transaction


    MAX(qt.transaction_date) AS last_txn_date, -- last transaction date of each company

    CASE 
        WHEN ft.first_txn_date IS NULL THEN 'not_activated'
        WHEN MAX(qt.transaction_date) >= last_date.last_txn_date - INTERVAL 30 DAY  
        THEN 'unchurned'  
        ELSE 'churned'
    END as churn_flag -- churn flag shows us if the company is a churned or an unchurned company

FROM companies_final
LEFT JOIN qualifying_txns qt  ON companies_final.company_id = qt.company_id
LEFT JOIN first_txn ft ON companies_final.company_id = ft.company_id
CROSS JOIN last_date

GROUP BY 
    companies_final.company_id,
    companies_final.company_name,
    companies_final.company_size, 
    companies_final.kyb_approval_date,
    ft.first_txn_date,
    last_date.last_txn_date;


-------------------------------------------------------------------------------------------------
-- COPY OF (company_features --> temp_cf) for dashboard (contains activation_14d_txns.. etc) ----
-------------------------------------------------------------------------------------------------

-- temp_cf VIEW now has:
--      transactions in the first 30 day since kyb approval (each company)
--      first transaction date of each company
-- 		TXNS IN THE FIRST 14 DAYS
--      TXNS IN THE FIRST 30 DAYS 
--      TXNS IN THE FIRST 45 DAYS
--      txns in the first 60 days
--      days since first transaction
--      transaction volume in the first 60 days since the first succesful transaction
--      last_transaction date of each company
--      churn flag --> if this certain company churned

--      lifecycle bucket
--      lifecycle bucket sort


CREATE VIEW temp_cf AS
WITH first_txn AS (
        SELECT 
        company_id,
        MIN(transaction_date) as first_txn_date
        FROM qualifying_txns
        GROUP BY company_id
    ),
last_date AS (
    SELECT MAX(transaction_date) as last_txn_date
    FROM transactions_final
)
    SELECT 
    companies_final.company_id,
    companies_final.company_name,
    companies_final.company_size, 
    companies_final.kyb_approval_date, 

    SUM(CASE 
            WHEN qt.transaction_date >= companies_final.kyb_approval_date
            AND qt.transaction_date < companies_final.kyb_approval_date + INTERVAL 30 DAY
            THEN  1
            ELSE  0
        END) as kyb_30d_txns, -- transactions in the first 30 days since kyb approval

    ft.first_txn_date, -- first transaction of each company

    SUM(CASE 
            WHEN qt.transaction_date >= ft.first_txn_date 
            AND qt.transaction_date <= ft.first_txn_date + INTERVAL 14 DAY
            THEN  1
            ELSE  0
        END) AS activation_14d_txns,  -- transctions in the first 14 days 

    SUM(CASE 
            WHEN qt.transaction_date >= ft.first_txn_date 
            AND qt.transaction_date <= ft.first_txn_date + INTERVAL 30 DAY
            THEN  1
            ELSE  0
        END) AS activation_30d_txns,  -- transctions in the first 30 days 

    SUM(CASE 
            WHEN qt.transaction_date >= ft.first_txn_date 
            AND qt.transaction_date <= ft.first_txn_date + INTERVAL 45 DAY
            THEN  1
            ELSE  0
        END) AS activation_45d_txns,  -- transctions in the first 45 days 

    SUM(CASE 
            WHEN qt.transaction_date >= ft.first_txn_date 
            AND qt.transaction_date <= ft.first_txn_date + INTERVAL 60 DAY
            THEN  1
            ELSE  0
        END) AS activation_60d_txns,  -- transctions in the first 60 days 

    DATEDIFF(last_date.last_txn_date,ft.first_txn_date) as days_since_first_txn, -- days since the company made it's first transaction
        
	SUM(CASE 
            WHEN qt.transaction_date >= ft.first_txn_date 
            AND qt.transaction_date <= ft.first_txn_date + INTERVAL 60 DAY
            THEN  qt.amount
            ELSE  0
        END) AS activation_60d_volume, -- transaction_volume in the first 60 days for each company

    MAX(qt.transaction_date) AS last_txn_date, -- last transaction date of each company

    CASE 
        WHEN ft.first_txn_date IS NULL THEN 'not_activated'
        WHEN MAX(qt.transaction_date) >= last_date.last_txn_date - INTERVAL 30 DAY  
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
LEFT JOIN qualifying_txns qt  ON companies_final.company_id = qt.company_id
LEFT JOIN first_txn ft ON companies_final.company_id = ft.company_id
CROSS JOIN last_date

GROUP BY 
    companies_final.company_id,
    companies_final.company_name,
    companies_final.company_size, 
    companies_final.kyb_approval_date,
    ft.first_txn_date,
    last_date.last_txn_date;



-------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------

-- temp_cf VIEW now has:
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

CREATE OR REPLACE VIEW temp_cf AS
WITH first_txn AS (
        SELECT 
        company_id,
        MIN(transaction_date) as first_txn_date
        FROM qualifying_txns
        GROUP BY company_id
    ),
last_date AS (
    SELECT MAX(transaction_date) as last_txn_date
    FROM transactions_final
)
    SELECT 
    companies_final.company_id,
    companies_final.company_name,
    companies_final.company_size, 
    companies_final.kyb_approval_date, 

    SUM(CASE 
            WHEN qt.transaction_date >= companies_final.kyb_approval_date
            AND qt.transaction_date < companies_final.kyb_approval_date + INTERVAL 30 DAY
            THEN  1
            ELSE  0
        END) as kyb_30d_txns, -- transactions in the first 30 days since kyb approval

    ft.first_txn_date, -- first transaction of each company

    SUM(CASE 
            WHEN qt.transaction_date >= ft.first_txn_date 
            AND qt.transaction_date <= ft.first_txn_date + INTERVAL 14 DAY
            THEN  1
            ELSE  0
        END) AS activation_14d_txns,  -- transctions in the first 14 days 

    SUM(CASE 
            WHEN qt.transaction_date >= ft.first_txn_date 
            AND qt.transaction_date <= ft.first_txn_date + INTERVAL 30 DAY
            THEN  1
            ELSE  0
        END) AS activation_30d_txns,  -- transctions in the first 30 days 

    SUM(CASE 
            WHEN qt.transaction_date >= ft.first_txn_date 
            AND qt.transaction_date <= ft.first_txn_date + INTERVAL 45 DAY
            THEN  1
            ELSE  0
        END) AS activation_45d_txns,  -- transctions in the first 45 days 

    SUM(CASE 
            WHEN qt.transaction_date >= ft.first_txn_date 
            AND qt.transaction_date <= ft.first_txn_date + INTERVAL 60 DAY
            THEN  1
            ELSE  0
        END) AS activation_60d_txns,  -- transctions in the first 60 days 

    DATEDIFF(last_date.last_txn_date,ft.first_txn_date) as days_since_first_txn, -- days since the company made it's first transaction

    CASE 
        WHEN DATEDIFF(last_date.last_txn_date, ft.first_txn_date) IS NOT NULL 
            AND DATEDIFF(last_date.last_txn_date, ft.first_txn_date) BETWEEN 0 AND 60
        THEN  1
        ELSE  0
    END as is_early_stage, -- is_early_stage shows us if the company is in its early stages or not
        
	SUM(CASE 
            WHEN qt.transaction_date >= ft.first_txn_date 
            AND qt.transaction_date <= ft.first_txn_date + INTERVAL 60 DAY
            THEN  qt.amount
            ELSE  0
        END) AS activation_60d_volume, -- transaction_volume in the first 60 days for each company

    MAX(qt.transaction_date) AS last_txn_date, -- last transaction date of each company

    CASE 
        WHEN ft.first_txn_date IS NULL THEN 'not_activated'
        WHEN MAX(qt.transaction_date) >= last_date.last_txn_date - INTERVAL 30 DAY  
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
LEFT JOIN qualifying_txns qt  ON companies_final.company_id = qt.company_id
LEFT JOIN first_txn ft ON companies_final.company_id = ft.company_id
CROSS JOIN last_date

GROUP BY 
    companies_final.company_id,
    companies_final.company_name,
    companies_final.company_size, 
    companies_final.kyb_approval_date,
    ft.first_txn_date,
    last_date.last_txn_date;









-------------------------------------------------------------------------------------------------
-- FULL TABLE VIEW ------------------------------------------------------------------------------

SELECT * FROM company_features;
SELECT * FROM temp_cf; 


SELECT * FROM company_features
ORDER BY activation_60d_txns desc;


SELECT COUNT(churn_flag), churn_flag
FROM company_features
group by churn_flag;

-------------------------------------------------------------------------------------------------
-- QUALIFYING TRANSACTIONS ----------------------------------------------------------------------

SELECT * from qualifying_txns;

SELECT COUNT(*) from qualifying_txns;

WITH last_date AS (
    SELECT MAX(transaction_date) as last_txn_date
    FROM transactions_final
)
SELECT COUNT(DISTINCT company_id) FROM qualifying_txns qt
CROSS JOIN last_date ld  
WHERE qt.transaction_date > ld.last_txn_date - INTERVAL 30 DAY;


-------------------------------------------------------------------------------------------------
-- ANALYZING SUPPORT TICKETS --------------------------------------------------------------------

SELECT * from support_tickets_final;

SELECT COUNT(*) from support_tickets_final;

SELECT COUNT(*) FROM support_tickets_final
WHERE created_date > "2024-03-31";


SELECT * FROM support_tickets_final
WHERE created_date > "2024-03-31";

SELECT ticket_type, COUNT(ticket_type) as COUNT 
FROM support_tickets_final
WHERE created_date > "2024-03-31"
GROUP BY ticket_type;