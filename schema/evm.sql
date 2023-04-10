CREATE SCHEMA IF NOT EXISTS {{ chain }};

CREATE TABLE IF NOT EXISTS {{ chain }}.blocks (
    id                      BIGSERIAL,
    block_timestamp         TIMESTAMP,
    _st                     INTEGER,            -- The unix timestamp
    _st_day                 DATE,               -- The unix datetime
    blknum                  BIGINT NOT NULL,    -- The block number
    blkhash                 CHAR(66) NOT NULL,  -- The block hash
    parent_hash             CHAR(66) NOT NULL,  -- The parent block hash
    nonce                   TEXT,               -- The hash of the generated proof-of-work
    sha3_uncles             CHAR(66),           -- SHA3 of the uncles data in the block
    logs_bloom              TEXT,               -- The bloom filter for the logs of the block
    txs_root                CHAR(66) NOT NULL,  -- The root of the transaction trie of the block
    state_root              CHAR(66) NOT NULL,  -- The root of the final state trie of the block
    receipts_root           CHAR(66) NOT NULL,  -- The root of the receipts trie of the block
    miner                   CHAR(42) NOT NULL,  -- The address of the beneficiary to whom the mining rewards were given
    difficulty              NUMERIC,            -- Integer of the difficulty for this block
    total_difficulty        NUMERIC,            -- Integer of the total difficulty of the chain until this block
    blk_size                BIGINT,             -- The size of this block in bytes
    extra_data              TEXT,               -- The extra data field of this block
    gas_limit               BIGINT,             -- The maximum gas allowed in this block
    gas_used                BIGINT,             -- The total used gas by all transactions in this block
    tx_count                BIGINT,             -- The number of transactions in the block
    base_fee_per_gas        NUMERIC,            -- Protocol base fee per gas, which can move up or down
    uncle_count             SMALLINT DEFAULT 0,
    uncle0_hash             CHAR(66) DEFAULT NULL,
    uncle1_hash             CHAR(66) DEFAULT NULL,
    item_id                 TEXT,
    created_at              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (item_id, block_timestamp)
);
CREATE INDEX IF NOT EXISTS {{ chain }}_blocks_blknum_idx ON {{ chain }}.blocks(blknum);
{% if is_timescale_db is true %}
SELECT create_hypertable('{{ chain }}.blocks', 'block_timestamp', if_not_exists => true);
ALTER TABLE {{ chain }}.blocks SET(timescaledb.compress, timescaledb.compress_segmentby = 'blknum', timescaledb.compress_orderby = 'item_id, block_timestamp asc');
SELECT add_compression_policy('{{ chain }}.blocks', INTERVAL '60 days', if_not_exists => true);
{% endif %}

CREATE TABLE IF NOT EXISTS {{ chain }}.txs (
    id                          BIGSERIAL,
    block_timestamp             TIMESTAMP,
    _st                         INTEGER,    -- The unix timestamp
    _st_day                     DATE,       -- The unix datetime
    blknum                      BIGINT,     -- The block number
    txhash                      CHAR(66) NOT NULL,       -- Hash of the transaction
    txpos                       BIGINT,     -- Integer of the transactions index position in the block
    nonce                       BIGINT,     -- The number of transactions made by the sender prior to this one
    from_address                CHAR(42) NOT NULL,       -- Address of the sender
    to_address                  CHAR(42),   -- Address of the receiver. null when its a contract creation transaction
    value                       NUMERIC,    -- Value transferred in Wei
    gas                         BIGINT,     -- Gas provided by the sender
    gas_price                   NUMERIC,    -- Gas price provided by the sender in Wei
    input                       TEXT,       -- The data sent along with the transaction
    max_fee_per_gas             BIGINT,     -- Total fee that covers both base and priority fees
    max_priority_fee_per_gas    BIGINT,     -- Fee given to miners to incentivize them to include the transaction
    tx_type                     INTEGER,    -- Transaction type. 0 before London; 0, 2 after London
    receipt_cumulative_gas_used BIGINT,     -- The total amount of gas used when this transaction was executed in the block
    receipt_gas_used            BIGINT,     -- The amount of gas used by this specific transaction alone
    receipt_contract_address    TEXT,       -- The contract address created, if the transaction was a contract creation, otherwise null
    receipt_root                TEXT,       -- 32 bytes of post-transaction stateroot (pre Byzantium)
    receipt_status              INTEGER,    -- Either 1 (success) or 0 (failure) (post Byzantium), null before Byzantium
    receipt_effective_gas_price NUMERIC,    -- The actual value per gas deducted from the senders account. Replacement of gas_price after EIP-1559
    receipt_log_count           BIGINT,     -- The number of logs in this transaction
    item_id                     TEXT,
    created_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (item_id, block_timestamp)
);
CREATE INDEX IF NOT EXISTS {{ chain }}_txs_txhash_idx ON {{ chain }}.txs(txhash);
CREATE INDEX IF NOT EXISTS {{ chain }}_txs_blknum_idx ON {{ chain }}.txs(blknum);
{% if create_address_index is true %}
CREATE INDEX IF NOT EXISTS {{ chain }}_txs_from_addr_st_idx ON {{ chain }}.txs(from_address, block_timestamp);
CREATE INDEX IF NOT EXISTS {{ chain }}_txs_to_addr_st_idx ON {{ chain }}.txs(to_address, block_timestamp);
CREATE INDEX IF NOT EXISTS {{ chain }}_txs_contract_addr_st_idx ON {{ chain }}.txs(receipt_contract_address, block_timestamp) WHERE receipt_contract_address is not null;
{% endif %}
{% if is_timescale_db is true %}
SELECT create_hypertable('{{ chain }}.txs', 'block_timestamp', if_not_exists => true);
ALTER TABLE {{ chain }}.txs SET(timescaledb.compress, timescaledb.compress_segmentby = 'blknum', timescaledb.compress_orderby = 'item_id, block_timestamp asc');
SELECT add_compression_policy('{{ chain }}.txs', INTERVAL '30 days', if_not_exists => true);
{% endif %}

