#!/usr/bin/bash

docker run -it --rm -v "$(pwd)"/pgback:/home/postgres/pgback -v "$(pwd)"/pgdata-bk:/home/postgres/pgdata -v "$(pwd)"/etc/pgbackrest.conf:/home/postgres/pgdata/backup/pgbackrest.conf jsvisa/ethereum-tsdb:latest bash -c "pgbackrest --stanza=demo restore"
