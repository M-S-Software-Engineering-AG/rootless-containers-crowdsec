variable "REGISTRY" {
  default = "ghcr.io/m-s-software-engineering-ag"
}

# renovate: datasource=docker depName=crowdsecurity/crowdsec
variable "CROWDSEC_VERSION" {
  default = "v1.8.1"
}

# renovate: datasource=github-releases depName=M-S-Software-Engineering-AG/container-supervisor
variable "SUPERVISOR_VERSION" {
  default = "v1.11.0"
}

# renovate: datasource=github-releases depName=M-S-Software-Engineering-AG/env2yml
variable "ENV2YML_VERSION" {
  default = "v1.2.3"
}

# renovate: datasource=github-releases depName=M-S-Software-Engineering-AG/container-healthcheck
variable "HEALTHCHECK_VERSION" {
  default = "v1.0.0"
}

# Set by the release workflow from the git tags; this default only tags local builds.
variable "IMAGE_REVISION" {
  default = "0.0"
}

group "default" {
  targets = ["crowdsec", "crowdsec-debug"]
}

target "crowdsec" {
  context    = "."
  dockerfile = "Dockerfile"
  args       = {
    CROWDSEC_VERSION    = CROWDSEC_VERSION
    SUPERVISOR_VERSION  = SUPERVISOR_VERSION
    ENV2YML_VERSION     = ENV2YML_VERSION
    HEALTHCHECK_VERSION = HEALTHCHECK_VERSION
  }
  tags       = [
    "${REGISTRY}/rootless-containers-crowdsec:${CROWDSEC_VERSION}-${IMAGE_REVISION}",
    "${REGISTRY}/rootless-containers-crowdsec:${CROWDSEC_VERSION}-${regex_replace(IMAGE_REVISION, "\\.[0-9]+$", "")}",
    "${REGISTRY}/rootless-containers-crowdsec:latest",
  ]
  platforms  = [
    "linux/amd64",
    "linux/arm64",
    "linux/arm/v7",
  ]
}

target "crowdsec-debug" {
  inherits = ["crowdsec"]
  args     = {
    BASE_IMAGE = "gcr.io/distroless/static-debian13:debug-nonroot"
  }
  tags     = [
    "${REGISTRY}/rootless-containers-crowdsec:${CROWDSEC_VERSION}-${IMAGE_REVISION}-debug",
    "${REGISTRY}/rootless-containers-crowdsec:${CROWDSEC_VERSION}-${regex_replace(IMAGE_REVISION, "\\.[0-9]+$", "")}-debug",
    "${REGISTRY}/rootless-containers-crowdsec:latest-debug",
  ]
}
