use corporate_card_data;



-- Creating the final transactions table without the last month 
CREATE TABLE transactions_f AS 
SELECT * FROM transactions_final
WHERE transaction_date < DATE_FORMAT((SELECT MAX(transaction_date) FROM transactions_final), '%Y-%m-01');


-- creating a qualifying transactions VIEW without the last month

-- creating a view of only succesful transactions
CREATE VIEW qf AS
SELECT * FROM transactions_f
WHERE status = 'success'
AND transaction_type IN ('purchase','cash_withdrawal')
AND amount > 0;

-- count of succesful transactions (NEW ONE)
SELECT COUNT(*) FROM qf;
