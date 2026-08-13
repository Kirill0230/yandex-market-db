FROM postgres:17

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      cron \
      procps \
      curl \
      jq \
      ca-certificates \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc && \
    chmod +x /usr/local/bin/mc

COPY db_backup.sh /usr/local/bin/db_backup.sh
RUN chmod +x /usr/local/bin/db_backup.sh

COPY restore.sh /usr/local/bin/restore.sh
RUN chmod +x /usr/local/bin/restore.sh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["cron", "-f"]