ARG PYTHON_MAJOR=3.11
ARG NODE_MAJOR=20

# Build the python gbstats package
FROM python:${PYTHON_MAJOR}-slim AS pybuild
WORKDIR /usr/local/src/app
# Install system dependencies needed for poetry and building Python packages
# Scientific Python packages (numpy, pandas, scipy) need additional libraries
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  curl \
  build-essential \
  gfortran \
  libblas-dev \
  liblapack-dev \
  pkg-config \
  && rm -rf /var/lib/apt/lists/*
# Upgrade pip and install poetry
RUN pip3 install --upgrade pip setuptools wheel && \
  pip3 install poetry==1.8.5 poetry-plugin-export
# Configure poetry to not create virtual environment (we're in a container)
ENV POETRY_VENV_CREATE=false
ENV POETRY_NO_INTERACTION=1
ENV POETRY_CACHE_DIR=/tmp/poetry_cache
COPY ./packages/stats .
# Check poetry and files
RUN echo "=== Poetry version ===" && poetry --version && \
  echo "=== Listing files ===" && ls -la && \
  echo "=== Checking poetry.lock ===" && \
  (test -f poetry.lock && echo "poetry.lock exists" || echo "WARNING: poetry.lock not found")
# Install dependencies
RUN echo "=== Installing dependencies ===" && \
  poetry install --no-root --without dev --no-interaction --no-ansi -vvv
# Build package
RUN echo "=== Building package ===" && poetry build
# Export requirements
RUN echo "=== Exporting requirements ===" && \
  poetry export -f requirements.txt --output requirements.txt --without-hashes
# Cleanup
RUN echo "=== Cleaning cache ===" && \
  rm -rf $POETRY_CACHE_DIR && \
  echo "=== Build complete ==="

# Build the nodejs app
FROM python:${PYTHON_MAJOR}-slim AS nodebuild
ARG NODE_MAJOR
WORKDIR /usr/local/src/app
# Set node max memory
ENV NODE_OPTIONS="--max-old-space-size=8192"
RUN apt-get update && \
  apt-get install -y wget gnupg2 build-essential ca-certificates && \
  mkdir -p /etc/apt/keyrings && \
  wget -qO- https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
  wget -qO- https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /etc/apt/keyrings/yarn.gpg && \
  echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list && \
  apt-get update && \
  apt-get install -yqq nodejs yarn && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*
# Copy over minimum files to install dependencies
COPY package.json ./package.json
COPY yarn.lock ./yarn.lock
COPY packages/front-end/package.json ./packages/front-end/package.json
COPY packages/back-end/package.json ./packages/back-end/package.json
COPY packages/sdk-js/package.json ./packages/sdk-js/package.json
COPY packages/sdk-react/package.json ./packages/sdk-react/package.json
COPY packages/shared/package.json ./packages/shared/package.json
COPY patches ./patches
# Yarn install with dev dependencies (will be cached as long as dependencies don't change)
RUN yarn install --frozen-lockfile
# Apply patches this is not ideal since this should run at the end of yarn install but since node 20 it is not
RUN yarn postinstall
# Build the app and do a clean install with only production dependencies
COPY packages ./packages
# Build with increased memory and timeout
RUN \
  NODE_OPTIONS="--max-old-space-size=8192" yarn build \
  && test -f packages/back-end/dist/server.js || (echo "ERROR: packages/back-end/dist/server.js is missing after build!" && exit 1) \
  && rm -rf node_modules \
  && rm -rf packages/back-end/node_modules \
  && rm -rf packages/front-end/node_modules \
  && rm -rf packages/front-end/.next/cache \
  && rm -rf packages/shared/node_modules \
  && rm -rf packages/sdk-js/node_modules \
  && rm -rf packages/sdk-react/node_modules \
  && yarn install --frozen-lockfile --production=true --ignore-optional
RUN yarn postinstall


# Package the full app together
FROM python:${PYTHON_MAJOR}-slim
ARG NODE_MAJOR
WORKDIR /usr/local/src/app
RUN apt-get update && \
  apt-get install -y wget gnupg2 build-essential ca-certificates libkrb5-dev && \
  mkdir -p /etc/apt/keyrings && \
  wget -qO- https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
  wget -qO- https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /etc/apt/keyrings/yarn.gpg && \
  echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list && \
  apt-get update && \
  apt-get install -yqq nodejs yarn && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*
COPY --from=pybuild /usr/local/src/app/requirements.txt /usr/local/src/requirements.txt
RUN pip3 install -r /usr/local/src/requirements.txt && rm -rf /root/.cache/pip
COPY --from=nodebuild /usr/local/src/app/packages ./packages
COPY --from=nodebuild /usr/local/src/app/node_modules ./node_modules
COPY --from=nodebuild /usr/local/src/app/package.json ./package.json

# wildcard used to act as 'copy if exists'
COPY buildinfo* ./buildinfo

COPY --from=pybuild /usr/local/src/app/dist /usr/local/src/gbstats
RUN pip3 install /usr/local/src/gbstats/*.whl ddtrace
ARG DD_GIT_COMMIT_SHA=""
ARG DD_GIT_REPOSITORY_URL=https://github.com/growthbook/growthbook.git
ARG DD_VERSION=""
ENV DD_GIT_COMMIT_SHA=$DD_GIT_COMMIT_SHA
ENV DD_GIT_REPOSITORY_URL=$DD_GIT_REPOSITORY_URL
ENV DD_VERSION=$DD_VERSION
# The front-end app (NextJS)
EXPOSE 3000
# The back-end api (Express)
EXPOSE 3100
# Start both front-end and back-end at once
CMD ["yarn","start"]
