# ethereum-tsdb

Ethereum ETL Schema based on TimescaleDB

> build

find a valid timescaledb image from https://hub.docker.com/r/timescale/timescaledb-ha

```bash
TS_VERSION=pg15-ts2.15-all VERSION=pg15-ts2.15-v0.5 make build-image
TS_VERSION=pg15-ts2.11 VERSION=pg15-ts2.11-v0.4 make build-image
TS_VERSION=pg15-ts2.9-latest VERSION=pg15-ts2.9-v0.3 make build-image
TS_VERSION=pg14-ts2.9-latest VERSION=pg14-ts2.9-v0.2 make build-image
```

## upgrade tsdb

Ref [timescaledb upgrade](https://docs.timescale.com/timescaledb/latest/how-to-guides/upgrades/upgrade-docker/)

1. Connect to the upgraded instance using psql with the -X flag:

> you need to specify the target database, else the extension maybe not updated as expected
> ref [#issue 300](https://github.com/timescale/docs.timescale.com-content/issues/300)

```bash
docker exec -it tsdb psql -U postgres tsdb -X
```

At the psql prompt, use the ALTER command to upgrade the extension:

```sql
ALTER EXTENSION timescaledb UPDATE;
```

Update the TimescaleDB Toolkit extension. Toolkit is packaged with TimescaleDB's HA Docker image, and includes additional hyperfunctions to help you with queries and data analysis:

```sql
CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit;
ALTER EXTENSION timescaledb_toolkit UPDATE;
```

## setup master-slave replication

ref https://docs.timescale.com/self-hosted/latest/replication-and-ha/configure-replication/

## use [pgBackRest](https://pgbackrest.org) to archive the database

> exec into the tsdb container

```bash
docker exec -it tsdb bash
```

> create stanza and modify the postgresql.conf to enable archive mode

```bash
cat <<EOF >> /path/to/postgresql.conf
archive_command = 'pgbackrest --stanza=demo archive-push %p'
archive_mode = on
EOF

pgbackrest --stanza=demo stanza-create
```

> restart tsdb container

```bash
docker-compose restart tsdb
```

### restore issues

1. requested timeline 2 is not a child of this server's history

full logs:

```log
FATAL:  requested timeline 2 is not a child of this server's history
DETAIL:  Latest checkpoint is at 12/90000060 on timeline 1, but in the history of the requested timeline, the server forked off from that timeline at 11/F5000000.
LOG:  startup process (PID 13) exited with exit code 1
LOG:  aborting startup due to startup process failure
LOG:  database system is shut down
```

you need to restore with `--target-timeline=1` to bypass this issue:

```bash
$ pgbackrest --stanza=demo --target-timeline=1 restore
```

```log
INFO: restore command begin 2.42: --config=/home/postgres/pgdata/backup/pgbackrest.conf --exec-id=20-a9088980 --log-level-console=info --log-level-file=debug --pg1-path=/home/postgres/pgdata/data --process-max=4 --repo1-path=/tsdb-backup ... --stanza=demo --target-timeline=1
INFO: repo1: restore backup set 20230207-030321F, recovery will start at 2023-02-07 03:03:21
INFO: write updated /home/postgres/pgdata/data/postgresql.auto.conf
INFO: restore global/pg_control (performed last to ensure aborted restores cannot be started)
INFO: restore size = 14.2GB, file total = 1594
INFO: restore command end: completed successfully (74266ms)
```

## Tips

1. change the chunk interval on an existing hypertable

```sql
SELECT set_chunk_time_interval('geth.traces', INTERVAL '1 hour');
```

2. enable compression on hypertable

```sql
ALTER TABLE geth.traces SET(timescaledb.compress, timescaledb.compress_segmentby = 'blknum', timescaledb.compress_orderby = 'item_id, block_timestamp asc');
SELECT add_compression_policy('geth.traces', INTERVAL '2 days', if_not_exists => true);
```
