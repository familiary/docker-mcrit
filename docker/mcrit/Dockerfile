# syntax=docker/dockerfile:1
FROM ubuntu:24.04
ARG MCRIT_BRANCH

RUN apt-get update && apt-get install -y --no-install-recommends \
  apt-utils \
  locales \
  p7zip-full \
  python3.12 \
  python3-pip \
  python3-dev \
  build-essential \
  git \
  openssh-client \
  inotify-tools \
  zip \
  curl \
  libssl-dev \
  && locale-gen en_US.UTF-8 \
  && rm -rf /var/lib/apt/lists/*

ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

ENV PIP_BREAK_SYSTEM_PACKAGES=1
RUN --mount=type=cache,target=/root/.cache/pip python3.12 -m pip install -U setuptools
RUN mkdir -p /root/.local/lib/python3.12/site-packages/
RUN ln -s /usr/bin/python3.12 /usr/bin/python

# install mcrit
RUN git clone --depth 1 -b "${MCRIT_BRANCH}" --single-branch https://github.com/danielplohmann/mcrit.git /opt/mcrit
# MCRIT >= 1.8.0 declares its dependencies in pyproject.toml, so a single editable
# install pulls them in - there is no requirements.txt to read anymore
RUN --mount=type=cache,target=/root/.cache/pip python -m pip install -e /opt/mcrit

WORKDIR /opt/mcrit
# don't create pyc files and immediately flush (log) buffers
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY ./entry_server.sh /entry_server.sh
COPY ./entry_worker.sh /entry_worker.sh
COPY ./entry_test.sh /entry_test.sh
RUN chmod +x /entry_server.sh /entry_worker.sh /entry_test.sh
