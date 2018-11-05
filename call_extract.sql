CREATE OR REPLACE TEMP TABLE scratch.public.tmp_first_source_call_data AS

SELECT
    call_guid as call_id
    ,order_id
    ,origin_lob
    ,local_start_timestamp
    ,local_first_queue_timestamp
    ,local_first_answer_timestamp
    ,local_end_timestamp
    ,total_talk_time
    ,total_hold_time
    ,total_call_duration
    ,wrap_up_duration
    ,total_handle_time
    ,primary_agent_id
    ,city_name as customer_city
    ,phone_cleaned as customer_phone
    ,contact_reason
    ,csat_good
    ,csat_bad
FROM 
    production.denormalised.nvm_calls ch
WHERE 
    ch.local_start_timestamp between '2018-07-01' and '2018-10-01'
    and ch.local_start_timestamp <> '2018-09-16'
    and ch.local_start_timestamp <> '2018-09-26'
    and ch.was_answered = True
    and was_abandoned_under_5_secs = False
    and origin_lob = 'Customer';