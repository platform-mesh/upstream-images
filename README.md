# Images Repository

This repository simplifies the replacement of images and dependencies from Bitnami charts and builds OCM components for them.

## Workflows

There are two main workflows:

### 1. `helm-chart-replacement`
- Clones the Bitnami chart for the version you specify.  
- Finds all Bitnami images, pulls them, retags them, and pushes them to the `ghcr.io` registry.  
- Checks the `dependencies` section in `Chart.yaml` to verify whether the required dependencies already exist in the `ghcr.io` registry.  
  - If they exist, it rebuilds the `Chart.lock` file, packages the chart, and pushes it to `ghcr.io`.  
  - If they do not exist, it outputs a list of charts that must be built first.  

### 2. `job-ocm`
- Builds an OCM component for the chart specified in the input parameters.  

## Running Locally

You can test the replacement process locally by running the `helm-chart-replacement.sh` script.  '
This script performs the same steps as the `helm-chart-replacement` workflow.  

### Prerequisites
Make sure you have the following tools installed and available in your `PATH`:
- `git`
- `docker`
- `helm` (v3.17.2)
- `yq`
- `jq`

### Authentication
The script requires access to the GitHub Container Registry (`ghcr.io`).  
Before running it, set the following environment variables:

```bash
export GHCR_USER="<your-github-username>"
export GHCR_PAT="<your-personal-access-token>"
```
### Usage

Run the script with the Bitnami chart name and version in the format chart/version.

For example, to process the keycloak chart version 24.8.1 run:

```bash
./helm-chart-replacement.sh keycloak/24.8.1
```

## Creating a New Component Release

1. Run the `helm-chart-replacement` workflow with the desired chart and version.  
2. Pass the registry URL of the pushed chart to the `chartOCIPath` parameter. For example:  

   ```bash
   ghcr.io/platform-mesh/images/charts/keycloak:24.8.1
   ```
3. Run the job-ocm.yml workflow