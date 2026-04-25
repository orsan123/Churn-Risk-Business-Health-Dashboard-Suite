use corporate_card_data;


-- 4013 rows
SELECT COUNT(*) FROM transactions_raw;
SELECT * FROM transactions_raw;



-- creating a staging table for transactions
CREATE TABLE transactions_stg AS
SELECT * FROM transactions_raw;



-- transactions_stg table view
SELECT COUNT(*) FROM transactions_stg;


-- 4003 unique transaction_ids
SELECT COUNT(DISTINCT transaction_id) from transactions_stg;



-- 10 identical duplicates found
SELECT *
FROM transactions_stg
WHERE transaction_id IN
    (
        SELECT transaction_id
        from transactions_stg
        GROUP BY transaction_id
        HAVING COUNT(transaction_id) >1
    )
ORDER BY transaction_id;



-- these are the 10 duplicates using row_number
WITH temp AS (SELECT *, 
ROW_NUMBER() OVER (PARTITION BY transaction_id, 
                                card_id, 
                                company_id, 
                                transaction_date, 
                                amount, currency, 
                                merchant_name, 
                                category, 
                                transaction_type, 
                                status 
                                ORDER BY transaction_id) as rn  
FROM transactions_stg)
SELECT * FROM temp WHERE rn > 1;



-- there are empty strings in amount column
SELECT MIN(amount) from transactions_stg;



-- there are 8 empty strings in amount column (we can convert it to null when adding to transactions_final)
select * from transactions_stg
ORDER BY amount;



-- we can see here that there are 12 rows with merchant_names as empty string
SELECT DISTINCT merchant_name, COUNT(merchant_name) 
FROM transactions_stg
GROUP BY merchant_name
ORDER BY merchant_name;



-- 12 rows with merchant_name as empty strings
SELECT * FROM transactions_stg
WHERE merchant_name = '';

BEGIN;



-- Creating the final table
CREATE TABLE transactions_final AS
SELECT  
        transaction_id, 
        card_id, 
        company_id, 
        transaction_date, 
        CAST(NULLIF(amount, '') AS DECIMAL(15, 2)) as amount,
        currency, 
        NULLIF(merchant_name, '') as merchant_name,
        category, 
        transaction_type, 
        status
FROM 
(
    SELECT *, 
    ROW_NUMBER() OVER (PARTITION BY transaction_id, 
                                    card_id, 
                                    company_id, 
                                    transaction_date, 
                                    amount, currency, 
                                    merchant_name, 
                                    category, 
                                    transaction_type, 
                                    status 
                                    ORDER BY transaction_id) as rn  
    FROM transactions_stg
) temp
WHERE rn = 1;



-- checking the transactions_final_table
SELECT COUNT(*) FROM transactions_final;



-- no duplicate transaction_id
select transaction_id, count(transaction_id) as txn
FROM transactions_final
GROUP BY transaction_id
HAVING txn > 1;



-- merchant names have been NULLed
select DISTINCT merchant_name FROM transactions_final;



-- No empty strings
select amount FROM transactions_final
WHERE amount = '';



-- Final row count after cleaning -- 4003 -- this adds up with the value we saw earlier.
select COUNT(*) from transactions_final

-- commiting the transaction
COMMIT;



-- transaction_id changed to PRIMARY KEY
ALTER TABLE transactions_final
ADD PRIMARY KEY (transaction_id);



-- company_id and card_id changed to FOREIGN KEY
ALTER TABLE transactions_final
ADD CONSTRAINT fk_card_txn Foreign Key (card_id) REFERENCES cards_final(card_id), 
ADD CONSTRAINT fk_company_txn Foreign Key (company_id) REFERENCES companies_final(company_id);

-- view table
select * from transactions_final;
