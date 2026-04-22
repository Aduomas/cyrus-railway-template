FROM node:22-bookworm

ENV NODE_ENV=production \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    git \
    gh \
    jq \
    ca-certificates \
    curl \
    socat \
    tini \
  && rm -rf /var/lib/apt/lists/*

ARG CYRUS_VERSION=latest
RUN npm install -g cyrus-ai@${CYRUS_VERSION} && npm cache clean --force

# Cyrus stores state (config.json, repos, tokens) under $HOME/.cyrus.
# Point HOME at the Railway volume so state persists across deploys.
ENV HOME=/data \
    CYRUS_SERVER_PORT=3456

WORKDIR /data

EXPOSE 3457

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["cyrus"]
