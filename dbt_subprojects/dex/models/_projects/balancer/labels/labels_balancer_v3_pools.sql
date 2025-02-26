{{config(
        schema = 'labels',
        alias = 'balancer_v3_pools',        
        post_hook='{{ expose_spells(\'["arbitrum", "base", "ethereum", "gnosis"]\',
                                    "sector",
                                    "labels",
                                    \'["balancerlabs", "viniabussafi"]\') }}')}}

SELECT * FROM  {{ ref('labels_balancer_v3_pools_ethereum') }}
UNION
SELECT * FROM  {{ ref('labels_balancer_v3_pools_gnosis') }}
UNION
SELECT * FROM  {{ ref('labels_balancer_v3_pools_arbitrum') }}
UNION
SELECT * FROM  {{ ref('labels_balancer_v3_pools_base') }}
