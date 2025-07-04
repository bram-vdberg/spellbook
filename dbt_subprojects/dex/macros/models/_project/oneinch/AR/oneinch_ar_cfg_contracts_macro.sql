{% macro oneinch_ar_cfg_contracts_macro() %}

{%
    set samples = {
        "aggregate": {
            "src_token_address":    "fromToken",
            "dst_token_address":    "toToken",
            "src_token_amount":     "tokensAmount",
            "dst_token_amount":     "output_returnAmount",
            "dst_token_amount_min": "minTokensAmount",
            "router_type":          "generic",
        },
        "swap": {
            "kit":                  "cast(json_parse(desc) as map(varchar, varchar))",
            "src_token_address":    "from_hex(kit['srcToken'])",
            "dst_token_address":    "from_hex(kit['dstToken'])",
            "src_receiver":         "from_hex(kit['srcReceiver'])",
            "dst_receiver":         "from_hex(kit['dstReceiver'])",
            "src_token_amount":     "cast(kit['amount'] as uint256)",
            "dst_token_amount":     "output_returnAmount",
            "dst_token_amount_min": "cast(kit['minReturnAmount'] as uint256)",
            "router_type":          "generic",
        },
        "unoswap v3-v5": {
            "pools":                "pools",
            "src_token_amount":     "amount",
            "dst_token_amount":     "output_returnAmount",
            "dst_token_amount_min": "minReturn",
            "direction_mask":       "bytearray_to_uint256(rpad(0x80, 32, 0x00))",
            "unwrap_mask":          "bytearray_to_uint256(rpad(0x40, 32, 0x00))",
            "router_type":          "unoswap",
        },
        "unoswap v6": {
            "src_token_address":    "substr(cast(if(token <> 0, token) as varbinary), 13)",
            "src_token_amount":     "amount",
            "dst_token_amount":     "output_returnAmount",
            "dst_token_amount_min": "minReturn",
            "pool_type_mask":       "bytearray_to_uint256(rpad(0xe0000000, 32, 0x00))",
            "pool_type_offset":     "253",
            "direction_mask":       "bytearray_to_uint256(rpad(0x00800000, 32, 0x00))",
            "unwrap_mask":          "bytearray_to_uint256(rpad(0x10000000, 32, 0x00))",
            "src_token_mask":       "bytearray_to_uint256(rpad(0x000000ff, 32, 0x00))",
            "src_token_offset":     "224",
            "dst_token_mask":       "bytearray_to_uint256(rpad(0x0000ff00, 32, 0x00))",
            "dst_token_offset":     "232",
            "router_type":          "unoswap",
        },
        "clipper": {
            "src_token_address":    "srcToken",
            "dst_token_address":    "dstToken",
            "src_token_amount":     "inputAmount",
            "dst_token_amount":     "output_returnAmount",
            "router_type":          "clipper",
        },
    }
%}

{% set native = '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee' %}

