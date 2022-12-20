CREATE DATABASE IF NOT EXISTS {{ chain }};

-- extract via OpenEthereum/Geth's json-rpc eth_getBlock
CREATE TABLE IF NOT EXISTS {{ chain }}.blocks (
    block_timestamp     DateTime('UTC'),-- The unix timestamp
    blknum              BIGINT,         -- The block number
    blkhash             TEXT,           -- The block hash
    parent_hash         TEXT,           -- The parent block hash
    nonce               TEXT,           -- The hash of the generated proof-of-work
    sha3_uncles         TEXT,           -- SHA3 of the uncles data in the block
    logs_bloom          TEXT,           -- The bloom filter for the logs of the block
    txs_root            TEXT,           -- The root of the transaction trie of the block
    state_root          TEXT,           -- The root of the final state trie of the block
    receipts_root       TEXT,           -- The root of the receipts trie of the block
    miner               TEXT,           -- The address of the beneficiary to whom the mining rewards were given
    difficulty          UInt256,        -- Integer of the difficulty for this block
    total_difficulty    UInt256,        -- Integer of the total difficulty of the chain until this block
    blk_size            BIGINT,         -- The size of this block in bytes
    extra_data          TEXT,           -- The extra data field of this block
    gas_limit           BIGINT,         -- The maximum gas allowed in this block
    gas_used            BIGINT,         -- The total used gas by all transactions in this block
    tx_count            BIGINT,         -- The number of transactions in the block
    base_fee_per_gas    UInt256,        -- Protocol base fee per gas, which can move up or down
    uncle_count         INTEGER,       -- The number of uncles in the block
    uncle0_hash         TEXT,           -- The hash of the uncle 0
    uncle1_hash         TEXT            -- The hash of the uncle 1
)
ENGINE = ReplacingMergeTree
PARTITION BY toYYYYMM(block_timestamp)
ORDER BY (blknum)
SETTINGS storage_policy = 's3_main';

-- extract via OpenEthereum/Geth's json-rpc eth_getBlock(block_num, full_transactions=True)
-- enrich with eth_getTransactionReceipt
CREATE TABLE IF NOT EXISTS {{ chain }}.txs (
    block_timestamp             DateTime('UTC'),      -- The unix timestamp
    blknum                      BIGINT,     -- The block number
    txhash                      TEXT,       -- Hash of the transaction
    txpos                       BIGINT,     -- Integer of the transactions index position in the block
    nonce                       BIGINT,     -- The number of transactions made by the sender prior to this one
    from_address                TEXT,       -- Address of the sender
    to_address                  TEXT,       -- Address of the receiver. null when its a contract creation transaction
    value                       UInt256,    -- Value transferred in Wei
    gas                         BIGINT,     -- Gas provided by the sender
    gas_price                   UInt256,    -- Gas price provided by the sender in Wei
    input                       TEXT,       -- The data sent along with the transaction
    max_fee_per_gas             BIGINT,     -- Total fee that covers both base and priority fees
    max_priority_fee_per_gas    BIGINT,     -- Fee given to miners to incentivize them to include the transaction
    tx_type                     INTEGER,    -- Transaction type. 0 before London; 0, 2 after London
    receipt_cumulative_gas_used BIGINT,     -- The total amount of gas used when this transaction was executed in the block
    receipt_gas_used            BIGINT,     -- The amount of gas used by this specific transaction alone
    receipt_contract_address    TEXT,       -- The contract address created, if the transaction was a contract creation, otherwise null
    receipt_root                TEXT,       -- 32 bytes of post-transaction stateroot (pre Byzantium)
    receipt_status              INTEGER,    -- Either 1 (success) or 0 (failure) (post Byzantium), null before Byzantium
    receipt_effective_gas_price UInt256,    -- The actual value per gas deducted from the senders account. Replacement of gas_price after EIP-1559
    receipt_log_count           BIGINT      -- The number of logs in this transaction
)
ENGINE = ReplacingMergeTree
PARTITION BY toYYYYMM(block_timestamp)
ORDER BY (blknum, txhash)
SETTINGS storage_policy = 's3_main';

-- extract via OpenEthereum/Geth's json-rpc eth_getTransactionReceipt
-- about the column `topics`:
--    In solidity: The first topic is the hash of the signature of the event (e.g. Deposit(address,bytes32,uint256)),
--    except you declared the event with the anonymous specifier
CREATE TABLE IF NOT EXISTS {{ chain }}.logs (
    block_timestamp     DateTime('UTC'),      -- The unix timestamp
    blknum              BIGINT,     -- The block number
    txhash              TEXT,       -- Hash of the transaction
    txpos               BIGINT,     -- Integer of the transactions index position in the block
    logpos              INTEGER,    -- Integer of the log index in the transaction receipt
    address             TEXT,       -- Address from which this log originated
    n_topics            INTEGER,    -- Integer of topics length
    topics              TEXT,       -- Indexed log arguments (0 to 4 32-byte hex strings).
    data                TEXT,       -- Contains one or more 32 Bytes non-indexed arguments of the log
    topics_0            TEXT        -- The first topic, aka the Event signature hash
)
ENGINE = ReplacingMergeTree
PARTITION BY toYYYYMM(block_timestamp)
ORDER BY (blknum, txhash, logpos)
SETTINGS storage_policy = 's3_main';

