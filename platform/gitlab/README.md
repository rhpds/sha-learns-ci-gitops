# GitLab Workload

## Overview

Deploys a self-hosted GitLab CE instance with PostgreSQL and Redis on OpenShift. This is a **platform-only** workload — no operator is installed; GitLab runs as plain Deployments. After deployment, an init Job runs an Ansible playbook that waits for GitLab to become healthy, creates a root API token, provisions users, and optionally creates groups with imported repositories.

## File Inventory

All paths relative to gitops repo root.

| File | Sync-wave | Purpose |
|------|-----------|---------|
| `platform/gitlab/Chart.yaml` | — | Helm chart metadata (appVersion `12.5.7`) |
| `platform/gitlab/values.yaml` | — | All defaults (host, users, SMTP, DB creds, etc.) |
| `platform/gitlab/templates/sa-gitlab.yaml` | `-2` | ServiceAccount used by all GitLab pods and the init Job |
| `platform/gitlab/templates/crb-gitlab-anyuid.yaml` | `-1` | ClusterRoleBinding granting `anyuid` SCC |
| `platform/gitlab/templates/crb-gitlab-privileged.yaml` | `-1` | RoleBinding granting `privileged` SCC |
| `platform/gitlab/templates/crb-gitlab-admin-ns.yaml` | `-1` | RoleBinding granting `admin` ClusterRole in chart namespace |
| `platform/gitlab/templates/cm-gitlab.yaml` | `0` | ConfigMap with GitLab env vars (host, SMTP, DB, email) |
| `platform/gitlab/templates/sct-gitlab.yaml` | `0` | Secret with DB password, root password, key bases, SMTP password |
| `platform/gitlab/templates/pvc-postgresql.yaml` | `1` | 10Gi PVC for PostgreSQL |
| `platform/gitlab/templates/pvc-redis.yaml` | `1` | 10Gi PVC for Redis |
| `platform/gitlab/templates/deploy-postgresql.yaml` | `1` | PostgreSQL Deployment |
| `platform/gitlab/templates/deploy-redis.yaml` | `1` | Redis Deployment |
| `platform/gitlab/templates/svc-postgresql.yaml` | `1` | PostgreSQL Service |
| `platform/gitlab/templates/svc-redis.yaml` | `1` | Redis Service |
| `platform/gitlab/templates/pvc-gitlab.yaml` | `2` | 10Gi PVC for GitLab data |
| `platform/gitlab/templates/deploy-gitlab.yaml` | `2` | GitLab Deployment (image from values) |
| `platform/gitlab/templates/svc-gitlab.yaml` | `2` | GitLab Service (ports 22, 80) |
| `platform/gitlab/templates/rt-gitlab.yaml` | `2` | OpenShift Route (edge TLS) |
| `platform/gitlab/templates/cm-gitlab-root-pat.yaml` | `1` | ConfigMap with script to create root Personal Access Token |
| `platform/gitlab/templates/cm-gitlab-init.yaml` | `3` | ConfigMap containing Ansible playbook for post-deploy init |
| `platform/gitlab/templates/job-gitlab-init.yaml` | `3` | Job that runs the init playbook |
| `platform/bootstrap/templates/application-gitlab.yaml` | — | ArgoCD Application, gated by `gitlab.enabled` |

## Variables Reference

### Platform bootstrap (`platform/bootstrap/values.yaml`)

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `gitlab.enabled` | `false` | **Yes** | Master switch — creates the ArgoCD Application |
| `gitlab.git.repoURL` | **none** | **Yes** | Must be provided — no default in values.yaml |
| `gitlab.git.targetRevision` | **none** | **Yes** | Must be provided — no default in values.yaml |
| `gitlab.startingCSV` | unset | No | Passed as helm override to the chart (vestigial — chart has no operator) |

Note: unlike other workloads, `gitlab` has no `git:` block with `<<: *git_defaults` in the platform bootstrap values. The git values and the path (`gitlab`) are handled differently — see Gotchas.

### Platform chart (`platform/gitlab/values.yaml`)

**GitLab settings:**

| Variable | Default | Description |
|----------|---------|-------------|
| `gitlab.image` | `quay.io/redhat-gpte/gitlab:16.0.4` | GitLab container image |
| `gitlab.host` | `gitlab-gitlab.apps.cluster-br9rv...` | GitLab FQDN — **must override** |
| `gitlab.https` | `"true"` | Whether GitLab uses HTTPS |
| `gitlab.rootPassword` | `openshift` | Root user password |
| `gitlab.rootEmail` | `treddy@redhat.com` | Root user email |
| `gitlab.email.address` | `gitlab@example.com` | System email from address |
| `gitlab.email.displayName` | `Tyrell Reddy` | System email display name |
| `gitlab.email.replyTo` | `noreply@redhat.com` | Reply-to address |
| `gitlab.ssh.host` | `ssh.gitlab-gitlab.apps.cluster-br9rv...` | SSH hostname — **must override** |
| `gitlab.ssh.port` | `"22"` | SSH port |
| `gitlab.keyBase.db` | `0123456789` | `GITLAB_SECRETS_DB_KEY_BASE` — **should override** |
| `gitlab.keyBase.otp` | `0123456789` | `GITLAB_SECRETS_OTP_KEY_BASE` — **should override** |
| `gitlab.keyBase.secret` | `0123456789` | `GITLAB_SECRETS_SECRET_KEY_BASE` — **should override** |
| `gitlab.users.base` | `user` | Username prefix (creates `user1`, `user2`, ...) |
| `gitlab.users.password` | `openshift` | Password for created users |
| `gitlab.users.count` | `2` | Number of users to create |
| `gitlab.groups` | `[]` | List of groups with repos to import (see format below) |

