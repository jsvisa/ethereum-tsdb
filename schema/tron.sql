CREATE SCHEMA IF NOT EXISTS tron;

CREATE TABLE IF NOT EXISTS tron.blocks (
    id              BIGSERIAL,
    block_timestamp TIMESTAMP,
    blknum          BIGINT NOT NULL,
    blkhash         TEXT,
    parent_hash     TEXT,
    txs_root        TEXT,
    miner           TEXT,
    version         INTEGER,
    tx_count        INTEGER,
    extra_data      TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id, block_timestamp)
);
CREATE INDEX IF NOT EXISTS tron_blocks_blknum_idx ON tron.blocks(blknum);
SELECT create_hypertable('tron.blocks', 'block_timestamp', chunk_time_interval => INTERVAL '7 days');
ALTER TABLE tron.blocks SET(timescaledb.compress, timescaledb.compress_segmentby = 'blknum', timescaledb.compress_orderby = 'id, block_timestamp asc');
SELECT add_compression_policy('tron.blocks', INTERVAL '10 days');

CREATE TABLE IF NOT EXISTS tron.txs (
    id              BIGSERIAL,
    block_timestamp TIMESTAMP,
    blknum          BIGINT,
    txhash          TEXT NOT NULL,
    txpos           BIGINT,
    tx_type         TEXT,
    from_address    TEXT,
    to_address      TEXT,
    value           NUMERIC,
    input           TEXT,
    token           TEXT,
    amount          NUMERIC,
    votes           TEXT,
    frozen_days     BIGINT,
    frozen_balance  NUMERIC,
    account_name    TEXT,
    token_name      TEXT,
    total_supply    NUMERIC,
    trx_num         NUMERIC,
    start_time      BIGINT,
    end_time        BIGINT,
    error           TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id, block_timestamp)
);
CREATE INDEX IF NOT EXISTS tron_txs_blknum_idx ON tron.txs(blknum);
CREATE INDEX IF NOT EXISTS tron_txs_txhash_idx ON tron.txs(txhash);
SELECT create_hypertable('tron.txs', 'block_timestamp', chunk_time_interval => INTERVAL '7 days');
ALTER TABLE tron.txs SET(timescaledb.compress, timescaledb.compress_segmentby = 'blknum', timescaledb.compress_orderby = 'id, block_timestamp asc');
SELECT add_compression_policy('tron.txs', INTERVAL '5 days');
SELECT add_retention_policy('tron.txs', INTERVAL '32 days');

CREATE TABLE IF NOT EXISTS tron.logs (
    id              BIGSERIAL,
    block_timestamp TIMESTAMP,
    blknum          BIGINT,
    txhash          TEXT,
    txpos           BIGINT,
    logpos          INTEGER,
    address         TEXT,
    n_topics        INTEGER,
    topics          TEXT,
    data            TEXT,
    topics_0        TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id, block_timestamp)
);
CREATE INDEX IF NOT EXISTS tron_logs_blknum_idx ON tron.logs(blknum);
SELECT create_hypertable('tron.logs', 'block_timestamp', chunk_time_interval => INTERVAL '7 days');
ALTER TABLE tron.logs SET(timescaledb.compress, timescaledb.compress_segmentby = 'blknum', timescaledb.compress_orderby = 'id, block_timestamp asc');
SELECT add_compression_policy('tron.logs', INTERVAL '5 days');
SELECT add_retention_policy('tron.logs', INTERVAL '32 days');

CREATE TABLE IF NOT EXISTS tron.tokens (
    id                          BIGSERIAL,
    block_timestamp             TIMESTAMP,
    blknum                      BIGINT,     -- The block number
    txhash                      VARCHAR(66),   -- Hash of the transaction
    txpos                       BIGINT,     -- Integer of the transactions index position in the block
    trace_address               TEXT,       -- The trace address, extract from trace.trace_address
    address                     VARCHAR(42) NOT NULL,       -- The address of the ERC20 token
    symbol                      TEXT,       -- The symbol of the ERC20 token
    name                        TEXT,       -- The name of the ERC20 token
    decimals                    INTEGER,    -- The number of decimals the token uses
    total_supply                NUMERIC,    -- The total token supply
    is_erc20                    BOOLEAN,    -- Whether this token is ERC20
    is_erc721                   BOOLEAN,    -- Whether this token is ERC721
    is_erc1155                  BOOLEAN,    -- Whether this token is ERC1155
    source                      TEXT DEFAULT 'contract', -- Where this token comes from
    is_proxy                    BOOLEAN,    -- Whether this token is EIP1947/EIP897 or other proxy
    upstream                    TEXT,       -- The upstream address of this token
    created_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (address) -- Address maybe reused(via trace.trace_type = create2)
);

CREATE TABLE IF NOT EXISTS tron.token_xfers (
    id              BIGSERIAL,
    block_timestamp TIMESTAMP,
    blknum          BIGINT,     -- The block number
    txhash          TEXT,       -- Hash of the transaction
    txpos           BIGINT,     -- Integer of the transactions index position in the block
    logpos          BIGINT,     -- Log index in the transaction receipt
    token_address   TEXT,       -- ERC20 token address
    from_address    TEXT,       -- Address of the sender
    to_address      TEXT,       -- Address of the receiver
    value           NUMERIC,     -- Amount of tokens transferred (ERC20) / id of the token transferred (ERC721)
    name            TEXT,       -- Token name, extract from tron.tokens
    symbol          TEXT,       -- Token symol, extract from tron.tokens
    decimals        BIGINT,     -- Token decimals, extract from tron.tokens
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id, block_timestamp)
);
CREATE INDEX IF NOT EXISTS tron_token_xfers_blknum_idx ON tron.token_xfers(blknum);
-- CREATE INDEX IF NOT EXISTS tron_token_xfers_txhash_idx ON tron.token_xfers(txhash);
SELECT create_hypertable('tron.token_xfers', 'block_timestamp', chunk_time_interval => INTERVAL '7 days');
ALTER TABLE tron.token_xfers SET(timescaledb.compress, timescaledb.compress_segmentby = 'blknum', timescaledb.compress_orderby = 'id, block_timestamp asc');
SELECT add_compression_policy('tron.token_xfers', INTERVAL '5 days');
SELECT add_retention_policy('tron.token_xfers', INTERVAL '32 days');
