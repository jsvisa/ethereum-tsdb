#!/usr/bin/env python3

# flake8: noqa

import os
import argparse
import pandas as pd
import logging
from time import time
from jinja2 import Template
from datetime import timedelta
from sqlalchemy import create_engine, text

import psycopg2
import psycopg2.extensions
import psycopg2.extras

# set wait timeout https://github.com/psycopg/psycopg2/issues/333#issuecomment-543016895
psycopg2.extensions.set_wait_callback(psycopg2.extras.wait_select)


BLOCK_SQL = Template(
    """
WITH time_range(st, et) AS (
    VALUES ('{{st}}'::timestamp, '{{et}}'::timestamp)
),
aaa AS (
    SELECT
        *
    FROM
        {{aaa}}.blocks
    WHERE
        true
        AND block_timestamp >= (SELECT st FROM time_range)
        AND block_timestamp <  (SELECT et FROM time_range)
),
bbb AS (
    SELECT
        *
    FROM
        {{bbb}}.blocks
    WHERE
        true
        AND block_timestamp >= (SELECT st FROM time_range)
        AND block_timestamp <  (SELECT et FROM time_range)
),
ab AS (
    SELECT
        a.block_timestamp AS a_block_timestamp,
        b.block_timestamp AS b_block_timestamp,
        a.blknum AS a_blknum,
        b.blknum AS b_blknum,
        a.blkhash AS a_blkhash,
        b.blkhash AS b_blkhash,
        COALESCE(a.parent_hash, '-parent-hash') AS a_parent_hash,
        COALESCE(b.parent_hash, '-parent-hash') AS b_parent_hash,
        COALESCE(a.nonce, '-nonce') AS a_nonce,
        COALESCE(b.nonce, '-nonce') AS b_nonce,
        COALESCE(a.sha3_uncles, '-sha3_uncles') AS a_sha3_uncles,
        COALESCE(b.sha3_uncles, '-sha3_uncles') AS b_sha3_uncles,
        COALESCE(a.logs_bloom, '-logs_bloom') AS a_logs_bloom,
        COALESCE(b.logs_bloom, '-logs_bloom') AS b_logs_bloom,
        COALESCE(a.txs_root, '-txs_root') AS a_txs_root,
        COALESCE(b.txs_root, '-txs_root') AS b_txs_root,
        COALESCE(a.state_root, '-state_root') AS a_state_root,
        COALESCE(b.state_root, '-state_root') AS b_state_root,
        COALESCE(a.receipts_root, '-receipts_root') AS a_receipts_root,
        COALESCE(b.receipts_root, '-receipts_root') AS b_receipts_root,
        COALESCE(a.miner, '-miner') AS a_miner,
        COALESCE(b.miner, '-miner') AS b_miner,
        COALESCE(a.difficulty, -1) AS a_difficulty,
        COALESCE(b.difficulty, -1) AS b_difficulty,
        COALESCE(a.total_difficulty, -1) AS a_total_difficulty,
        COALESCE(b.total_difficulty, -1) AS b_total_difficulty,
        COALESCE(a.blk_size, -1) AS a_blk_size,
        COALESCE(b.blk_size, -1) AS b_blk_size,
        COALESCE(a.extra_data, '-extra_data') AS a_extra_data,
        COALESCE(b.extra_data, '-extra_data') AS b_extra_data,
        COALESCE(a.gas_limit, -1) AS a_gas_limit,
        COALESCE(b.gas_limit, -1) AS b_gas_limit,
        COALESCE(a.gas_used, -1) AS a_gas_used,
        COALESCE(b.gas_used, -1) AS b_gas_used,
        COALESCE(a.tx_count, -1) AS a_tx_count,
        COALESCE(b.tx_count, -1) AS b_tx_count,
        COALESCE(a.base_fee_per_gas, -1) AS a_base_fee_per_gas,
        COALESCE(b.base_fee_per_gas, -1) AS b_base_fee_per_gas,
        COALESCE(a.uncle_count, -1) AS a_uncle_count,
        COALESCE(b.uncle_count, -1) AS b_uncle_count,
        COALESCE(a.uncle0_hash, '-uncle0_hash') AS a_uncle0_hash,
        COALESCE(b.uncle0_hash, '-uncle0_hash') AS b_uncle0_hash,
        COALESCE(a.uncle1_hash, '-uncle1_hash') AS a_uncle1_hash,
        COALESCE(b.uncle1_hash, '-uncle1_hash') AS b_uncle1_hash
    FROM
        aaa a
    LEFT JOIN bbb b ON true
        AND a.block_timestamp = b.block_timestamp
        AND a.blknum = b.blknum
),
same AS (
    SELECT
        *
    FROM
        ab
    WHERE
        true
        AND a_blknum = b_blknum
        AND a_blkhash = b_blkhash
        AND a_parent_hash = b_parent_hash
        AND a_nonce = b_nonce
        AND a_sha3_uncles = b_sha3_uncles
        AND a_logs_bloom = b_logs_bloom
        AND a_txs_root = b_txs_root
        AND a_state_root = b_state_root
        AND a_receipts_root = b_receipts_root
        AND a_miner = b_miner
        AND a_difficulty = b_difficulty
        AND a_total_difficulty = b_total_difficulty
        AND a_blk_size = b_blk_size
        AND a_extra_data = b_extra_data
        AND a_gas_limit = b_gas_limit
        AND a_gas_used = b_gas_used
        AND a_tx_count = b_tx_count
        AND a_base_fee_per_gas = b_base_fee_per_gas
        AND a_uncle_count = b_uncle_count
        AND a_uncle0_hash = b_uncle0_hash
        AND a_uncle1_hash = b_uncle1_hash
),
diff AS (
    SELECT
        *
    FROM
        ab
    WHERE
        false
        OR a_blknum <> b_blknum
        OR a_blkhash <> b_blkhash
        OR a_parent_hash <> b_parent_hash
        OR a_nonce <> b_nonce
        OR a_sha3_uncles <> b_sha3_uncles
        OR a_logs_bloom <> b_logs_bloom
        OR a_txs_root <> b_txs_root
        OR a_state_root <> b_state_root
        OR a_receipts_root <> b_receipts_root
        OR a_miner <> b_miner
        OR a_difficulty <> b_difficulty
        OR a_total_difficulty <> b_total_difficulty
        OR a_blk_size <> b_blk_size
        OR a_extra_data <> b_extra_data
        OR a_gas_limit <> b_gas_limit
        OR a_gas_used <> b_gas_used
        OR a_tx_count <> b_tx_count
        OR a_base_fee_per_gas <> b_base_fee_per_gas
        OR a_uncle_count <> b_uncle_count
        OR a_uncle0_hash <> b_uncle0_hash
        OR a_uncle1_hash <> b_uncle1_hash
)
{% if summary %}
SELECT
    A.count AS same, B.count AS diff
FROM (SELECT count(*) FROM same) A JOIN (SELECT count(*) FROM diff) B ON true
{% else %}
SELECT
    *,
    CASE
        WHEN a_blknum <> b_blknum               THEN 'blknum'
        WHEN a_blkhash <> b_blkhash             THEN 'blkhash'
        WHEN a_parent_hash <> b_parent_hash     THEN 'parent_hash'
        WHEN a_nonce <> b_nonce                 THEN 'nonce'
        WHEN a_sha3_uncles <> b_sha3_uncles     THEN 'sha3_uncles'
        WHEN a_txs_root <> b_txs_root           THEN 'txs_root'
        WHEN a_state_root <> b_state_root       THEN 'state_root'
        WHEN a_receipts_root <> b_receipts_root THEN 'receipts_root'
        WHEN a_miner <> b_miner                 THEN 'miner'
        WHEN a_difficulty <> b_difficulty       THEN 'difficulty'
        WHEN a_total_difficulty <> b_total_difficulty THEN 'total_difficulty'
        WHEN a_blk_size <> b_blk_size           THEN 'blk_size'
        WHEN a_extra_data <> b_extra_data       THEN 'extra_data'
        WHEN a_gas_limit <> b_gas_limit         THEN 'gas_limit'
        WHEN a_gas_used <> b_gas_used           THEN 'gas_used'
        WHEN a_tx_count <> b_tx_count           THEN 'tx_count'
        WHEN a_base_fee_per_gas <> b_base_fee_per_gas THEN 'base_fee_per_gas'
        WHEN a_uncle_count <> b_uncle_count     THEN 'uncle_count'
        WHEN a_uncle0_hash <> b_uncle0_hash     THEN 'uncle0_hash'
        WHEN a_uncle1_hash <> b_uncle1_hash     THEN 'uncle1_hash'
        ELSE 'unknown'
    END AS reason
FROM
    diff
LIMIT 10000
{% endif %}
"""
)

