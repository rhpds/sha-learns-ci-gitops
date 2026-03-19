# KubeVirt (OpenShift Virtualization) Workload

## Overview

Installs and configures the OpenShift Virtualization (KubeVirt) operator. This enables running virtual machines alongside containers on OpenShift. The workload spans **two layers**:

- **infra** — installs the operator via OLM with Manual install plan approval, plus a Job to auto-approve the InstallPlan
- **platform** — creates the `HyperConverged` CR, an external Ceph StorageClass, and a Job to patch storage settings for VM boot images

## File Inventory

All paths relative to gitops repo root.

### Infra layer (operator installation)

| File | Sync-wave | Purpose |
|------|-----------|---------|
| `infra/kubevirt-operator/Chart.yaml` | — | Helm chart metadata |
| `infra/kubevirt-operator/values.yaml` | — | Defaults: channel, startingCSV, Manual approval |
| `infra/kubevirt-operator/templates/operatorgroup.yaml` | `3` | OperatorGroup in `openshift-cnv` |
| `infra/kubevirt-operator/templates/subscription.yaml` | `3` | OLM Subscription with pinned CSV |
| `infra/kubevirt-operator/templates/installplan-approval-job.yaml` | `3` | ServiceAccount + ClusterRoleBinding + Job that approves the InstallPlan |
| `infra/bootstrap/templates/application-kubevirt-operator.yaml` | — | ArgoCD Application, gated by `kubevirtOperator.enabled` |

### Platform layer (operator configuration)

| File | Sync-wave | Purpose |
|------|-----------|---------|
| `platform/kubevirt/Chart.yaml` | — | Helm chart metadata |
| `platform/kubevirt/values.yaml` | — | Defaults: tolerations, external_ceph, guid |
| `platform/kubevirt/templates/hyperconverged.yaml` | `3` | `HyperConverged` CR in `openshift-cnv` |
| `platform/kubevirt/templates/storageclass.yaml` | `0` | External Ceph RBD StorageClass (set as default) |
| `platform/kubevirt/templates/vm-datasource-job.yaml` | `4` | Job that patches StorageProfile and re-enables boot image import |
| `platform/bootstrap/templates/application-kubevirt.yaml` | — | ArgoCD Application, gated by `kubevirt.enabled` |

## Variables Reference

### Infra bootstrap (`infra/bootstrap/values.yaml`)

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `kubevirtOperator.enabled` | `false` | **Yes** | Master switch |
| `kubevirtOperator.git.repoURL` | inherited from `&git_defaults` | No | Git repo URL |
| `kubevirtOperator.git.targetRevision` | inherited from `&git_defaults` | No | Git branch/tag |
| `kubevirtOperator.git.path` | `infra/kubevirt-operator` | No | Chart path |

### Infra chart (`infra/kubevirt-operator/values.yaml`)

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `operator.channel` | `candidate` | No | OLM subscription channel |
| `operator.startingCSV` | `kubevirt-hyperconverged-operator.v4.20.3` | No | Pinned operator version |
| `operator.installPlanApproval` | `Manual` | No | `Manual` triggers the approval Job |

### Platform bootstrap (`platform/bootstrap/values.yaml`)

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `kubevirt.enabled` | `false` | **Yes** | Master switch |
| `kubevirt.git.repoURL` | inherited from `&git_defaults` | No | Git repo URL |
| `kubevirt.git.targetRevision` | inherited from `&git_defaults` | No | Git branch/tag |
| `kubevirt.git.path` | `platform/kubevirt` | No | Chart path |

### Platform chart (`platform/kubevirt/values.yaml`)

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `ocp4_workload_openshift_virtualization_workload_tolerations` | `[]` | No | Node tolerations for VM workloads |
| `external_ceph` | `true` | No | When `true`, disables common boot image import in the CR (the Job re-enables it at wave 4 after patching storage) |
| `guid` | `xyzzy` | **Yes** | Cluster GUID, used as volume name prefix in the StorageClass |

## Enabling / Disabling

Two independent `enabled` flags must both be `true`:

1. **Infra** — `kubevirtOperator.enabled: true` in `infra/bootstrap/values.yaml`
2. **Platform** — `kubevirt.enabled: true` in `platform/bootstrap/values.yaml`

The infra flag can be overridden from the AgnosticV catalog. The platform flag must be set in the repo.

## AgnosticV Catalog Integration

KubeVirt is a **cluster-level** workload enabled from your **cluster** catalog item.

Your cluster catalog `common.yaml` should already have:

```yaml
ocp4_workload_gitops_bootstrap_repo_url: https://github.com/rhpds/your-gitops-repo.git
ocp4_workload_gitops_bootstrap_repo_revision: main
ocp4_workload_gitops_bootstrap_application_name: "bootstrap-infra"

workloads:
  - agnosticd.core_workloads.ocp4_workload_openshift_gitops
  - agnosticd.core_workloads.ocp4_workload_gitops_bootstrap
```

To enable KubeVirt from the catalog:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  kubevirtOperator:
    enabled: true
```

The platform layer (`kubevirt.enabled`) must be set to `true` directly in `platform/bootstrap/values.yaml` in your repo — the infra-to-platform bootstrap only forwards `deployer` values.

You must also set `guid` in `platform/kubevirt/values.yaml` (or templatize it to receive the deployer's guid).

## Gotchas

1. **Manual InstallPlan approval pattern.** Unlike most workloads that use `Automatic` approval, KubeVirt uses `Manual` with a companion Job (`installplan-approval-job`) that runs `oc patch installplan ... --patch '{"spec":{"approved":true}}'`. This pins the operator to a specific CSV version. The Job uses `cluster-admin` and runs in the `default` namespace.

2. **`startingCSV` pins the version.** The default `kubevirt-hyperconverged-operator.v4.20.3` pins to a specific operator version. When upgrading OpenShift or the operator, update this value.

3. **`ignoreDifferences` on `HyperConverged`.** The platform Application ignores diffs on `/spec/enableCommonBootImageImport` because the `vm-datastore-job` patches this field post-deploy (from `false` to `true` after configuring the StorageProfile).

4. **External Ceph StorageClass is hardcoded.** The `storageclass.yaml` creates `ocs-external-storagecluster-ceph-rbd` as the default StorageClass, configured for an external Ceph cluster with specific pool name (`ocpv-tenants`) and CSI secrets. If you don't use external Ceph, remove or modify this template.

5. **The `guid` variable must be set.** It's used as a volume name prefix in the StorageClass (`openshift-cluster-<guid>-`). The default `xyzzy` is a placeholder.

6. **Two Jobs with `cluster-admin`.** Both the install plan approval Job (infra) and the VM datastore Job (platform) create ServiceAccounts with `cluster-admin` ClusterRoleBindings in the `default` namespace. These persist after the Jobs complete.

7. **Boot image import sequence.** The `HyperConverged` CR initially sets `enableCommonBootImageImport: false` (when `external_ceph: true`). Then at wave 4, the `vm-datastore-job` patches the StorageProfile to use PVC-based import and re-enables boot image import. This two-step approach avoids failures when the StorageProfile isn't ready yet.
