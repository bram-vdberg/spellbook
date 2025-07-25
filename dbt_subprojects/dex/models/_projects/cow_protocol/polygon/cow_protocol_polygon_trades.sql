{{  config(
    schema='cow_protocol_polygon',
    alias='trades',
    materialized='incremental',
    partition_by = ['block_month'],
    unique_key = ['tx_hash', 'order_uid', 'evt_index'],
    on_schema_change='sync_all_columns',
    file_format ='delta',
    incremental_strategy='merge',
    incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_time')],
    post_hook='{{ expose_spells(\'["polygon"]\',
                                "project",
                                "cow_protocol",
                                \'["harisang"]\') }}'
    )
}}

WITH
-- First subquery joins buy and sell token prices from prices.usd.
-- Also deducts fee from sell amount.
trades_with_prices AS (
    SELECT cast(date_trunc('day', evt_block_time) as date) as block_date,
           cast(date_trunc('month', evt_block_time) as date) as block_month,
           evt_block_time            as block_time,
           evt_block_number          as block_number,
           evt_tx_hash               as tx_hash,
           evt_index,
           trade.contract_address    as project_contract_address,
           owner                     as trader,
           orderUid                  as order_uid,
           sellToken                 as sell_token,
           buyToken                  as buy_token,
           sellAmount - feeAmount    as sell_amount,
           buyAmount                 as buy_amount,
           feeAmount                 as fee_amount,
           ps.price                  as sell_price,
           pb.price                  as buy_price
    FROM {{ source('gnosis_protocol_v2_polygon', 'GPv2Settlement_evt_Trade') }} trade
             LEFT OUTER JOIN {{ source('prices', 'usd') }} as ps
                             ON sellToken = ps.contract_address
                                 AND ps.minute = date_trunc('minute', evt_block_time)
                                 AND ps.blockchain = 'polygon'
                                 {% if is_incremental() %}
                                 AND {{ incremental_predicate('ps.minute') }}
                                 {% endif %}
             LEFT OUTER JOIN {{ source('prices', 'usd') }} as pb
                             ON pb.contract_address = (
                                 CASE
                                     WHEN buyToken = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
                                         THEN 0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270
                                     ELSE buyToken
                                     END)
                                 AND pb.minute = date_trunc('minute', evt_block_time)
                                 AND pb.blockchain = 'polygon'
                                 {% if is_incremental() %}
                                 AND {{ incremental_predicate('pb.minute') }}
                                 {% endif %}
    {% if is_incremental() %}
    WHERE {{ incremental_predicate('evt_block_time') }}
    {% endif %}
),
-- Second subquery gets token symbol and decimals from tokens.erc20 (to display units bought and sold)
trades_with_token_units as (
    SELECT block_date,
           block_month,
           block_time,
           block_number,
           tx_hash,
           evt_index,
           project_contract_address,
           order_uid,
           trader,
           sell_token                        as sell_token_address,
           (CASE
                WHEN ts.symbol IS NULL THEN cast(sell_token as varchar)
                ELSE ts.symbol
               END)                          as sell_token,
           buy_token                         as buy_token_address,
           (CASE
                WHEN tb.symbol IS NULL THEN cast(buy_token as varchar)
                WHEN buy_token = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee THEN 'POL'
                ELSE tb.symbol
               END)                          as buy_token,
           sell_amount / pow(10, ts.decimals) as units_sold,
           sell_amount                       as atoms_sold,
           buy_amount / pow(10, tb.decimals)  as units_bought,
           buy_amount                        as atoms_bought,
           -- We use sell value when possible and buy value when not
           fee_amount / pow(10, ts.decimals)  as fee,
           fee_amount                        as fee_atoms,
           sell_price,
           buy_price
    FROM trades_with_prices
             LEFT OUTER JOIN {{ source('tokens', 'erc20') }} ts
                             ON ts.blockchain='polygon' AND ts.contract_address = sell_token
             LEFT OUTER JOIN {{ source('tokens', 'erc20') }} tb
                             ON tb.blockchain='polygon' AND tb.contract_address =
                                (CASE
                                     WHEN buy_token = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
                                         THEN 0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270
                                     ELSE buy_token
                                    END)
),
sorted_orders as (
    select
        evt_tx_hash,
        evt_block_number,
        array_agg(orderUid order by evt_index) as order_ids
    from (
        select
            evt_tx_hash,
            evt_index,
            evt_block_number,
            orderUid
        from {{ source('gnosis_protocol_v2_polygon', 'GPv2Settlement_evt_Trade') }}
        {% if is_incremental() %}
        where {{ incremental_predicate('evt_block_time') }}
        {% endif %}
    )
    group by evt_tx_hash, evt_block_number
),

orders_and_trades as (
    select
        evt_tx_hash,
        trades,
        order_ids
    from sorted_orders
    inner join {{ source('gnosis_protocol_v2_polygon', 'GPv2Settlement_call_settle') }}
        on evt_block_number = call_block_number
        and evt_tx_hash = call_tx_hash
),

