# syntax=docker/dockerfile:1
FROM ubuntu:24.04@sha256:224a1869083a311ef3f13648a154ba79832fbef6364d31493642ca03082da254 AS builder
ARG MCRIT_BRANCH

RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  git \
  libssl-dev \
  python3-dev \
  python3.12 \
  python3.12-venv \
  && rm -rf /var/lib/apt/lists/*

RUN python3.12 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"
# the venv's ensurepip ships pip only, and a pyproject.toml build needs setuptools>=77
RUN --mount=type=cache,target=/root/.cache/pip pip install -U setuptools

RUN git clone --depth 1 -b "${MCRIT_BRANCH}" --single-branch https://github.com/danielplohmann/mcrit.git /opt/mcrit \
  && git -C /opt/mcrit rev-parse HEAD > /opt/mcrit/.git-revision \
  && rm -rf /opt/mcrit/.git
# MCRIT >= 1.8.0 declares its dependencies in pyproject.toml, so a single editable
# install pulls them in - there is no requirements.txt to read anymore.
# Editable, because the compose files mount the deployment's config/ over the package's
# own mcrit/config/ and that has to be the config the running package reads.
# pytest is the "dev" extra's only part this image needs: /entry_test.sh runs the unit
# tests, and a non-root runtime user cannot install it at startup.
RUN --mount=type=cache,target=/root/.cache/pip pip install -e /opt/mcrit pytest


FROM ubuntu:24.04@sha256:224a1869083a311ef3f13648a154ba79832fbef6364d31493642ca03082da254
ARG MCRIT_TAG

LABEL org.opencontainers.image.source="https://github.com/danielplohmann/mcrit" \
      org.opencontainers.image.version="${MCRIT_TAG}" \
      org.opencontainers.image.licenses="GPL-3.0-only"

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  libssl3 \
  locales \
  p7zip-full \
  python3.12 \
  && locale-gen en_US.UTF-8 \
  && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV PATH="/opt/venv/bin:${PATH}"
# don't create pyc files and immediately flush (log) buffers
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /opt/mcrit /opt/mcrit

COPY ./entry_server.sh /entry_server.sh
COPY ./entry_worker.sh /entry_worker.sh
COPY ./entry_test.sh /entry_test.sh
RUN chmod +x /entry_server.sh /entry_worker.sh /entry_test.sh

# /opt/mcrit has to stay writable: the test entrypoint writes pytest's cache there
RUN useradd -u 10001 -m mcrit && chown -R 10001:10001 /opt/mcrit

WORKDIR /opt/mcrit
USER 10001
