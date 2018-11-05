CREATE OR REPLACE TEMP TABLE scratch.public.tmp_first_source_chat_data AS

SELECT
    id as chat_id
    ,order_id
    ,lob
    ,local_chat_timestamp
    ,local_first_response_timestamp
    ,local_end_timestamp
    ,agent_ids
    ,city_name as customer_city
    ,visitor_id as customer_id
    ,contact_reason
    ,csat_good
    ,csat_bad
    ,total_message_count
FROM 
    production.denormalised.zendesk_chats ch
WHERE 
    ch.chat_timestamp between '2018-07-01' and '2018-10-01'
    and ch.chat_timestamp <> '2018-09-16'
    and ch.chat_timestamp <> '2018-09-26'
    and ch.was_abandoned_under_5_secs = False
    and ch.missed = False
    and lob = 'Customer';



CREATE OR REPLACE TEMP TABLE scratch.public.first_source_chat_transcript AS

SELECT 
    tr.chat_id
    ,case when is_visitor_event = True then message_body end as Customer_chat
    ,case when is_agent_event = True then message_body end as agent_chat
    ,row_number() over(partition by tr.chat_id order by event_timestamp) as chat_cum
--    ,message_body
--    ,message_to
FROM
    production.denormalised.zendesk_chats_event_log tr
INNER JOIN
    scratch.public.tmp_first_source_chat_data ch
ON
    ch.chat_id = tr.chat_id
WHERE event_type = 'chat.msg'  
    order by tr.chat_id, event_timestamp;
    
 
CREATE OR REPLACE TEMP TABLE scratch.public.first_source_chat_data AS

SELECT c.*
FROM 
    scratch.public.tmp_first_source_chat_data c
INNER JOIN
    scratch.public.first_source_chat_transcript t
ON
    c.chat_id = t.chat_id
WHERE
    t.chat_cum > 1