TRANSACTION_SQL = Template(
    """
WITH time_range(st, et) AS (
    VALUES ('{{st}}'::timestamp, '{{et}}'::timestamp)
),
aaa AS (
    SELECT
        *
    FROM
        {{aaa}}.txs
    WHERE
        true
        AND block_timestamp >= (SELECT st FROM time_range)
        AND block_timestamp <  (SELECT et FROM time_range)
),
bbb AS (
    SELECT
        *
    FROM
        {{bbb}}.txs
    WHERE
        true
        AND block_timestamp >= (SELECT st FROM time_range)
        AND block_timestamp <  (SELECT et FROM time_range)
),
ab AS (
    SELECT
        a.block_timestamp AS a_block_timestamp,
        b.block_timestamp AS b_block_timestamp,
        a.blknum AS a_blknum,
        b.blknum AS b_blknum,
        a.txhash AS a_txhash,
        b.txhash AS b_txhash,
        a.txpos AS a_txpos,
        b.txpos AS b_txpos,
        a.nonce AS a_nonce,
        b.nonce AS b_nonce,
        COALESCE(a.from_address, '-from-address') AS a_from_address,
        COALESCE(b.from_address, '-from-address') AS b_from_address,
        COALESCE(a.to_address, '-to-address') AS a_to_address,
        COALESCE(b.to_address, '-to-address') AS b_to_address,
        COALESCE(a.value, -1) AS a_value,
        COALESCE(b.value, -1) AS b_value,
        COALESCE(a.gas, -1) AS a_gas,
        COALESCE(b.gas, -1) AS b_gas,
        COALESCE(a.gas_price, -1) AS a_gas_price,
        COALESCE(b.gas_price, -1) AS b_gas_price,
        COALESCE(a.input, '-input') AS a_input,
        COALESCE(b.input, '-input') AS b_input,
        COALESCE(a.max_fee_per_gas, -1) AS a_max_fee_per_gas,
        COALESCE(b.max_fee_per_gas, -1) AS b_max_fee_per_gas,
        COALESCE(a.max_priority_fee_per_gas, -1) AS a_max_priority_fee_per_gas,
        COALESCE(b.max_priority_fee_per_gas, -1) AS b_max_priority_fee_per_gas,
        COALESCE(a.tx_type, -1) AS a_tx_type,
        COALESCE(b.tx_type, -1) AS b_tx_type,
        COALESCE(a.receipt_cumulative_gas_used, -1) AS a_receipt_cumulative_gas_used,
        COALESCE(b.receipt_cumulative_gas_used, -1) AS b_receipt_cumulative_gas_used,
        COALESCE(a.receipt_gas_used, -1) AS a_receipt_gas_used,
        COALESCE(b.receipt_gas_used, -1) AS b_receipt_gas_used,
        COALESCE(a.receipt_contract_address, '-receipt_contract_address') AS a_receipt_contract_address,
        COALESCE(b.receipt_contract_address, '-receipt_contract_address') AS b_receipt_contract_address,
        COALESCE(a.receipt_root, '-receipt_root') AS a_receipt_root,
        COALESCE(b.receipt_root, '-receipt_root') AS b_receipt_root,
        COALESCE(a.receipt_status, -1) AS a_receipt_status,
        COALESCE(b.receipt_status, -1) AS b_receipt_status,
        COALESCE(a.receipt_effective_gas_price, -1) AS a_receipt_effective_gas_price,
        COALESCE(b.receipt_effective_gas_price, -1) AS b_receipt_effective_gas_price,
        COALESCE(a.receipt_log_count, -1) AS a_receipt_log_count,
        COALESCE(b.receipt_log_count, -1) AS b_receipt_log_count
    FROM
        aaa a
    LEFT JOIN bbb b ON true
        AND a.block_timestamp = b.block_timestamp
        AND a.blknum = b.blknum
        AND a.txhash = b.txhash
        AND a.txpos = b.txpos
),
same AS (
    SELECT
        *
    FROM
        ab
    WHERE
        true
        AND a_blknum = b_blknum
        AND a_txhash = b_txhash
        AND a_txpos = b_txpos
        AND a_nonce = b_nonce
        AND a_from_address = b_from_address
        AND a_to_address = b_to_address
        AND a_value = b_value
        AND a_gas = b_gas
        AND a_gas_price = b_gas_price
        AND a_input = b_input
        AND a_max_fee_per_gas = b_max_fee_per_gas
        AND a_max_priority_fee_per_gas = b_max_priority_fee_per_gas
        AND a_tx_type = b_tx_type
        AND a_receipt_cumulative_gas_used = b_receipt_cumulative_gas_used
        AND a_receipt_gas_used = b_receipt_gas_used
        AND a_receipt_contract_address = b_receipt_contract_address
        AND a_receipt_root = b_receipt_root
        AND a_receipt_status = b_receipt_status
        AND a_receipt_effective_gas_price = b_receipt_effective_gas_price
        AND a_receipt_log_count = b_receipt_log_count
),
diff AS (
    SELECT
        *
    FROM
        ab
    WHERE
        false
        OR a_blknum <> b_blknum
        OR a_txhash <> b_txhash
        OR a_txpos <> b_txpos
        OR a_nonce <> b_nonce
        OR a_from_address <> b_from_address
        OR a_to_address <> b_to_address
        OR a_value <> b_value
        OR a_gas <> b_gas
        OR a_gas_price <> b_gas_price
        OR a_input <> b_input
        OR a_max_fee_per_gas <> b_max_fee_per_gas
        OR a_max_priority_fee_per_gas <> b_max_priority_fee_per_gas
        OR a_tx_type <> b_tx_type
        OR a_receipt_cumulative_gas_used <> b_receipt_cumulative_gas_used
        OR a_receipt_gas_used <> b_receipt_gas_used
        OR a_receipt_contract_address <> b_receipt_contract_address
        OR a_receipt_root <> b_receipt_root
        OR a_receipt_status <> b_receipt_status
        OR a_receipt_effective_gas_price <> b_receipt_effective_gas_price
        OR a_receipt_log_count <> b_receipt_log_count
)
{% if summary %}
SELECT
    A.count AS same, B.count AS diff
FROM (SELECT count(*) FROM same) A JOIN (SELECT count(*) FROM diff) B ON true
{% else %}
SELECT
    *,
    CASE
        WHEN a_blknum <> b_blknum               THEN 'blknum'
        WHEN a_txhash <> b_txhash               THEN 'txhash'
        WHEN a_txpos <> b_txpos                 THEN 'txpos'
        WHEN a_nonce <> b_nonce                 THEN 'nonce'
        WHEN a_from_address <> b_from_address   THEN 'from_address'
        WHEN a_to_address <> b_to_address       THEN 'to_address'
        WHEN a_value <> b_value                 THEN 'value'
        WHEN a_gas <> b_gas                     THEN 'gas'
        WHEN a_gas_price <> b_gas_price         THEN 'gas_price'
        WHEN a_input <> b_input                 THEN 'input'
        WHEN a_max_fee_per_gas <> b_max_fee_per_gas                     THEN 'max_fee_per_gas'
        WHEN a_max_priority_fee_per_gas <> b_max_priority_fee_per_gas   THEN 'max_priority_fee_per_gas'
        WHEN a_tx_type <> b_tx_type             THEN 'tx_type'
        WHEN a_receipt_cumulative_gas_used <> b_receipt_cumulative_gas_used THEN 'receipt_cumulative_gas_used'
        WHEN a_receipt_gas_used <> b_receipt_gas_used                       THEN 'receipt_gas_used'
        WHEN a_receipt_contract_address <> b_receipt_contract_address       THEN 'receipt_contract_address'
        WHEN a_receipt_root <> b_receipt_root                               THEN 'receipt_root'
        WHEN a_receipt_status <> b_receipt_status                           THEN 'receipt_status'
        WHEN a_receipt_effective_gas_price <> b_receipt_effective_gas_price THEN 'receipt_effective_gas_price'
        WHEN a_receipt_log_count <> b_receipt_log_count                     THEN 'receipt_log_count'
        ELSE 'unknown'
    END AS reason
FROM
    diff
LIMIT 10000
{% endif %}
"""
)


