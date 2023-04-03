#!/usr/bin/env python3

import os
import argparse
import pandas as pd
import logging
from datetime import timedelta
from sqlalchemy import create_engine

SQL = """
 WITH time_range(st, et) AS (
    VALUES ('{st}'::timestamp, '{et}'::timestamp)
),
prd AS (
    SELECT
        *
    FROM
        {chain}.traces
    WHERE
        1 = 1
        AND block_timestamp >= (SELECT st FROM time_range)
        AND block_timestamp <  (SELECT et FROM time_range)
        AND trace_type <> 'reward'
),
dev AS (
    SELECT
        *
    FROM
        {chain}_dev.traces
    WHERE
        1 = 1
        AND block_timestamp >= (SELECT st FROM time_range)
        AND block_timestamp <  (SELECT et FROM time_range)
        AND trace_type <> 'reward'
),
pdev AS (
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
        CASE a.trace_type WHEN 'create2' THEN 'create'
            ELSE COALESCE(a.trace_type, '-trace-type')
        END AS a_trace_type,
        COALESCE(b.trace_type, '-trace-type') AS b_trace_type,
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
        prd a
    LEFT JOIN dev b ON a.block_timestamp = b.block_timestamp
        AND a.blknum = b.blknum
        AND a.txhash = b.txhash
        AND a.txpos = b.txpos
        AND a.trace_address = b.trace_address
),
diff AS (
    SELECT
        *
    FROM
        pdev
    WHERE
        a_blknum <> b_blknum
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
"""


def main():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description="Trace differ(compares the {chain}.traces with {chain}_dev.traces)",
    )
    parser.add_argument(
        "--debug", action="store_true", default=False, help="Enable debug output"
    )
    parser.add_argument(
        "--chain",
        default="ethereum",
        help="Check which chain",
    )
    parser.add_argument(
        "--db-url",
        required=True,
        help="PostgreSQL URL",
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
    args = parser.parse_args()

    is_debug_mode = args.debug is True
    logging.basicConfig(
        format="[%(asctime)s] - %(levelname)s - %(message)s",
        level=logging.DEBUG if is_debug_mode else logging.INFO,
    )
    chain = args.chain
    output = args.output

    os.makedirs(output, exist_ok=True)

    engine = create_engine(args.db_url)

    for st in pd.date_range(
        args.start_timestamp, args.end_timestamp, freq="1H", inclusive="left"
    ):
        et = st + timedelta(hours=1)
        sql = SQL.format(st=str(st), et=str(et), chain=chain)
        df = pd.read_sql(sql, con=engine)
        logging.info(f"check with timestamp: [{st}, {et}) got #{len(df)}")
        if len(df) > 0:
            print(
                df.groupby(["reason"])["a_txhash"]
                .count()
                .reset_index()
                .rename(columns={"a_txhash": "count"})  # type: ignore
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