CREATE TABLE IF NOT EXISTS {{ chain }}.txpools (
    id                          BIGSERIAL,
    block_timestamp             TIMESTAMP,  -- The current timestamp
    blknum                      BIGINT,     -- The block number of current blknum
    txhash                      CHAR(66) NOT NULL,       -- Hash of the transaction
    txpos                       BIGINT DEFAULT NULL,     -- Integer of the transactions index position in the block
    nonce                       BIGINT NOT NULL,     -- The number of transactions made by the sender prior to this one
    from_address                CHAR(42) NOT NULL,       -- Address of the sender
    to_address                  CHAR(42),   -- Address of the receiver. null when its a contract creation transaction
    value                       NUMERIC,    -- Value transferred in Wei
    gas                         BIGINT,     -- Gas provided by the sender
    gas_price                   NUMERIC,    -- Gas price provided by the sender in Wei
    input                       TEXT,       -- The data sent along with the transaction
    max_fee_per_gas             BIGINT,     -- Total fee that covers both base and priority fees
    max_priority_fee_per_gas    BIGINT,     -- Fee given to miners to incentivize them to include the transaction
    tx_type                     INTEGER,    -- Transaction type. 0 before London; 0, 2 after London
    pool_type                   TEXT,       -- available: pending, queued
    item_id                     TEXT,
    created_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (item_id, block_timestamp)
);
{% if create_address_index is true %}
CREATE INDEX IF NOT EXISTS {{ chain }}_txpools_from_addr_st_idx ON {{ chain }}.txpools(from_address, block_timestamp);
CREATE INDEX IF NOT EXISTS {{ chain }}_txpools_to_addr_st_idx ON {{ chain }}.txpools(to_address, block_timestamp);
{% endif %}
{% if is_timescale_db is true %}
SELECT create_hypertable('{{ chain }}.txpools', 'block_timestamp', if_not_exists => true);
SELECT add_retention_policy('{{ chain }}.txpools', INTERVAL '6 hours', if_not_exists => true);
{% endif %}

