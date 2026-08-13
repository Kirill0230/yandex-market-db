FROM liquibase/liquibase:5.0.1

USER root

RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    ca-certificates \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://realkarych.github.io/seqwall-apt/public.key \
    | tee /etc/apt/trusted.gpg.d/seqwall.asc >/dev/null

RUN echo "deb [arch=$(dpkg --print-architecture)] https://realkarych.github.io/seqwall-apt stable main" \
    > /etc/apt/sources.list.d/seqwall.list

RUN apt-get update && apt-get install -y seqwall \
    && rm -rf /var/lib/apt/lists/*

RUN lpm add postgresql --global

WORKDIR /liquibase/changelog

COPY scripts /scripts
RUN chmod +x /scripts/*.sh

RUN apt-get update && apt-get install -y python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

COPY seed /seed
RUN python3 -m pip install -r /seed/requirements.txt

ENTRYPOINT ["/scripts/entrypoint.sh"]