USE corporate_card_data;

SELECT * FROM features_temp;

CREATE OR REPLACE VIEW early_engagement_companies AS
with retained_benchmark as 
(
    SELECT 
        ROUND(AVG(activation_14d_txns)) as benchmark_14d,
        ROUND(AVG(activation_30d_txns)) as benchmark_30d,
        ROUND(AVG(activation_45d_txns)) as benchmark_45d,
        ROUND(AVG(activation_60d_txns)) as benchmark_60d
    FROM features_temp
    WHERE churn_flag = 'unchurned'
    AND is_early_stage = 0
)
    SELECT 
        ft.company_id, 
        ft.company_name,
        ft.days_since_first_txn,
        ft.life_cycle_bucket, 
        ft.activation_60d_txns as transactions, 
        ft.activation_60d_volume as total_volume,
        ft.days_since_last_txn, 

        CASE 
            WHEN ft.life_cycle_bucket = '0-14' THEN rb.benchmark_14d
            WHEN ft.life_cycle_bucket = '15-30' THEN rb.benchmark_30d
            WHEN ft.life_cycle_bucket = '31-45' THEN rb.benchmark_45d
            WHEN ft.life_cycle_bucket = '46-60' THEN rb.benchmark_60d
        END as benchmark,

        CASE 
            WHEN ft.days_since_last_txn <= 7  
                AND
                ft.activation_60d_txns >= 0.8 * 
                    (CASE 
                    WHEN ft.life_cycle_bucket = '0-14' THEN rb.benchmark_14d
                    WHEN ft.life_cycle_bucket = '15-30' THEN rb.benchmark_30d
                    WHEN ft.life_cycle_bucket = '31-45' THEN rb.benchmark_45d
                    WHEN ft.life_cycle_bucket = '46-60' THEN rb.benchmark_60d
                    END) 
            THEN  'Healthy'

            WHEN ft.days_since_last_txn > 14   
                OR
                ft.activation_60d_txns < 0.6 * 
                    (CASE 
                    WHEN ft.life_cycle_bucket = '0-14' THEN rb.benchmark_14d
                    WHEN ft.life_cycle_bucket = '15-30' THEN rb.benchmark_30d
                    WHEN ft.life_cycle_bucket = '31-45' THEN rb.benchmark_45d
                    WHEN ft.life_cycle_bucket = '46-60' THEN rb.benchmark_60d
                    END) 
            THEN  'High Risk'

            ELSE 'Medium Risk'

        END as risk_label


FROM features_temp ft
CROSS JOIN retained_benchmark rb 
WHERE ft.is_early_stage = 1;
    