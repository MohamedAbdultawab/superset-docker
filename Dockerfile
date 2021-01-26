# VERSION 1.0 
# AUTHOR: Mohamed Abdultawab <mohamedtoba96@gmail.com>

FROM python:3.8

# Build argument[version of apache-superset to be built: pass value while building image]
ARG SUPERSET_VERSION

ENV SUPERSET_HOME=/home/superset/
ENV SUPERSET_DOWNLOAD_URL=https://github.com/apache/superset/archive/$SUPERSET_VERSION.tar.gz

# Add a normal superset group & user
# Change group & user id as per your requirement.
RUN groupadd -g 5006 superset; \
    useradd --create-home --no-log-init --uid 5004 --gid 5006 --home ${SUPERSET_HOME} --shell /bin/bash superset

# Configure environment
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Install dependencies to fix `curl https support error` and `delaying package configuration warning` and common useful packages
# Install nodejs for custom build
# https://github.com/apache/incubator-superset/blob/master/docs/installation.rst#making-your-own-build
# https://nodejs.org/en/download/package-manager/

RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -; \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -; \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends \
        apt-transport-https apt-utils vim-tiny curl netcat \
        postgresql-client redis-tools build-essential libssl-dev \
        libffi-dev python3-dev libsasl2-dev libldap2-dev libxi-dev \
        nodejs yarn; \
    rm -rf /var/lib/apt/lists/*; \
    apt-get purge --auto-remove; \
    apt-get clean


WORKDIR $SUPERSET_HOME

# Download & install superset
RUN curl -L -o superset.tar.gz $SUPERSET_DOWNLOAD_URL; \
    tar -xzf superset.tar.gz -C $SUPERSET_HOME --strip-components=1; \
    rm superset.tar.gz; \
    mkdir -p /home/superset/.cache /home/superset/config

COPY extra-requirements.txt requirements/
RUN pip install --upgrade setuptools pip && \
    pip install --no-cache-dir -r requirements/docker.txt -r requirements/extra-requirements.txt
RUN cd superset/assets; yarn; cd ../../superset-frontend; npm ci; npm run build && rm -rf node_modules

COPY scripts/docker-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh; \
    ln -s /usr/local/bin/docker-entrypoint.sh /entrypoint.sh; # backwards compat \
    chown -R superset:superset $SUPERSET_HOME

USER superset

ENV PATH=$PATH:${SUPERSET_HOME}superset/bin \
    PYTHONPATH=$PYTHONPATH:${SUPERSET_HOME}config/
HEALTHCHECK CMD ["curl", "-f", "http://localhost:8088/health"]
ENTRYPOINT ["docker-entrypoint.sh"]