CREATE TABLE IF NOT EXISTS {{ chain }}.traces (
    id                          BIGSERIAL,
    block_timestamp             TIMESTAMP,
    _st                         INTEGER NOT NULL,   -- The unix timestamp
    _st_day                     DATE NOT NULL,      -- The unix datetime
    blknum                      BIGINT NOT NULL,    -- The block number
    txhash                      CHAR(66),           -- Hash of the transaction, null if this trace is block reward
    txpos                       BIGINT,             -- Integer of the transactions index position in the block, null if this trace is block reward
    from_address                CHAR(42),           -- Address of the sender, null when trace_type is genesis or reward
    to_address                  CHAR(42),           -- Address of the receiver
    value                       NUMERIC(65, 0),     -- Value transferred in Wei
    input                       TEXT,               -- The data sent along with the message call
    output                      TEXT,               -- The output of the message call, bytecode of contract when trace_type is create
    trace_type                  VARCHAR(16),        -- One of call, create, suicide, reward, genesis, daofork
    call_type                   VARCHAR(64),        -- One of call, callcode, delegatecall, staticcall
    reward_type                 VARCHAR(64),        -- One of block, uncle
    gas                         BIGINT,             -- Gas provided with the message call
    gas_used                    BIGINT,             -- Gas used by the message call
    subtraces                   BIGINT,             -- Number of subtraces
    trace_address               TEXT,               -- Comma separated list of trace address in call tree
    error                       TEXT,               -- Error if message call failed
    status                      INTEGER,            -- The status of the tx, either 1 (success) or 0 (failure) (post Byzantium)
    item_id                     TEXT,
    created_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (item_id, block_timestamp)
);
CREATE INDEX IF NOT EXISTS {{ chain }}_traces_blknum_idx ON {{ chain }}.traces(blknum);
CREATE INDEX IF NOT EXISTS {{ chain }}_traces_txhash_idx ON {{ chain }}.traces(txhash);
{% if create_address_index is true %}
CREATE INDEX IF NOT EXISTS {{ chain }}_traces_from_addr_st_idx ON {{ chain }}.traces(from_address, block_timestamp);
CREATE INDEX IF NOT EXISTS {{ chain }}_traces_to_addr_st_idx ON {{ chain }}.traces(to_address, block_timestamp);
{% endif %}
{% if is_timescale_db is true %}
SELECT create_hypertable('{{ chain }}.traces', 'block_timestamp', if_not_exists => true);
ALTER TABLE {{ chain }}.traces SET(timescaledb.compress, timescaledb.compress_segmentby = 'blknum', timescaledb.compress_orderby = 'item_id, block_timestamp asc');
SELECT add_compression_policy('{{ chain }}.traces', INTERVAL '30 days', if_not_exists => true);
{% endif %}

-- extract via Geth's json-rpc eth_getTransactionReceipt
-- about the column `topics`:
--    In solidity: The first topic is the hash of the signature of the event (e.g. Deposit(address,bytes32,uint256)),
--    except you declared the event with the anonymous specifier
CREATE TABLE IF NOT EXISTS {{ chain }}.logs (
    id                          BIGSERIAL,
    block_timestamp             TIMESTAMP,
    _st                         INTEGER,    -- The unix timestamp
    _st_day                     DATE,       -- The unix datetime
    blknum                      BIGINT,     -- The block number
    txhash                      CHAR(66),   -- Hash of the transaction
    txpos                       BIGINT,     -- Integer of the transactions index position in the block
    logpos                      INTEGER,    -- Integer of the log index in the transaction receipt
    address                     CHAR(42),   -- Address from which this log originated
    n_topics                    INTEGER,    -- Integer of topics length
    topics                      TEXT,       -- Indexed log arguments (0 to 4 32-byte hex strings).
    data                        TEXT,       -- Contains one or more 32 Bytes non-indexed arguments of the log
    topics_0                    TEXT,       -- The first topic, aka the Event signature hash
    item_id                     TEXT,
    created_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (item_id, block_timestamp)
);
CREATE INDEX IF NOT EXISTS {{ chain }}_logs_blknum_idx ON {{ chain }}.logs(blknum);
CREATE INDEX IF NOT EXISTS {{ chain }}_logs_txhash_idx ON {{ chain }}.logs(txhash);
{% if create_address_index is true %}
CREATE INDEX IF NOT EXISTS {{ chain }}_logs_address_st_idx ON {{ chain }}.logs(address, block_timestamp);
{% endif %}
{% if is_timescale_db is true %}
SELECT create_hypertable('{{ chain }}.logs', 'block_timestamp', if_not_exists => true);
ALTER TABLE {{ chain }}.logs SET(timescaledb.compress, timescaledb.compress_segmentby = 'blknum', timescaledb.compress_orderby = 'item_id, block_timestamp asc');
SELECT add_compression_policy('{{ chain }}.logs', INTERVAL '30 days', if_not_exists => true);
{% endif %}

