SELECT
      COUNT(call_guid) as call_count
      ,sum(answered_15) as answered_15
      ,sum(answered_30) as answered_30
      ,sum(answered_45) as answered_45
      ,sum(answered_60) as answered_60
      ,sum(answered_90) as answered_90
      ,sum(answered_120) as answered_120
      ,sum(answered_300) as answered_300
      ,sum(answered_over_300) as answered_over_300
      --,sum(Good) as Good
      --,sum(Bad) as Bad
FROM
  (
      SELECT distinct
          call_guid
          ,case when was_ans_in_15s = False and was_ans_in_30s = False and was_ans_in_45s = False and was_ans_in_60s = False and was_ans_in_90s = False and was_ans_in_120s = False and was_ans_in_300s = False then 1 else 0 end as answered_over_300
          ,case when was_ans_in_15s = False and was_ans_in_30s = False and was_ans_in_45s = False and was_ans_in_60s = False and was_ans_in_90s = False and was_ans_in_120s = False and was_ans_in_300s = True then 1 else 0 end as answered_300
          ,case when was_ans_in_15s = False and was_ans_in_30s = False and was_ans_in_45s = False and was_ans_in_60s = False and was_ans_in_90s = False and was_ans_in_120s = True and was_ans_in_300s = True then 1 else 0 end as answered_120
          ,case when was_ans_in_15s = False and was_ans_in_30s = False and was_ans_in_45s = False and was_ans_in_60s = False and was_ans_in_90s = True and was_ans_in_120s = True and was_ans_in_300s = True then 1 else 0 end as answered_90
          ,case when was_ans_in_15s = False and was_ans_in_30s = False and was_ans_in_45s = False and was_ans_in_60s = True and was_ans_in_90s = True and was_ans_in_120s = True and was_ans_in_300s = True then 1 else 0 end as answered_60
          ,case when was_ans_in_15s = False and was_ans_in_30s = False and was_ans_in_45s = True and was_ans_in_60s = True and was_ans_in_90s = True and was_ans_in_120s = True and was_ans_in_300s = True then 1 else 0 end as answered_45
          ,case when was_ans_in_15s = False and was_ans_in_30s = True and was_ans_in_45s = True and was_ans_in_60s = True and was_ans_in_90s = True and was_ans_in_120s = True and was_ans_in_300s = True then 1 else 0 end as answered_30
          ,case when was_ans_in_15s = True and was_ans_in_30s = True and was_ans_in_45s = True and was_ans_in_60s = True and was_ans_in_90s = True and was_ans_in_120s = True and was_ans_in_300s = True then 1 else 0 end as answered_15
          ,case when csat_good = True then 1 else 0 end as Good
          ,case when csat_bad = True then 1 else 0 end as Bad
      FROM denormalised.nvm_calls
      where origin_country_name not in ('UK', 'Ireland')
          --and (CSAT_good = True or CSAT_bad = True)
          and CSAT_good = True
          and was_answered = True
          and start_timestamp between '2018-09-01' and '2018-09-30' 
  )
