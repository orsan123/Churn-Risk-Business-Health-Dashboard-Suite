use corporate_card_data;

select * from support_tickets_final;
-- -------------------------------------------------------------------------------------- 
-- CREATING support_tickets_f to remove the data in july and keeping only the data in june 
-- -------------------------------------------------------------------------------------- 
CREATE TABLE support_tickets_f AS 
SELECT 
	ticket_id,
	company_id,
	ticket_type,
	priority,
	status,
	created_date,
	resolved_date,
	DATEDIFF(resolved_date, created_date) as resolution_time,
	agent, 
	satisfaction_score
FROM support_tickets_final
WHERE ticket_id NOT IN 
(
	select ticket_id from support_tickets_final where 
	resolved_date > "2024-06-30"
);


