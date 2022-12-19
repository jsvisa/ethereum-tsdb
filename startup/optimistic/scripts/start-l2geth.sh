#!/bin/sh

set -eou

if [ -z "$DATADIR" ]; then
    echo "Must pass DATADIR"
    exit 1
fi
if [ -z "$BLOCK_SIGNER_PRIVATE_KEY" ]; then
    echo "Must pass BLOCK_SIGNER_PRIVATE_KEY"
    exit 1
fi
if [ -z "$BLOCK_SIGNER_PRIVATE_KEY_PASSWORD" ]; then
    echo "Must pass BLOCK_SIGNER_PRIVATE_KEY_PASSWORD"
    exit 1
fi
if [ -z "$L2GETH_GENESIS_URL" ]; then
    echo "Must pass L2GETH_GENESIS_URL"
    exit 1
fi
if [ -z "$L2GETH_GENESIS_HASH" ]; then
    echo "Must pass L2GETH_GENESIS_HASH"
    exit 1
fi

if [ -z "$BLOCK_SIGNER_ADDRESS" ]; then
    echo "Must pass BLOCK_SIGNER_ADDRESS"
    exit 1
fi

# Check for an existing chaindata folder.
# If it exists, assume it's correct and skip geth init step
GETH_GENESIS_FILE=$DATADIR/genesis.json
GETH_CHAINDATA_DIR=$DATADIR/geth/chaindata

if [ -d "$GETH_CHAINDATA_DIR" ]; then
    echo "$GETH_CHAINDATA_DIR existing, skipping geth init"
else
    echo "$GETH_CHAINDATA_DIR missing, running geth init"
    echo "Retrieving genesis file $L2GETH_GENESIS_URL"
    wget -c -O "$GETH_GENESIS_FILE" "$L2GETH_GENESIS_URL"
    GENESIS_SHA256SUM=$(sha256sum "$GETH_GENESIS_FILE" | awk '{print $1}')
    if [ "$GENESIS_SHA256SUM" != "$L2GETH_GENESIS_SHA256SUM" ]; then
        echo GENESIS_SHA256SUM: "$GENESIS_SHA256SUM" != L2GETH_GENESIS_SHA256SUM: "$L2GETH_GENESIS_SHA256SUM"
        exit 1
    else
        echo checksum match
        echo GENESIS_SHA256SUM: "$GENESIS_SHA256SUM" == L2GETH_GENESIS_SHA256SUM: "$L2GETH_GENESIS_SHA256SUM"
    fi

    mkdir -p "$GETH_CHAINDATA_DIR"
    echo "start geth init with genesis.json"
    geth init --datadir="$DATADIR" "$GETH_GENESIS_FILE" "$L2GETH_GENESIS_HASH"
    echo "finish geth init"
fi

# Check for an existing keystore folder.
# If it exists, assume it's correct and skip geth acount import step
GETH_KEYSTORE_DIR=$DATADIR/keystore
mkdir -p "$GETH_KEYSTORE_DIR"
GETH_KEYSTORE_KEYS=$(find "$GETH_KEYSTORE_DIR" -type f)

if [ -n "$GETH_KEYSTORE_KEYS" ]; then
    echo "$GETH_KEYSTORE_KEYS exist, skipping account import if any keys are present"
else
    echo "$GETH_KEYSTORE_DIR missing, running account import"
    printf "%s" "$BLOCK_SIGNER_PRIVATE_KEY_PASSWORD" > "$DATADIR"/password
    printf "%s" "$BLOCK_SIGNER_PRIVATE_KEY" > "$DATADIR"/block-signer-key
    geth account import --datadir="$DATADIR" --password "$DATADIR"/password "$DATADIR"/block-signer-key
fi

echo "l2geth setup complete"

exec geth \
  --datadir="$DATADIR" \
  --password="$DATADIR"/password \
  --allow-insecure-unlock \
  --unlock="$BLOCK_SIGNER_ADDRESS" \
  --mine \
  --miner.etherbase="$BLOCK_SIGNER_ADDRESS" \
  --metrics \
  --metrics.expensive
