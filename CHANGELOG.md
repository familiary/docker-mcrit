# Changelog

All notable changes to this deployment are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), adapted in two ways
because this repository is a deployment rather than a library.

**Entries are keyed by date and by what they ship**, not by a version of their own: docker-mcrit is
not versioned - it carries one tag in its whole history - and what a reader needs from an entry is
which MCRIT and MCRITweb a pull now gives them. For the same reason there are no comparison links at
the bottom; there is nothing to compare between.

**`[Unreleased]` is where this repository's own changes go** - Dockerfiles, entry scripts, compose,
NGINX, the shipped `config/`, CI. Historically the log recorded only upstream version bumps, so
changes made here were invisible to anyone reading it: the Dockerfile learning to install from
`pyproject.toml`, `entry_test.sh` gaining pytest, and the TUNING.md drift check all happened without
an entry. Write those down when they merge, and they get carried into the next dated entry.

An entry carries the measurement, the caveat and the failure mode, not just the change - and for a
deployment that means saying plainly what an operator has to *do*, which is what `Upgrading` is for.

## [Unreleased]

### Changed

- The images and `clone_repositories.sh` clone from `github.com/familiary/*`, where MCRIT, MCRITweb
  and this repository now live. The old paths still redirect, so this changes nothing about what is
  built - but a redirect stops the moment a repository of the same name appears under the old owner,
  and the two places that would break are build-time clones. `danielplohmann/smda` and
  `danielplohmann/purepdb` are deliberately unchanged: they did not move.

### Added

- A pull request that changes what a deployment is built from or how it is checked - `docker/`,
  `nginx/`, `config/`, `.github/`, the compose files, `.env` or the helper scripts - has to add an
  entry here or carry the
  `no-changelog` label; CI checks it. `RELEASING.md` describes how a bump is done and where this
  repository sits in the ecosystem's release order.
- Dependabot watches the pinned actions and the Ubuntu base images of both Dockerfiles.
- Both compose files declare healthchecks for `mongodb` and `mcrit-server`, and every dependent
  service waits for them rather than for the container to merely exist. The old `sleep 1` at the
  top of each entry script is gone with them.
- `docker-compose.yml` sets `restart: unless-stopped` on every service, so a deployment comes back
  after a host reboot. The development compose file deliberately does not.
- `.dockerignore` in both build contexts, so only the entry scripts are sent to the daemon.
- **`docker-compose.yml` caps every service's logs** at 5 files of 50 MB on the `json-file` driver,
  through one `x-logging` anchor, so a chatty container cannot fill the host's disk. Every service
  also runs with `no-new-privileges:true`.
- `MCRIT_AUTH_TOKEN` is passed through to `mcrit-server` and `mcrit-worker` from the environment,
  defaulting to empty. Only the server enforces it today - the worker reaches MongoDB directly -
  but both halves of one image are configured alike. MCRITweb has no matching variable: it stores
  the token per server in its own database, so it has to be set once in *Administration -> Server*
  to the same value. The README's production checklist says so.
- A `lint` job in CI: hadolint on both Dockerfiles, `docker compose config -q` on both compose
  files, and shellcheck over every `.sh`. `.hadolint.yaml` records why apt and pip version pinning
  are not enforced here.
