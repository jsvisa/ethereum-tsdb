CREATE SCHEMA IF NOT EXISTS evm;

CREATE TABLE IF NOT EXISTS evm.func_signs (
    pkey                TEXT PRIMARY KEY,      -- pkey = md5(byte_sign || text_sign || abi::text)
    byte_sign           TEXT NOT NULL,
    text_sign           TEXT NOT NULL,
    abi                 JSONB,
    score               INTEGER DEFAULT 0,
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS evm_func_signs_byte_sign_idx ON evm.func_signs (byte_sign);
CREATE INDEX IF NOT EXISTS evm_func_signs_text_sign_idx ON evm.func_signs (split_part(text_sign, '(', 1));

CREATE TABLE IF NOT EXISTS public.cgc_live_prices (
    id                  BIGSERIAL,
    st                  INTEGER,    -- eg: 1658314892
    cgc_id              TEXT,       -- eg: ethereummax
    chain               TEXT,       -- eg: ethereum
    token_address       TEXT,       -- eg: 0x15874d65e649880c2614e7a480cb7c9a55787ff6
    name                TEXT,       -- eg: ethereum
    symbol              TEXT,       -- eg: ETH
    price               NUMERIC NOT NULL,
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS public_cgc_live_prices_st_idx ON cgc_live_prices(st);
CREATE INDEX IF NOT EXISTS public_cgc_live_prices_chain_token_st_idx ON cgc_live_prices(chain, token_address, st);

CREATE TABLE IF NOT EXISTS public.cmc_live_prices (
    id                  BIGSERIAL,
    st                  INTEGER,    -- eg: 1658314892
    cmc_id              TEXT,       -- eg: ethereummax
    chain               TEXT,       -- eg: ethereum
    token_address       TEXT,       -- eg: 0x15874d65e649880c2614e7a480cb7c9a55787ff6
    name                TEXT,       -- eg: ethereum
    symbol              TEXT,       -- eg: ETH
    price               NUMERIC NOT NULL,
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS public_cmc_live_prices_st_idx ON cmc_live_prices(st);
CREATE INDEX IF NOT EXISTS public_cmc_live_prices_chain_token_st_idx ON cmc_live_prices(chain, token_address, st);