CREATE TABLE IF NOT EXISTS {{ chain }}.contracts (
    id                          BIGSERIAL,
    block_timestamp             TIMESTAMP,
    _st                         INTEGER,    -- The unix timestamp
    _st_day                     DATE,       -- The unix datetime
    blknum                      BIGINT,     -- The block number
    txhash                      CHAR(66),   -- Hash of the transaction
    txpos                       BIGINT,     -- Integer of the transactions index position in the block
    trace_type                  TEXT,       -- One of create, create2
    trace_address               TEXT,       -- The trace address, extract from trace.trace_address
    address                     CHAR(42) NOT NULL,       -- Address of the contract
    creater                     CHAR(42) NOT NULL,       -- The creater of the contract, extract from trace.from_address
    initcode                    TEXT,       -- Initcode of the contract, extract from trace.input
    bytecode                    TEXT,       -- Bytecode of the contract, extract from trace.output
    func_sighashes              TEXT,       -- 4-byte function signature hashes
    is_erc20                    BOOLEAN,    -- Whether this contract is an ERC20 contract
    is_erc721                   BOOLEAN,    -- Whether this contract is an ERC721 contract
    item_id                     TEXT,
    created_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (item_id, block_timestamp)
);
CREATE INDEX IF NOT EXISTS {{ chain }}_contracts_txhash_idx ON {{ chain }}.contracts(txhash);
{% if create_address_index is true %}
CREATE INDEX IF NOT EXISTS {{ chain }}_contracts_creater_idx ON {{ chain }}.contracts(creater);
CREATE INDEX IF NOT EXISTS {{ chain }}_contracts_address_idx ON {{ chain }}.contracts(address);
{% endif %}
{% if is_timescale_db is true %}
SELECT create_hypertable('{{ chain }}.contracts', 'block_timestamp', if_not_exists => true);
{% endif %}

