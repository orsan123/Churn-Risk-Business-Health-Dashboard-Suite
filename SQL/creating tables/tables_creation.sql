USE corporate_card_data;

create table companies_raw(
    company_id varchar(25) , 
    company_name varchar(200), 
    industry varchar(200), 
    company_size varchar(100),
    kyb_approval_date DATE NULL, 
    account_manager varchar(200),
    plan varchar(100)
);

create table cards_raw(
    card_id varchar(25), 
    company_id varchar(200), 
    cardholder_name varchar(200), 
    card_type varchar(100),
    issued_date DATE,
    activation_date varchar(25), 
    status varchar(100),
    card_limit DECIMAL
);

create table transactions_raw (
    transaction_id varchar(25) ,
    card_id VARCHAR (25),
    company_id VARCHAR (25),
    transaction_date DATE,
    amount varchar(255), 
    currency CHAR(10), 
    merchant_name varchar(200),
    category VARCHAR(200),
    transction_type char(25),
    status CHAR(25)
);


create table support_tickets_raw(
    ticket_id VARCHAR (100),
    company_id varchar(25),
    ticket_type VARCHAR(100),
    priority VARCHAR(100),
    status varchar(25),
    created_date DATE,
    resolved_date varchar(250),
    agent varchar(50),
    satisfaction_score varchar(20)
);