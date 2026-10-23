<!-- Icinga Web 2 Docker image | (c) 2020 Icinga GmbH | GPLv2+ -->

# Icinga Web 2 - Docker image

This image integrates [Icinga Web 2] into your [Docker] environment.

This is the Inuits fork of [Icinga/docker-icingaweb2]. Compared to upstream it:

* is published to `ghcr.io/inuits/docker-icingaweb2` for `linux/amd64` and `linux/arm64`,
* can be built from any Icinga Web 2 commit, tag or branch,
  with library and module versions matching that point in time (see [Building in CI](#building-in-ci)),
* is based on Debian 13 (trixie) with PHP 8.4 and Apache 2.4,
  installing the latest Debian security updates on every build.

## Tags

Tags look like `<ref>-<timestamp>`, e.g. `v2.13.1-20261023065608`:

* `<ref>` is the Icinga Web 2 tag that was built, or the first 12 characters of the commit hash
  if a commit or branch was built.
* `<timestamp>` is the build time (UTC, `YYYYMMDDhhmmss`).

There is no `latest` tag: pin a specific tag in your deployment.
The weekly scheduled build produces `<commit>-<timestamp>` tags from the latest `main`.

## What's inside

* [Icinga Web 2] with these libraries and modules:
  ipl, thirdparty, audit, aws, businessprocess, cube, director, fileshipper, graphite, icingadb,
  idoreports, incubator, kubernetes, L10n, monitoring, notifications, pdfexport, reporting,
  sso, vspheredb and x509.
* `/usr/share/icingaweb2-build-info.txt` lists the exact version and commit of every library and module,
  and the date they were resolved for.
  Modules that did not exist yet at that date are listed as `skipped`.
* `/usr/share/icingaweb2/application/VERSION` contains the Icinga Web 2 commit.
* OCI labels: `org.opencontainers.image.revision` (Icinga Web 2 commit) and `org.opencontainers.image.source`.

To check what an image contains:

```bash
docker run --rm --entrypoint cat ghcr.io/inuits/docker-icingaweb2:<tag> /usr/share/icingaweb2-build-info.txt
docker run --rm --entrypoint php ghcr.io/inuits/docker-icingaweb2:<tag> -v
```

## Usage

```bash
docker run --rm -d \
	-p 8080:8080 \
	-v icingaweb:/data \
	-e icingaweb.enabledModules=icingadb \
	-e icingaweb.passwords.icingaweb2.icingaadmin=123456 \
	-e icingaweb.authentication.icingaweb2.backend=db \
	-e icingaweb.authentication.icingaweb2.resource=icingaweb_db \
	-e icingaweb.config.global.config_backend=db \
	-e icingaweb.config.global.config_resource=icingaweb_db \
	-e icingaweb.config.logging.log=php \
	-e icingaweb.groups.icingaweb2.backend=db \
	-e icingaweb.groups.icingaweb2.resource=icingaweb_db \
	-e icingaweb.modules.icingadb.config.icingadb.resource=icingadb \
	-e icingaweb.modules.icingadb.redis.redis1.host=2001:db8::192.0.2.18 \
	-e icingaweb.modules.icingadb.redis.redis1.port=6379 \
	-e icingaweb.modules.icingadb.commandtransports.icinga2.transport=api \
	-e icingaweb.modules.icingadb.commandtransports.icinga2.host=2001:db8::192.0.2.9 \
	-e icingaweb.modules.icingadb.commandtransports.icinga2.username=root \
	-e icingaweb.modules.icingadb.commandtransports.icinga2.password=123456 \
	-e icingaweb.resources.icingaweb_db.type=db \
	-e icingaweb.resources.icingaweb_db.db=mysql \
	-e icingaweb.resources.icingaweb_db.host=2001:db8::192.0.2.13 \
	-e icingaweb.resources.icingaweb_db.dbname=icingaweb \
	-e icingaweb.resources.icingaweb_db.username=icingaweb \
	-e icingaweb.resources.icingaweb_db.password=123456 \
	-e icingaweb.resources.icingaweb_db.charset=utf8mb4 \
	-e icingaweb.resources.icingadb.type=db \
	-e icingaweb.resources.icingadb.db=mysql \
	-e icingaweb.resources.icingadb.host=2001:db8::192.0.2.113 \
	-e icingaweb.resources.icingadb.dbname=icingadb \
	-e icingaweb.resources.icingadb.username=icingaweb \
	-e icingaweb.resources.icingadb.password=123456 \
	-e icingaweb.resources.icingadb.charset=utf8mb4 \
	-e icingaweb.roles.Administrators.users=icingaadmin \
	-e icingaweb.roles.Administrators.permissions='*' \
	-e icingaweb.roles.Administrators.groups=Administrators \
	ghcr.io/inuits/docker-icingaweb2:<tag>
```

The container listens on port 8080 and expects a volume on `/data`.
It runs as `www-data` (UID 33), so a bind-mounted `/data` must be writable by that UID.
To configure it, do one of the following:

* Run the setup wizard as usual.
  It will store all configuration in `/data/etc/icingaweb2`.
  Hint: `docker run --rm -v icingaweb:/data ghcr.io/inuits/docker-icingaweb2:<tag> icingacli setup token create`
* Provide configuration files in `/data/etc/icingaweb2` by yourself.
  Consult the [Icinga Web 2 configuration documentation]
  on which .ini files there are.
* Provide environment variables as shown above.

### Environment variables

`icingaweb.enabledModules` is a comma-separated set
of the only modules to be enabled.

Variables like `icingaweb.passwords.backend.user=pass`
ensures a user "user" with the password "pass" to be present
in the database authentication backend "backend".

Variables like `icingaweb.dir.subdir.file.section.option=value` create .ini
files like `/data/etc/icingaweb2/dir/subdir/file.ini` with content like this:

```ini
[section]
option = value
```

Consult the [Icinga Web 2 configuration documentation]
on which .ini files there are.

### External authentication

When using `icingaweb.authentication.autologin.backend=external`, the username needs to be passed in the `X-Remote-User` header.

**Warning:** the container trusts this header as-is. Only enable external authentication
behind a reverse proxy that authenticates users and always overwrites (or removes) `X-Remote-User`,
and never expose port 8080 directly. Otherwise anyone can log in as any user by sending the header.

## Building in CI

The [Build workflow](.github/workflows/build.yml) runs every Sunday and can be started manually
(Actions → Build → Run workflow, or `gh workflow run build.yml -f ref=v2.13.1 -f modules_as_of=commit`).

| Input | Default | Meaning |
|---|---|---|
| `ref` | `main` | Icinga Web 2 commit hash, tag (e.g. `v2.13.1`) or branch (e.g. `main`, `support/2.13`). Must be on `main` or a `support/*` branch. |
| `modules_as_of` | `commit` | Which library/module versions to use: `commit` (latest release at the date of the Icinga Web 2 commit), `latest`, or a date `YYYY-MM-DD` (latest release at the end of that day, UTC). |

Scheduled builds use `main` with the `latest` modules.

Each platform is built on a native GitHub runner, pushed by digest,
and then merged into one multi-platform tag.
There is deliberately no layer cache, so every build gets the latest Debian security updates.

## Build it yourself

```bash
git clone https://github.com/Icinga/icingaweb2.git
git -C icingaweb2 checkout v2.13.1

./build.bash ./icingaweb2
```

`build.bash /icingaweb2/source/dir [release|snapshot [local|all|push|digest [IMAGE] [TAG]]]`

* `local` (default) builds for the current platform and loads the image into Docker,
  `all` builds for all platforms in `platforms.txt`, `push` builds and pushes them,
  and `digest` pushes untagged by digest (used by CI), writing build metadata to `$METADATA_FILE`.
* `MODULES_AS_OF` (Unix timestamp) resolves libraries and modules to the latest releases at that moment.
  Empty means the latest releases, e.g.
  `MODULES_AS_OF="$(git -C icingaweb2 show -s --format=%ct HEAD)" ./build.bash ./icingaweb2`.
* `PLATFORMS` overrides `platforms.txt`.

[Icinga Web 2]: https://github.com/Icinga/icingaweb2
[Docker]: https://www.docker.com
[Icinga/docker-icingaweb2]: https://github.com/Icinga/docker-icingaweb2
[Icinga Web 2 configuration documentation]: https://icinga.com/docs/icingaweb2/latest/doc/03-Configuration/
