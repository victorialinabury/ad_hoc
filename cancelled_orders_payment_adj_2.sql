select
    orders
    ,order_date
    ,adjustment_cost
    ,adjustment_flag
    ,restaurant_id
    ,restaurant_name
    ,restaurant_company
    ,subtotal
    ,alcohol_cost
    ,commission_in_ledger
    ,commission_calc
    ,case when subtotal = '0.00' then '0.00'
        else subtotal - alcohol_cost - commission_calc end as pay_adj_total
from 
(

        select
            o.orders
            ,to_date(o.CREATED_AT) as order_date
            ,o.adjustment_cost
            ,adjustment_flag
            ,o.restaurant_id
            ,o.restaurant_name
            ,o.restaurant_company
            ,subtotal
            ,alcohol_cost
            ,commission_rate as commission_in_ledger
            ,case when alcohol_cost = '0.00' then round(((subtotal * perc_com) + fixed_com), 2) 
                  when subtotal = '0.00' then '0.00'
                  when subtotal - alcohol_cost = 0 then '0.00'
                  else round((((subtotal - alcohol_cost) * perc_com) + fixed_com), 2) end as commission_calc
        from scratch.public.tmp_commission_combined c
        inner join scratch.public.tmp_orders_alcohol o
        on c.orders = o.orders
)