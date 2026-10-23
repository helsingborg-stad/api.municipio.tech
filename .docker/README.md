# Municipio Docker image

This repository builds a ready-to-run [Municipio](https://github.com/municipio-se/municipio-deployment) WordPress image. The image contains OpenLiteSpeed, PHP, WordPress, WP-CLI, and the checked-out deployment source. Composer, Node.js, npm, and Git are used only while building the image and are not included in the runtime image.

On its first start, the container connects to the database, installs WordPress, and activates ACF Pro automatically. Later starts reuse the existing database and ensure that ACF Pro remains active.

## Before you start

You need:

- Docker with Docker Compose
- An ACF Pro license key used to download ACF Pro while building the image
- A checkout of the Municipio deployment revision you want to package

Set the ACF Pro key in your shell. Docker passes it to the build as a temporary BuildKit secret, so it does not need to be written into the Compose file or stored in the image:

```sh
export ACF_PRO_KEY="your-license-key"
```

## Building the image directly

From the repository root, you can build the currently checked-out, committed revision without Compose. `git archive` keeps untracked local data out of the build context:

```sh
git archive HEAD | docker build \
  --secret id=acf_pro_key,env=ACF_PRO_KEY \
  -f .docker/Dockerfile \
  -t municipio:local -
```

The `acf_pro_key` secret is required for the build. It is mounted only while Composer installs the dependencies and is not retained in the resulting image.

The deployment source is copied into the image when it is built. Rebuild after checking out a different revision to change the version in the image. For a direct build of working-tree files instead, use `docker build --secret id=acf_pro_key,env=ACF_PRO_KEY -f .docker/Dockerfile -t municipio:local .`; the root `.dockerignore` filters common local and sensitive files, but the tracked-file archive is preferable for publishing.

## Common settings

Runtime settings use the `WP_CONF_` prefix. The most useful ones are:

| Setting | Purpose |
| --- | --- |
| `WP_CONF_DB_NAME` | Database name. |
| `WP_CONF_DB_USER` | Database user. |
| `WP_CONF_DB_PASSWORD` | Database password. |
| `WP_CONF_DB_HOST` | Database service name or host. |
| `WP_CONF_WP_HOME` | Public address of the site. |
| `WP_CONF_WP_SITEURL` | Address of WordPress core, normally the site address followed by `/wp`. |
| `WP_CONF_WP_ADMIN_USER` | Admin username created on the first start. |
| `WP_CONF_WP_ADMIN_PASSWORD` | Admin password created on the first start. |
| `WP_CONF_WP_ADMIN_EMAIL` | Admin email created on the first start. |
| `WP_CONF_WP_DEBUG` | Set to `true` to enable WordPress debugging. |
| `WP_CONF_WP_REDIS_DISABLED` | Set to `true` when no Redis or Valkey service is used. |
| `ENABLE_LS_CACHE` | Set to `true` to enable LiteSpeed Cache plugin and include LiteSpeed rewrite rules when `.htaccess` is first created. |
| `ENABLE_PHP_TIDY` | Set to `true` to install the Tidy extension for the current LiteSpeed PHP version on startup (requires access to the package repository). |

The database and admin values are only used to perform the initial installation. If a database volume already contains WordPress, changing the initial admin values will not update the existing account.

On startup, `.htaccess` is created from the selected single-site or multisite template only if it does not already exist. Existing files, including plugin-generated rules and ownership, are left untouched; changing multisite or cache settings does not rewrite them. An installed site with a missing `.htaccess` receives the template without a WordPress rewrite flush.

Any additional WordPress constant can be defined with `WP_CONF_EXTRA_`. For example, `WP_CONF_EXTRA_MY_SETTING: enabled` defines the `MY_SETTING` constant.

## Multisite

Multisite is optional. Add these settings to the `municipio` service to enable a subdomain network:

```yaml
environment:
  WP_CONF_WP_ALLOW_MULTISITE: true
  WP_CONF_SUBDOMAIN_INSTALL: true
  WP_CONF_DOMAIN_CURRENT_SITE: localhost:9090
```

For a real domain, make sure its DNS and local development setup route subdomains to the Docker host. Subdomain multisite on `localhost` may behave differently between browsers and operating systems.

## Examples

The [`examples/`](examples/) directory contains ready-to-run Compose files that build on the base setup above. They use the repository root as their build context (`../..`). Run them from the repository root with `-f`, e.g.:

```sh
export ACF_PRO_KEY="your-license-key"
docker compose -f .docker/examples/docker-compose-base.yml up -d --build
```

Tear an example down, including its volumes, before switching to a different one:

```sh
docker compose -f .docker/examples/docker-compose-base.yml down -v
```

| File | Description |
| --- | --- |
| `docker-compose-base.yml` | Minimal single-site setup: `municipio` plus a MariaDB `db` service, no cache. |
| `docker-compose-using-lscache.yml` | Enables the `litespeed-cache` plugin and applies LiteSpeed Cache `.htaccess` rewrite rules. |
| `docker-compose-using-redis.yml` | Adds a Valkey (Redis-compatible) service and activates the `redis-cache` plugin for object caching. |
| `docker-compose-using-s3.yml` | Adds a MinIO service for S3-compatible media offloading and activates the `s3-uploads`/`s3-local-index` plugins. See the file's comments for the required `S3_UPLOADS_*` constants. |
| `docker-compose-multisite-subfolder.yml` | Enables WordPress multisite (subfolder mode) and creates a `subsite` site on first start. |
| `docker-compose-with-spec-repo-and-branch.yml` | Legacy copy of the basic setup. To select a source repository or branch, check it out locally before building; build arguments no longer fetch another source. |
| `common-services.yml` | Shared `database` and `redis` service definitions, extended by the other examples via `extends`. Not meant to be run on its own. |

## Useful commands

Follow startup logs:

```sh
docker compose logs -f municipio
```

Run WP-CLI as the webroot owner, so files created by commands remain writable by OpenLiteSpeed:

```sh
docker compose exec --user ubuntu municipio wp option get siteurl
```

Use `docker compose exec --user ubuntu municipio <command>` for other commands that write to the webroot. The container starts as root to install optional packages and configure OpenLiteSpeed.

Stop the containers while keeping the database and uploaded files:

```sh
docker compose down
```

Remove the containers, database, and uploaded files, allowing a completely fresh installation next time:

```sh
docker compose down --volumes
```

## Publish an image

Commit the `.docker/` directory, the root `.dockerignore`, and `.github/workflows/build-image.yml` to the repository's default branch so GitHub Actions can display the workflow. Pushing a Git tag automatically builds that tagged revision and publishes an image with the same tag. Alternatively, in the **Actions** tab, open **Build Docker image**, select **Run workflow**, choose the source branch or tag, and enter an image tag such as `v1.2.3` (or any valid Docker tag). For manual runs, the input is the *image* tag; the selected workflow revision supplies the source code. A manual image tag does not automatically resolve to a corresponding source branch or Git tag.

The workflow publishes `ghcr.io/helsingborg-stad/api.municipio.tech:<tag>` for `linux/amd64` and `linux/arm64`. Image tags (including pushed Git tags) must be 1-128 characters starting with a letter, digit, or underscore and containing only letters, digits, underscores, periods, or hyphens; other Git tags, such as those containing slashes, fail validation. It does not automatically add `latest` or other inferred tags. An existing GHCR tag fails the job rather than being overwritten.

Configure the repository's `ACF_PRO_KEY` Actions secret. The workflow uses its built-in `GITHUB_TOKEN` with `contents: read` and `packages: write`; ensure Actions has permission to publish to the GHCR package (especially if the package already exists and is not linked to this repository). It sends the ACF key as a BuildKit secret, not a build argument or image layer. The workflow archives tracked files from the selected checkout, excluding local uploads, ignored configuration, and other untracked files from the published build context.

## Notes for deployed environments

The example is deliberately simple and uses local development credentials. For a shared or public environment:

- Use strong, unique passwords and provide secrets through your deployment platform.
- Put the site behind HTTPS and set `WP_CONF_WP_HOME` and `WP_CONF_WP_SITEURL` to the public HTTPS addresses.
- Pin the MariaDB image and Municipio deployment to versions that you have tested.
- Back up the database and uploads volumes.
- Do not publish the OpenLiteSpeed administration port unless it is specifically needed and protected.
