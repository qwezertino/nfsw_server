#!/bin/sh
# Core entrypoint: generate project-defaults.yml from env vars at runtime, then start.
# This ensures DB_HOST=mysql (Docker service name) is used, not the build-time value.

cat > /sbrw/core/project-defaults.yml << EOF
thorntail:
  http:
    port: ${SERVER_PORT:-4444}
  datasources:
    data-sources:
      SoapBoxDS:
        driver-name: mysql
        connection-url: jdbc:mysql://${DB_HOST}:3306/${DB_NAME}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC
        user-name: ${DB_USER}
        password: ${DB_PASS}
        valid-connection-checker-class-name: org.jboss.jca.adapters.jdbc.extensions.mysql.MySQLValidConnectionChecker
        validate-on-match: true
        background-validation: false
        exception-sorter-class-name: org.jboss.jca.adapters.jdbc.extensions.mysql.MySQLExceptionSorter
        max-pool-size: 64
        min-pool-size: 8
        share-prepared-statements: true
  mail:
    mail-sessions:
      Gmail:
        smtp-server:
          username: serveremailhere@gmail.com
          password: secret
          ssl: true
    smtp:
      host: smtp.gmail.com
      port: 465
  undertow:
    filter-configuration:
      response-headers:
      gzips:
        gzipFilter:
    servers:
      default-server:
        hosts:
          default-host:
            filter-refs:
              gzipFilter:
                priority: 1
                predicate: "exists['%{o,Content-Type}'] and regex[pattern='(?:application/javascript|text/css|text/html|text/xml|application/json|application/xml)(;.*)?', value=%{o,Content-Type}, full-match=true]"
EOF

exec java -jar core.jar