CREATE TABLE IF NOT EXISTS {{ chain }}.tokens (
    id                          BIGSERIAL,
    block_timestamp             TIMESTAMP,
    _st                         INTEGER,    -- The unix timestamp
    _st_day                     DATE,       -- The unix datetime
    blknum                      BIGINT,     -- The block number
    txhash                      CHAR(66) NOT NULL,       -- Hash of the transaction
    txpos                       BIGINT,     -- Integer of the transactions index position in the block
    trace_address               TEXT,       -- The trace address, extract from trace.trace_address
    address                     CHAR(42) NOT NULL,       -- The address of the ERC20 token
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

CREATE TABLE IF NOT EXISTS {{ chain }}.token_xfers (
    id                          BIGSERIAL,
    block_timestamp             TIMESTAMP,
    _st                         INTEGER,    -- The unix timestamp
    _st_day                     DATE,       -- The unix datetime
    blknum                      BIGINT,     -- The block number
    txhash                      CHAR(66) NOT NULL,       -- Hash of the transaction
    txpos                       BIGINT,     -- Integer of the transactions index position in the block
    logpos                      BIGINT,     -- Log index in the transaction receipt
    token_address               CHAR(42) NOT NULL,       -- ERC20 token address
    from_address                CHAR(42) NOT NULL,       -- Address of the sender
    to_address                  CHAR(42) NOT NULL,       -- Address of the receiver
    value                       NUMERIC,     -- Amount of tokens transferred (ERC20) / id of the token transferred (ERC721)
    name                        TEXT,       -- Token name
    symbol                      TEXT,       -- Token symol
    decimals                    BIGINT,     -- Token decimals
    item_id                     TEXT,
    created_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (item_id, block_timestamp)
);
{% if create_address_index is true %}
CREATE INDEX IF NOT EXISTS {{ chain }}_token_xfers_token_addr_st_idx ON {{ chain }}.token_xfers(token_address, block_timestamp);
CREATE INDEX IF NOT EXISTS {{ chain }}_token_xfers_from_addr_st_idx ON {{ chain }}.token_xfers(from_address, block_timestamp);
CREATE INDEX IF NOT EXISTS {{ chain }}_token_xfers_to_addr_st_idx ON {{ chain }}.token_xfers(to_address, block_timestamp);
{% endif %}
{% if is_timescale_db is true %}
SELECT create_hypertable('{{ chain }}.token_xfers', 'block_timestamp', if_not_exists => true);
ALTER TABLE {{ chain }}.token_xfers SET(timescaledb.compress, timescaledb.compress_segmentby = 'blknum', timescaledb.compress_orderby = 'item_id, block_timestamp asc');
SELECT add_compression_policy('{{ chain }}.token_xfers', INTERVAL '30 days', if_not_exists => true);
{% endif %}

CREATE TABLE IF NOT EXISTS {{ chain }}.erc721_xfers (
    id                          BIGSERIAL,
    block_timestamp             TIMESTAMP,
    _st                         INTEGER,    -- The unix timestamp
    _st_day                     DATE,       -- The unix datetime
    blknum                      BIGINT,     -- The block number
    txhash                      CHAR(66) NOT NULL,       -- Hash of the transaction
    txpos                       BIGINT,     -- Integer of the transactions index position in the block
    logpos                      BIGINT,     -- Log index in the transaction receipt
    token_address               CHAR(42) NOT NULL,       -- ERC721 token address
    from_address                CHAR(42) NOT NULL,       -- Address of the sender
    to_address                  CHAR(42) NOT NULL,       -- Address of the receiver
    token_id                    NUMERIC,    -- Token ID
    name                        TEXT,
    symbol                      TEXT,
    item_id                     TEXT,
    created_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (item_id, block_timestamp)
);
{% if create_address_index is true %}
-- the number of token id transactions under the token address is too sparse in the long term, using
-- the token address, token id, and _st as the index is much more efficient than _st, token address, and token id as the index
CREATE INDEX IF NOT EXISTS {{ chain }}_erc721_xfers_token_addr_id_st_idx ON {{ chain }}.erc721_xfers(token_address, token_id, block_timestamp);
CREATE INDEX IF NOT EXISTS {{ chain }}_erc721_xfers_from_addr_st_idx ON {{ chain }}.erc721_xfers(from_address, block_timestamp);
CREATE INDEX IF NOT EXISTS {{ chain }}_erc721_xfers_to_addr_st_idx ON {{ chain }}.erc721_xfers(to_address, block_timestamp);
{% endif %}
{% if is_timescale_db is true %}
SELECT create_hypertable('{{ chain }}.erc721_xfers', 'block_timestamp', if_not_exists => true);
ALTER TABLE {{ chain }}.erc721_xfers SET(timescaledb.compress, timescaledb.compress_segmentby = 'blknum', timescaledb.compress_orderby = 'item_id, block_timestamp asc');
SELECT add_compression_policy('{{ chain }}.erc721_xfers', INTERVAL '30 days', if_not_exists => true);
{% endif %}

CREATE TABLE IF NOT EXISTS {{ chain }}.erc1155_xfers (
    id                          BIGSERIAL,
    block_timestamp             TIMESTAMP,
    _st                         INTEGER,    -- The unix timestamp
    _st_day                     DATE,       -- The unix datetime
    blknum                      BIGINT,     -- The block number
    txhash                      CHAR(66) NOT NULL,       -- Hash of the transaction
    txpos                       BIGINT,     -- Integer of the transactions index position in the block
    logpos                      BIGINT,     -- Log index in the transaction receipt
    token_address               CHAR(42) NOT NULL,       -- ERC1155 token address
    operator                    CHAR(42) NOT NULL,       -- Address of the operator
    from_address                CHAR(42) NOT NULL,       -- Address of the sender
    to_address                  CHAR(42) NOT NULL,       -- Address of the receiver
    token_id                    NUMERIC,    -- Token ID
    value                       NUMERIC,    -- ID of the tokens transferred
    id_pos                      BIGINT,     -- The position of this id in the batch
    id_cnt                      BIGINT,     -- Count of the id/value pairs, 1 for TransferSingle, #n for TransferBatch
    xfer_type                   VARCHAR(20),-- TransferSingle, TransferBatch
    name                        TEXT,
    symbol                      TEXT,
    item_id                     TEXT,
    created_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (item_id, block_timestamp)
);
{% if create_address_index is true %}
-- the number of token id transactions under the token address is too sparse in the long term, using
-- the token address, token id, and _st as the index is much more efficient than _st, token address, and token id as the index
CREATE INDEX IF NOT EXISTS {{ chain }}_erc1155_xfers_token_addr_id_st_idx ON {{ chain }}.erc1155_xfers(token_address, token_id, block_timestamp);
CREATE INDEX IF NOT EXISTS {{ chain }}_erc1155_xfers_from_addr_st_idx ON {{ chain }}.erc1155_xfers(from_address, block_timestamp);
CREATE INDEX IF NOT EXISTS {{ chain }}_erc1155_xfers_to_addr_st_idx ON {{ chain }}.erc1155_xfers(to_address, block_timestamp);
{% endif %}
{% if is_timescale_db is true %}
SELECT create_hypertable('{{ chain }}.erc1155_xfers', 'block_timestamp', if_not_exists => true);
ALTER TABLE {{ chain }}.erc1155_xfers SET(timescaledb.compress, timescaledb.compress_segmentby = 'blknum', timescaledb.compress_orderby = 'item_id, block_timestamp asc');
SELECT add_compression_policy('{{ chain }}.erc1155_xfers', INTERVAL '30 days', if_not_exists => true);
{% endif %}
