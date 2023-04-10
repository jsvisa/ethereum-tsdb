CREATE SCHEMA IF NOT EXISTS bitcoin;

-- see more from https://en.bitcoin.it/wiki/Block
CREATE TABLE IF NOT EXISTS bitcoin.blocks (
    id              BIGSERIAL,
    block_timestamp TIMESTAMP,
    _st             INTEGER NOT NULL,
    _st_day         DATE NOT NULL,
    blknum          BIGINT NOT NULL,
    blkhash         CHAR(64) NOT NULL,
    tx_count        INTEGER NOT NULL DEFAULT 1,
    blk_size        BIGINT,
    stripped_size   BIGINT,
    weight          BIGINT,
    version         BIGINT,
    nonce           VARCHAR(1024) DEFAULT NULL,
    bits            VARCHAR(1024) DEFAULT NULL,
    difficulty      NUMERIC,
    coinbase_param  TEXT DEFAULT NULL,
    item_id         TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (item_id, block_timestamp)
);
CREATE INDEX IF NOT EXISTS bitcoin_blocks_blknum_idx ON bitcoin.blocks(blknum);
SELECT create_hypertable('bitcoin.blocks', 'block_timestamp', if_not_exists => true);
ALTER TABLE bitcoin.blocks SET(timescaledb.compress, timescaledb.compress_segmentby = 'blknum', timescaledb.compress_orderby = 'item_id, block_timestamp asc');
SELECT add_compression_policy('bitcoin.blocks', INTERVAL '30 days');

