CREATE OR REPLACE TABLE scratch.public.tmp_week_cohorts AS

SELECT 
	orders.user_id
	,orders.id
	,orders.delivered_at AS First_Delivery_Date
	,week(date_trunc(week, orders.delivered_at)) - 13 AS Cohort
FROM production.denormalised.orders orders
--INNER JOIN production.reference.zone_city_country zone
--ON orders.zone_id = zone.zone_id
WHERE
    orders.order_rank_user = 1
    and orders.delivered_at between '2018-04-02' and '2018-07-01'
    and (country_name in ('Netherlands') or city_name in ('Ghent', 'Leuven', 'Antwerp', 'Brugge', 'Hasselt', 'Knokke', 'Mechelen', 'Kortrijk') )
    --and (country_name in ('Netherlands', 'UK', 'Ireland') or city_name in ('Ghent', 'Leuven', 'Antwerp', 'Brugge', 'Hasselt', 'Knokke', 'Mechelen', 'Kortrijk') )
    
CREATE OR REPLACE TABLE scratch.public.tmp_week_contacts AS

SELECT
	order_id
FROM production.denormalised.nvm_calls
WHERE
	ORIGIN_LOB = 'Customer' 
	and order_id is not null 
	and start_timestamp between '2018-04-02' and '2018-07-01'

UNION

SELECT
	order_id
FROM production.denormalised.zendesk_chats
WHERE 
	LOB = 'Customer' 
	and order_id is not null 
	and chat_timestamp between '2018-04-02' and '2018-07-01'

UNION

SELECT
	order_id
FROM production.denormalised.zendesk_emails
WHERE
	LOB = 'Customer' 
	and order_id is not null 
	and created_at between '2018-04-02' and '2018-07-01';
    
  
  
CREATE OR REPLACE TABLE scratch.public.tmp_week_self_serve AS

SELECT
    order_id
FROM production.denormalised.compensation_claims
WHERE
    is_self_serve_claim = True
    and claim_time between '2018-04-02' and '2018-07-01';
	
    
CREATE OR REPLACE TABLE scratch.public.tmp_week_cohort_contacts AS

SELECT 
	o.user_id
	,o.first_order_id
	,to_date(first_delivery_date) as First_order_date
	,o.cohort
	,case when cs_contact_id is null then 0 else 1 end as cs_contact
    ,case when self_serve_id is null then 0 else 1 end as self_serve
FROM
(
	SELECT
		user_id
        ,id as first_order_id
        ,first_delivery_date
        ,cohort
        ,contacts.order_id as cs_contact_id
        ,self.order_id as self_serve_id
	FROM scratch.public.tmp_week_cohorts cohorts
	LEFT JOIN scratch.public.tmp_week_contacts contacts
    ON cohorts.id = contacts.order_id
    LEFT JOIN scratch.public.tmp_week_self_serve self
    ON cohorts.id = self.order_id
  ) o;
  
  
  
CREATE OR REPLACE TABLE scratch.public.tmp_week_retained AS

SELECT DISTINCT
        cc.user_id
        ,cc.cohort
        ,cs_contact
        ,self_serve
        ,ceil(datediff(day, cc.First_order_date, o.delivered_at) / 7) as week_round
FROM scratch.public.tmp_week_cohort_contacts cc
LEFT JOIN production.denormalised.orders o
ON cc.user_id = o.user_id
WHERE
    to_date(o.delivered_at) <= dateadd(week, 12, cc.first_order_date)
    and to_date(o.delivered_at) > cc.first_order_date


SELECT
    co.cohort
    ,count(distinct co.user_id) as retained_users 
	,co.week_round
FROM scratch.public.tmp_week_retained co
WHERE 
	cs_contact = 0
GROUP BY co.cohort, week_round
ORDER BY co.cohort, week_round

SELECT
	count(distinct USER_ID) as cohort_total
FROM scratch.public.tmp_week_retained
WHERE
	cs_contact = 1
    group by cohort
 
  