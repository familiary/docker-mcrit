# syntax=docker/dockerfile:1
FROM ubuntu:24.04
ARG MCRITWEB_BRANCH
ARG MCRIT_TAG

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

# install specific mcritweb+mcrit versions for this release
RUN git clone --depth 1 -b "${MCRITWEB_BRANCH}" --single-branch https://github.com/fkie-cad/mcritweb.git /opt/mcritweb
RUN --mount=type=cache,target=/root/.cache/pip python -m pip install mcrit==${MCRIT_TAG}
# install remaining requirements
RUN --mount=type=cache,target=/root/.cache/pip python -m pip install -r /opt/mcritweb/requirements.txt
# the WSGI server entry_web_prod.sh runs; MCRITweb's requirements.txt does not list it
RUN --mount=type=cache,target=/root/.cache/pip python -m pip install gunicorn

WORKDIR /opt/mcritweb
# don't create pyc files and immediately flush (log) buffers
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# for mcritweb
ENV FLASK_APP=/opt/mcritweb/mcritweb

COPY ./entry_web_dev.sh /entry_web_dev.sh
COPY ./entry_web_prod.sh /entry_web_prod.sh
RUN chmod +x /entry_web_dev.sh /entry_web_prod.sh