TRACE_SQL = Template(
    """
 WITH time_range(st, et) AS (
    VALUES ('{{st}}'::timestamp, '{{et}}'::timestamp)
),
aaa AS (
    SELECT
        *
    FROM
        {{aaa}}.traces
    WHERE
        true
        AND block_timestamp >= (SELECT st FROM time_range)
        AND block_timestamp <  (SELECT et FROM time_range)
        AND trace_type <> 'reward'
),
bbb AS (
    SELECT
        *
    FROM
        {{bbb}}.traces
    WHERE
        true
        AND block_timestamp >= (SELECT st FROM time_range)
        AND block_timestamp <  (SELECT et FROM time_range)
        AND trace_type <> 'reward'
),
ab AS (
    SELECT
        a.block_timestamp AS a_block_timestamp,
        b.block_timestamp AS b_block_timestamp,
        a.blknum AS a_blknum,
        b.blknum AS b_blknum,
        a.txhash AS a_txhash,
        b.txhash AS b_txhash,
        a.txpos AS a_txpos,
        b.txpos AS b_txpos,
        COALESCE(a.from_address, '-from-address') AS a_from_address,
        COALESCE(b.from_address, '-from-address') AS b_from_address,
        COALESCE(a.to_address, '-to-address') AS a_to_address,
        COALESCE(b.to_address, '-to-address') AS b_to_address,
        COALESCE(a.value, -1) AS a_value,
        COALESCE(b.value, -1) AS b_value,
        COALESCE(a.input, '-input') AS a_input,
        COALESCE(b.input, '-input') AS b_input,
        COALESCE(a.output, '-output') AS a_output,
        COALESCE(b.output, '-output') AS b_output,
        CASE a.trace_type WHEN 'create2' THEN 'create' ELSE COALESCE(a.trace_type, '-trace-type') END AS a_trace_type,
        CASE b.trace_type WHEN 'create2' THEN 'create' ELSE COALESCE(b.trace_type, '-trace-type') END AS b_trace_type,
        COALESCE(a.call_type, '-call-type') AS a_call_type,
        COALESCE(b.call_type, '-call-type') AS b_call_type,
        COALESCE(a.reward_type, '-reward-type') AS a_reward_type,
        COALESCE(b.reward_type, '-reward-type') AS b_reward_type,
        COALESCE(a.gas, -1) AS a_gas,
        COALESCE(b.gas, -1) AS b_gas,
        COALESCE(a.gas_used, -1) AS a_gas_used,
        COALESCE(b.gas_used, -1) AS b_gas_used,
        COALESCE(a.subtraces, -1) AS a_subtraces,
        COALESCE(b.subtraces, -1) AS b_subtraces,
        COALESCE(a.trace_address, '-[]') AS a_trace_address,
        COALESCE(b.trace_address, '-[]') AS b_trace_address,
        COALESCE(a.error, '-error') AS a_error,
        COALESCE(b.error, '-error') AS b_error,
        COALESCE(a.status, -1) AS a_status,
        COALESCE(b.status, -1) AS b_status
    FROM
        aaa a
    LEFT JOIN bbb b ON true
        AND a.block_timestamp = b.block_timestamp
        AND a.blknum = b.blknum
        AND a.txhash = b.txhash
        AND a.txpos = b.txpos
        AND a.trace_address = b.trace_address
),
same AS (
    SELECT
        *
    FROM
        ab
    WHERE
        true
        AND a_blknum = b_blknum
        AND a_txhash = b_txhash
        AND a_txpos = b_txpos
        AND a_from_address = b_from_address
        AND a_to_address = b_to_address
        AND a_value = b_value
        AND a_call_type = b_call_type
        AND a_reward_type = b_reward_type
        AND a_subtraces = b_subtraces
        AND a_trace_address = b_trace_address
        AND a_input = b_input
        AND a_gas = b_gas
        AND a_gas_used = b_gas_used
        -- AND a_error = b_error
        AND a_status = b_status
        AND a_trace_type = b_trace_type
        AND a_output = b_output
),
diff AS (
    SELECT
        *
    FROM
        ab
    WHERE
        false
        OR a_blknum <> b_blknum
        OR a_txhash <> b_txhash
        OR a_txpos <> b_txpos
        OR a_from_address <> b_from_address
        OR a_to_address <> b_to_address
        OR a_value <> b_value
        OR a_call_type <> b_call_type
        OR a_reward_type <> b_reward_type
        OR a_subtraces <> b_subtraces
        OR a_trace_address <> b_trace_address
        OR a_input <> b_input
        OR a_gas <> b_gas
        OR a_gas_used <> b_gas_used
        -- OR a_error <> b_error
        OR a_status <> b_status
        OR a_trace_type <> b_trace_type
        OR a_output <> b_output
)
{% if summary %}
SELECT
    A.count AS same, B.count AS diff
FROM (SELECT count(*) FROM same) A JOIN (SELECT count(*) FROM diff) B ON true
{% else %}
SELECT
    *,
    CASE
        WHEN a_blknum <> b_blknum               THEN 'blknum'
        WHEN a_txhash <> b_txhash               THEN 'txhash'
        WHEN a_txpos <> b_txpos                 THEN 'txpos'
        WHEN a_from_address <> b_from_address   THEN 'from_address'
        WHEN a_to_address <> b_to_address       THEN 'to_address'
        WHEN a_value <> b_value                 THEN 'value'
        WHEN a_call_type <> b_call_type         THEN 'call_type'
        WHEN a_reward_type <> b_reward_type     THEN 'reward_type'
        WHEN a_subtraces <> b_subtraces         THEN 'subtraces'
        WHEN a_trace_address <> b_trace_address THEN 'trace_address'
        WHEN a_input <> b_input                 THEN 'input'
        WHEN a_gas <> b_gas                     THEN 'gas'
        WHEN a_gas_used <> b_gas_used           THEN 'gas_used'
        WHEN a_error <> b_error                 THEN 'error'
        WHEN a_status <> b_status               THEN 'status'
        WHEN a_trace_type <> b_trace_type       THEN 'trace_type'
        WHEN a_output <> b_output               THEN 'output'
        ELSE 'unknown'
    END AS reason
FROM
    diff
LIMIT 10000
{% endif %}
"""
)

