# Release Notes

All notable changes to the [sha-learns-ci-gitops](https://github.com/rhpds/sha-learns-ci-gitops) repo are tracked here.

---

## 2026-03-18 — Workload Documentation

- commit `33a89c4`
    - Added shared documentation `docs/enabling-workloads.md`: explains the three-layer system (infra/platform/tenant), bootstrap chain (with ASCII tree), how to enable/disable workloads, AgnosticV catalog integration (`ocp4_workload_gitops_bootstrap_helm_values`), platform-values-not-overridable limitation, and common ArgoCD sync options. All workload READMEs link here instead of duplicating this content.
    - Added `docs/RELEASE-NOTES.md` (this file).
    - Added 11 new workload READMEs (standardized format: Overview, File Inventory, How to Enable, Variables Reference, Gotchas):
        - `infra/descheduler-operator/README.md` — two-layer (infra+platform), covers OLM Subscription + KubeDescheduler CR + optional MachineConfig.
        - `infra/kubevirt-operator/README.md` — two-layer, Manual InstallPlan approval pattern, external Ceph StorageClass, VM boot image import.
        - `infra/mtc-operator/README.md` — two-layer, MigrationController CR + external Ceph StorageClass.
        - `infra/mtv-operator/README.md` — two-layer, ForkliftController CR + featuregate-patch-job, cross-references KubeVirt dependency.
        - `infra/node-health-check-operator/README.md` — three-component (NHC operator + SNR operator + platform console plugin), three enable flags.
        - `infra/self-node-remediation-operator/README.md` — brief companion README pointing to NHC doc.
        - `infra/rhoai-operator/README.md` — two-layer with inner gates (`datasciencecluster.enabled`, `dscinitialization.enabled`, `patcher.enabled`), bootstrap overrides apiVersion to v2.
        - `infra/default-storageclass/README.md` — infra-only, enabled by default (unusual), sync-wave -50, Sync hook pattern.
        - `infra/keycloak/README.md` — most complex: three sub-charts (keycloak-infra, keycloak-resources, keycloak-realm) + tenant integration, architecture diagram, CronJobs, data round-trip via userdata ConfigMaps.
        - `platform/gitlab/README.md` — platform-only, non-operator deployment (GitLab CE + PostgreSQL + Redis), init Job with Ansible playbook.
        - `platform/odf/README.md` — platform-only, patches Ceph RBD CSI Driver with node remediation tolerations, pairs with NHC/SNR.
    - Rewrote `platform/webterminal/README.md` — replaced generic 5-line placeholder with full standardized doc (platform-only with sub-chart dependencies, operator.enabled gotcha, hardcoded path mismatch).
    - Rewrote `platform/rhoai/README.md` — replaced generic 18-line placeholder with one-line companion pointing to `infra/rhoai-operator/README.md`.
    - Added Claude Code skill `.claude/skills/agnosticv-gitops-workload-document/` — reusable skill for generating new workload docs following the standardized template. Includes `SKILL.md` (4-step workflow: Discover, Read, Placement, Write), `references/example-descheduler.md` (complete reference output), and `evals/evals.json` (8 eval cases covering all workload patterns).

---
