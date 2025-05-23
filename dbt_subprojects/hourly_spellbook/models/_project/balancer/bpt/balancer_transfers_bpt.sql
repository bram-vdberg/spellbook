{{ config(
    schema = 'balancer',
    alias = 'transfers_bpt',
    post_hook='{{ expose_spells(blockchains = \'["arbitrum", "avalanche_c", "base", "ethereum", "gnosis", "optimism", "polygon", "zkevm"]\',
                                spell_type = "project",
                                spell_name = "balancer",
                                contributors = \'["thetroyharris", "victorstefenon", "viniabussafi"]\') }}'
    )
}}

{% set balancer_models = [
    ref('balancer_v2_arbitrum_transfers_bpt'),
    ref('balancer_v2_avalanche_c_transfers_bpt'),
    ref('balancer_v2_base_transfers_bpt'),
    ref('balancer_v2_ethereum_transfers_bpt'),
    ref('balancer_v2_gnosis_transfers_bpt'),
    ref('balancer_v2_optimism_transfers_bpt'),
    ref('balancer_v2_polygon_transfers_bpt'),
    ref('balancer_v2_zkevm_transfers_bpt'),
    ref('balancer_v3_ethereum_transfers_bpt'),
    ref('balancer_v3_gnosis_transfers_bpt'),
    ref('balancer_v3_arbitrum_transfers_bpt'),
    ref('balancer_v3_base_transfers_bpt')   
] %}

SELECT *
FROM (
    {% for model in balancer_models %}
    SELECT
        blockchain
      , version    
      , contract_address
      , block_date
      , evt_tx_hash
      , evt_index
      , evt_block_time
      , evt_block_number
      , "from"
      , to
      , value
    FROM {{ model }}
    {% if not loop.last %}
    UNION ALL
    {% endif %}
    {% endfor %}
)