LOG_SQL = Template(
    """
WITH time_range(st, et) AS (
    VALUES ('{{st}}'::timestamp, '{{et}}'::timestamp)
),
aaa AS (
    SELECT
        *
    FROM
        {{aaa}}.logs
    WHERE
        true
        AND block_timestamp >= (SELECT st FROM time_range)
        AND block_timestamp <  (SELECT et FROM time_range)
),
bbb AS (
    SELECT
        *
    FROM
        {{bbb}}.logs
    WHERE
        true
        AND block_timestamp >= (SELECT st FROM time_range)
        AND block_timestamp <  (SELECT et FROM time_range)
),
ab AS (
    SELECT
        a.block_timestamp AS a_block_timestamp,
        b.block_timestamp AS b_block_timestamp,
        a.blknum AS a_blknum,
        b.blknum AS b_blknum,
        a.txhash AS a_txhash,
        b.txhash AS b_txhash,
        a.txpos AS a_txpos,
        b.txpos AS b_txpos,
        a.logpos AS a_logpos,
        b.logpos AS b_logpos,
        a.address AS a_address,
        b.address AS b_address,
        a.n_topics AS a_n_topics,
        b.n_topics AS b_n_topics,
        a.topics AS a_topics,
        b.topics AS b_topics,
        a.data AS a_data,
        b.data AS b_data,
        a.topics_0 AS a_topics_0,
        b.topics_0 AS b_topics_0
    FROM
        aaa a
    LEFT JOIN bbb b ON true
        AND a.block_timestamp = b.block_timestamp
        AND a.blknum = b.blknum
        AND a.txhash = b.txhash
        AND a.logpos = b.logpos
),
same AS (
    SELECT
        *
    FROM
        ab
    WHERE
        true
        AND a_blknum = b_blknum
        AND a_txhash = b_txhash
        AND a_txpos = b_txpos
        AND a_logpos = b_logpos
        AND a_address = b_address
        AND a_n_topics = b_n_topics
        AND a_topics = b_topics
        AND a_data = b_data
        AND a_topics_0 = b_topics_0
),
diff AS (
    SELECT
        *
    FROM
        ab
    WHERE
        false
        OR a_blknum <> b_blknum
        OR a_txhash <> b_txhash
        OR a_txpos <> b_txpos
        OR a_logpos <> b_logpos
        OR a_address <> b_address
        OR a_n_topics <> b_n_topics
        OR a_topics <> b_topics
        OR a_data <> b_data
        OR a_topics_0 <> b_topics_0
)
{% if summary %}
SELECT
    A.count AS same, B.count AS diff
FROM (SELECT count(*) FROM same) A JOIN (SELECT count(*) FROM diff) B ON true
{% else %}
SELECT
    *,
    CASE
        WHEN a_blknum <> b_blknum THEN 'blknum'
        WHEN a_txhash <> b_txhash THEN 'txhash'
        WHEN a_txpos <> b_txpos THEN 'txpos'
        WHEN a_logpos <> b_logpos THEN 'logpos'
        WHEN a_address <> b_address THEN 'address'
        WHEN a_n_topics <> b_n_topics THEN 'n_topics'
        WHEN a_topics <> b_topics THEN 'topics'
        WHEN a_data <> b_data THEN 'data'
        WHEN a_topics_0 <> b_topics_0 THEN 'topics_0'
        ELSE 'unknown'
    END AS reason
FROM
    diff
LIMIT 10000
{% endif %}
"""
)


