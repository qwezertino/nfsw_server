# Single base image for all SBRW services
# Each service is defined in docker-compose.yml
FROM eclipse-temurin:11-jre-alpine

# Python 3 (modnet HTTP server) + bash (openfire scripts) + envsubst (openfire.xml templating)
RUN apk add --no-cache python3 bash gettext

# Enable TLSv1/TLSv1.1 — required for the NFS World game client (uses TLSv1 for XMPP)
RUN sed -i \
    's/jdk.tls.disabledAlgorithms=SSLv3, TLSv1, TLSv1.1, DTLSv1.0,/jdk.tls.disabledAlgorithms=SSLv3, DTLSv1.0,/' \
    /opt/java/openjdk/conf/security/java.security

WORKDIR /sbrw

# Docker helper files (entrypoints, templates)
COPY docker/ /docker/
RUN chmod +x /docker/*.sh
