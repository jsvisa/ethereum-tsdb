FROM timescale/timescaledb-ha:pg14-latest

USER root
# python packages
RUN apt-get update \
    && apt-get install -y python3-pip \
    && pip3 install eth-abi base58

# cleanup
RUN apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
            /usr/share/doc \
            /usr/share/man \
            /usr/share/locale/?? \
            /usr/share/locale/??_?? \
    && find /var/log -type f -exec truncate --size 0 {} \;

WORKDIR /home/postgres
EXPOSE 5432 8008 8081
USER postgres
