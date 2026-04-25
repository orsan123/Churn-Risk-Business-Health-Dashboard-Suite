use corporate_card_data;

-- -------------------------------------------------------------------------------------- 
-- creating a VIEW called "features" exactly like "company_features" but for the NEW ONE
-- -------------------------------------------------------------------------------------- 


CREATE OR REPLACE VIEW features AS
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
    companies_final.company_size, 
    companies_final.kyb_approval_date, 

    SUM(CASE 
            WHEN qf.transaction_date >= companies_final.kyb_approval_date
            AND qf.transaction_date < companies_final.kyb_approval_date + INTERVAL 30 DAY
            THEN  1
            ELSE  0
        END) as kyb_30d_txns, -- transactions in the first 30 days since kyb approval

    ft.first_txn_date, -- first transaction of each company
    

    SUM(CASE 
            WHEN qf.transaction_date >= ft.first_txn_date 
            AND qf.transaction_date <= ft.first_txn_date + INTERVAL 60 DAY
            THEN  1
            ELSE  0
        END) AS activation_60d_txns, -- transctions in the first 60 days since the first transaction
        
	SUM(CASE 
            WHEN qf.transaction_date >= ft.first_txn_date 
            AND qf.transaction_date <= ft.first_txn_date + INTERVAL 60 DAY
            THEN  qf.amount
            ELSE  0
        END) AS activation_60d_volume, -- transaction_volume in the first 60 days for each company


    DATEDIFF(last_date.last_txn_date,ft.first_txn_date) as days_since_first_txn, -- days since the company made it's first transaction


    MAX(qf.transaction_date) AS last_txn_date, -- last transaction date of each company

    CASE 
        WHEN ft.first_txn_date IS NULL THEN 'not_activated'
        WHEN MAX(qf.transaction_date) >= last_date.last_txn_date - INTERVAL 30 DAY  
        THEN 'unchurned'  
        ELSE 'churned'
    END as churn_flag -- churn flag shows us if the company is a churned or an unchurned company

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


-- number of rows in the features VIEW
SELECT count(*) from features;

SELECT * from features;


SELECT churn_flag, 
COUNT(churn_flag) as count
from features
GROUP BY churn_flag;
