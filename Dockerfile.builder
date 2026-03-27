FROM eclipse-temurin:11-jdk-jammy

# JDK 11 can compile source/target 1.8 just fine — no need for a separate JDK 8
RUN apt-get update && apt-get install -y --no-install-recommends \
    maven \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Go 1.21+ required (cmp/slices packages); Ubuntu Jammy only has 1.18
RUN curl -sSL https://go.dev/dl/go1.22.5.linux-amd64.tar.gz \
    | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

# Openfire build.sh uses JAVA8_HOME — point it at our JDK 11
ENV JAVA8_HOME=/opt/java/openjdk

RUN git config --global --add safe.directory /workspace

WORKDIR /workspace
ENTRYPOINT ["bash", "build.sh"]
