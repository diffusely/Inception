*This project has been created as part of the 42 curriculum by nor.*

# Inception

## Description

Inception is a small web infrastructure built with Docker Compose. Three containers, each built from
its own Dockerfile on top of Debian 12 ("bookworm", the penultimate stable Debian release), work together
to serve a WordPress website over HTTPS:

| Service     | Role                                                          | Reachable from        |
|-------------|---------------------------------------------------------------|-----------------------|
| `nginx`     | Web server and the only entry point. TLSv1.2 / TLSv1.3 only.  | Outside, port 443     |
| `wordpress` | WordPress + php-fpm (runs the PHP code, no web server inside) | `nginx`, port 9000    |
| `mariadb`   | MariaDB database used by WordPress                            | `wordpress`, port 3306|

Request flow:

```
browser --https:443--> [nginx] --fastcgi:9000--> [wordpress / php-fpm] --sql:3306--> [mariadb]
                          |                              |                              |
                          +---- volume wordpress_data ---+                     volume mariadb_data
```

Persistent data lives on the host in `/home/<login>/data/` (`mariadb/` and `wordpress/`), so it survives
container removal and rebuilds.

### Repository layout

```
.
|-- Makefile                      entry point: build, start, stop, clean
|-- README.md
|-- secrets/                      generated passwords (git-ignored)
`-- srcs/
    |-- docker-compose.yml        services, network, volumes, secrets
    |-- .env                      non-secret settings (git-ignored)
    |-- .env.example              template for .env
    `-- requirements/
        |-- mariadb/              Dockerfile, conf/50-server.cnf, tools/init.sh
        |-- wordpress/            Dockerfile, conf/www.conf,      tools/setup.sh
        `-- nginx/                Dockerfile, conf/nginx.conf.template, tools/entrypoint.sh
```

## Instructions

### Requirements

- Linux (the project is meant to be run inside a virtual machine)
- Docker Engine and **Docker Compose v2** (`docker compose`, not the old `docker-compose`)
- `make`, `git`, `openssl`
- Your user in the `docker` group

### Configuration

1. Copy the template (this is also done automatically by `make` if `srcs/.env` is missing):

   ```
   cp srcs/.env.example srcs/.env
   ```

2. Edit `srcs/.env` and replace `nor` with your own login in `LOGIN`, `DOMAIN_NAME` and the WordPress user
   names / e-mails. `LOGIN` must be the name of the Linux user, because data is stored in `/home/<LOGIN>/data`.
   The WordPress administrator name must not contain `admin`.

3. Point the domain to your machine:

   ```
   echo "127.0.0.1 <login>.42.fr" | sudo tee -a /etc/hosts
   ```

Passwords are not written by hand: `make` generates a random password for each missing file in `secrets/`.

### Usage

| Command       | What it does                                                                     |
|---------------|----------------------------------------------------------------------------------|
| `make`        | Create missing config/secrets, build the images and start everything in the background |
| `make down`   | Stop and remove the containers (data is kept)                                    |
| `make stop` / `make start` | Stop / start the containers without removing them                   |
| `make ps`     | Show container status                                                            |
| `make logs`   | Follow the logs of all containers                                                 |
| `make fclean` | Remove containers, images, volumes **and all data** in `/home/<login>/data`      |
| `make re`     | `fclean` followed by a fresh build                                               |

### Access

- Website: `https://<login>.42.fr` (the certificate is self-signed, so the browser shows a warning;
  accept it to continue)
- Administration: `https://<login>.42.fr/wp-admin`
- Administrator login: the value of `WP_ADMIN_USER` in `srcs/.env`
- Passwords: `secrets/wp_admin_password.txt` (administrator) and `secrets/wp_user_password.txt` (author)

### Quick checks

```
docker compose -f srcs/docker-compose.yml ps         # 3 containers, mariadb is "healthy"
curl -k https://<login>.42.fr                        # HTTP 200
curl -m 3 http://<login>.42.fr                       # fails: port 80 is closed
openssl s_client -connect <login>.42.fr:443 -tls1_1  # fails: only TLS 1.2 / 1.3 are accepted
```

## Project description

### How Docker is used

- Every image is built from a Dockerfile in `srcs/requirements/<service>/`, starting from `debian:bookworm`.
  No ready-made application images (nginx, wordpress, mariadb) are pulled, and the `latest` tag is not used.
- Each container runs exactly one service as its main process (PID 1, in the foreground). Start-up scripts
  prepare the service and then call `exec`, so the real service receives the stop signals.
  No `tail -f`, `sleep infinity` or `while true` loops are used to keep containers alive.
- `restart: unless-stopped` restarts a container if it crashes.
- `mariadb` has a health check; `wordpress` starts only when the database is healthy, and `nginx` after `wordpress`.
- NGINX is the only service that publishes a port (443).
- The TLS certificate is generated when the `nginx` container starts, for the domain from `.env`.

### Design choices compared

**Virtual Machines vs Docker.**
A virtual machine emulates a whole computer and runs its own full operating system with its own kernel:
it is strongly isolated but heavy (gigabytes of disk, slow to boot). A Docker container is just an isolated
process that shares the host kernel (isolation through namespaces and cgroups): it starts in seconds and
uses far less disk and memory, but it is isolated less strongly than a VM. Here the VM is the machine that
hosts Docker, and Docker splits the application into small, reproducible services.

**Secrets vs Environment Variables.**
Environment variables are convenient for non-sensitive settings, but they are visible in `docker inspect`,
inherited by child processes and easy to leak into logs. Docker secrets are files mounted read-only in
`/run/secrets/` inside only the containers that need them and never become part of an image. In this project
the non-sensitive settings (domain, database name, user names) are in `srcs/.env`, and all passwords are
secrets generated into `secrets/` (git-ignored).

**Docker Network vs Host Network.**
With the host network a container shares the network stack of the host: no isolation, and ports can collide.
This project uses a dedicated bridge network `inception`. Containers reach each other by service name
(`mariadb`, `wordpress`) through Docker's internal DNS, and only NGINX publishes a port to the outside.
The database and php-fpm are not reachable from outside the network. (`network: host` and `links` are
forbidden by the subject.)

**Docker Volumes vs Bind Mounts.**
A bind mount maps an arbitrary host path into the container and depends on the host directory layout and
permissions. A named volume is created and managed by Docker and is referenced by name in the Compose file.
The subject requires named volumes whose data is stored in `/home/<login>/data`, so the two named volumes
(`mariadb_data`, `wordpress_data`) use the `local` driver with `device: /home/<login>/data/...` and `o: bind`.
They are declared and managed as volumes, while the data stays at a known place on the host.

## Resources

- Docker documentation: https://docs.docker.com/
- Docker Compose file reference: https://docs.docker.com/compose/
- Dockerfile best practices: https://docs.docker.com/build/building/best-practices/
- NGINX documentation: https://nginx.org/en/docs/
- MariaDB Knowledge Base: https://mariadb.com/kb/en/documentation/
- PHP-FPM manual: https://www.php.net/manual/en/install.fpm.php
- WP-CLI: https://wp-cli.org/
- Debian releases: https://www.debian.org/releases/

### Use of AI

An AI assistant (Claude Code by Anthropic) was used to generate the first version of the Dockerfiles,
configuration files, start-up scripts and this README, to explain how the components fit together, and to
test the result (HTTPS, TLS versions, data persistence, `make re`). All files were then checked against the
subject and are explained in this document so the whole setup can be understood and defended.
