CREATE SCHEMA IF NOT EXISTS {{ chain }};

CREATE TABLE IF NOT EXISTS {{ chain }}.token_latest_balances (
    id              BIGSERIAL UNIQUE,
    address         CHAR(42) NOT NULL,
    token_address   CHAR(42) NOT NULL,
    blknum          BIGINT NOT NULL,    -- blknum used as checkpoint
    out_blocks      BIGINT,             -- sum(count(distinct blknum) where address is from_address)
    vin_blocks      BIGINT,             -- sum(count(distinct blknum) where address is to_address)
    out_txs         BIGINT,             -- count(distinct txhash) where address is from_address
    vin_txs         BIGINT,             -- count(distinct txhash) where address is to_address
    out_xfers       BIGINT,             -- count(*) where address is from_address
    vin_xfers       BIGINT,             -- count(*) where address is to_address
    out_value       NUMERIC,            -- sum(value) where address is from_address
    vin_value       NUMERIC,            -- sum(value) where address is to_address
    out_1th_st      INTEGER,            -- the first timestamp when the address is from_address
    vin_1th_st      INTEGER,            -- the first timestamp when the address is to_address
    out_nth_st      INTEGER,            -- the  last timestamp when the address is from_address
    vin_nth_st      INTEGER,            -- the  last timestamp when the address is from_address
    out_1th_blknum  BIGINT,             -- the first blknum when the address is from_address
    vin_1th_blknum  BIGINT,             -- the first blknum when the address is to_address
    out_nth_blknum  BIGINT,             -- the  last blknum when the address is from_address
    vin_nth_blknum  BIGINT,             -- the  last blknum when the address is from_address
    out_1th_st_day  DATE,               -- the first date when the address is from_address
    vin_1th_st_day  DATE,               -- the first date when the address is to_address
    out_nth_st_day  DATE,               -- the  last date when the address is from_address
    vin_nth_st_day  DATE,               -- the  last date when the address is from_address
    decimals        BIGINT,             -- token decimals
    value           NUMERIC NOT NULL,   -- vin_value - out_value
    balance         NUMERIC,            -- extract from json-rpc
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (address, token_address)
);

CREATE TABLE IF NOT EXISTS {{ chain }}.token_history_balances (
    id              BIGSERIAL UNIQUE,
    address         CHAR(42) NOT NULL,
    token_address   CHAR(42) NOT NULL,
    blknum          BIGINT NOT NULL,    -- blknum used as checkpoint
    out_blocks      BIGINT,             -- sum(count(distinct blknum) where address is from_address)
    vin_blocks      BIGINT,             -- sum(count(distinct blknum) where address is to_address)
    out_txs         BIGINT,             -- count(distinct txhash) where address is from_address
    vin_txs         BIGINT,             -- count(distinct txhash) where address is to_address
    out_xfers       BIGINT,             -- count(*) where address is from_address
    vin_xfers       BIGINT,             -- count(*) where address is to_address
    out_value       NUMERIC,            -- sum(value) where address is from_address
    vin_value       NUMERIC,            -- sum(value) where address is to_address
    decimals        BIGINT,             -- token decimals
    value           NUMERIC NOT NULL,   -- vin_value - out_value
    balance         NUMERIC,            -- extract from json-rpc
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (address, token_address, blknum)
);

CREATE TABLE IF NOT EXISTS {{ chain }}.latest_balances (
    id              BIGSERIAL UNIQUE,
    address         CHAR(42) NOT NULL,
    blknum          BIGINT NOT NULL,    -- blknum used as checkpoint
    out_blocks      BIGINT,             -- sum(count(distinct blknum) where address is from_address)
    vin_blocks      BIGINT,             -- sum(count(distinct blknum) where address is to_address)
    cnb_blocks      BIGINT,             -- sum(count(distinct blknum) where address is miner)
    out_txs         BIGINT,             -- count(distinct txhash) where address is from_address
    vin_txs         BIGINT,             -- count(distinct txhash) where address is to_address
    cnb_txs         BIGINT,             -- count(distinct txhash) where address is miner
    out_xfers       BIGINT,             -- count(*) where address is from_address
    vin_xfers       BIGINT,             -- count(*) where address is to_address
    cnb_xfers       BIGINT,             -- count(*) where address is miner
    out_value       NUMERIC,            -- sum(value) where address is from_address
    fee_value       NUMERIC,            -- sum(gas fee) where address is from_address
    vin_value       NUMERIC,            -- sum(value) where address is to_address
    cnb_value       NUMERIC,            -- sum(value) where address is miner
    out_1th_st      INTEGER,            -- the first timestamp when the address is from_address
    vin_1th_st      INTEGER,            -- the first timestamp when the address is to_address
    cnb_1th_st      INTEGER,            -- the first timestamp when the address is miner
    out_nth_st      INTEGER,            -- the  last timestamp when the address is from_address
    vin_nth_st      INTEGER,            -- the  last timestamp when the address is to_address
    cnb_nth_st      INTEGER,            -- the  last timestamp when the address is miner
    out_1th_blknum  BIGINT,             -- the first blknum when the address is from_address
    vin_1th_blknum  BIGINT,             -- the first blknum when the address is to_address
    cnb_1th_blknum  BIGINT,             -- the first blknum when the address is miner
    out_nth_blknum  BIGINT,             -- the  last blknum when the address is from_address
    vin_nth_blknum  BIGINT,             -- the  last blknum when the address is to_address
    cnb_nth_blknum  BIGINT,             -- the  last blknum when the address is miner
    out_1th_st_day  DATE,               -- the first date when the address is from_address
    vin_1th_st_day  DATE,               -- the first date when the address is to_address
    cnb_1th_st_day  DATE,               -- the first date when the address is miner
    out_nth_st_day  DATE,               -- the  last date when the address is from_address
    vin_nth_st_day  DATE,               -- the  last date when the address is to_address
    cnb_nth_st_day  DATE,               -- the  last date when the address is miner
    value           NUMERIC NOT NULL,   -- cnb_value + vin_value - out_value - fee_value
    balance         NUMERIC,            -- fetched from on-chain
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (address)
);

CREATE TABLE IF NOT EXISTS {{ chain }}.history_balances (
    id              BIGSERIAL UNIQUE,
    address         CHAR(42) NOT NULL,
    blknum          BIGINT NOT NULL,
    out_blocks      BIGINT,             -- sum(count(distinct blknum) when address is from_address)
    vin_blocks      BIGINT,             -- sum(count(distinct blknum) when address is to_address)
    cnb_blocks      BIGINT,             -- sum(count(distinct blknum) when address is miner)
    out_txs         BIGINT,             -- count(distinct txhash) when address is from_address
    vin_txs         BIGINT,             -- count(distinct txhash) when address is to_address
    cnb_txs         BIGINT,             -- count(distinct txhash) when address is miner
    out_xfers       BIGINT,             -- count(*) when address is from_address
    vin_xfers       BIGINT,             -- count(*) when address is to_address
    cnb_xfers       BIGINT,             -- count(*) when address is miner
    out_value       NUMERIC,            -- sum(value) when address is from_address
    fee_value       NUMERIC,            -- sum(gas fee) when address is from_address
    vin_value       NUMERIC,            -- sum(value) when address is to_address
    cnb_value       NUMERIC,            -- sum(value) when address is miner
    value           NUMERIC NOT NULL,   -- cnb_value + vin_value - out_value - fee_value
    balance         NUMERIC,            -- extract from json-rpc
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (address, blknum)
);