TYPOS = {
    "block": BLOCK_SQL,
    "transaction": TRANSACTION_SQL,
    "trace": TRACE_SQL,
    "log": LOG_SQL,
}


def main():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description="ChainDB differ",
    )
    parser.add_argument(
        "--debug", action="store_true", default=False, help="Enable debug output"
    )
    parser.add_argument(
        "--db-url",
        required=True,
        help="PostgreSQL URL",
    )
    parser.add_argument(
        "--aaa",
        required=True,
        help="The left side of differ",
    )
    parser.add_argument(
        "--bbb",
        required=True,
        help="The right side of differ",
    )
    parser.add_argument(
        "--typo",
        required=True,
        choices=TYPOS.keys(),
        default="block",
        help="Check which typo",
    )
    parser.add_argument(
        "--output",
        default="diff",
        help="Save diff records into this output path",
    )
    parser.add_argument(
        "--start-timestamp",
        required=True,
        help="Start timestamp, format: 2023-01-02 10:00:00",
    )
    parser.add_argument(
        "--end-timestamp",
        required=True,
        help="End timestamp, format: 2023-01-02 10:00:00",
    )
    parser.add_argument(
        "--dryrun",
        action="store_true",
        default=False,
        help="Dry run only, print SQL and exit",
    )
    args = parser.parse_args()

    is_debug_mode = args.debug is True
    logging.basicConfig(
        format="[%(asctime)s] - %(levelname)s - %(message)s",
        level=logging.DEBUG if is_debug_mode else logging.INFO,
    )
    output = args.output

    os.makedirs(output, exist_ok=True)
    SQL = TYPOS[args.typo]

    engine = create_engine(args.db_url)

    for st in pd.date_range(
        args.start_timestamp, args.end_timestamp, freq="1H", inclusive="left"
    ):
        et = st + timedelta(hours=1)
        summary_sql = SQL.render(
            st=str(st), et=str(et), aaa=args.aaa, bbb=args.bbb, summary=True
        )
        detail_sql = SQL.render(
            st=str(st), et=str(et), aaa=args.aaa, bbb=args.bbb, summary=False
        )
        if args.dryrun is True:
            print(summary_sql)
            print(detail_sql)
            return

        st0 = time()
        with engine.connect() as conn:
            summary = conn.execute(text(summary_sql)).fetchone()._asdict()
        df = pd.read_sql(detail_sql, con=engine)
        st1 = time()
        logging.info(
            f"check with timestamp: [{st}, {et}) summary: {summary} "
            f"got #{len(df)} elapsed: {round(st1-st0, 2)}s"
        )
        if len(df) > 0:
            print(
                df.groupby(["reason"])["a_blknum"]
                .count()
                .reset_index()
                .rename(columns={"a_blknum": "count"})  # type: ignore
                .to_markdown()  # type: ignore
            )

            file = "{output}/{st}-{et}.csv".format(
                output=output,
                st=st.strftime("%Y%m%d%H%M%S"),
                et=et.strftime("%Y%m%d%H%M%S"),
            )
            df.to_csv(file, index=False)


if __name__ == "__main__":
    main()
