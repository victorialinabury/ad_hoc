*********************************************************
--Script to compare rention of first time customers in june with first time time customers who had CS contact

--1. get first time customers in june and assign their cohort
--2. Find CS contacts in june
--3. Combine these tables and create a flag
--4. Get any orders 12 weeks from their first order date and find the difference beteween the first order and the others
--5. Get totals for pivot table

CREATE OR REPLACE TABLE scratch.public.tmp_june_cohorts AS

SELECT 
	orders.user_id
	,orders.id
	,orders.delivered_at AS First_Delivery_Date
	,Day(orders.delivered_at) AS Cohort
FROM production.denormalised.orders orders
WHERE
    order_rank_user = 1
    and delivered_at between '2018-06-01' and '2018-06-30';

*********************************************************
	
CREATE OR REPLACE TABLE scratch.public.tmp_june_contacts AS

SELECT
	order_id
FROM production.denormalised.nvm_calls
WHERE
	ORIGIN_LOB = 'Customer' 
	and order_id is not null 
	and start_timestamp between '2018-06-01' and '2018-06-30'

UNION

SELECT
	order_id
FROM production.denormalised.zendesk_chats
WHERE 
	LOB = 'Customer' 
	and order_id is not null 
	and chat_timestamp between '2018-06-01' and '2018-06-30'

UNION

SELECT
	order_id
FROM production.denormalised.zendesk_emails
WHERE
	LOB = 'Customer' 
	and order_id is not null 
	and created_at between '2018-06-01' and '2018-06-30';

*********************************************************
	
CREATE OR REPLACE TABLE scratch.public.tmp_june_cohort_contacts AS

SELECT 
	o.user_id
	,o.id
	,to_date(first_delivery_date) as First_order_date
	,o.cohort
	,case when order_id is null then 0 else 1 end as cs_contact
FROM
(
	SELECT
		*
	FROM scratch.public.tmp_june_cohorts cohorts
	LEFT JOIN scratch.public.tmp_june_contacts contacts
	ON cohorts.id = contacts.order_id
  ) o;
  
*********************************************************
  
CREATE OR REPLACE TABLE scratch.public.tmp_june_week_retained AS
SELECT DISTINCT
        cc.user_id
        ,cc.cohort
        ,cs_contact
        ,ceil(datediff(day, cc.First_order_date, o.delivered_at) / 7) as week_round
FROM scratch.public.tmp_june_cohort_contacts cc
LEFT JOIN production.denormalised.orders o
ON cc.user_id = o.user_id
WHERE
    to_date(o.delivered_at) <= dateadd(week, 12, cc.first_order_date)
    and to_date(o.delivered_at) > cc.first_order_date;
	
*********************************************************

SELECT
    co.cohort
    ,count(distinct co.user_id) as retained_users 
	,co.week_round
FROM scratch.public.tmp_june_weeks_retained co
WHERE 
	cs_contact = 0
GROUP BY co.cohort, week_round
ORDER BY co.cohort, week_round


SELECT
	count(distinct USER_ID) as cohort_total
	,cohort
FROM scratch.public.tmp_june_weeks_retained
WHERE
	cs_contact = 0
GROUP BY cohort