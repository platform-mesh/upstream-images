## Overview

# Contributing to platform-mesh
We want to make contributing to this project as easy and transparent as possible.

## Our development process
We use GitHub to track issues and feature requests, as well as accept pull requests.

## Pull requests
You are welcome to contribute with your pull requests. These steps explain the contribution process:

1. Fork the repository and create your branch from `main`.
1. [Add tests](#testing) for your code.
1. If you've changed APIs, update the documentation. 
1. Make sure the tests pass. Our github actions pipeline is running the unit and e2e tests for your PR and will indicate any issues.
1. Sign the Developer Certificate of Origin (DCO).

## Workflows

The main workflows are:

### 1. `helm-chart-replacement`
- Clones the Bitnami chart for the version you specify.
- Checks the `dependencies` section in `Chart.yaml` to verify whether the required dependencies already exist in the `ghcr.io` registry.
    - If they exist, it rebuilds the `Chart.lock` file, packages the chart, and pushes it to `ghcr.io`.
    - If they do not exist, it outputs a list of charts that must be built first.

### 2. `job-ocm`
- Builds an OCM component for the chart specified in the input parameters.

### 2. `build-keycloak`
- Builds the keycloak image used in the keycloak chart.
- You can lookup what commit to build by going to: https://github.com/bitnami/containers/commits/main/bitnami/keycloak/26/debian-12/Dockerfile

### 2. `build-postgresql`
- Builds the postgresql image used in the keycloak chart.
- You can lookup what commit to build by going to: https://github.com/bitnami/containers/commits/main/bitnami/postgresql/17/debian-12/Dockerfile

## How to upgrade to a new keycloak version

1. Trigger workflow to build new keycloak image
1. Trigger workflow to build new postgresql image
1. Trigger workflow to build new common chart if the version has changed
1. Trigger workflow to build new postgresql chart if the version has changed
1. Trigger workflow to build new keycloak chart if the version has changed
1. Trigger workflow to build new keycloak-ocm component

## Issues
We use GitHub issues to track bugs. Please ensure your description is
clear and includes sufficient instructions to reproduce the issue.

## License
By contributing to platform-mesh, you agree that your contributions will be licensed
under its [Apache-2.0 license](LICENSE).