**SMTP settings (disabled by default):**

| Variable | Default | Description |
|----------|---------|-------------|
| `gitlab.smtp.enabled` | `"false"` | Enable SMTP |
| `gitlab.smtp.domain` | `example.com` | SMTP domain |
| `gitlab.smtp.host` | hardcoded sandbox host | SMTP server — **must override if enabled** |
| `gitlab.smtp.port` | `"587"` | SMTP port |
| `gitlab.smtp.user` | `gitlab` | SMTP username |
| `gitlab.smtp.password` | `gitlab` | SMTP password |

**PostgreSQL settings:**

| Variable | Default | Description |
|----------|---------|-------------|
| `postgresql.dbUser` | `gitlab` | Database username |
| `postgresql.dbPassword` | `passw0rd` | Database password |
| `postgresql.dbName` | `gitlab_production` | Database name |

### Groups format

```yaml
gitlab:
  groups:
  - name: backstage
    repo:
    - name: software-templates
      url: https://github.com/example/software-templates.git
```

The init Job creates the group, imports each repo into it, and adds all matching users as Owners (access level 50).

## Enabling / Disabling

Set `gitlab.enabled: true` in `platform/bootstrap/values.yaml`. Since the `git` defaults are missing (see Gotchas), you also need to provide `gitlab.git.repoURL` and `gitlab.git.targetRevision`.

The platform flag must be set in the repo — it cannot be overridden from the AgnosticV catalog (same limitation as descheduler: the infra-to-platform bootstrap only forwards `deployer` values).

## AgnosticV Catalog Integration

GitLab is a **cluster-level** workload enabled from your **cluster** catalog item.

Your cluster catalog `common.yaml` should already have these:

```yaml
ocp4_workload_gitops_bootstrap_repo_url: https://github.com/rhpds/your-gitops-repo.git
ocp4_workload_gitops_bootstrap_repo_revision: main
ocp4_workload_gitops_bootstrap_application_name: "bootstrap-infra"

workloads:
  - agnosticd.core_workloads.ocp4_workload_openshift_gitops
  - agnosticd.core_workloads.ocp4_workload_gitops_bootstrap
```

GitLab is enabled in the repo's `platform/bootstrap/values.yaml`, not via catalog helm overrides. The `gitlab.host` value (which must match the cluster's ingress domain) is the main thing you need to customize. Since the platform bootstrap receives `deployer.domain` from infra, you would need to templatize `gitlab.host` in the chart values to use the domain dynamically — or hardcode it for a known cluster.

## Gotchas

1. **The Application path is hardcoded to `gitlab`.** Unlike other workloads that use `.Values.<name>.git.path`, the gitlab Application template has `path: gitlab` hardcoded. This means ArgoCD looks for the chart at `<repoRoot>/gitlab`, not `platform/gitlab`. If your repo has the chart at `platform/gitlab`, this will fail. You may need to fix the path to `platform/gitlab` in the Application template.

2. **Missing `git` defaults.** The `gitlab` entry in `platform/bootstrap/values.yaml` only has `enabled: false` — no `git:` block with `<<: *git_defaults`. The Application template references `.Values.gitlab.git.repoURL` and `.Values.gitlab.git.targetRevision`, which will be empty unless you add the defaults.

3. **`gitlab.host` and `gitlab.ssh.host` must match your cluster.** The defaults are hardcoded to a specific sandbox cluster FQDN. These must be overridden to match your actual cluster's ingress domain (e.g., `gitlab-gitlab.apps.<cluster-domain>`).

4. **`keyBase` values are placeholder.** The defaults (`0123456789`) are insecure. For production or shared environments, override `gitlab.keyBase.db`, `.otp`, and `.secret` with proper random strings.

5. **The init Job waits 5 minutes, then polls.** The `initialize-gitlab` Job (sync-wave `3`) first pauses 5 minutes, then polls the GitLab API with 60 retries at 10-second intervals. GitLab takes significant time to start — expect 5–15 minutes for full initialization.

6. **Privileged containers.** GitLab, PostgreSQL, and Redis all run with `securityContext.privileged: true`. The chart creates `anyuid` (ClusterRoleBinding) and `privileged` (RoleBinding) bindings for the `gitlab` ServiceAccount.

7. **30Gi total PVC storage.** Three 10Gi PVCs are created: one each for GitLab data, PostgreSQL, and Redis. Ensure sufficient storage capacity.

8. **No destination namespace in the Application.** The bootstrap Application doesn't set `spec.destination.namespace`. Resources use `{{ $.Release.Namespace }}`. Ensure your ArgoCD setup routes this correctly (typically by adding a `destination.namespace: gitlab` to the Application template).

9. **Vestigial `operator` helm values.** The Application template passes `operator.startingCSV` and `operator.installPlanApproval` as helm overrides, but the gitlab chart has no operator — it deploys GitLab directly. These values are unused.

10. **Double-escaped Jinja in the init playbook.** The `cm-gitlab-init.yaml` uses `{{ "{{" }}` / `{{ "}}" }}` to escape Ansible/Jinja2 variables inside Helm templates. If modifying the init playbook, maintain this escaping pattern.
