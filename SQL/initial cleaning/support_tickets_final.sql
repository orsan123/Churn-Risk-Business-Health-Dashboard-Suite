USE corporate_card_data;

SELECT * FROM support_tickets_raw;

-- 213 rows originally
SELECT COUNT(*) from support_tickets_raw;



-- creating a staging table
CREATE TABLE support_ticket_stg AS
SELECT * FROM support_tickets_raw;




-- 208 distinct ticket_ids
SELECT COUNT(distinct ticket_id) from support_ticket_stg;

-- ticket_ids that appear more than once in the table
SELECT ticket_id 
from support_ticket_stg
GROUP BY ticket_id
HAVING COUNT(ticket_id) > 1;

-- these are identical rows -we can drop them
SELECT * FROM support_ticket_stg
WHERE ticket_id IN 
(
    SELECT ticket_id 
    from support_ticket_stg
    GROUP BY ticket_id
    HAVING COUNT(ticket_id) > 1
)
ORDER BY ticket_id;


-- 5 duplicated rows
with temp as (
    SELECT *, 
    ROW_NUMBER() OVER (PARTITION BY ticket_id, company_id, ticket_type, priority, status, created_date, resolved_date, agent, satisfaction_score ORDER BY ticket_id) as rn  
    FROM support_ticket_stg
)
SELECT * FROM temp 
WHERE rn > 1;


-- 56 rows that has "resolved_date" as an empty string
SELECT COUNT(*) FROM support_ticket_stg
WHERE resolved_date = '';



-- 25 rows where satisfaction_score is an empty string
SELECT COUNT(*) FROM support_ticket_stg
WHERE satisfaction_score = '';


-- creating the final table without any duplicates and with columns in the right format
CREATE TABLE support_tickets_final AS 
SELECT  ticket_id, 
        company_id, 
        ticket_type, 
        priority, 
        status, 
        created_date, 
        STR_TO_DATE(NULLIF(resolved_date, ''), '%Y-%m-%d') as resolved_date, 
        agent, 
        CAST(NULLIF(satisfaction_score, '') AS DECIMAL(3,1)) as satisfaction_score
FROM
(
    SELECT *, 
    ROW_NUMBER() OVER (PARTITION BY ticket_id, company_id, ticket_type, priority, status, created_date, resolved_date, agent, satisfaction_score ORDER BY ticket_id) as rn  
    FROM support_ticket_stg
)  temp  
WHERE rn = 1;


-- view full table
SELECT * FROM support_tickets_final;


-- 208 rows
SELECT COUNT(*) FROM support_tickets_final;

-- no duplicates
select COUNT(DISTINCT ticket_id) from support_tickets_final

-- no empty strings in resolved_date and satisfaction_scores_columns
-- resolved_date was converted to date format
-- satisfaction_score was converted to decimal format
SELECT COUNT(*) FROM support_tickets_final
WHERE satisfaction_score = '';


-- change ticket_id to PRIMARY KEY  
ALTER TABLE support_tickets_final
ADD PRIMARY KEY (ticket_id);


-- change company_id to FOREIGN KEY 
ALTER TABLE support_tickets_final
ADD CONSTRAINT fk_company_suptic Foreign Key (company_id) REFERENCES companies_final(company_id);

