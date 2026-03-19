# Web Terminal Workload

## Overview

Installs the OpenShift Web Terminal Operator, which adds an in-console terminal for running CLI commands directly from the OpenShift web console. This is a **platform-only** workload — the operator is installed via OLM directly in the platform layer (no separate infra chart).

Uses the `helper-status-checker` sub-chart from `charts.stderr.at` to verify operator readiness after installation.

## File Inventory

All paths relative to gitops repo root.

| File | Purpose |
|------|---------|
| `platform/webterminal/Chart.yaml` | Helm chart metadata, declares sub-chart dependencies |
| `platform/webterminal/Chart.lock` | Locked dependency versions |
| `platform/webterminal/values.yaml` | Defaults for operator and status checker |
| `platform/webterminal/templates/operator.yaml` | OLM Subscription (sync-wave from values, default `-5`) |
| `platform/webterminal/application-webterminal.yaml` | Standalone ArgoCD Application (reference only, not used by bootstrap) |
| `platform/webterminal/.helmignore` | Helm build ignore patterns |
| `platform/webterminal/.gitignore` | Ignores `charts/` directory (sub-chart tarballs) |
| `platform/bootstrap/templates/application-webterminal.yaml` | ArgoCD Application, gated by `webterminal.enabled` |

## Variables Reference

### Platform bootstrap (`platform/bootstrap/values.yaml`)

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `webterminal.enabled` | `false` | **Yes** | Master switch |
| `webterminal.git.repoURL` | inherited from `&git_defaults` | No | Git repo URL |
| `webterminal.git.targetRevision` | inherited from `&git_defaults` | No | Git branch/tag |
| `webterminal.git.path` | `platform/webterminal` | No | Chart path |
| `webterminal.startingCSV` | unset | No | Pin to a specific operator version |

### Platform chart (`platform/webterminal/values.yaml`)

**Operator settings:**

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `operator.enabled` | `false` | No | Inner gate for the Subscription template (see Gotchas — effectively unused) |
| `operator.name` | `web-terminal` | No | Operator package name |
| `operator.namespace` | `openshift-operators` | No | Install namespace |
| `operator.channel` | `fast` | No | OLM channel |
| `operator.installPlanApproval` | `Automatic` | No | Install plan approval |
| `operator.source` | `redhat-operators` | No | CatalogSource name |
| `operator.sourceNamespace` | `openshift-marketplace` | No | CatalogSource namespace |
| `operator.startingCSV` | unset | No | Pin to specific version |
| `operator.syncwave` | `-5` | No | Sync-wave for the Subscription |

**Status checker settings:**

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `helper-status-checker.enabled` | `true` | No | Run post-install operator readiness check |
| `helper-status-checker.approver` | `false` | No | Auto-approve InstallPlans (not needed with `Automatic` approval) |
| `helper-status-checker.checks[0].operatorName` | `web-terminal` | No | Operator to check |
| `helper-status-checker.checks[0].namespace.name` | `openshift-operators` | No | Namespace to check in |
| `helper-status-checker.checks[0].syncwave` | `"1"` | No | Sync-wave for the check Job |
| `helper-status-checker.checks[0].serviceAccount.name` | `webterminal-status-checker` | No | SA for the checker Job |

## Enabling / Disabling

Set `webterminal.enabled: true` in `platform/bootstrap/values.yaml`. This is a single-layer workload — only one flag needed.

The platform flag must be set in the repo — it cannot be overridden from the AgnosticV catalog (the infra-to-platform bootstrap only forwards `deployer` values).

## AgnosticV Catalog Integration

Web Terminal is a **cluster-level** workload. Your cluster catalog `common.yaml` should already have:

```yaml
ocp4_workload_gitops_bootstrap_repo_url: https://github.com/rhpds/your-gitops-repo.git
ocp4_workload_gitops_bootstrap_repo_revision: main
ocp4_workload_gitops_bootstrap_application_name: "bootstrap-infra"

workloads:
  - agnosticd.core_workloads.ocp4_workload_openshift_gitops
  - agnosticd.core_workloads.ocp4_workload_gitops_bootstrap
```

Since the platform flag can't be overridden from the catalog, enable it directly in `platform/bootstrap/values.yaml` in your gitops repo.

## Gotchas

1. **Sub-chart dependencies.** This chart depends on `helper-status-checker` (~4.0.0) and `tpl` (~1.0.0) from `https://charts.stderr.at/`. The `charts/` directory is gitignored — ArgoCD fetches the dependencies at sync time. If the external chart repo is unavailable, the sync will fail.

2. **`operator.enabled` vs `webterminal.enabled`.** There are two gates: `webterminal.enabled` in the bootstrap controls whether the ArgoCD Application is created; `operator.enabled` in the chart values controls whether the Subscription template renders. The chart defaults `operator.enabled: false`, but the Subscription template's condition (`{{ if .Values.operator -}}`) checks for the existence of the `operator` map (which is truthy since defaults exist), not `.Values.operator.enabled`. So the Subscription renders regardless of `operator.enabled` — the field is effectively unused.

3. **Bootstrap path is `webterminal`, not `platform/webterminal`.** The bootstrap Application template hardcodes `path: webterminal` instead of using `.Values.webterminal.git.path`. ArgoCD looks for the chart at `<repoRoot>/webterminal`. If your chart is at `platform/webterminal`, this path is wrong and needs to be fixed.

4. **Two Application manifests.** `platform/webterminal/application-webterminal.yaml` is a standalone reference example (uses `project: default`, no syncPolicy). The actual Application used by the bootstrap is `platform/bootstrap/templates/application-webterminal.yaml`. Don't confuse them.

5. **Bootstrap overrides `installPlanApproval`.** The bootstrap Application template always passes `installPlanApproval: Automatic` as a helm override, regardless of what's in the chart defaults. The chart default is also `Automatic`, so this is redundant but worth knowing if you want `Manual` approval — you'd need to change the bootstrap template.
