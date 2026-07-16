FROM ubuntu:24.04
ARG MCRIT_BRANCH

RUN apt-get -y update && apt-get -y install locales locales-all
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

RUN apt-get -y update && apt-get -y upgrade && apt-get install -y --no-install-recommends \
  apt-utils \
  p7zip-full \
  python3.12 \
  python3-pip \
  python3-dev \
  build-essential \
  gcc-multilib \
  git \
  openssh-client \
  inotify-tools \
  zip \
  curl \
  libssl-dev

ENV PIP_BREAK_SYSTEM_PACKAGES=1
RUN python3.12 -m pip install -U setuptools
RUN mkdir -p /root/.local/lib/python3.12/site-packages/
RUN ln -s /usr/bin/python3.12 /usr/bin/python

# install mcrit
RUN git clone -b "${MCRIT_BRANCH}" --single-branch https://github.com/danielplohmann/mcrit.git /opt/mcrit
RUN python -m pip install -r /opt/mcrit/requirements.txt
RUN python -m pip install -e /opt/mcrit --no-deps

WORKDIR /opt/mcrit
# don't create pyc files and immediately flush (log) buffers
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY ./entry_server.sh /entry_server.sh
COPY ./entry_worker.sh /entry_worker.sh
COPY ./entry_test.sh /entry_test.sh
RUN chmod +x /entry_server.sh /entry_worker.sh /entry_test.sh