---
name: agnosticv-gitops-workload-document
description: |
  Generates standardized README documentation for GitOps workloads in this repository.

  **USE THIS SKILL** when the user mentions:
  - "document", "write a README", "create docs" for a workload
  - "document the descheduler", "document kubevirt", "document gitlab"
  - "generate workload documentation"
  - "create a README for infra/some-operator" or "create a README for platform/something"

  Reads all files across layers (infra, platform, tenant, bootstrap), analyzes variables,
  sync-waves, gating conditions, and gotchas, then produces a README following the
  established template. Output links to the shared docs/enabling-workloads.md for
  common patterns.
---

# GitOps Workload Documentation Skill

Generate a README.md for a workload in this gitops repository. The output follows a standardized template so all workload docs are consistent.

## Before You Start

1. **Identify the workload.** The user will name a workload (e.g., "descheduler", "kubevirt", "webterminal", "gitlab", "keycloak"). Determine which layers it spans by checking for directories and bootstrap Application templates.

2. **Read the shared doc.** Read `docs/enabling-workloads.md` at the repo root. Your README will link to it — don't duplicate its content.

3. **Read EVERY file.** You must read all files before writing. Do not guess or infer file contents.

## Step 1: Discover All Files

Workloads come in several shapes. Check ALL of these locations:

### Standard patterns

