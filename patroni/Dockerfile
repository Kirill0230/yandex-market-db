FROM postgres:17

RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv curl && \
    python3 -m venv /opt/patroni && \
    /opt/patroni/bin/pip install --no-cache-dir "patroni[etcd3]" psycopg2-binary && \
    ln -s /opt/patroni/bin/patroni /usr/local/bin/patroni && \
    ln -s /opt/patroni/bin/patronictl /usr/local/bin/patronictl && \
    mkdir -p /config /var/lib/postgresql/data && \
    chown -R postgres:postgres /config /var/lib/postgresql/data && \
    rm -rf /var/lib/apt/lists/*

USER postgres

ENTRYPOINT []
CMD ["patroni", "/config/patroni.yml"]