uid_to_app_id as (
    SELECT
      distinct uid,
      evt_tx_hash as hash,
      from_hex(JSON_EXTRACT_SCALAR(trade, '$.appData')) AS app_data,
      from_hex(JSON_EXTRACT_SCALAR(trade, '$.receiver')) AS receiver,
      cast(JSON_EXTRACT_SCALAR(trade, '$.sellAmount') as uint256) AS limit_sell_amount,
      cast(JSON_EXTRACT_SCALAR(trade, '$.buyAmount') as uint256) AS limit_buy_amount,
      date_format(
        from_unixtime(cast(JSON_EXTRACT_SCALAR(trade, '$.validTo') as double)),
        '%Y-%m-%d %T'
      ) AS valid_to,
      cast(JSON_EXTRACT_SCALAR(trade, '$.flags') as integer) AS flags
    FROM
      orders_and_trades
      CROSS JOIN UNNEST (order_ids)
    WITH
      ORDINALITY AS o (uid, i)
      CROSS JOIN UNNEST (trades)
    WITH
      ORDINALITY AS t (trade, j)
    WHERE
      i = j
),

eth_flow_senders as (
    select
        sender,
        bytearray_concat(
            bytearray_concat(
                output_orderHash,
                bytearray_substring(event.contract_address, 1, 20)
            ),
            0xffffffff
        ) AS order_uid
    from {{ source('cow_protocol_polygon', 'CoWSwapEthFlow_evt_OrderPlacement') }} event
    inner join {{ source('cow_protocol_polygon', 'CoWSwapEthFlow_call_createOrder') }} call
        on call_block_number = evt_block_number
        and call_tx_hash = evt_tx_hash
    {% if is_incremental() %}
    where {{ incremental_predicate('evt_block_time') }}
    {% endif %}
),

valued_trades as (
    SELECT block_date,
           block_month,
           block_time,
           block_number,
           tx_hash,
           evt_index,
           ARRAY[-1] as trace_address,
           project_contract_address,
           trades.order_uid,
           -- ETH Flow orders have trader = sender of orderCreation.
           case when sender is not null then sender else trader end as trader,
           sell_token_address,
           case when sender is not null then 'POL' else sell_token end as sell_token,
           buy_token_address,
           buy_token,
           case
                 when lower(buy_token) > lower(sell_token) then concat(sell_token, '-', buy_token)
                 else concat(buy_token, '-', sell_token)
               end as token_pair,
           units_sold,
           atoms_sold,
           units_bought,
           atoms_bought,
           (CASE
                WHEN sell_price IS NOT NULL THEN
                    -- Choose the larger of two prices when both not null.
                    CASE
                        WHEN buy_price IS NOT NULL and buy_price * COALESCE(units_bought,0) > sell_price * COALESCE(units_sold,0)
                            then buy_price * units_bought
                        ELSE sell_price * units_sold
                        END
                WHEN sell_price IS NULL AND buy_price IS NOT NULL THEN buy_price * units_bought
               END)                                        as usd_value,
           buy_price,
           buy_price * units_bought                        as buy_value_usd,
           sell_price,
           sell_price * units_sold                         as sell_value_usd,
           fee,
           fee_atoms,
           (CASE
                WHEN sell_price IS NOT NULL THEN
                    CASE
                        WHEN buy_price IS NOT NULL and buy_price * COALESCE(units_bought,0) > sell_price * COALESCE(units_sold,0)
                            then buy_price * units_bought * fee / units_sold
                        ELSE sell_price * fee
                        END
                WHEN sell_price IS NULL AND buy_price IS NOT NULL
                    THEN buy_price * units_bought * fee / units_sold
               END)                                        as fee_usd,
           app_data,
           case
              when receiver = 0x0000000000000000000000000000000000000000
              then trader
              else receiver
           end                                    as receiver,
           limit_sell_amount,
           limit_buy_amount,
           valid_to,
           flags,
           case when (flags % 2) = 0 then 'SELL' else 'BUY' end as order_type,
           bitwise_and(flags, 2) != 0 as partial_fill,
           (CASE
            when (flags % 2) = 0 then atoms_sold / limit_sell_amount
            else atoms_bought / limit_buy_amount
            end
        ) as fill_proportion
    FROM trades_with_token_units trades
    JOIN uid_to_app_id
        ON uid = trades.order_uid
        AND hash=tx_hash
    LEFT OUTER JOIN eth_flow_senders efs
            ON trades.order_uid = efs.order_uid
)

select *,
  -- Relative surplus (in %) is the difference between limit price and executed price as a ratio of the limit price.
  -- Absolute surplus (in USD) is relative surplus multiplied with the value of the trade
  usd_value * (atoms_bought * limit_sell_amount - atoms_sold * limit_buy_amount) / (atoms_bought * limit_sell_amount) as surplus_usd
from valued_trades
