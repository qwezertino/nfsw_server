.PHONY: deploy build up down configure logs

# Full deploy: build artifacts then start all containers
deploy: build up

# Build all artifacts (Go, Java, download plugins) into sbrw/
build:
	bash build.sh

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
