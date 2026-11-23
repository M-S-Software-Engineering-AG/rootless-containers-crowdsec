ARG BASE_IMAGE=gcr.io/distroless/static-debian13:nonroot
ARG CROWDSEC_VERSION

FROM crowdsecurity/crowdsec:${CROWDSEC_VERSION:?} AS upstream

FROM --platform=$BUILDPLATFORM crowdsecurity/crowdsec:${CROWDSEC_VERSION:?} AS config

ARG TARGETARCH
ARG TARGETVARIANT
ARG SUPERVISOR_VERSION
ARG HEALTHCHECK_VERSION
ARG ENV2YML_VERSION

WORKDIR /staging

RUN yq -i ' \
      del(.plugin_config) | \
      del(.config_paths.plugin_dir) | \
      del(.api.server.tls) | \
      .common.log_dir = "/var/lib/crowdsec/log" | \
      .api.server.online_client.credentials_path = "/etc/crowdsec/capi/credentials.yaml" \
    ' etc/crowdsec/config.yaml

RUN mkdir -p var/lib/crowdsec/log supervisor_environment etc/crowdsec/capi

RUN wget -q -O container-supervisor \
    https://github.com/M-S-Software-Engineering-AG/container-supervisor/releases/download/$SUPERVISOR_VERSION/container-supervisor-linux-$TARGETARCH$TARGETVARIANT \
    && chmod +x container-supervisor

ADD --chmod=755 https://github.com/M-S-Software-Engineering-AG/container-healthcheck/releases/download/${HEALTHCHECK_VERSION:?}/container-healthcheck-linux-${TARGETARCH}${TARGETVARIANT} healthcheck

RUN wget -q -O env2yml \
    https://github.com/M-S-Software-Engineering-AG/env2yml/releases/download/$ENV2YML_VERSION/env2yml-linux-$TARGETARCH$TARGETVARIANT \
    && chmod +x env2yml

FROM --platform=$BUILDPLATFORM golang:1.27-bookworm AS register-bouncer-build

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

WORKDIR /register-bouncer

COPY go.mod .
COPY register-bouncer/ register-bouncer/

RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH GOARM=${TARGETVARIANT#v} \
    go build -o /out/register-bouncer ./register-bouncer

FROM --platform=$BUILDPLATFORM golang:1.27-bookworm AS register-capi-build

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

WORKDIR /register-capi

COPY go.mod .
COPY register-capi/ register-capi/

RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH GOARM=${TARGETVARIANT#v} \
    go build -o /out/register-capi ./register-capi

FROM $BASE_IMAGE
COPY --from=upstream /usr/local/bin/crowdsec /usr/local/bin/cscli /usr/local/bin/
COPY --from=register-bouncer-build /out/register-bouncer /usr/local/bin/register-bouncer
COPY --from=register-capi-build /out/register-capi /usr/local/bin/register-capi
COPY --from=config /staging/container-supervisor /staging/env2yml /staging/healthcheck /usr/local/bin/
COPY --from=config --chown=65532:65532 /staging/etc/crowdsec/ /etc/crowdsec/
COPY --from=config --chown=65532:65532 /staging/var/lib/crowdsec/ /var/lib/crowdsec/
COPY --from=config --chown=65532:65532 /staging/supervisor_environment/ /container-supervisor/supervisor_environment/
COPY supervisor.yml /container-supervisor/config.yml
USER nonroot:nonroot

EXPOSE 8080 6060
ENTRYPOINT ["/usr/local/bin/container-supervisor"]
