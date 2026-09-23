# Docker MCRIT
[![Test](https://github.com/danielplohmann/docker-mcrit/actions/workflows/test.yml/badge.svg)](https://github.com/danielplohmann/docker-mcrit/actions/workflows/test.yml)

This repository is the Docker deployment of the MinHash-based Code Recognition and Investigation
Toolkit. `docker-compose.yml` runs five services: MongoDB, the
[MCRIT](https://github.com/danielplohmann/mcrit) server and worker (one image, built here from the
upstream tag), the [MCRITweb](https://github.com/fkie-cad/mcritweb) frontend behind gunicorn, and
NGINX in front of it. The versions are pinned in `.env` - `MCRIT_TAG`/`MCRIT_BRANCH`,
`MCRITWEB_TAG`/`MCRITWEB_BRANCH`, `MONGO_TAG` and `NGINX_TAG` - and moving them is how an upgrade
is done. MCRIT itself was released at Botconf 2023
([paper](https://journal.cecyf.fr/ojs/index.php/cybin/article/view/45),
[slides](https://www.botconf.eu/wp-content/uploads/formidable/2/2023-15-Plohmann_MCRIT.pdf),
[video](https://www.youtube.com/watch?v=kvBHbXZZq2c&list=PL8fFmUArVzKhanPzq5HlGAUHhzRB3qDLE&index=24&ab_channel=botconfeu));
for using it, see the documentation in the two upstream repositories.

## Requirements

Docker Engine with the Compose v2 plugin, so that `docker compose` works. The images build on
amd64 and arm64. Disk is the sizing constraint: `./storage/mongodb` grows with the indexed corpus,
and MongoDB's cache defaults to about half of the host's RAM.

## First deployment

```bash
git clone https://github.com/danielplohmann/docker-mcrit.git
cd docker-mcrit
chown -R 10001:10001 storage/mcritweb
docker compose up -d
```

The containers run as uid 10001, so `./storage/mcritweb` - a host bind mount holding MCRITweb's
SQLite database and cached reports - has to be handed to that uid once; MCRITweb refuses to start
with that command in the message otherwise. The first `up` builds both images, which takes a while.

NGINX publishes ports 80 and 443. MongoDB, the MCRIT API on 8000 and MCRITweb on 5000 are published
on the loopback interface only. Register the first account through the web interface; it becomes
the administrator.

## Configuration

`.env` holds the version pins and is read by both compose files. `MCRIT_AUTH_TOKEN` is read from
the environment or from `.env` and passed to the server and the worker.

`config/` holds MCRIT's configuration modules and is mounted read-only over the installed package's
own `mcrit/config/`. The deviations from MCRIT's stock configuration are `STORAGE_SERVER`,
`QUEUE_SERVER` and `BAND_MATCHES_REQUIRED`, each carrying a comment saying why. `docs/TUNING.md`
mirrors the upstream tuning guide.

NGINX serves plain HTTP by default, which is meant for a first look. For TLS, copy
`nginx/ssl/fullchain.pem.example` and `nginx/ssl/privkey.pem.example` to the same names without the
`.example` suffix, fill them with the certificate and key, and in the `nginx` service of
`docker-compose.yml` swap the `mcritweb_plain.conf` mount for the two commented-out `mcritweb_ssl`
lines. The `.pem` files are gitignored. Both site configurations listen for `server_name localhost`
and reject other hosts, so set the deployment's name in whichever one is in use.

## Running in production

Serve over TLS as described above. Set `MCRIT_AUTH_TOKEN`, which makes the MCRIT server reject
unauthenticated requests; MCRITweb has no matching variable, because it keeps the token per server
in its own database, so after the first start put the same value under *Server* in the
administration menu, at *Change Backend Server*; the form that creates the first account asks for
it as well. Until both sides carry it, MCRITweb's own calls are rejected too. Passing the token
through the compose environment puts it where `docker inspect` and `docker compose config` show it,
so anyone with access to the Docker host has the token: treat host access as equivalent to API
access.

Log rotation needs nothing: every service logs to the `json-file` driver capped at five files of
50 MB. Back up `./storage/mongodb`. A file-level copy is only valid with everything stopped; for a
running instance, stream a dump out:

```bash
docker compose exec -T mongodb mongodump --archive --gzip > mcrit-dump.archive.gz
```

## Upgrading

An MCRIT or MCRITweb bump is a change to the pins in `.env` together with a `CHANGELOG.md` entry;
`RELEASING.md` describes the procedure, including regenerating `config/` and what the changelog
entry has to say. `CHANGELOG.md` is where a release states whether it needs a migration - the
disassembly split that `./migrate.sh` completes is one such step.

`MONGO_TAG` is `8.0`. A fresh instance needs nothing. An existing `./storage/mongodb` written by
5.0 cannot be opened by 8.0 directly, because MongoDB refuses to skip a major version: step it
`5.0` -> `6.0` -> `7.0` -> `8.0`, raising `featureCompatibilityVersion` before each next step. Back
up first; raising the FCV is not reversible. For each of `6.0`, `7.0` and `8.0` in turn:

```bash
docker compose down
sed -i 's/^MONGO_TAG=.*/MONGO_TAG=6.0/' .env     # then 7.0, then 8.0
docker compose up -d --wait mongodb
docker compose exec mongodb mongosh --quiet --eval 'db.adminCommand({setFeatureCompatibilityVersion: "6.0"})'
```

From 7.0 onwards the command also requires `confirm: true`, so those two steps read
`{setFeatureCompatibilityVersion: "7.0", confirm: true}`. If the corpus is disposable, `./reset.sh`
discards it instead.

### Check the SMDA escaper fingerprint after any rebuild

MCRIT does not pin SMDA, so rebuilding the images can pull a newer SMDA whose instruction escaping
differs. MinHashes are derived from the escaped representation, so when the escaping changes,
previously indexed signatures stop being comparable to newly computed ones. **The failure is silent**:
the old signatures still look valid and still match each other, while identical code submitted
afterwards no longer finds them. SMDA 4.4.5 is the worked example - it corrected how
segment-qualified memory operands are escaped, and altered about a fifth of the stored MinHashes on
a real corpus.

`/status` reports what the running build produces, so note it after a build and compare it after the
next one:

```bash
curl -s http://127.0.0.1:8000/status | python3 -m json.tool | grep -E "smda_version|escaper_fingerprint"
```

An unchanged fingerprint means stored MinHashes stay valid across the rebuild and nothing is owed. A
changed one means the index should be re-minhashed to stay internally consistent - the stored
disassembly makes that a local recomputation, with no need to re-submit any samples.

## Development mode

`docker-compose-dev.yml` runs MCRIT and MCRITweb from host checkouts under `./repositories`, so
edits take effect without rebuilding. Clone them first, then start the stack:

```bash
./clone_repositories.sh
docker compose -f docker-compose-dev.yml up
```

It starts no NGINX: MCRITweb is on port 5000 and the MCRIT API on port 8000, both on loopback.

## Version history

[CHANGELOG.md](CHANGELOG.md) records which MCRIT and MCRITweb a pull now gives you, what changed in
the deployment itself, and what an upgrade requires.

This repository is licensed under the GNU General Public License v3, see [LICENSE](LICENSE).
