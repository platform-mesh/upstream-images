#!/bin/bash

set -eo pipefail

# Configuration
TARGET_VERSION="25.0.2-debian-12-r2"  # Change this to your desired Keycloak version
REPO_URL="https://github.com/bitnami/containers.git"
CLONE_DIR="/tmp/bitnami-containers"
KEYCLOAK_PATH="bitnami/keycloak"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -rf "${CLONE_DIR}"
}

# Error handling
trap cleanup ERR EXIT

# Clone repository with full history
echo "Cloning Bitnami containers repository with full history..."
git clone "${REPO_URL}" "${CLONE_DIR}"
cd "${CLONE_DIR}"

# Find the commit for the specific version
echo "Searching for commit with version ${TARGET_VERSION}..."

# Try different search patterns
COMMIT_HASH=$(git log --oneline --grep="keycloak.*${TARGET_VERSION}" --all | head -n 1 | cut -d' ' -f1)

if [[ -z "${COMMIT_HASH}" ]]; then
    echo "Trying alternative search pattern..."
    COMMIT_HASH=$(git log --oneline --grep="${TARGET_VERSION}" --all | grep -i keycloak | head -n 1 | cut -d' ' -f1)
fi

if [[ -z "${COMMIT_HASH}" ]]; then
    echo "Trying broader search..."
    COMMIT_HASH=$(git log --oneline --all | grep -i "${TARGET_VERSION}" | grep -i keycloak | head -n 1 | cut -d' ' -f1)
fi

if [[ -z "${COMMIT_HASH}" ]]; then
    echo "Error: Could not find commit for version ${TARGET_VERSION}"
    echo "Available Keycloak releases:"
    git log --oneline --grep="keycloak" --all | head -20
    echo ""
    echo "Trying to find any version close to ${TARGET_VERSION}..."
    git log --oneline --all | grep -i keycloak | grep -E "[0-9]+\.[0-9]+\.[0-9]+" | head -20
    exit 1
fi

echo "Found commit: ${COMMIT_HASH}"
echo "Commit message: $(git log --format=%B -n 1 ${COMMIT_HASH})"

# Checkout the specific commit
echo "Checking out commit ${COMMIT_HASH}..."
git checkout "${COMMIT_HASH}"

# Navigate to the Keycloak directory
if [[ ! -d "${KEYCLOAK_PATH}" ]]; then
    echo "Error: Keycloak directory not found at ${KEYCLOAK_PATH}"
    exit 1
fi

cd "${KEYCLOAK_PATH}"

# Find the appropriate version directory
MAJOR_VERSION=$(echo "${TARGET_VERSION}" | cut -d. -f1)
VERSION_DIR=$(find . -maxdepth 1 -type d -name "${MAJOR_VERSION}*" | head -n 1)

if [[ -z "${VERSION_DIR}" ]]; then
    echo "Error: Could not find version directory for ${TARGET_VERSION}"
    echo "Available directories:"
    ls -d */
    exit 1
fi

echo "Found version directory: ${VERSION_DIR}"
cd "${VERSION_DIR}"

# Find OS directory
OS_DIR=$(find . -maxdepth 1 -type d \( -name "debian*" -o -name "rhel*" -o -name "ubuntu*" \) | head -n 1)

if [[ -z "${OS_DIR}" ]]; then
    echo "Error: Could not find OS directory"
    echo "Available directories:"
    ls -d */
    exit 1
fi

echo "Found OS directory: ${OS_DIR}"
cd "${OS_DIR}"

# Check for Dockerfile
if [[ ! -f "Dockerfile" ]]; then
    echo "Error: Dockerfile not found in ${PWD}"
    exit 1
fi

echo "Building Docker image from ${PWD}..."

# Build with Docker
docker build \
    --tag "keycloak:${TARGET_VERSION}-custom" \
    --tag "keycloak:latest-custom" \
    .

echo "Build completed successfully!"
echo "Image tagged as: keycloak:${TARGET_VERSION}-custom"
echo "Image tagged as: keycloak:latest-custom"