**Infra + Platform pair** (most common — e.g., descheduler, kubevirt, mtc, mtv):
- `infra/<workload>-operator/` — Chart.yaml, values.yaml, templates/*
- `platform/<workload>/` — Chart.yaml, values.yaml, templates/*
- `infra/bootstrap/templates/application-<workload>-operator.yaml`
- `platform/bootstrap/templates/application-<workload>.yaml`

**Platform-only** (e.g., webterminal, gitlab, odf):
- `platform/<workload>/` — all files
- `platform/bootstrap/templates/application-<workload>.yaml`

**Infra-only** (e.g., default-storageclass):
- `infra/<workload>/` — all files
- `infra/bootstrap/templates/application-<workload>.yaml`

### Non-standard patterns to watch for

- **Sub-directories** — Keycloak has `infra/keycloak/keycloak-infra/`, `infra/keycloak/keycloak-resources/`, and `infra/keycloak/keycloak-realm/` (three separate charts under one directory)
- **Tenant integration** — some workloads have files in `tenant/bootstrap/templates/` (e.g., keycloak-realm is deployed by tenant bootstrap, not infra bootstrap)
- **Related workloads** — some workloads are designed to work together (e.g., node-health-check + self-node-remediation both install in `openshift-workload-availability`). Document them together or cross-reference.

**Names may not follow the convention exactly.** For example, the infra chart might be `kubevirt-operator` but the bootstrap key is `kubevirtOperator`. Always verify by reading the actual files.

Always also check `infra/bootstrap/values.yaml` and `platform/bootstrap/values.yaml` for the workload's entry.

## Step 2: Read Every File

Read ALL discovered files completely. Pay attention to:

- **Gating conditions** — `{{ if .Values.something.enabled }}` in bootstrap Application templates and within chart templates (inner gates)
- **Sync-wave annotations** — `argocd.argoproj.io/sync-wave` on each resource
- **Values used in templates** — every `{{ .Values.* }}` reference
- **Hardcoded values** — important fields in CRs or resources that are NOT templatized
- **ignoreDifferences** — fields the operator mutates post-creation
- **Additional conditions** — inner gates like `{{ if .Values.something.enable_machineconfig }}`
- **Sub-chart dependencies** — `dependencies` in Chart.yaml (e.g., helper-status-checker from charts.stderr.at)
- **Helm value overrides** — values passed via `helm.values` in the bootstrap Application template (these override chart defaults!)
- **Path references** — whether the bootstrap Application uses `.Values.<name>.git.path` or a hardcoded path (a mismatch is a gotcha)
- **Namespace handling** — explicit namespaces vs `{{ $.Release.Namespace }}`
- **Jobs, CronJobs, and init scripts** — post-deploy automation, what they do, whether they're idempotent
- **RBAC resources** — ServiceAccounts, ClusterRoleBindings, SCCs — and whether they use cluster-admin
- **Hook annotations** — `argocd.argoproj.io/hook: PostSync` or `Sync` changes when/how resources are managed
- **Finalizers** — `resources-finalizer.argocd.argoproj.io` on Applications affects deletion behavior
- **Unused values** — values defined in values.yaml but never referenced in templates (gotcha)
- **Missing syncPolicy** — some Applications lack automated sync, retry, or syncOptions (gotcha)

## Step 3: Determine README Placement

- **Two-layer workloads (infra + platform):** Place README in the **infra** chart directory (entry point — operator installs first). For the platform chart, create a one-line README pointing to the infra doc.
- **Platform-only:** Place README in the platform chart directory.
- **Infra-only:** Place README in the infra chart directory.
- **Multi-chart workloads** (e.g., keycloak with 3 sub-charts): Place README in the parent directory (e.g., `infra/keycloak/README.md`).
- **Related workloads** (e.g., NHC + SNR): Pick one as primary, create a brief README in the other pointing to the primary.

The relative path to `docs/enabling-workloads.md` is always `../../docs/enabling-workloads.md` from any chart directory.

## Step 4: Write the README

Follow this template. Adapt sections as needed for the workload's complexity — the template is a guide, not a straitjacket.

---

### Template

````markdown
# <Workload Display Name> Workload

## Overview

<2-4 sentences: what this workload does, why you'd use it.>

<If this workload has a companion/dependency, call it out with a link early:>
**Requires** the [KubeVirt workload](../kubevirt-operator/README.md) to be installed first.
OR: This operator is the **remediation backend** for the [Node Health Check operator](../node-health-check-operator/README.md).

<State which layers it spans and the path to each:>
This workload spans **two layers**:
- **infra** (`infra/<name>/`) — <what infra does>
- **platform** (`platform/<name>/`) — <what platform does>

> For background on the layer system, bootstrap chain, and common enable/disable pattern, see [docs/enabling-workloads.md](<relative-path>).

## Architecture (optional — use for complex workloads)

<ASCII diagram showing deployment flow, component relationships, or data flow. Use this for workloads with 3+ charts, tenant integration, CronJobs, or non-obvious relationships.>

## File Inventory

<Use tree format. Group by layer/chart. Annotate each file with a brief description and sync-wave if applicable.>

### <Layer> layer — <purpose>

```
<layer>/<workload>/
├── Chart.yaml
├── values.yaml                              # <key values listed>
└── templates/
    ├── <resource>.yaml                      # <description> (sync-wave N)
    └── <resource>.yaml                      # <description> (sync-wave N), gated by <condition>

<layer>/bootstrap/templates/
└── application-<workload>.yaml              # ArgoCD Application, gated by <key>.enabled
```

## How to Enable

> Full explanation of the enable pattern and AgnosticV integration: [docs/enabling-workloads.md](<relative-path>).

<State how many enabled flags are needed and whether any have inner gates:>

| Flag | File | Default |
|------|------|---------|
| `<key>.enabled` | `<path>/values.yaml` | `false` |

<Show the catalog override snippet for infra-layer flags:>

```yaml
# In your cluster catalog common.yaml:
ocp4_workload_gitops_bootstrap_helm_values:
  <infraKey>:
    enabled: true
```

<Note platform/tenant flags that must be set in the repo.>

## Variables Reference

<Only list variables from the workload's own values.yaml files — NOT the bootstrap git/enabled variables.>
<Split by chart. Use a table for each.>
<If a bootstrap Application passes helm overrides that change chart defaults, mention it.>

### <Chart> chart — `<path>/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `<var>` | `<default>` | <description> |

<If important CR fields are hardcoded in templates, add a separate table:>

### <Resource Name> — hardcoded values

The following are set directly in `<template-file>` and are **not** configurable via values. To change them, edit the template:

| Field | Value | Description |
|-------|-------|-------------|
| `<field>` | `<value>` | <description> |

## Gotchas

<Numbered list. Each gotcha has a bold title and 1-2 sentence explanation.>
<Include ONLY workload-specific gotchas — don't repeat things covered in docs/enabling-workloads.md.>
````

---

## Writing Guidelines

1. **Be factual.** Only document what you actually read in the files. Don't infer or assume.

2. **Don't duplicate the shared doc.** The "How to Enable" section links to `docs/enabling-workloads.md` for the full explanation. Don't re-explain the three-layer system, what bootstrap Applications are, or how the catalog works.

3. **Call out companions and dependencies early.** If a workload requires another workload (e.g., MTV requires KubeVirt, ODF pairs with Node Health Check), mention it in the first paragraph of the Overview with a relative link to the companion's README.

4. **List all variables, including defaults.** Someone reading this should see every knob they can turn.

5. **Call out hardcoded values.** If an important CR field is hardcoded in a template instead of templatized, document it in a separate "hardcoded values" table.

6. **Document bootstrap helm overrides.** If the bootstrap Application passes `helm.values` that override chart defaults (e.g., RHOAI's bootstrap overrides the API version), call this out explicitly — it's a common source of confusion.

7. **Gotchas are workload-specific.** Common patterns (SkipDryRunOnMissingResource, retry backoff) are in the shared doc. Focus on things unique to THIS workload.

8. **Flag unused values.** If a value exists in `values.yaml` but is never referenced in any template, call it out as a gotcha. The reader should know it's a no-op.

9. **Flag missing syncPolicy.** Most bootstrap Applications have `syncPolicy.automated`, `syncOptions`, and `retry`. If one is missing any of these, flag it as a gotcha.

10. **Use tree format for file inventory.** It's faster to scan than tables and shows directory structure naturally.

11. **Use the Architecture section for complex workloads.** If a workload has 3+ charts, CronJobs, tenant integration, or data round-trip patterns (userdata ConfigMaps), an ASCII diagram at the top saves the reader from having to piece together the relationships from the file list.

12. **Create companion READMEs for two-layer workloads.** When placing the main README in the infra chart, create a one-line `README.md` in the platform chart pointing to the main doc:
    ```markdown
    # <Workload> — Platform Layer
    See the [main <workload> documentation](../../infra/<workload>-operator/README.md).
    ```

### Gotcha checklist

When writing gotchas, check for each of these:

- [ ] Multi-flag requirement (two-layer or three-flag workloads)
- [ ] `ignoreDifferences` entries and why they exist
- [ ] Hardcoded paths in bootstrap Application vs `.Values.*.git.path`
- [ ] Missing `git` defaults in bootstrap values.yaml
- [ ] MachineConfigs that trigger node reboots
- [ ] Jobs/CronJobs with `cluster-admin` in `default` namespace (persist after completion)
- [ ] Privileged containers or SCC requirements
- [ ] Sub-chart dependencies on external repos (charts.stderr.at)
- [ ] Hardcoded hostnames or cluster-specific values that must be overridden
- [ ] Placeholder/insecure default passwords or key bases
- [ ] Template conditions that don't work as expected (e.g., checking map existence vs `.enabled`)
- [ ] Resources that are never cleaned up
- [ ] PostSync hooks vs regular sync-wave resources
- [ ] Missing syncPolicy on bootstrap Applications
- [ ] Unused/vestigial values or helm overrides
- [ ] Bootstrap helm overrides that change chart defaults
- [ ] Dependencies on other workloads being installed
- [ ] Default `enabled: true` (unusual — most default to false)

## Reference Examples

See `references/example-descheduler.md` for a standard two-layer workload example.

For more complex workloads, the keycloak README (`infra/keycloak/README.md`) demonstrates:
- Architecture diagram for multi-chart workloads
- Documenting tenant-layer integration
- Handling 3+ enable flags
- CronJobs and data round-trip patterns
