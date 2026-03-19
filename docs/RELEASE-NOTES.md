# Release Notes

## 2026-03-18 — Workload Documentation

### Added

- **Shared documentation** (`docs/enabling-workloads.md`) — explains the three-layer system, bootstrap chain, how to enable/disable workloads, AgnosticV catalog integration, and common sync options. All workload READMEs link here to avoid duplication.

- **14 workload READMEs** covering every infra and platform workload:

  | Workload | README | Type |
  |----------|--------|------|
  | Descheduler | `infra/descheduler-operator/README.md` | Two-layer (infra+platform) |
  | KubeVirt | `infra/kubevirt-operator/README.md` | Two-layer |
  | MTC | `infra/mtc-operator/README.md` | Two-layer |
  | MTV | `infra/mtv-operator/README.md` | Two-layer |
  | Node Health Check + SNR | `infra/node-health-check-operator/README.md` | Three-component |
  | Self Node Remediation | `infra/self-node-remediation-operator/README.md` | Companion (points to NHC) |
  | RHOAI | `infra/rhoai-operator/README.md` | Two-layer with inner gates |
  | Default StorageClass | `infra/default-storageclass/README.md` | Infra-only |
  | Keycloak | `infra/keycloak/README.md` | Multi-chart + tenant integration |
  | GitLab | `platform/gitlab/README.md` | Platform-only |
  | Web Terminal | `platform/webterminal/README.md` | Platform-only |
  | ODF | `platform/odf/README.md` | Platform-only |
  | RHOAI (platform) | `platform/rhoai/README.md` | Companion (points to infra) |

- **Claude Code skill** (`.claude/skills/agnosticv-gitops-workload-document/`) — reusable skill for generating standardized workload documentation. Includes SKILL.md with template, reference example, and eval cases.

### Documentation format

Each README follows a standardized template:
1. **Overview** — what the workload does, which layers it spans, companion links
2. **File Inventory** — tree format with sync-wave annotations
3. **How to Enable** — flags table, catalog snippet, link to shared doc
4. **Variables Reference** — per-chart tables including hardcoded CR values
5. **Gotchas** — workload-specific issues (multi-flag requirements, ignoreDifferences, hardcoded paths, missing syncPolicy, etc.)