-- extract via OpenEthereum's json-rpc trace_block
-- or Geth's debug_traceBlockByNumber
-- about the column `to_address`, the value depends on column `trace_type`:
--    if trace_type is call, is the address of the receiver
--    if trace_type is create, is the address of the new contract
--    if trace_type is suicide, is the beneficiary address
--    if trace_tyep is reward, is the miner address
--    if trace_type is genesis, is the shareholder address ,
--    if trace_type is daofork, is the WithdrawDAO address
CREATE TABLE IF NOT EXISTS {{ chain }}.traces (
    block_timestamp     DateTime('UTC'),      -- The unix timestamp
    blknum              BIGINT,     -- The block number
    txhash              TEXT,       -- Hash of the transaction
    txpos               BIGINT,     -- Integer of the transactions index position in the block
    from_address        TEXT,       -- Address of the sender, null when trace_type is genesis or reward
    to_address          TEXT,       -- Address of the receiver
    value               UInt256,    -- Value transferred in Wei
    input               TEXT,       -- The data sent along with the message call
    output              TEXT,       -- The output of the message call, bytecode of contract when trace_type is create
    trace_type          TEXT,       -- One of call, create, suicide, reward, genesis, daofork
    call_type           TEXT,       -- One of call, callcode, delegatecall, staticcall
    reward_type         TEXT,       -- One of block, uncle
    gas                 BIGINT,     -- Gas provided with the message call
    gas_used            BIGINT,     -- Gas used by the message call
    subtraces           BIGINT,     -- Number of subtraces
    trace_address       TEXT,       -- Comma separated list of trace address in call tree
    error               TEXT,       -- Error if message call failed
    status              INTEGER     -- The status of the tx, either 1 (success) or 0 (failure) (post Byzantium)
)
ENGINE = ReplacingMergeTree
PARTITION BY toYYYYMM(block_timestamp)
ORDER BY (blknum, txhash, trace_address)
SETTINGS storage_policy = 's3_main';


-- extract from traces
CREATE TABLE IF NOT EXISTS {{ chain }}.contracts (
    block_timestamp     DateTime('UTC'),      -- The unix timestamp
    blknum              BIGINT,     -- The block number
    txhash              TEXT,       -- Hash of the transaction
    txpos               BIGINT,     -- Integer of the transactions index position in the block
    trace_type          TEXT,       -- One of create, create2
    trace_address       TEXT,       -- The trace address, extract from trace.trace_address
    address             TEXT,       -- Address of the contract
    creater             TEXT,       -- The creater of the contract, extract from trace.from_address
    initcode            TEXT,       -- Initcode of the contract, extract from trace.input
    bytecode            TEXT,       -- Bytecode of the contract, extract from trace.output
    func_sighashes      TEXT,       -- 4-byte function signature hashes
    is_erc20            BOOLEAN,    -- Whether this contract is an ERC20 contract
    is_erc721           BOOLEAN     -- Whether this contract is an ERC721 contract
)
ENGINE = ReplacingMergeTree
PARTITION BY toYYYYMM(block_timestamp)
ORDER BY (blknum)
SETTINGS storage_policy = 's3_main';

-- extract from logs
CREATE TABLE IF NOT EXISTS {{ chain }}.token_xfers (
    block_timestamp     DateTime('UTC'),      -- The unix timestamp
    blknum              BIGINT,     -- The block number
    txhash              TEXT,       -- Hash of the transaction
    txpos               BIGINT,     -- Integer of the transactions index position in the block
    logpos              BIGINT,     -- Log index in the transaction receipt
    token_address       TEXT,       -- ERC20 token address
    name                TEXT,       -- Token name
    symbol              TEXT,       -- Token symol
    decimals            BIGINT DEFAULT -1,     -- Token decimals, -1 stands for null in PostgreSQL
    from_address        TEXT,       -- Address of the sender
    to_address          TEXT,       -- Address of the receiver
    value               UInt256     -- Amount of tokens transferred (ERC20) / id of the token transferred (ERC721)
)
ENGINE = ReplacingMergeTree
PARTITION BY toYYYYMM(block_timestamp)
ORDER BY (blknum, txhash, logpos)
SETTINGS storage_policy = 's3_main';

-- extract from logs
CREATE TABLE IF NOT EXISTS {{ chain }}.erc1155_xfers (
    block_timestamp     DateTime('UTC'),      -- The unix timestamp
    blknum              BIGINT,     -- The block number
    txhash              TEXT,       -- Hash of the transaction
    txpos               BIGINT,     -- Integer of the transactions index position in the block
    logpos              BIGINT,     -- Log index in the transaction receipt
    token_address       TEXT,       -- ERC1155 token address
    token_name          TEXT,       -- Token name/symol, extract from {{ chain }}.tokens
    operator            TEXT,       -- Address of the operator
    from_address        TEXT,       -- Address of the sender
    to_address          TEXT,       -- Address of the receiver
    token_id            UInt256,    -- Token ID
    value               UInt256,    -- ID of the tokens transferred
    id_pos              BIGINT,     -- The position of this id in this batch
    id_cnt              BIGINT,     -- Count of the id/value pairs, 1 for TransferSingle, #n for TransferBatch
    xfer_type           TEXT,       -- TransferSingle, TransferBatch
    name                TEXT,       -- Token name
    symbol              TEXT        -- Token symol
)
ENGINE = ReplacingMergeTree
PARTITION BY toYYYYMM(block_timestamp)
ORDER BY (blknum, txhash, logpos, id_pos)
SETTINGS storage_policy = 's3_main';
