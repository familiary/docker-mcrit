FROM ubuntu:24.04
ARG MCRITWEB_BRANCH
ARG MCRIT_TAG

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

# install specific mcritweb+mcrit versions for this release
RUN git clone -b "${MCRITWEB_BRANCH}" --single-branch https://github.com/familiary/mcritweb.git /opt/mcritweb
RUN python -m pip install mcrit==${MCRIT_TAG}
# install remaining requirements
RUN python -m pip install -r /opt/mcritweb/requirements.txt

WORKDIR /opt/mcritweb
# don't create pyc files and immediately flush (log) buffers
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# for mcritweb
ENV FLASK_APP=/opt/mcritweb/mcritweb
ENV FLASK_ENV=/opt/mcritweb/mcritweb
ENV FLASK_DEBUG=1

COPY ./entry_web_dev.sh /entry_web_dev.sh
COPY ./entry_web_prod.sh /entry_web_prod.sh
RUN chmod +x /entry_web_dev.sh
RUN chmod +x /entry_web_prod.sh
