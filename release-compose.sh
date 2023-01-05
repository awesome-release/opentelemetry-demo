#!/bin/bash

# This script converts the docker-compose.yml file to a new compose file that can be used for Release.
# Requirements:
# - docker: https://docs.docker.com/compose/install/
# - yq: https://github.com/mikefarah/yq/#install
# - sed

# Convert docker-compose.yml to a new compose file that can be used for Release
# Replace the following strings:
# - Remove absolute paths
# - Replace the postgres service name to remove the underscore
# - Replace the kafka service name to avoid clashing env vars
docker compose convert --no-normalize | \
  sed \
    -e "s|$PWD/||g" \
    -e "s/ffs_postgres/ffspostgres/g" \
    -e "s/kafka:/kafkaservice:/g" \
  > release-compose.yaml && \
  mv release-compose.yaml compose.yaml

# Update the compose file with the following changes:

# otelcol hostname does not resolve during deployment, replace with localhost
yq -i '.exporters.prometheus.endpoint |= sub("(otelcol)", "localhost")' src/otelcollector/otelcol-config.yml

# featureflagservice depends on postgres, add condition
yq -i '.services.featureflagservice.depends_on.ffspostgres.condition = "service_started"' compose.yaml

# add port to postgres service
yq -i '.services.ffspostgres.ports[0] = "5432"' compose.yaml

# fix featureflagservice hostname
yq -i '.services.frontendproxy.environment.FEATURE_FLAG_SERVICE_HOST = "featureflagservice"' compose.yaml

# fix kafka service name
yq -i '.services.kafkaservice.environment.OTEL_SERVICE_NAME = "kafkaservice"' compose.yaml

# kafka service depends on otelcol, add condition
yq -i '.services.kafkaservice.depends_on.otelcol.condition = "service_started"' compose.yaml

# add ports to kafka service
yq -i '.services.kafkaservice.ports[0] = "9092"' compose.yaml
yq -i '.services.kafkaservice.ports[1] = "9093"' compose.yaml

# fix kafka healthcheck
yq -i '.services.kafkaservice.healthcheck.test[] |= sub("(kafka)", "localhost")' compose.yaml
