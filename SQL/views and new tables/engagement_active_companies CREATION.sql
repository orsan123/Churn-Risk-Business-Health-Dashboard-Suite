USE corporate_card_data;


CREATE OR REPLACE VIEW company_month_engagement AS
WITH monthly_engagement as 
(
    SELECT t.company_id, 
    DATE_FORMAT(t.transaction_date, '%Y-%m-01') as period_date,
    COUNT(t.transaction_id) as transaction_count,
    SUM(t.amount) as transaction_volume,
    COUNT(DISTINCT t.card_id) as active_cards,
    MAX(t.transaction_date) as last_txn_in_month
FROM qf t 
    GROUP BY t.company_id,
    DATE_FORMAT(t.transaction_date, '%Y-%m-01')),

activated AS
(
    SELECT 
    qf.company_id, 
    COUNT(DISTINCT qf.card_id) as activated_cards
    FROM qf
    GROUP BY qf.company_id),

base AS
(
    SELECT me.company_id, 
    c.company_name,
    me.period_date,
    me.transaction_count,
    me.transaction_volume,
    me.active_cards,
    ac.activated_cards,
    ROUND(me.active_cards / ac.activated_cards, 2) as card_utilization,
    me.last_txn_in_month
    FROM monthly_engagement me  
    LEFT JOIN companies_final c 
        ON me.company_id = c.company_id
    LEFT JOIN activated ac  
        ON me.company_id = ac.company_id
),

avg_per_month AS
(
    SELECT 
        period_date, 
        ROUND(AVG(transaction_count), 2) AS avg_txns
        FROM base
        GROUP BY period_date
)
SELECT 
    b.period_date,
    b.company_id,
    b.company_name, 
    b.transaction_count as transactions,
    b.transaction_volume, 
    b.active_cards, 
    b.activated_cards, 
    b.card_utilization, 
    b.last_txn_in_month, 

    apm.avg_txns as avg_txns_month,

    CASE 
        WHEN b.transaction_count >= apm.avg_txns
            AND b.card_utilization > 0.70
                THEN 'High Engagement'  
        WHEN b.transaction_count < 0.5 * apm.avg_txns
            OR b.card_utilization < 0.40
                THEN 'Low Engagement'
        ELSE  'Medium Engagement'
    END AS engagement_label

    FROM base b  
    LEFT JOIN avg_per_month apm  
    ON b.period_date = apm.period_date;

