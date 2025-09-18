# Images Repository

This repository simplifies the replacement of images and dependencies from Bitnami charts and builds OCM components for them.

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