- **An untracked `./config.local/` overlays the shipped `./config/`**
  ([#8](https://github.com/danielplohmann/docker-mcrit/issues/8)). The containers no longer mount
  `config/` over the installed package: they copy the shipped defaults into it at startup and then
  copy `config.local/` on top, so a deployment's own settings survive a `git pull` instead of
  colliding with it, and `config/` stays a reviewable default rather than a file every operator
  edits. Only the files actually overridden belong in `config.local/`, as whole modules.
- **Every MCRIT container reports configuration drift at startup**
  ([#8](https://github.com/danielplohmann/docker-mcrit/issues/8)). The image keeps a copy of the
  configuration the installed MCRIT ships, and the entry scripts compare the settings it defines
  against the assembled configuration, printing
  `WARNING: <file>.py is missing settings the installed MCRIT defines: ...` for each module that has
  fallen behind. It warns rather than fails: a missing setting is a deployment that is
  silently not using an upstream default, not a reason to refuse to start.
- **A tracked `mongodb/mongod.conf`**, mounted read-only at `/etc/mongod.conf`
  ([#3](https://github.com/danielplohmann/docker-mcrit/issues/3)), so MongoDB's settings are a file
  to edit rather than flags to append to a `command:` list. It carries a commented-out
  `storage.wiredTiger.engineConfig.cacheSizeGB`, which is the setting worth revisiting on a host
  MongoDB shares - the default cache is about half of RAM minus 1 GB. `mongod` still logs to
  stdout: the file deliberately sets no `systemLog.path`.
- **NGINX compresses text responses** ([#9](https://github.com/danielplohmann/docker-mcrit/issues/9)):
  `gzip on` for HTML, CSS, JavaScript, JSON and SVG above 1 KB, with `gzip_vary` so caches key on
  the encoding and `gzip_proxied any` so it applies to the proxied MCRITweb responses, which is all
  of them.

### Changed

- CI pins `actions/checkout` to a commit SHA, no longer keeps the checkout's credentials on the
  runner, and runs with a read-only token. It now builds both images with Buildx and a GitHub
  Actions layer cache, reading the tags from `.env` instead of restating them.
- **MongoDB moves from 5.0 to 8.0.** A fresh instance needs nothing. An existing
  `./storage/mongodb` cannot jump there in one go - MongoDB refuses to skip a major version - so it
  has to be stepped `5.0` -> `6.0` -> `7.0` -> `8.0`, raising `featureCompatibilityVersion` at each
  step; see *Upgrading MongoDB from 5.0* in the README, or `./reset.sh` if the corpus is
  disposable. `mongod` now logs to stdout, so `docker compose logs mongodb` shows what it is doing
  and `logs/mongodb/` is gone.
- **MCRITweb is served by gunicorn** (2 workers, 8 threads each, 300 s timeout) instead of the
  Flask development server, which was never meant to take production traffic. The image installs
  gunicorn explicitly because MCRITweb's `requirements.txt` does not list it, and no longer sets
  `FLASK_DEBUG=1` - the development compose file's entry script exports it where it belongs.
- **NGINX is pinned to `nginx:${NGINX_TAG}` (`1.29-alpine`) instead of `nginx:latest`**, so an
  upgrade is a reviewable change to `.env` rather than whatever a pull happened to fetch. Every
  interpolated tag in both compose files is now `${VAR:?}`, which fails the run with a named
  variable instead of silently resolving to `image:`.
- `nginx/mcritweb_ssl.conf` serves TLS 1.2 and 1.3 with the Mozilla intermediate cipher list and
  `ssl_prefer_server_ciphers off`. `ssl_dhparam` is dropped along with the DHE suites that needed
  it, and HSTS no longer asks for `preload` - that is a decision for whoever owns the domain, not
  a default.
- The MCRIT server and worker run from one `mcrit:${MCRIT_TAG}` image built once by `mcrit-server`,
  rather than two identical images built twice. `build.sh` and `test_build.sh` build through
  `docker compose` accordingly.
- Both Dockerfiles build as one apt layer with the package lists removed afterwards, clone shallow,
  and cache pip downloads across builds. `apt-get upgrade` is gone: it defeats layer caching and
  makes the base-image pin a suggestion. `gcc-multilib` is no longer installed: nothing needs a
  32-bit toolchain, and the package does not exist on arm64, so the images now build on Apple
  Silicon and other arm64 hosts.
- The entry scripts run under `set -eu` and `exec` their long-running process, so signals reach it
  and `docker compose stop` is not a ten-second wait. The mcrit services run under `init: true`,
  because a Python process as PID 1 has no default `SIGTERM` handler and would ignore the signal.
- **Both images are built in two stages and run as a non-root user.** A `builder` stage carries the
  toolchain and installs into a `/opt/venv` virtualenv; the runtime stage starts from the same base
  and adds only what running needs, copying the venv and the source across. That takes the MCRIT
  image from 1.19 GB to 714 MB and the MCRITweb image from 1.28 GB to 787 MB. Both run as uid
  10001 at the end, which makes `./storage/mcritweb` - a host bind mount - something the operator
  has to hand over once: `chown -R 10001:10001 storage/mcritweb`. The MCRITweb entry scripts exit
  with that command in the message rather than failing obscurely later. MCRIT stays an editable
  install, because the entry scripts assemble the configuration into the package's own
  `mcrit/config/` and that has to be what the running package reads.
- The base images are pinned by digest rather than by the `24.04` tag, so a rebuild cannot silently
  pick up a different Ubuntu. Dependabot proposes the digest bumps. Both images carry
  `org.opencontainers.image.source`, `.version` and `.licenses`, and record the commit they were
  built from in `/opt/mcrit/.git-revision` and `/opt/mcritweb/.git-revision` - a label cannot hold
  a value resolved during the build.
- `entry_test.sh` no longer installs pytest at startup: the non-root runtime user cannot, and the
  image carries it. It runs `pytest -m 'not mongo'` directly, which is what `make test-nomongo`
  runs, so the image needs no `make`.
- The NGINX configuration is mounted read-only, and so are the two configuration directories the
  MCRIT containers assemble their configuration from.

### Removed

- **`nginx/ssl/*.pem` are no longer tracked**; the placeholders ship as `*.pem.example` and the
  real files are gitignored, so a private key cannot be committed by accident. Copy the examples
  and fill them in. `dhparam.pem` is not needed any more and is gone.
- `FLASK_ENV` is unset everywhere. It has done nothing since Flask 2.3, and the value here was a
  filesystem path.

## [2026-09-08] - MCRIT 1.9.0, MCRITweb 1.4.8

Correctness and operator-recovery release upstream, plus a large `getUniqueBlocks` speedup. **No
migration, no re-index and no database shape change**, and matching results are unchanged at default
configuration - verified byte-for-byte on an 11.6M-function corpus.

### Changed

- `.env` tracks MCRIT `1.9.0`; MCRITweb stays at `1.4.8` and works unchanged against it. New
  endpoints arrive with 1.9.0, so MCRITweb needs a matching release to *use* them.
- `config/` regenerated from 1.9.0 stock. The only intentional deviations remain
  `STORAGE_SERVER`/`QUEUE_SERVER` pointing at the `mongodb` service and `BAND_MATCHES_REQUIRED = 1`.
- The comment on `BAND_MATCHES_REQUIRED` no longer defers the choice "until the reworked banding
  lands" - it landed in 1.9.0. `k` is query-time, so one index serves every operating point, and the
  measured ones are hunt `k=1`, identification `k=2-3`, fast `k=5`. Which to ship as a default is a
  product decision, so the value is unchanged.

### Added

- `config/BandPresets.py`, **which is required, not optional**: 1.9.0's `StorageConfig` imports
  `BAND_PRESETS` from it, and this deployment bind-mounts `./config/` *over* the package's own config
  directory - so a config folder without that file makes server and worker fail to import at startup.

### Upgrading

**Rebuild the mcrit images**, and **merge the regenerated `config/` rather than keeping your own copy
wholesale** - see the new required file above.

**The first `/status` will report every sample as having stale minhashes, and that is usually
wrong.** 1.9.0 decides staleness from a per-sample `minhash_smda_version` that did not exist before,
and a sample without one counts as stale. Do not answer that by running `repair_minhashes`, which
rehashes the whole corpus for hours; check whether the minhashes really are stale and, if they are
current, record it with `setMinHashVersionForSamples(<running smda version>)` instead. Observed on an
8,693-sample instance: every sample reported stale, actual drift 0.000%, and the stamp took seconds.

Five one-time operator actions are available, none automatic and none required for correct serving:

| action | effect |
|---|---|
| `rebuild_picblockhash_index` | enables the fast `getUniqueBlocks`; until it runs the previous full scan is used, so upgrading changes performance and never results |
| `recompute_family_stats` | corrects per-family counters that have already drifted |
| `repair_minhashes` | rehashes only the samples an older escaper hashed - read the note above first |
| `purgeEmptyBandDocuments()` | clears the band tombstones older deletions left |
| `db.functions.dropIndex("_picblockhashes.offset_1")` | reclaims an index no query could use |

Measured on the reference instance after upgrading: the index rebuild took ~4 minutes and produced
12,140,807 documents (0.51 GB plus 0.29 GB of index), taking `getUniqueBlocks` for one sample from
**94.7 s to 0.18 s**.

## Older updates

Entries below predate this format and are kept verbatim, newest first. They record which MCRIT and
MCRITweb each pull shipped, and what a deployer had to do about it.

 * 2026-08-25: MCRIT 1.8.1 (packaging and latent-bug release, no migration, no re-index and no database shape change; matching results are unchanged. **1.8.0 is skipped deliberately** - it does not declare `packaging`, which `MongoDbStorage` imports, so a server or worker built from it cannot start; 1.8.1 declares it. **Rebuild the mcrit images rather than pulling code** - MCRIT no longer ships `requirements.txt`, its dependencies are declared in `pyproject.toml`, and the Dockerfile installs them in one step accordingly; a build against the old Dockerfile fails on the missing file. The shipped `config/` copies are regenerated from 1.8.0 stock, so **merge rather than overwrite if you have edited them locally** - the only intentional deviations are `STORAGE_SERVER`/`QUEUE_SERVER` pointing at the `mongodb` service and `BAND_MATCHES_REQUIRED = 1`, which is left as it was and now says so in a comment. `AUTH_TOKEN` can now be supplied through the `MCRIT_AUTH_TOKEN` environment variable instead of being edited into the config, and the API token is compared in constant time - note that actually locking the API down in this deployment also needs MCRITweb's matching apitoken set, so the variable alone changes nothing here, and the API is only bound to `127.0.0.1` regardless. Adopting the `ty` type checker in CI turned up eleven latent bugs, all fixed: five `MemoryStorage` methods that raised on every call, a corrupt pichash entry written on import, a server that could not start where gunicorn is absent, and a query-sample deletion that reported success as failure ([mcrit#102](https://github.com/danielplohmann/mcrit/issues/102)). Malformed search queries answer HTTP 400 with the parser's message instead of a 500 and a traceback, and unique-block requests report `yara_covers` for real rather than always `0`), MCRITweb 1.4.8
 * 2026-08-24: MCRIT 1.7.1 (bugfix release, no migration, no database shape change and no new settings - the shipped `config/` copies are unchanged apart from `VERSION`, so a local merge is not needed this time. Search conditions on `pichash` are served instead of raising: `=`, `!=` and substring searches work, while range comparisons such as `pichash:<0x99` are rejected with a message, because the stored form is variable-width hex on which comparisons are not meaningful (see [mcrit#145](https://github.com/danielplohmann/mcrit/issues/145)). The search endpoints now answer an unsupported query with HTTP 400 and that message instead of a 500 and a traceback; `McritClient` treats both as no result, so nothing downstream changes. Cross-compare reports no longer emit phantom rows for samples outside the requested set. Sorting a function search by pichash is now refused on the MongoDB backend rather than returning a mis-sorted first page and failing on the second - the MCRITweb function table has no sortable Pichash column, so the UI here is unaffected and only a client calling the API with `sort_by=pichash` notices), MCRITweb 1.4.8
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
