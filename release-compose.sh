#!/bin/bash

docker compose convert --no-normalize | \
  sed \
    -e "s|$PWD/||g" \
    -e "s/ffs_postgres/ffspostgres/g" \
    -e "s/kafka:/kafkaservice:/g" \
  > release-compose.yaml && \
  mv release-compose.yaml compose.yaml

yq -i '.exporters.prometheus.endpoint |= sub("(otelcol)", "localhost")' src/otelcollector/otelcol-config.yml

yq -i '.services.featureflagservice.depends_on.ffspostgres.condition = "service_started"' compose.yaml
yq -i '.services.ffspostgres.ports[0] = "5432"' compose.yaml

yq -i '.services.frontendproxy.environment.FEATURE_FLAG_SERVICE_HOST = "featureflagservice"' compose.yaml

yq -i '.services.kafkaservice.environment.OTEL_SERVICE_NAME = "kafkaservice"' compose.yaml
yq -i '.services.kafkaservice.depends_on.otelcol.condition = "service_started"' compose.yaml
yq -i '.services.kafkaservice.ports[0] = "9092"' compose.yaml
yq -i '.services.kafkaservice.ports[1] = "9093"' compose.yaml
yq -i '.services.kafkaservice.healthcheck.test[] |= sub("(kafka)", "localhost")' compose.yaml
