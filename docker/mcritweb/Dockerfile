# syntax=docker/dockerfile:1
FROM ubuntu:24.04@sha256:224a1869083a311ef3f13648a154ba79832fbef6364d31493642ca03082da254 AS builder
ARG MCRITWEB_BRANCH
ARG MCRIT_TAG

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
RUN --mount=type=cache,target=/root/.cache/pip pip install -U setuptools

# install specific mcritweb+mcrit versions for this release
RUN git clone --depth 1 -b "${MCRITWEB_BRANCH}" --single-branch https://github.com/familiary/mcritweb.git /opt/mcritweb \
  && git -C /opt/mcritweb rev-parse HEAD > /opt/mcritweb/.git-revision \
  && rm -rf /opt/mcritweb/.git
# gunicorn is the WSGI server entry_web_prod.sh runs; MCRITweb's requirements.txt does not list it
RUN --mount=type=cache,target=/root/.cache/pip pip install \
  "mcrit==${MCRIT_TAG}" \
  -r /opt/mcritweb/requirements.txt \
  gunicorn


FROM ubuntu:24.04@sha256:224a1869083a311ef3f13648a154ba79832fbef6364d31493642ca03082da254
ARG MCRITWEB_TAG

LABEL org.opencontainers.image.source="https://github.com/familiary/mcritweb" \
      org.opencontainers.image.version="${MCRITWEB_TAG}" \
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
# for mcritweb
ENV FLASK_APP=/opt/mcritweb/mcritweb

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /opt/mcritweb /opt/mcritweb

COPY ./entry_web_dev.sh /entry_web_dev.sh
COPY ./entry_web_prod.sh /entry_web_prod.sh
RUN chmod +x /entry_web_dev.sh /entry_web_prod.sh

RUN useradd -u 10001 -m mcritweb && chown -R 10001:10001 /opt/mcritweb

WORKDIR /opt/mcritweb
USER 10001
