# Docker MCRIT
[![Test](https://github.com/danielplohmann/docker-mcrit/actions/workflows/test.yml/badge.svg)](https://github.com/danielplohmann/docker-mcrit/actions/workflows/test.yml)

Dockerized Setup for the MinHash-based Code Recognition and Investigation Toolkit (MCRIT).

## Summary

This repository intends to enable you to quickly run a production-ready deployment of [MCRIT](https://github.com/danielplohmann/mcrit) including its frontend [MCRITweb](https://github.com/fkie-cad/mcritweb) with minimal effort through a pre-configured Docker setup.  
The latest commit on this repository will always hold references to the most recent versions of the front- and backend, and stable milestone releases will be marked as such.

## Setup

Given an installation of `docker-compose`, running this command in the repository root:

```bash
$ docker-compose up
```

should build the MCRIT server and worker as well as the MCRITweb images, pull images for mongodb and nginx, and then start up containers for everything.

The data produced and stored by the services are found in `./storage`:

* `./storage/mcritweb` contains the sqlite DB for the web application and cached data, such as matching reports in JSON format
* `./storage/mongodb`  contains all collections and indices, allowing it to persist across MCRIT web instance rebuilds and updates.

### Setup for HTTP(S)

By default, the NGINX included in this setup is only listening for the `server_name` of `localhost`, so you will need to configure
* `./nginx/mcritweb_plain.conf` or recommendably:
* `./nginx/mcritweb_ssl.conf`

based on the specifics of your server.

If you want to run the service over HTTPS
* you will need to adjust the NGINX service of the `docker-compose.yml` to use the `./nginx/mcritweb_ssl.conf` instead of `./nginx/mcritweb_plain.conf` and 
* Fill the respective files in `./nginx/ssl` with a certificate, private key, and ideally fresh Diffie-Hellman parameters.

### Development Mode

If you want to use this Docker setup for development on MCRIT, you will need the code repositories available outside of the containers to trivially reflect your changes.
For this, `mcrit` and `mcritweb` should first be cloned into `./repositories`, for which you can conveniently use the script `clone_repositories.sh`.
Afterwards, you can start the setup up in development mode, using:
```bash
$ docker-compose -f docker-compose-dev.yml up
```
Note that running in development mode will not start up NGINX, meaning you can reach MCRIT only via ports `5000` (frontend) and `8000` (backend).

## Usage

For an explanation of the usage of MCRIT itself, please refer to the respective repositories for 
* backend: [MCRIT](https://github.com/danielplohmann/mcrit) (documentation in preparation)
* frontend: [MCRITweb](https://github.com/fkie-cad/mcritweb) ([documentation](https://github.com/fkie-cad/mcritweb/tree/master/documentation))

## History

MCRIT was officially released as version 1.0.0 at Botconf 2023 ([paper](https://journal.cecyf.fr/ojs/index.php/cybin/article/view/45), [slides](https://www.botconf.eu/wp-content/uploads/formidable/2/2023-15-Plohmann_MCRIT.pdf), [video](https://www.youtube.com/watch?v=kvBHbXZZq2c&list=PL8fFmUArVzKhanPzq5HlGAUHhzRB3qDLE&index=24&ab_channel=botconfeu))

## Updates

 * 2026-08-20: MCRIT 1.6.2 (reliability release: the worker survives a mongod restart instead of exiting, a dead child process fails its job instead of reporting it finished, queue polling and the sha256/family/function-name lookups are served by indexes, and matching memory is bounded by a candidate-pair budget - see [docs/TUNING.md](docs/TUNING.md); matching results are unchanged), MCRITweb 1.4.8 (**NOTE: the first start after this bump builds two new indexes on the `functions` collection, which blocks for minutes on a multi-million function corpus - plan the restart accordingly**)
 * 2026-08-11: MCRIT 1.6.1 (the 1.6.0 optimisations are now **on by default** — matching runs single-process and the MatchingCache persists under a 512 MiB budget; results are unchanged, see [docs/TUNING.md](docs/TUNING.md)), MCRITweb 1.4.8 (**the session cookie is now `Secure`** — an instance served over plain HTTP needs `SESSION_COOKIE_SECURE = False` in `instance/config.py` or logins fail; the NGINX-terminated deployment here is unaffected)
 * 2026-08-11: MCRIT 1.6.0 (major matching-performance release, up to 4.4x with the new opt-in optimisations — all default off, see [docs/TUNING.md](docs/TUNING.md)), MCRITweb 1.4.7
 * 2026-08-07: MCRIT 1.5.3, MCRITweb 1.4.7 (Flask 3 / Werkzeug 3 — **rebuild the mcritweb image, a code-only pull keeps the old Flask**)
 * 2026-08-06: MCRIT 1.5.3, MCRITweb 1.4.6 (overall code quality and security improvements)
 * 2026-08-04: MCRIT 1.5.3 (~7x faster matching report loading), MCRITweb 1.4.2
 * 2026-08-04: MCRIT 1.5.2 (Dalvik capability, shingler packaging fix), MCRITweb 1.4.1
 * 2026-07-16: MCRIT 1.5.0 (worker+server moved to ubuntu24.04 / python3.12), MCRITweb 1.4.1
 * 2025-12-10: MCRIT 1.4.3, MCRITweb 1.4.1
 * 2025-12-08: MCRIT 1.4.3, MCRITweb 1.4.0
 * 2025-08-22: MCRIT 1.4.1, MCRITweb 1.3.6