CREATE TABLE IF NOT EXISTS bitcoin.txs (
    id              BIGSERIAL,
    block_timestamp TIMESTAMP,
    _st             INTEGER,
    _st_day         DATE,
    blknum          BIGINT,
    txhash          CHAR(64),
    txpos           INTEGER,
    is_coinbase     BOOLEAN DEFAULT false,
    input_count     INTEGER,  -- length(tx["inputs"])
    input_value     BIGINT,   -- sum of all vin's value
    output_count    INTEGER,  -- length("tx["outputs"]) of this or the previous tx
    output_value    BIGINT,   -- sum of all vout's value
    size            BIGINT,
    vsize           BIGINT,
    weight          BIGINT,
    version         BIGINT,  -- such as 2164260863, should be in bigint
    locktime        BIGINT,
    hex             TEXT,
    item_id         TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (item_id, block_timestamp)
);
CREATE INDEX IF NOT EXISTS bitcoin_txs_blknum_idx ON bitcoin.txs(blknum);
SELECT create_hypertable('bitcoin.txs', 'block_timestamp', if_not_exists => true);
ALTER TABLE bitcoin.txs SET(timescaledb.compress, timescaledb.compress_segmentby = 'blknum', timescaledb.compress_orderby = 'item_id, block_timestamp asc');
SELECT add_compression_policy('bitcoin.txs', INTERVAL '30 days');

CREATE TABLE IF NOT EXISTS bitcoin.traces (
    id              BIGSERIAL,
    block_timestamp TIMESTAMP,
    _st             INTEGER NOT NULL,
    _st_day         DATE NOT NULL,
    blknum          BIGINT NOT NULL,
    txhash          CHAR(64) NOT NULL,
    txpos           SMALLINT NOT NULL,
    is_coinbase     BOOLEAN DEFAULT false,
    is_in           BOOLEAN DEFAULT false,
    pxhash          CHAR(64) DEFAULT NULL,        -- the previous txhash if input, else null
    tx_in_value     BIGINT DEFAULT 0 NOT NULL,   -- sum of all vin's value
    tx_out_value    BIGINT DEFAULT 0 NOT NULL,   -- sum of all vout's value
    vin_seq         BIGINT DEFAULT 0,   -- sequence only available in input
    vin_idx         INTEGER DEFAULT 0,  -- the index of this vin in tx["inputs"]
    vin_cnt         INTEGER DEFAULT 0,  -- length(tx["inputs"])
    vin_type        VARCHAR(1024) DEFAULT NULL,     --
    vout_idx        INTEGER DEFAULT 0,  -- the index of this or the previous one in tx["outputs"]
    vout_cnt        INTEGER DEFAULT 0,  -- length("tx["outputs"]) of this or the previous tx
    vout_type       VARCHAR(1024) DEFAULT NULL,     -- pubkeyhash(1xxx), scripthash(3xxx), notstandard,
    address         VARCHAR(1024) DEFAULT '',     -- if output then ';'.join(tx["outputs"]["addresses"]); else NULL
    value           BIGINT DEFAULT 0 NOT NULL, -- value in Satashi if output, else 0;
    script_hex      TEXT,
    script_asm      TEXT,
    req_sigs        INTEGER,
    txinwitness     TEXT,     --  ';'.join(tx[scriptSig/scriptPubkey][txinwitness])
    item_id         TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- vout maybe a multisig address
    -- the multisig address's behavior is the same as pubkeyhash's, the UTXO should be spent in one Tx
    -- eg https://btc.com/fc75da255af43ab69f5f268e578a584d49a511ff5228eedbefe24e732307198b as multisign vin
    -- eg https://btc.com/217ea41e7eb23f4fb52310c4b624ebbe5a05c02e022cac85ebc90540ab94d558 as multisign vout
    PRIMARY KEY (item_id, block_timestamp)
);
CREATE INDEX IF NOT EXISTS bitcoin_traces_blknum_idx ON bitcoin.traces(blknum);
CREATE INDEX IF NOT EXISTS bitcoin_traces_txhash_idx ON bitcoin.traces(txhash);
CREATE INDEX IF NOT EXISTS bitcoin_traces_pxhash_idx ON bitcoin.traces(pxhash);
CREATE INDEX IF NOT EXISTS bitcoin_traces_addr_st_idx ON bitcoin.traces(address, block_timestamp);
SELECT create_hypertable('bitcoin.traces', 'block_timestamp', if_not_exists => true);
ALTER TABLE bitcoin.traces SET(timescaledb.compress, timescaledb.compress_segmentby = 'blknum', timescaledb.compress_orderby = 'item_id, block_timestamp asc');
SELECT add_compression_policy('bitcoin.traces', INTERVAL '30 days');

-- in PostgreSQL
CREATE TABLE IF NOT EXISTS bitcoin.latest_balances (
    id              BIGSERIAL,
    address         VARCHAR(1024) NOT NULL,
    blknum          BIGINT NOT NULL,
    out_blocks      BIGINT,     -- sum(count(distinct blknum) where address is from_address)
    vin_blocks      BIGINT,     -- sum(count(distinct blknum) where address is to_address)
    cnb_blocks      BIGINT,     -- sum(count(distinct blknum) where address is to_address)
    out_txs         BIGINT,     -- count(distinct txhash) where address is from_address
    vin_txs         BIGINT,     -- count(distinct txhash) where address is to_address
    cnb_txs         BIGINT,     -- sum(count(distinct blknum) where address is to_address)
    out_xfers       BIGINT,     -- count(*) where address is from_address
    vin_xfers       BIGINT,     -- count(*) where address is to_address
    cnb_xfers       BIGINT,     -- count(*) where address is to_address
    out_value       NUMERIC,    -- sum(value) where address is from_address
    vin_value       NUMERIC,    -- sum(value) where address is to_address
    cnb_value       NUMERIC,    -- sum(value) where address is to_address
    out_1th_st      INTEGER,
    vin_1th_st      INTEGER,
    cnb_1th_st      INTEGER,
    out_nth_st      INTEGER,
    vin_nth_st      INTEGER,
    cnb_nth_st      INTEGER,
    out_1th_blknum  BIGINT,
    vin_1th_blknum  BIGINT,
    cnb_1th_blknum  BIGINT,
    out_nth_blknum  BIGINT,
    vin_nth_blknum  BIGINT,
    cnb_nth_blknum  BIGINT,
    out_1th_st_day  DATE,
    vin_1th_st_day  DATE,
    cnb_1th_st_day  DATE,
    out_nth_st_day  DATE,
    vin_nth_st_day  DATE,
    cnb_nth_st_day  DATE,
    value           BIGINT, -- cnb_value + vin_value - out_value
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY(address)
);
