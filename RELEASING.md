# Releasing docker-mcrit

This repository is a deployment, not a package, and follows the MCRIT ecosystem's release process
in the one way that applies to it: `CHANGELOG.md` is the single authoritative record of what a
pull now gives an operator, and every change to it is written when the change merges, not
reconstructed later. The other ecosystem repositories
([smda](https://github.com/danielplohmann/smda), [purepdb](https://github.com/danielplohmann/purepdb),
[mcrit](https://github.com/familiary/mcrit), [mcritweb](https://github.com/familiary/mcritweb),
[mcrit-plugin](https://github.com/familiary/mcrit-plugin)) release on a `vX.Y.Z` tag; this one
does not carry a version of its own.

## What a release is here

A release is a merged pull request that moves the pinned versions in `.env` and adds a dated entry
to `CHANGELOG.md`. There is no tag and no GitHub release: an operator gets the release by pulling
`main` and rebuilding, and the changelog entry is what tells them which MCRIT and MCRITweb they now
have and what, if anything, they have to do.

## Bumping to a new MCRIT or MCRITweb

Wait for the upstream release to exist - its tag is what the Dockerfiles clone, and its PyPI
version is what the MCRITweb image installs - then, in one pull request:

1. Set `MCRIT_TAG`/`MCRIT_BRANCH` and/or `MCRITWEB_TAG`/`MCRITWEB_BRANCH` in `.env`.
2. Regenerate `config/` from the new MCRIT's stock configuration, keeping this deployment's
   deviations: `STORAGE_SERVER` in `config/StorageConfig.py` and `QUEUE_SERVER` in
   `config/QueueConfig.py` pointing at the `mongodb` service, and `BAND_MATCHES_REQUIRED` in
   `config/MinHashConfig.py`. Each carries a comment saying why; the `CHANGELOG.md` entry for the
   bump that introduced it has the longer rationale.
3. Mirror `docs/TUNING.md` from mcrit if it changed there (CI checks it).
4. In `CHANGELOG.md`, rename `## [Unreleased]` to `## [YYYY-MM-DD] - MCRIT X.Y.Z, MCRITweb A.B.C`,
   carry this repository's own unreleased changes into it, and write the `Upgrading` section from
   the upstream release notes: a migration to run, a re-index, a config key that changed meaning.
   Open a fresh empty `## [Unreleased]` above it.
5. Let CI build both images and run the MCRIT image's self-test, then merge.

## Changes to this repository itself

Dockerfiles, entry scripts, compose files, NGINX, the shipped `config/`, the helper scripts, the
workflows under `.github/`: a pull
request that changes any of them adds a bullet under `## [Unreleased]` or carries the
`no-changelog` label. The `Changelog` check enforces it. Those bullets are carried into the next
dated entry, so an operator reading it sees the deployment changes alongside the version bump.

## Release order across the ecosystem

MCRITweb consumes MCRIT's data classes and pins `mcrit>=1.5.3`; the MCRITweb image installs
`mcrit==MCRIT_TAG` from PyPI and clones MCRITweb at `MCRITWEB_BRANCH`. So the order is: smda (if
MCRIT needs it), then MCRIT, then MCRITweb, then this repository. A bump here that pairs an MCRIT
release with an older MCRITweb is fine when MCRITweb works unchanged against it; the changelog
entry says so, as the 2026-09-08 entry does.

## Maintainer configuration

- **Label** `no-changelog`, used by the changelog check. It does not exist until someone creates
  it, and the check cannot be waived without it:

  ```bash
  gh label create no-changelog --description "Deployment change that genuinely needs no changelog entry"
  ```
