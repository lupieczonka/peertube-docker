FROM node:10-buster

# Allow to pass extra options to the npm run build
# eg: --light --light-fr to not build all client languages
#     (speed up build time if i18n is not required)
ARG NPM_RUN_BUILD_OPTS

RUN set -ex; \
    if ! command -v gpg > /dev/null; then \
      apt update; \
      apt install -y --no-install-recommends \
        gnupg \
        dirmngr \
      ; \
      rm -rf /var/lib/apt/lists/*; \
fi

# Install dependencies
RUN apt update \
    && apt -y install ffmpeg \
    && rm /var/lib/apt/lists/* -fR

# Add peertube user
RUN groupadd -r peertube \
    && useradd -r -g peertube -m peertube

# grab gosu for easy step-down from root
RUN set -eux; \
	apt update; \
	apt install -y gosu; \
	rm -rf /var/lib/apt/lists/*; \
	gosu nobody true

# Install PeerTube from github
ARG PEERTUBE_VER=v2.0.0
USER root
WORKDIR /tmp
RUN git clone --branch ${PEERTUBE_VER} https://github.com/Chocobozzz/PeerTube.git peertube-$PEERTUBE_VER \
    && mv peertube-$PEERTUBE_VER /app \
    && cp /app/support/docker/production/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh \
    && chown -cR peertube:peertube /app

RUN chown -R peertube:peertube /app
WORKDIR /app
USER peertube
RUN yarn install --pure-lockfile \
    && npm run build -- $NPM_RUN_BUILD_OPTS \
    && rm -r ./node_modules ./client/node_modules \
    && yarn install --pure-lockfile --production \
    && yarn cache clean

USER root

RUN mkdir /data /config
RUN chown -R peertube:peertube /data /config

ENV NODE_ENV production
ENV NODE_CONFIG_DIR /config

VOLUME /data
VOLUME /config

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Run the application
CMD ["npm", "start"]
EXPOSE 9000
