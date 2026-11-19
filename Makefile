# ---------------------------------------------------------------------------
# Inception - Makefile. The whole project is driven from here:
#   make / make down / make re / make logs ...
# ---------------------------------------------------------------------------

# Settings (LOGIN etc.) come from srcs/.env - one source of truth for make and docker compose
-include srcs/.env

LOGIN    ?= $(USER)
DATA_DIR := /home/$(LOGIN)/data
COMPOSE  := docker compose -f srcs/docker-compose.yml
SECRETS  := $(addprefix secrets/,db_root_password.txt db_password.txt \
                                 wp_admin_password.txt wp_user_password.txt)

all: up

# Build the images and start the containers in the background
up: srcs/.env $(SECRETS)
	@mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	$(COMPOSE) up -d --build

# Stop and remove the containers (data in $(DATA_DIR) is kept)
down:
	$(COMPOSE) down

start:
	$(COMPOSE) start

stop:
	$(COMPOSE) stop

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

clean: down

# Full cleanup: containers, project images, volumes AND the data on disk.
# Files in $(DATA_DIR) belong to users from inside the containers (mysql, www-data),
# so they are deleted from inside a container - no sudo needed.
fclean:
	$(COMPOSE) down -v --rmi all
	@if [ -d $(DATA_DIR) ]; then \
		docker run --rm -v $(DATA_DIR):/data debian:bookworm \
			sh -c 'rm -rf /data/mariadb /data/wordpress'; \
	fi

re: fclean all

# If .env is missing (e.g. after git clone) - create it from the template
srcs/.env:
	cp srcs/.env.example srcs/.env

# If a password file is missing - generate a random one
secrets/%.txt:
	@mkdir -p secrets
	@openssl rand -hex 16 > $@
	@chmod 600 $@
	@echo "created $@"

.PHONY: all up down start stop ps logs clean fclean re
