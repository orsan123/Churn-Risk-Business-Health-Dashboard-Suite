use corporate_card_data;


select * from companies_stg;

-- Number of rows (54)
select COUNT(*) from companies_stg;


-- Number of distinct company ids (50)
SELECT COUNT(DISTINCT company_id)
FROM companies_stg;


-- 4 duplicated company ids
SELECT company_id, COUNT(COMPANY_ID)
FROM companies_stg
GROUP BY company_id
HAVING COUNT(COMPANY_ID) > 1;

-- 4 original company ids and their copies (they are duplicates with the company name in full upper case)
SELECT * FROM companies_stg
WHERE company_id IN 
(SELECT company_id
FROM companies_stg
GROUP BY company_id
HAVING COUNT(COMPANY_ID) > 1);

-- Beginning a transaction
BEGIN;

-- updating the company names to upper case
UPDATE companies_stg
SET company_name = UPPER(TRIM(company_name)); 


-- These are the duplicates using row number
with temp as (SELECT *, 
ROW_NUMBER() OVER (PARTITION BY company_id, company_name, industry, company_size, kyb_approval_date, account_manager, plan ORDER BY company_id) as rn  
FROM companies_stg)
SELECT * FROM temp
WHERE rn >1;

-- New table companies_stg_clean without duplicates
CREATE TABLE companies_stg_clean AS
SELECT * FROM 
(
    SELECT *, 
    ROW_NUMBER() OVER (PARTITION BY company_id, company_name, industry, company_size, kyb_approval_date, account_manager, plan ORDER BY company_id) as rn 
    FROM companies_stg
) temp
WHERE rn = 1;

-- companies_final is the cleaned table without any helper columns ("rn")
CREATE TABLE companies_final AS
SELECT company_id, 
       company_name, 
       industry, 
       company_size, 
       kyb_approval_date, 
       account_manager, 
       plan 
FROM companies_stg_clean;

-- After cleaning we now make the company_id, PRIMARY KEY
ALTER TABLE companies_final
ADD PRIMARY KEY (company_id);

-- Final cleaned company table
-- 50 companies
SELECT COUNT(*) FROM companies_final;


-- Commiting the transaction
COMMIT;

-- View full table
select * from companies_final;
