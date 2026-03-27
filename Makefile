.PHONY: deploy build up down configure logs

# Full deploy: build artifacts then start all containers
deploy: build up

# Build all artifacts inside Docker (no local Maven/Go/Java required)
build:
	docker compose run --rm --build builder

# Start all services (rebuild Docker image if Dockerfile changed)
up:
	docker compose up -d --build

# Stop all services
down:
	docker compose down

# Apply configuration manually (for local/tmux setup, not needed in Docker)
configure:
	bash configure.sh

# Tail logs from all services
logs:
	docker compose logs -f

# Per-service logs
logs-core:
	docker compose logs -f core

logs-openfire:
	docker compose logs -f openfire

logs-mysql:
	docker compose logs -f mysql

logs-freeroam:
	docker compose logs -f freeroam

logs-race:
	docker compose logs -f race

logs-modnet:
	docker compose logs -f modnet
