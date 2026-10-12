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

## [2026-10-12] - MCRIT 1.15.0, MCRITweb 1.5.0

MCRIT 1.15.0 is a minor release with no repair jobs and no change to matching results. It makes
`recalculatePicHashes` remember which samples it rehashed, fixes `McritClient.awaitResult` for a
failed job and the client's handling of a non-JSON success answer, reuses one HTTP connection per
client, lets families carry `actors`, can keep submitted binaries, and keeps the query cleanup
working past a job without a result. MCRITweb 1.5.0 works against it unchanged: none of the REST
API it uses changed.

### Upgrading

- **The first start builds five new indexes**: three on `samples`, and two for the
  `sample_binaries` GridFS bucket, which is created whether or not binaries are kept.
- **The next `recalculatePicHashes`, including one started by `repair.sh`, is still about a full
  pass**, because no sample carries the new stamp yet. Runs after that select only what changed.
  Nothing requires running it for this upgrade.
- **Three new settings in `config/StorageConfig.py`, all off by default:**
  - `STORAGE_KEEP_SUBMITTED_BINARIES` keeps every binary submitted through `/samples/binary` in
    MongoDB, so `./storage/mongodb` grows by the size of the submissions.
  - `STORAGE_SERVE_SUBMITTED_BINARIES` makes the API hand those binaries out. On most instances they
    are malware, so turn it on only when the API is not reachable by anyone who should not
    download them.
  - `STORAGE_MONGODB_COMPACT_AFTER_CLEANUP` needs the `compact` privilege.

  A `config.local/StorageConfig.py` copied from an earlier release lacks these three, and the
  containers say so at startup. Add them to it.

### Changed

- `config/` and `docs/TUNING.md` follow MCRIT 1.15.0. `config/StorageConfig.py` gains the three
  settings above, and `docs/TUNING.md` gains the sections on keeping submitted binaries and on
  reclaiming space after the query cleanup.

## [2026-10-09] - MCRIT 1.14.0, MCRITweb 1.5.0

MCRIT 1.14.0 is a minor release: it adds a report of what the band df cutoff skips
(`GET /band_df_cutoff_coverage`, `McritClient.requestBandDfCutoffCoverage()`), and it fixes the
logbucket settings, unique blocks in memory mode, upper band buckets lost under the df cutoff, a
function stored without disassembly failing the whole minhash batch around it, and job and result
lookups with the memory queue. MCRITweb 1.5.0 works against it unchanged: the release adds REST API
and changes none that MCRITweb uses.

### Upgrading

- **On this deployment's configuration, nothing to run.** There are no new indexes, no change to
  `RESULTS_VERSION` and no repair jobs. Rebuild the images and restart.
- **If `config.local/` sets `SHINGLER_LOGBUCKETS` or `SHINGLER_LOGBUCKET_RANGE` away from their
  defaults, re-index after upgrading, and regenerate any exports taken from this instance.** Before
  1.14.0 the installed package always hashed with the default table, whatever those two said, so
  the stored MinHashes no longer agree with what the instance now computes.
- **If `config.local/` sets `STORAGE_BAND_BUCKET_SIZE` and band documents were ever deleted, run
  `rebuild_band_df_index` once.** It recreates a missing bucket 0, which the df cutoff and the new
  coverage report otherwise cannot see.

### Changed

- `config/` and `docs/TUNING.md` follow MCRIT 1.14.0. The only config change is
  `McritConfig.VERSION`; `docs/TUNING.md` gains the section on measuring the df cutoff.

