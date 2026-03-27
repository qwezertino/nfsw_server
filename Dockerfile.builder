FROM eclipse-temurin:8-jdk-jammy

RUN apt-get update && apt-get install -y --no-install-recommends \
    maven \
    golang-go \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN git config --global --add safe.directory /workspace

WORKDIR /workspace
ENTRYPOINT ["bash", "build.sh"]
