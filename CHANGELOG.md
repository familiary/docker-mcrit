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
