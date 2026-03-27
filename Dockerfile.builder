FROM eclipse-temurin:8-jdk-jammy

RUN apt-get update && apt-get install -y --no-install-recommends \
    maven \
    golang-go \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
ENTRYPOINT ["bash", "build.sh"]
