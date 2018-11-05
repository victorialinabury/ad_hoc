--First find alcoholic items and the total per order
 
--this gives you your true positives:
CREATE OR REPLACE TEMP TABLE scratch.public.tmp_alcohol_true_positives as
select distinct 
      MI_MENU_CATEGORY_NAME
      ,mi_name
      ,mi_description
      ,MI_ALCOHOL
      ,order_id
      ,oi_quantity
      ,oi_unit_price
     -- ,oi_total_unit_price
from production.DENORMALISED.DENORMALISED_ITEMS m
inner join scratch.public.victoria_orders_import o
on m.order_id = o.orders
where MI_ALCOHOL = True
    and MI_MENU_CATEGORY_NAME not in (
                                      'Desserts',
                                      'Appetisers',
                                      'Battered Fish',
                                      'Side Dishes',
                                      'Tandoori Dishes',
                                      '10" Pizzas',
                                       'Extras',
                                      'Garlic  ',
                                      'Add Cheese to Burger  ',
                                      'Sausage  ',
                                      'Cloudy Lemonade - Can',
                                      'Baked Beans',
                                      'Haddock (Large) (Grilled)',
                                      'Beef In A Spicy Green Tomatillo Sauce',
                                      'Lemon & Herb  ',
                                      'No Side  ',
                                      'Pineapple Pop',
                                      'Mild Heat  ',
                                      'No Chips  ',
                                      'Add Onion Rings to Burger  ',
                                      'Thick',
                                      'Garlic Mayo ',
                                      'French Dressing  ',
                                      'Curry Sauce',
                                      'Tomato Ketchup  ',
                                      'BBQ Sauce  ',
                                      'Relish  ',
                                      'Add Smoked Bacon to Burger  ',
                                      'Cream Soda - Can',
                                      'Mediterranean Dressing  ',
                                      'Plaice (Grilled)',
                                      'Gravy',
                                      'Lemon',
                                      'No Heat ',
                                      'Very Hot ',
                                      'Cod (Standard) (Grilled)',
                                      'Balsamic Dressing  ',
                                      'Free Cod & Chips',
                                      'No Dressing  ',
                                      'Hot  ',
                                      'Haddock',
                                      'The Whole Shabang (All 3 Flavours!)    ',
                                      'Lemon Sole (Grilled)',
                                      'Mushy Peas',
                                      'Cod',
                                      'Rajun Cajun  ',
                                      'Cod (Large) (Grilled)',
                                      'Mayo  ',
                                      'Mushy Peas ',
                                      'No Sauce  ',
                                      'Vegetarian')
      
      
      select * from scratch.public.tmp_alcohol_true_positives where order_id = 92744049
      select * from scratch.public.tmp_alcohol where order_id = 92744049
                                      
--this gives you your false negatives:
CREATE OR REPLACE TEMP TABLE scratch.public.tmp_alcohol_false_negatives as
select distinct 
      MI_MENU_CATEGORY_NAME
      ,mi_name
      ,mi_description
      ,MI_ALCOHOL
      ,order_id
      ,oi_quantity
      ,oi_unit_price
    --  ,oi_total_unit_price
from production.DENORMALISED.DENORMALISED_ITEMS m
inner join scratch.public.victoria_orders_import o
on m.order_id = o.orders
where MI_ALCOHOL = False
    and MI_MENU_CATEGORY_NAME in (select distinct MI_MENU_CATEGORY_NAME from scratch.public.tmp_alcohol_true_positives)
    and MI_MENU_CATEGORY_NAME not in ('Mods', 'Drinks', 'Other', 'Mixers', 'Premium',
                                       'Bread Choice',
                                      'Crepes',
                                      'Magnum Tubs',
                                      'Cakes',
                                      'I Like it Fried!',
                                      'Modifiers ',
                                      'Ben & Jerry Tubs',
                                      'Craft Beers',
                                      'Beer ',
                                      ' NEW! ALCOHOLIC DRINKS',
                                      'Red Wines - Argentina',
                                      'Sides',
                                      'Chocies for Bundles',
                                      'Topping',
                                      'Kids _Mods',
                                      'Soft Drinks',
                                      'Non-Dairy',
                                      'Waffles',
                                      'Smoothies',
                                      'Extra Filling',
                                      'Snacks_MOD',
                                      'MODS',
                                      'Express Café Menu')
    AND MI_MENU_CATEGORY_NAME not LIKE 'Ben & Jerry%'


--Join together and get the total per order
CREATE OR REPLACE TEMP TABLE scratch.public.tmp_alcohol as
select
  order_id
  ,sum(item_total) as order_total
from
(
    select
        order_id
        ,mi_name
        ,oi_quantity * oi_unit_price as item_total
      --  ,oi_quantity * oi_total_unit_price as item_total
    from
    (
          select * from scratch.public.tmp_alcohol_true_positives
          union
          select * from scratch.public.tmp_alcohol_false_negatives
    )
) group by order_id

--create an adjustment table
create or replace temp table scratch.public.tmp_adjustments as
select
    ord.orders
    ,sum(adjustment_cost) as adjustment_cost

from PRODUCTION.DENORMALISED.RESTAURANT_PAYMENT_ADJUSTMENTS adj
inner join scratch.public.victoria_orders_import ord
on ord.orders = adj.order_id
group by ord.orders