- `repair.sh` waits for each repair job itself and reports a failed or terminated job with its last
  error, instead of relying on `McritClient.awaitResult`. That call requests `/results/None` for a
  failed job, so the script died with a 400 traceback (mcrit#252). It also reads
  `QUEUE_SPAWNINGWORKER_CHILDREN_TIMEOUT` and warns when it is under 3 h, and says so before it starts.
  This image's worker runs `mcrit worker`, which has no such limit, but a deployment that overrides the
  worker to `mcrit spawningworker` kills a job's process at that timeout (stock 1 h) and retries it from
  scratch. A `recalculatePicHashes` of about 1 h 50 min on an 11.7M-function corpus was killed twice
  that way and then failed. Raise the timeout before running `repair.sh` there. Exercised end to end
  against a throwaway 1.13.0 server and worker.

## [2026-09-30] - MCRIT 1.13.0, MCRITweb 1.5.0

MCRIT 1.10.0 through 1.13.0 in one bump: two-stage matching and per-request presets, band posting
lists that can outgrow one document, matching kept within one architecture, typed client errors and
timeouts, and the batch lookups and `/jobs` selectors MCRITweb's next release uses. **Matching results
change, and the upgrade from 1.9.x has an order** - see Upgrading. MCRITweb stays at 1.5.0: its full
suite passes unchanged against the 1.13.0 client (962 passed, 6 skipped).

### Added

- `repair.sh` runs the three repair jobs MCRIT 1.13 asks for - `recalculatePicHashes`,
  `rebuildPicBlockHashIndex`, `repairMinHashes` - in that order inside the `mcrit-server` container,
  waits for each, and checks `/status` until `num_samples_with_stale_minhashes` and
  `num_samples_with_stale_picblockhashes` are both 0. Exercised end to end against a throwaway 1.13.0
  server and worker. `migrate.sh` remains the 1.7.0 disassembly split.

### Changed

- `config/` regenerated from MCRIT 1.13.0 stock, keeping the three deviations (`STORAGE_SERVER`,
  `QUEUE_SERVER`, `BAND_MATCHES_REQUIRED = 1`). New settings arrive at their stock defaults, all
  result-preserving or off: `STORAGE_BAND_BUCKET_SIZE`, `STORAGE_BAND_DF_CUTOFF`,
  `MINHASH_MATCHING_SHORTLIST_SIZE`, `STORAGE_REBUILD_PARTITION_SIZE`,
  `QUEUE_SPAWNINGWORKER_CHILD_MAX_MEMORY` among them. The `BAND_MATCHES_REQUIRED` comment is
  updated: since 1.13 the server resolves this default into every job that does not name `k`, and the
  per-request presets `hunt` and `identification` both use k=1. **If you have edited `config/`
  locally, merge rather than overwrite.**
- `docs/TUNING.md` mirrored from MCRIT 1.13.0.

### Upgrading

From MCRIT 1.9.x. Rehearsed on a copy of an 8,699-sample / 11.7M-function corpus whose reports go
back to smda 1.9, with MCRIT 1.13.0, smda 4.9.0, picblocks 2.1.0 and capstone 5.0.9 - what a rebuild
of these images installs:

1. **Rebuild both MCRIT images; do not pull code into old ones.** picblocks 2.1.0 is the floor now.
   smda 4.9.0 escapes Intel, AArch64, CIL and Dalvik exactly as 4.5.0 did - the escaper fingerprints
   are unchanged and so is every rehashed MinHash and PicHash - so the fingerprint check under
   Upgrading in the README should show no change. **Upgrade server and worker together**: the server
   now resolves the matching defaults, and an older worker fails matching jobs on arguments it does
   not know.
2. **The first start builds indexes before storage answers**: 34 new ones from 1.9.x, in 7.5 min on
   that corpus. Wait for it before judging the instance unhealthy.
3. **Run `./repair.sh`** once: 1 h 46 min, 5 min and 6 s on that corpus. On a corpus with reports
   older than smda 4.4.5 the first step is a full pass. It is worth it beyond housekeeping: it rewrote
   435,122 function PicHashes there, 357,474 of them in the 376 Intel samples whose reports came from
   smda 1.9.x (62% of their functions) - exact matching against such samples had been largely broken,
   because earlier repairs rehashed their MinHashes but never their PicHashes. **Run it once**: MCRIT
   1.13 selects most samples again on a second run, so a repeat costs the full pass again.
4. **Serve matching after the repairs.** Every cached match is recomputed once after this upgrade,
   because job keys now hold the values a job runs with and a results version; job caches do not key
   on corpus data, so a match computed before `repair.sh` finishes would keep the old PicHashes.

**MongoDB is independent of this.** MCRIT 1.13 matches byte-identically on 5.0 and on 8.0, so the
5.0 -> 8.0 steps in the README can be a window of their own, before or after. Rehearsed on the same
44 GB corpus: each step took 3-4 s to start and at most 1 s to raise the compatibility version, with
counts and all 128 indexes intact. Stop MongoDB with a timeout between steps (`docker compose down
-t 60`); the default 10 s can kill a busy `mongod` and force a journal recovery.

## [2026-09-23] - MCRIT 1.9.0, MCRITweb 1.5.0

MCRITweb 1.5.0: 46 pull requests, four security fixes and the function comparison view,
alongside this repository's own modernization. **The MCRITweb upgrade migrates its database
and needs one setting before it is deployed** - see Upgrading.


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


### Upgrading

**Set `TRUSTED_PROXY_COUNT` before deploying this.** MCRITweb 1.5.0 meters failed logins per source
address, reading that address from `X-Forwarded-For` only as far back as the setting allows. It
defaults to `0` - "served directly, trust no header" - and this deployment is never served directly:
both shipped NGINX configurations proxy to `mcritweb:5000`. At `0`, MCRITweb sees NGINX's container
address for every request, so **ten failed logins from anywhere refuse everyone's next login for
fifteen minutes** and nothing is metered per attacker. Put it in `storage/mcritweb/config.py`:

```python
TRUSTED_PROXY_COUNT = 1
```

`1` is the count for this deployment as shipped; add one for each further proxy in front of it, such
as a site load balancer or a CDN. Too low meters every user together, too high lets a caller choose
their own throttle key, so it is worth counting. Development mode starts no NGINX, so an instance
reached directly on port 5000 wants the default. Verify rather than assume: make one deliberately
failed login **through the proxy**, then read what was recorded and clear it again.

```bash
docker exec mcritweb python3 -c "
import sqlite3
c=sqlite3.connect('/opt/mcritweb/instance/mcritweb.sqlite')
for r in c.execute('select remote_addr, username, attempted_at from login_attempt'): print(r)"
```

A real client address means the count is right; NGINX's container address means it is too low. The
throttle cannot be turned off - its limit and window are constants in MCRITweb, not settings.

**MCRITweb migrates its own database on first start**, through idempotent migrations that alter
nothing existing: a `login_attempt` table, a `query_upload` table, and user timestamps rewritten as
explicit UTC. No operator action beyond restarting, but **back up `storage/mcritweb/mcritweb.sqlite`
first** - it holds every account and API token, and is tens of kilobytes.

**Existing query uploads are orphaned, and may be the only copy.** Until 1.4.8 a query upload was
stored in `storage/mcritweb/temp/uploads/` under a SHA-256; 1.5.0 files it under the backend-issued
job id, because the old scheme let any visitor overwrite another user's stored query by naming an
upload after it. Every pre-upgrade file is unreachable, and nothing prunes that folder. A query made
before the upgrade can no longer be promoted to a stored sample. **These are the submitted binaries
themselves, and MCRIT never stored them** - a query does not add to the corpus - so copy them out
before deleting. The filenames are genuine digests of the contents, so they stay identifiable.

Measured on the reference instance: 33 accounts migrated intact; 741 orphaned uploads totalling
494 MB dating back to 2023-05-08, of which 669 were PE and 36 ELF.

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
