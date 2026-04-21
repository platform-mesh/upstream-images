## Repository Description
- `upstream-images` contains automation for rebuilding selected upstream charts and images for Platform Mesh consumption.
- The main moving parts are manual GitHub Actions workflows under `.github/workflows/` and OCM constructor descriptors under `.ocm/`.
- Read the org-wide [AGENTS.md](https://github.com/platform-mesh/.github/blob/main/AGENTS.md) for general conventions.

## Core Principles
- Keep changes narrow and traceable. This repo exists to reproduce and publish upstream-derived artifacts.
- Preserve reproducibility: version bumps, source references, and workflow inputs should stay explicit.
- Prefer updating existing workflows and OCM descriptors over adding ad-hoc manual steps.
- Keep this file focused on agent execution and repository-specific constraints.

## Project Structure
- `.github/workflows/`: manually triggered workflows for rebuilding upstream images, replacing charts, and creating OCM components.
- `.ocm/`: constructor descriptors used for OCM packaging of the resulting artifacts.
- `README.md` and `CONTRIBUTING.md`: high-level workflow guidance for maintainers.

## Architecture
This is a workflow automation repo, not a service or operator.

### Workflow model
- Workflows are triggered through `workflow_dispatch` and encode the supported upgrade/build paths.
- Chart replacement and image rebuild flows are designed around explicit upstream versions and known source locations.
- OCM workflows package the produced chart/image outputs into Platform Mesh-consumable components.

### Risk areas
- Small workflow changes can alter published image tags, chart contents, or OCM outputs.
- Keep upstream version references and dependency ordering accurate, especially for Keycloak/PostgreSQL upgrade paths.

## Commands
- There is no local build system here; the primary execution path is GitHub Actions `workflow_dispatch`.
- Review `.github/workflows/*.yaml` and `.ocm/*.yaml` together when changing upgrade or packaging behavior.

## Code Conventions
- Keep workflow steps explicit and easy to audit.
- Update `README.md` or `CONTRIBUTING.md` when the documented manual upgrade flow changes.
- Prefer pinned, deterministic inputs where possible.

## Generated Artifacts
- Treat published charts, images, and OCM components as workflow outputs rather than hand-managed repo artifacts.

## Do Not
- Introduce opaque version resolution or hidden manual steps.
- Change workflow inputs or published artifact naming casually.
- Hardcode credentials or registry secrets into workflows.

## Hard Boundaries
- Ask before changing release/publishing behavior in a way that would impact downstream consumers.
- Be especially careful with chart dependency handling and OCM component packaging.

## Human-Facing Guidance
- Use `CONTRIBUTING.md` for contribution process, DCO, and broader developer workflow expectations.
