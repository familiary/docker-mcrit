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

## Maintenance

### Completing the MCRIT 1.7.0 disassembly split

MCRIT 1.7.0 keeps function disassembly in its own `xcfg` collection instead of inline in every
function document, so the queries on the matching path stop reading past a blob they do not need.
Upgrading does not require this - the readers fall back to an inline blob when none has been split
out - but until the migration runs, the instance keeps the old layout and none of the benefit.

```bash
$ ./migrate.sh
```

The script runs the migration inside the `mcrit-server` container and then verifies it. It is
resumable, so an interrupted run costs only the batch in flight, and running it again after
completion does nothing. For reference, 11.6M functions took about 17 minutes.

Three things worth knowing before you start:

* it needs free disk roughly the size of your stored disassembly, and **does not return it** until
  you compact the collection afterwards: `docker compose exec mongodb mongosh mcrit --eval
  'db.runCommand({compact: "functions"})'` (check your MongoDB version's notes - `compact` blocks
  operations on the collection in some versions)
* **byte-for-byte verification is only possible beforehand.** An in-place run leaves no original
  blobs to compare against, so verification afterwards establishes coverage and counts rather than
  content. To get content-level proof, rehearse into a second database first
  (`--mode copy --target <db>` then `--mode verify --target <db>`) or take a dump.
* **do not downgrade a migrated instance** without running `--mode unsplit` first. Older MCRIT
  versions do not know about the `xcfg` collection and fail quietly rather than loudly.

`/status` reports `inline_xcfg_remaining`, so an instance that has not finished migrating says so.

Full details in the upstream [migration guide](https://github.com/danielplohmann/mcrit/blob/main/docs/migration-v1.7.0.md).

### Checking the SMDA escaper fingerprint after a rebuild

MCRIT does not pin SMDA, so rebuilding the images can pull a newer SMDA whose instruction escaping
differs. That matters because MinHashes are derived from the escaped representation: when the
escaping changes, previously indexed signatures stop being comparable to newly computed ones. They
still look valid and still match each other, while identical code submitted afterwards no longer
finds them. SMDA 4.4.5 is a worked example - it corrected how segment-qualified memory operands are
escaped, which altered about a fifth of the stored MinHashes on a real corpus.

MCRIT 1.7.0 makes this visible. `/status` reports `smda_version` and `escaper_fingerprint`:

```bash
$ curl -s http://127.0.0.1:8000/status | python -m json.tool | grep -E "smda_version|escaper"
```

Note the fingerprint after a build. If it changes on a later rebuild, the escaping changed, and the
index should be re-minhashed to stay internally consistent - the stored disassembly makes that a
local recomputation, with no need to re-submit any samples.

## History

MCRIT was officially released as version 1.0.0 at Botconf 2023 ([paper](https://journal.cecyf.fr/ojs/index.php/cybin/article/view/45), [slides](https://www.botconf.eu/wp-content/uploads/formidable/2/2023-15-Plohmann_MCRIT.pdf), [video](https://www.youtube.com/watch?v=kvBHbXZZq2c&list=PL8fFmUArVzKhanPzq5HlGAUHhzRB3qDLE&index=24&ab_channel=botconfeu))

## Updates

 * 2026-08-24: MCRIT 1.7.0 (**database shape change**: disassembly moves out of the function documents into dedicated `xcfg`/`query_xcfg` collections - matching results are unchanged, and **upgrading needs no migration window** because every reader falls back to the inline blobs. Completing the split is a separate, manual step: run `./migrate.sh`, see [Maintenance](#maintenance). **NOTE: the in-place migration temporarily needs about as much free disk as your stored disassembly - +15 GB on an 11.6M function corpus - and does not hand it back until you compact the collection.** **NOTE: once migrated, older MCRIT versions can no longer read the database and fail _quietly_ - they start up healthy and then behave as if no function had disassembly - so run the migration's `--mode unsplit` before ever downgrading the images.** Also **NOTE: the `config/` copies shipped here had drifted behind MCRIT and were missing the settings introduced in 1.6.0/1.6.1, which silently left vectorised matching, numpy candidate accumulation, the persistent MatchingCache, concurrent signature fetch and the candidate-pair budget all disabled; they are regenerated from 1.7.0 stock in this bump, so matching should get noticeably faster with unchanged results - if you have edited `config/` locally, merge rather than overwrite.**), MCRITweb 1.4.8
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
