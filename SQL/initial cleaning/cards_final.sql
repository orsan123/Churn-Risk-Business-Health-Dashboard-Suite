USE CORPORATE_CARD_DATE;

SELECT * FROM cards_raw;



-- 406 rows originally
SELECT COUNT(*) FROM cards_raw;



-- creating a staging table (cards_stg)
CREATE TABLE cards_stg AS
SELECT * FROM CARDS_RAW;



-- 400 distinct card_id
SELECT COUNT( DISTINCT card_id) FROM cards_stg;



-- duplicate card ids
SELECT card_id
FROM cards_stg
GROUP BY card_id
HAVING COUNT(card_id) > 1; 



-- These are identical copies. can be excluded from final table
SELECT * FROM cards_stg
WHERE card_id IN 
(
    SELECT card_id
FROM cards_stg
GROUP BY card_id
HAVING COUNT(card_id) > 1
)
ORDER BY card_id;



-- 6 duplicates found
with temp as (SELECT *, 
ROW_NUMBER() OVER (PARTITION BY card_id, company_id, cardholder_name, card_type, issued_date, activation_date, status, card_limit ORDER BY card_id) as rn  
FROM cards_stg)
SELECT * FROM temp
WHERE rn >1;



-- starting a transaction
BEGIN;



-- there are 73 empty strings in activation_date column 
SELECT COUNT(*)
FROM cards_stg
WHERE activation_date = '';



-- new table cards_final with no duplicates
-- cards_final.activation_date is in DATE format and the empty strings were converted to nulls before adding them
CREATE TABLE cards_final AS
SELECT 
    card_id,
    company_id,
    cardholder_name,
    card_type,
    issued_date,
    STR_TO_DATE(NULLIF(activation_date, ''), '%Y-%m-%d') AS activation_date,
    status,
    card_limit
FROM 
(SELECT *, 
ROW_NUMBER() OVER (PARTITION BY card_id, company_id, cardholder_name, card_type, issued_date, activation_date, status, card_limit ORDER BY card_id) as rn  
FROM cards_stg) temp
WHERE rn = 1;



-- checking for bad date formats
SELECT * FROM cards_final
WHERE activation_date IS NOT NULL
AND STR_TO_DATE(activation_date, '%Y-%m-%d') IS NULL;



-- making card_id the PRIMARY KEY
ALTER TABLE cards_final
ADD PRIMARY KEY (card_id);



-- Making company_id the FOREIGN KEY
ALTER TABLE cards_final
ADD constraint  fk_company
Foreign Key (company_id) REFERENCES companies_final(company_id);



-- commit the transaction
COMMIT;



-- view table
SELECT * FROM cards_final;