-- EVENTS CONFIG
{%
    set contracts = {
        "ExchangeV1": {
            "version": "0.1",
            "blockchains": ["ethereum"],
            "start": "2019-06-03",
            "end": "2020-09-18",
            "methods": {
                "aggregate": samples["aggregate"],
            },
        },
        "ExchangeV2": {
            "version": "0.2",
            "blockchains": ["ethereum"],
            "start": "2019-06-10",
            "end": "2020-09-18",
            "methods": {
                "aggregate": samples["aggregate"],
            },
        },
        "ExchangeV3": {
            "version": "0.3",
            "blockchains": ["ethereum"],
            "start": "2019-06-18",
            "end": "2020-09-18",
            "methods": {
                "aggregate": samples["aggregate"],
            },
        },
        "ExchangeV4": {
            "version": "0.4",
            "blockchains": ["ethereum"],
            "start": "2019-07-18",
            "end": "2020-09-18",
            "methods": {
                "aggregate": samples["aggregate"],
            },
        },
        "ExchangeV5": {
            "version": "0.5",
            "blockchains": ["ethereum"],
            "start": "2019-07-18",
            "end": "2020-09-18",
            "methods": {
                "aggregate": samples["aggregate"],
            },
        },
        "ExchangeV6": {
            "version": "0.6",
            "blockchains": ["ethereum"],
            "start": "2019-07-19",
            "end": "2020-09-18",
            "methods": {
                "aggregate": samples["aggregate"],
            },
        },
        "ExchangeV7": {
            "version": "0.7",
            "blockchains": ["ethereum"],
            "start": "2019-09-17",
            "end": "2019-09-29",
            "methods": {
                "swap": dict(samples["aggregate"], src_token_amount="fromTokenAmount", dst_token_amount_min="minReturnAmount"),
            },
        },
        "AggregationRouterV1": {
            "version": "1",
            "blockchains": ["ethereum"],
            "start": "2019-09-28",
            "methods": {
                "swap": dict(samples["aggregate"], src_token_amount="fromTokenAmount", dst_token_amount_min="minReturnAmount"),
            },
        },
        "AggregationRouterV2": {
            "version": "2",
            "blockchains": ["ethereum", "bnb"],
            "start": "2020-11-04",
            "methods": {
                "swap":           samples["swap"],
                "discountedSwap": samples["swap"],
            },
        },
        "AggregationRouterV3": {
            "version": "3",
            "blockchains": ["ethereum", "bnb", "polygon", "arbitrum", "optimism"],
            "start": "2021-03-14",
            "methods": {
                "swap":              samples["swap"],
                "discountedSwap":    samples["swap"],
                "unoswap":           dict(samples["unoswap v3-v5"], blockchains=["ethereum","bnb","polygon","arbitrum"], src_token_address="srcToken", pools="transform(_0, x -> bytearray_to_uint256(x))"),
                "unoswapWithPermit": dict(samples["unoswap v3-v5"], blockchains=["ethereum","bnb","polygon","arbitrum"], src_token_address="srcToken", pools="transform(pools, x -> bytearray_to_uint256(x))"),
            },
        },
        "AggregationRouterV4": {
            "version": "4",
            "blockchains": ["ethereum", "bnb", "polygon", "arbitrum", "optimism", "avalanche_c", "gnosis", "fantom"],
            "start": "2021-11-05",
            "methods": {
                "swap":                      samples["swap"],
                "discountedSwap":            dict(samples["swap"], blockchains=["bnb", "polygon"]),
                "clipperSwap":               dict(samples["clipper"], src_token_amount="amount", dst_token_amount_min="minReturn", blockchains=["ethereum"]),
                "clipperSwapTo":             dict(samples["clipper"], src_token_amount="amount", dst_token_amount_min="minReturn", blockchains=["ethereum"], dst_receiver="recipient"),
                "clipperSwapToWithPermit":   dict(samples["clipper"], src_token_amount="amount", dst_token_amount_min="minReturn", blockchains=["ethereum"], dst_receiver="recipient"),
                "unoswap":                   dict(samples["unoswap v3-v5"], src_token_address="srcToken", pools="transform(pools, x -> bytearray_to_uint256(x))"),
                "unoswapWithPermit":         dict(samples["unoswap v3-v5"], src_token_address="srcToken", pools="transform(pools, x -> bytearray_to_uint256(x))"),
                "uniswapV3Swap":             dict(samples["unoswap v3-v5"], unwrap_mask="bytearray_to_uint256(rpad(0x20, 32, 0x00))"),
                "uniswapV3SwapTo":           dict(samples["unoswap v3-v5"], dst_receiver="recipient", unwrap_mask="bytearray_to_uint256(rpad(0x20, 32, 0x00))"),
                "uniswapV3SwapToWithPermit": dict(samples["unoswap v3-v5"], dst_receiver="recipient", unwrap_mask="bytearray_to_uint256(rpad(0x20, 32, 0x00))"),
            },
        },
        "AggregationRouterV5": {
            "version": "5",
            "blockchains": ["ethereum", "bnb", "polygon", "arbitrum", "optimism", "avalanche_c", "gnosis", "fantom", "base", "zksync"],
            "start": "2022-11-04",
            "methods": {
                "swap":                      samples["swap"],
                "clipperSwap":               samples["clipper"],
                "clipperSwapTo":             dict(samples["clipper"], dst_receiver="recipient"),
                "clipperSwapToWithPermit":   dict(samples["clipper"], dst_receiver="recipient"),
                "unoswap":                   dict(samples["unoswap v3-v5"], src_token_address="srcToken"),
                "unoswapTo":                 dict(samples["unoswap v3-v5"], src_token_address="srcToken", dst_receiver="recipient"),
                "unoswapToWithPermit":       dict(samples["unoswap v3-v5"], src_token_address="srcToken", dst_receiver="recipient"),
                "uniswapV3Swap":             dict(samples["unoswap v3-v5"], unwrap_mask="bytearray_to_uint256(rpad(0x20, 32, 0x00))"),
                "uniswapV3SwapTo":           dict(samples["unoswap v3-v5"], dst_receiver="recipient", unwrap_mask="bytearray_to_uint256(rpad(0x20, 32, 0x00))"),
                "uniswapV3SwapToWithPermit": dict(samples["unoswap v3-v5"], dst_receiver="recipient", unwrap_mask="bytearray_to_uint256(rpad(0x20, 32, 0x00))"),
            },
        },
        "AggregationRouterV6": {
            "version": "6",
            "blockchains": ["ethereum", "bnb", "polygon", "arbitrum", "optimism", "avalanche_c", "gnosis", "fantom", "base", "zksync", "linea", "sonic", "unichain"],
            "start": "2024-02-12",
            "methods": {
                "swap":          dict(samples["swap"], src_token_amount="output_spentAmount"),
                "clipperSwap":   dict(samples["clipper"], src_token_address="substr(cast(srcToken as varbinary), 13)", blockchains=["ethereum","bnb","polygon","arbitrum","optimism","avalanche_c","gnosis","fantom","base"]),
                "clipperSwapTo": dict(samples["clipper"], src_token_address="substr(cast(srcToken as varbinary), 13)", blockchains=["ethereum","bnb","polygon","arbitrum","optimism","avalanche_c","gnosis","fantom","base"], dst_receiver="recipient"),
                "ethUnoswap":    dict(samples["unoswap v6"], src_token_address=native, src_token_amount="call_value", pools="array[dex]"),
                "ethUnoswap2":   dict(samples["unoswap v6"], src_token_address=native, src_token_amount="call_value", pools="array[dex,dex2]"),
                "ethUnoswap3":   dict(samples["unoswap v6"], src_token_address=native, src_token_amount="call_value", pools="array[dex,dex2,dex3]"),
                "ethUnoswapTo":  dict(samples["unoswap v6"], src_token_address=native, src_token_amount="call_value", dst_receiver='substr(cast("to" as varbinary), 13)', pools="array[dex]"),
                "ethUnoswapTo2": dict(samples["unoswap v6"], src_token_address=native, src_token_amount="call_value", dst_receiver='substr(cast("to" as varbinary), 13)', pools="array[dex,dex2]"),
                "ethUnoswapTo3": dict(samples["unoswap v6"], src_token_address=native, src_token_amount="call_value", dst_receiver='substr(cast("to" as varbinary), 13)', pools="array[dex,dex2,dex3]"),
                "unoswap":       dict(samples["unoswap v6"], pools="array[dex]"),
                "unoswap2":      dict(samples["unoswap v6"], pools="array[dex,dex2]"),
                "unoswap3":      dict(samples["unoswap v6"], pools="array[dex,dex2,dex3]"),
                "unoswapTo":     dict(samples["unoswap v6"], dst_receiver='substr(cast("to" as varbinary), 13)', pools="array[dex]"),
                "unoswapTo2":    dict(samples["unoswap v6"], dst_receiver='substr(cast("to" as varbinary), 13)', pools="array[dex,dex2]"),
                "unoswapTo3":    dict(samples["unoswap v6"], dst_receiver='substr(cast("to" as varbinary), 13)', pools="array[dex,dex2,dex3]"),
            },
        },
    }
%}

{{ return(contracts) }}

{% endmacro %}