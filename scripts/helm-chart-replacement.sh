#!/usr/bin/env bash
set -euo pipefail

BITNAMI_REPO="https://github.com/bitnami/charts.git"
GHCR_NAMESPACE="ghcr.io/olegershov/images"
WORKDIR="./charts-workdir"

# For images
IMAGE_NAMESPACE="${GHCR_NAMESPACE}"
# For charts
CHART_NAMESPACE="${GHCR_NAMESPACE}/charts"
DEP_TEMPLATE="oci://${CHART_NAMESPACE}/__CHART__"

# clones exact chart whith the specified tag from bitnami-charts repo
clone_chart() {
    local chart_tag="$1"
    local tool version
    tool=$(echo "${chart_tag}" | cut -d/ -f1)
    version=$(echo "${chart_tag}" | cut -d/ -f2)

    local chart_path="${WORKDIR}/${tool}"
    rm -rf "${chart_path}"
    mkdir -p "${WORKDIR}"

    echo "[INFO] Sparse-cloning ${tool}@${version} from Bitnami repo..." >&2

    git init "${chart_path}" >&2
    git -C "${chart_path}" remote add origin "${BITNAMI_REPO}" >&2
    git -C "${chart_path}" config core.sparseCheckout true >&2

    mkdir -p "${chart_path}/.git/info"
    echo "bitnami/${tool}" > "${chart_path}/.git/info/sparse-checkout"

    git -C "${chart_path}" fetch --depth 1 origin "refs/tags/${chart_tag}:refs/tags/${chart_tag}" >&2
    git -C "${chart_path}" checkout "tags/${chart_tag}" >&2

    # move files up from sparse checkout directory
    if [[ -d "${chart_path}/bitnami/${tool}" ]]; then
        mv "${chart_path}/bitnami/${tool}"/* "${chart_path}/"
        rm -rf "${chart_path}/bitnami"
    fi

    if [[ ! -f "${chart_path}/values.yaml" ]]; then
        echo "[ERROR] Expected values.yaml not found in ${chart_path}" >&2
        exit 1
    fi

    echo "${chart_path}"
}

parse_images() {
    local chart_path="$1"
    local values_file="${chart_path}/values.yaml"

    echo "[INFO] Extracting images from ${values_file}..." >&2
    yq eval '.. | .image? | select(. != null)' "${values_file}" -o=json | \
        jq -r '.repository + ":" + .tag'
}

retag_and_push_images() {
    local registry="$1"
    local chart_path="$2"

    local repos
    repos=$(yq eval '.. | select(has("image")) | .image.repository' "${chart_path}/values.yaml" | grep "bitnami" || true)

    if [[ -z "$repos" ]]; then
        echo "[INFO] No bitnami images found" >&2
        return
    fi

    while IFS= read -r repo; do
        local tag img basename target
        tag=$(yq eval ".. | select(has(\"image\") and .image.repository == \"${repo}\") | .image.tag" "${chart_path}/values.yaml")
        img="${repo}:${tag}"
        basename=$(basename "${repo}")

        target="$(echo "${registry}/${basename}" | tr '[:upper:]' '[:lower:]'):${tag}"

        echo "[INFO] Pulling ${img}" >&2
        docker pull "${img}"

        echo "[INFO] Tagging ${img} -> ${target}" >&2
        docker tag "${img}" "${target}"

        echo "[INFO] Pushing ${target}" >&2
        docker push "${target}"

        yq eval --inplace "
          (.. | select(has(\"image\") and .image.repository == \"${repo}\") | .image.registry) = \"${registry}\" |
          (.. | select(has(\"image\") and .image.repository == \"${repo}\") | .image.repository) = \"${basename}\"
        " "${chart_path}/values.yaml"

        echo "[INFO] Updated values.yaml -> registry=${registry}, repository=${basename}" >&2
    done <<< "$repos"
}

# update Chart.yaml dependencies with correct repository and versions
update_dependencies() {
    local chart_path="$1"
    local chart_yaml="${chart_path}/Chart.yaml"
    local chart_lock="${chart_path}/Chart.lock"

    if [[ ! -f "${chart_lock}" ]]; then
        echo "[WARN] No Chart.lock found, skipping dependency update." >&2
        return
    fi

    echo "[INFO] Updating dependencies using ${chart_lock}..."

    local dep_count
    dep_count=$(yq eval '.dependencies | length' "${chart_lock}")
    local missing_deps=()

    echo "[INFO] Logging in to GHCR for Helm OCI..."
    if ! echo "$GHCR_PAT" | helm registry login "$GHCR_NAMESPACE" --username "$GHCR_USER" --password-stdin; then
        echo "[ERROR] Failed to login to GHCR registry" >&2
        exit 1
    fi

    # loop through all dependencies
    for i in $(seq 0 $((dep_count - 1))); do
        local name repo version dep_repo dep_target_versioned
        name=$(yq eval ".dependencies[${i}].name" "${chart_lock}")
        repo=$(yq eval ".dependencies[${i}].repository" "${chart_lock}")
        version=$(yq eval ".dependencies[${i}].version" "${chart_lock}")

        if [[ "${repo}" == *"bitnami"* ]]; then
            dep_repo="oci://${CHART_NAMESPACE}"
            dep_target_versioned="${dep_repo}/${name}:${version}"

            echo "[INFO] Updating dependency ${name} -> repository: ${dep_repo}, version: ${version}"

            # update Chart.yaml with exact version from Chart.lock
            yq eval --inplace "
.dependencies[] |= (select(.name == \"${name}\") | .repository = \"${dep_repo}\" | .version = \"${version}\")
" "${chart_yaml}"

            # check if chart exists in GHCR registry
            if ! helm pull "${dep_target_versioned}" --destination /tmp >/dev/null 2>&1; then
                echo "[WARN] Chart not found in registry: ${dep_target_versioned}"
                missing_deps+=("${name}:${version}")
            else
                echo "[INFO] Chart exists in registry: ${dep_target_versioned}"
            fi
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "[ERROR] The following charts must be built first:" >&2
        for dep in "${missing_deps[@]}"; do
            echo "  - ${dep}" >&2
        done
        exit 1
    fi
}

# package chart and push to GHCR
package_and_push_chart() {
    local chart_path="$1"
    local chart_yaml="${chart_path}/Chart.yaml"

    local name version target tgz tmpdir
    name=$(yq eval '.name' "${chart_yaml}")
    version=$(yq eval '.version' "${chart_yaml}")
    target="oci://${CHART_NAMESPACE}"

    echo "[INFO] Packaging chart ${name}@${version}..."

    # Ensure Chart.lock matches Chart.yaml
    if [[ -f "${chart_path}/Chart.lock" ]]; then
        echo "[WARN] Removing stale Chart.lock for ${name}"
        rm -f "${chart_path}/Chart.lock"
    fi

    echo "[INFO] Regenerating Chart.lock..."
    if ! helm dependency build "${chart_path}"; then
        echo "[ERROR] Failed to rebuild Chart.lock for ${name}" >&2
        exit 1
    fi

    tmpdir=$(mktemp -d)
    tgz="${tmpdir}/${name}-${version}.tgz"

    helm package "${chart_path}" --destination "${tmpdir}"

    echo "[INFO] Pushing chart ${name}@${version} to ${target}"
    helm push "${tgz}" "${target}"

    echo "[INFO] Chart ${name}@${version} successfully pushed to ${target}"

    rm -rf "${tmpdir}"
}

main() {
    local chart_tag="$1"

    local chart_path
    chart_path=$(clone_chart "${chart_tag}")
    echo "THE CHART IS CLONED into ${chart_path}"
    mapfile -t images < <(parse_images "${chart_path}")
    retag_and_push_images "$GHCR_NAMESPACE" "$chart_path"
    update_dependencies "$chart_path"

    package_and_push_chart "$chart_path"

    echo "[INFO] All images and chart are published successfully!" >&2
}

main "$@"