--get the orders and add the alcohol cost plus create a flag for those whithout payment adjustment
CREATE OR REPLACE temp TABLE scratch.public.tmp_orders_alcohol as
select distinct
    ord.orders
    ,sub.CREATED_AT
    ,adj.adjustment_cost
    ,case when adj.adjustment_cost is null then 'N' else 'Y' end as adjustment_flag
    ,sub.restaurant_id
    ,rm.restaurant_name
    ,rm.restaurant_company
    ,to_number(sub.subtotal, 10, 2) as subtotal
    ,coalesce(al.order_total, 0) as alcohol_cost
from scratch.public.victoria_orders_import ord
left join scratch.public.tmp_adjustments adj
on ord.orders = adj.orders
inner join production.denormalised.orders sub
on ord.orders = sub.id
left join scratch.public.tmp_alcohol al
on ord.orders = al.order_id
inner join production.reference.restaurant_mapping rm
on sub.restaurant_id = rm.restaurant_id
where sub.status in ('CANCELLED', 'CONFIRMED_BY_RESTAURANT')


--find the closest avaiable commission figure 1 day
CREATE OR REPLACE TEMP TABLE scratch.public.tmp_commission_1 as
select
    orders
    ,commission_rate
    ,perc_com
    ,fixed_com
    ,'1' as commission_rank
from
(
      select 
          o.orders
          ,o.restaurant_id
          ,subtotal
          ,restaurant_order_net
          ,abs(restaurant_order_net - subtotal) as diff
          ,row_number() over (partition by orders order by diff) as row_num
          ,commission_rate
          ,left(regexp_replace(commission_rate, '[^[:digit:]]', ''), 4) * 0.0001 as perc_com
          ,right(regexp_replace(commission_rate, '[^[:digit:]]', ''), 3) * 0.01 as fixed_com
      from scratch.public.tmp_orders_alcohol o
      inner join production.orderweb.restaurant_invoice_ledger_line_items r 
      on r.restaurant_id = o.restaurant_id 
      and to_date(r.created_at) = to_date(o.created_at) 
      where commission_rate not in ('Free Trial', 'Redelivery', '0')
) where row_num = 1

--fornight
CREATE OR REPLACE TEMP TABLE scratch.public.tmp_commission_2 as
select
    orders
    ,commission_rate
    ,perc_com
    ,fixed_com
    ,'2' as commission_rank
from
(
      select 
          o.orders
          ,o.restaurant_id
          ,subtotal
          ,restaurant_order_net
          ,abs(restaurant_order_net - subtotal) as diff
          ,row_number() over (partition by orders order by diff) as row_num
          ,commission_rate
          ,left(regexp_replace(commission_rate, '[^[:digit:]]', ''), 4) * 0.0001 as perc_com
          ,right(regexp_replace(commission_rate, '[^[:digit:]]', ''), 3) * 0.01 as fixed_com
      from scratch.public.tmp_orders_alcohol o
      inner join production.orderweb.restaurant_invoice_ledger_line_items r 
      on r.restaurant_id = o.restaurant_id 
      where commission_rate not in ('Free Trial', 'Redelivery', '0')
            and o.orders not in (select orders from scratch.public.tmp_commission_1)
            and to_date(r.created_at) <= dateadd(week, 1, to_date(o.created_at)) 
            and to_date(r.created_at) >= dateadd(week, -1, to_date(o.created_at))
) where row_num = 1

--anytime closest value
CREATE OR REPLACE TEMP TABLE scratch.public.tmp_commission_3 as
select
    orders
    ,commission_rate
    ,perc_com
    ,fixed_com
    ,'3' as commission_rank
from
(
      select 
          o.orders
          ,o.restaurant_id
          ,subtotal
          ,restaurant_order_net
          ,abs(restaurant_order_net - subtotal) as diff
          ,row_number() over (partition by orders order by diff) as row_num
          ,commission_rate
          ,left(regexp_replace(commission_rate, '[^[:digit:]]', ''), 4) * 0.0001 as perc_com
          ,right(regexp_replace(commission_rate, '[^[:digit:]]', ''), 3) * 0.01 as fixed_com
      from scratch.public.tmp_orders_alcohol o
      inner join production.orderweb.restaurant_invoice_ledger_line_items r 
      on r.restaurant_id = o.restaurant_id 
      where commission_rate not in ('Free Trial', 'Redelivery', '0')
            and o.orders not in (select orders from scratch.public.tmp_commission_1)
            and o.orders not in (select orders from scratch.public.tmp_commission_2)
) where row_num = 1

--can't find a value apply 25%
CREATE OR REPLACE TEMP TABLE scratch.public.tmp_commission_4 as
select
    orders
    ,'0' as commission_rate
    ,'0.2500' as perc_com
    ,'0.00' as fixed_com
    ,'4' as commission_rank
from scratch.public.tmp_orders_alcohol o
where o.orders not in (select orders from scratch.public.tmp_commission_1)
      and o.orders not in (select orders from scratch.public.tmp_commission_2)
      and o.orders not in (select orders from scratch.public.tmp_commission_3)

--join it all together
CREATE OR REPLACE TEMP TABLE scratch.public.tmp_commission_combined as
select
    orders
    ,commission_rate
    ,perc_com
    ,fixed_com
    ,commission_rank
from
(
select * from scratch.public.tmp_commission_1
union
select * from scratch.public.tmp_commission_2
union
select * from scratch.public.tmp_commission_3
union
select * from scratch.public.tmp_commission_4  
)

--created final table
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