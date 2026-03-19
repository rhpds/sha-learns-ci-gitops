# Keycloak Workload

## Overview

Deploys Red Hat Build of Keycloak (RHBK) as the SSO/identity provider for the cluster. Handles operator installation, database provisioning, Keycloak instance creation, OpenShift OAuth integration, and per-tenant realm management with automatic user provisioning.

This is a complex workload with **three infra sub-charts** and **tenant integration** — no platform layer:
- **infra** (`infra/keycloak/keycloak-infra/`) — installs the RHBK operator, PostgreSQL database, and generates DB credentials
- **infra** (`infra/keycloak/keycloak-resources/`) — creates the Keycloak instance, hub realm, OpenShift OAuth, hub provisioner, and cleanup CronJob
- **infra** (`infra/keycloak/keycloak-realm/`) — per-tenant realm creation, user provisioning, IdP federation (referenced by tenant bootstrap, not infra bootstrap)

> For background on the layer system, bootstrap chain, and common enable/disable pattern, see [docs/enabling-workloads.md](../../docs/enabling-workloads.md).

## Architecture

```
infra bootstrap
├── keycloak-infra Application        ← installs operator + PostgreSQL (one-time)
└── keycloak-resources Application    ← creates Keycloak instance + hub realm + OAuth (one-time)

tenant bootstrap (per tenant)
└── keycloak-realm Application        ← creates tenant realm + provisions users (per GUID)
    ├── KeycloakRealmImport CR
    ├── user-provisioner Job          ← creates users, stores credentials, writes userdata ConfigMap
    └── idp-registration CronJob      ← federates tenant realm into hub realm
```

The hub realm is the single realm OpenShift OAuth connects to. Each tenant gets a spoke realm that is federated into the hub via an OIDC Identity Provider, using Keycloak 26 Organizations for Home IdP Discovery.

## File Inventory

### keycloak-infra — operator + database

```
infra/keycloak/keycloak-infra/
├── Chart.yaml
├── values.yaml                              # operator.channel, database.*, storage.size
└── templates/
    ├── namespace-keycloak.yaml              # Creates keycloak namespace (sync-wave -20)
    ├── operatorgroup.yaml                   # OperatorGroup in keycloak
    ├── subscription.yaml                    # OLM Subscription (RHBK operator)
    ├── job-secret-db-credentials-postgresql.yaml  # Job that generates random DB password if secret doesn't exist (sync-wave -15)
    ├── service-postgresql.yaml              # PostgreSQL Service (sync-wave -15)
    ├── pvc-postgresql.yaml                  # PostgreSQL PVC (sync-wave -16)
    └── deployment-postgresql.yaml           # PostgreSQL Deployment (sync-wave -14)

infra/bootstrap/templates/keycloak/
└── application-keycloak-infra.yaml          # ArgoCD Application, gated by keycloakInfra.enabled
```

### keycloak-resources — instance + hub realm + OAuth

```
infra/keycloak/keycloak-resources/
├── Chart.yaml
├── values.yaml                              # deployer.domain, hub.realm.*, oauth.*, ssoadmin.*
└── templates/
    ├── tls-service.yaml                     # Service with serving-cert annotation for TLS (sync-wave -14)
    ├── instance.yaml                        # Keycloak CR — the main instance (sync-wave -13)
    ├── hub-realm.yaml                       # KeycloakRealmImport for hub realm (sync-wave -11)
    ├── route.yaml                           # Route: sso.<deployer.domain>
    ├── oauth.yaml                           # OpenShift OAuth configuration (sync-wave -8), gated by oauth.enabled
    ├── clusterrolebinding-ssoadmin.yaml     # cluster-admin for ssoadmin user (sync-wave -10), gated by ssoadmin.enabled
    ├── job-hub-provisioner.yaml             # Job that configures hub realm, creates OAuth client secret, ssoadmin user, enables Organizations (sync-wave -10)
    └── cronjob-idp-and-realm-cleanup.yaml   # CronJob (every 2m) that removes orphaned tenant realms/IdPs

infra/bootstrap/templates/keycloak/
└── application-keycloak-resources.yaml      # ArgoCD Application, gated by keycloakResources.enabled (passes deployer values)
```

### keycloak-realm — per-tenant (referenced by tenant bootstrap)

```
infra/keycloak/keycloak-realm/
├── Chart.yaml
├── values.yaml                              # tenant.name, realm.*, user.*, hub.realmName, deployer.domain
└── templates/
    ├── keycloak-realm-cr.yaml               # KeycloakRealmImport for tenant realm (sync-wave -9)
    ├── idp-registration-configmap.yaml      # ConfigMap for IdP registration data (sync-wave -7)
    ├── cronjob-register-idp.yaml            # CronJob (every 2m) that registers tenant realm as IdP in hub + creates Organization
    └── job-user-provisioner.yaml            # Job that creates users, generates passwords, stores in Secret, writes userdata ConfigMap (sync-wave -8)

tenant/bootstrap/templates/platform-apps/
├── application-keycloak-realm.yaml          # ArgoCD Application, gated by keycloakRealm.enabled
├── configmap-keycloak-provisiondata.yaml    # Empty userdata ConfigMap (populated by user-provisioner Job)
├── _users.tpl                               # Helper template for building user lists from prefix+count and named users
└── applicationset-workspace.yaml            # Per-user workspace ApplicationSet (gated by tenant.user.keycloakEnabled)
```

## How to Enable

This workload has **three independent enable flags** (two infra, one tenant). All are in `infra/bootstrap/values.yaml`:

| Flag | File | Default |
|------|------|---------|
| `keycloakInfra.enabled` | `infra/bootstrap/values.yaml` | `false` |
| `keycloakResources.enabled` | `infra/bootstrap/values.yaml` | `false` |
| `keycloakRealm.enabled` | `tenant/bootstrap/values.yaml` | `false` |

Enable `keycloakInfra` first (operator + DB), then `keycloakResources` (instance + hub). The `keycloakRealm` is enabled per-tenant from the tenant bootstrap.

The infra flags can be set from the catalog:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  keycloakInfra:
    enabled: true
  keycloakResources:
    enabled: true
```

The keycloak-resources Application passes `deployer` values through (unlike most infra Applications), so the Keycloak hostname (`sso.<domain>`) resolves correctly.

## Variables Reference

### keycloak-infra — `infra/keycloak/keycloak-infra/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `operator.channel` | `stable-v26.0` | OLM channel for RHBK operator |
| `operator.installPlanApproval` | `Automatic` | Install plan approval |
| `database.secretName` | `keycloak-db-credentials` | Name of the DB credentials Secret |
| `database.name` | `keycloak` | PostgreSQL database name |
| `database.username` | `keycloak` | PostgreSQL username |
| `storage.size` | `50Gi` | PVC size for PostgreSQL |

### keycloak-resources — `infra/keycloak/keycloak-resources/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `deployer.domain` | `cluster.example.com` | Cluster ingress domain — **must match actual cluster** |
| `hub.realm.name` | `hub` | Hub realm name |
| `hub.realm.displayName` | `OpenShift` | Hub realm display name |
| `oauth.enabled` | `true` | Configure OpenShift OAuth to use Keycloak |
| `oauth.clientId` | `openshift-oauth` | OAuth client ID |
| `ssoadmin.enabled` | `true` | Create an ssoadmin user with cluster-admin |
| `ssoadmin.username` | `ssoadmin` | SSO admin username |
| `ssoadmin.email` | `ssoadmin@example.com` | SSO admin email |

### keycloak-realm — `infra/keycloak/keycloak-realm/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `tenant.name` | `xyzzy` | Tenant identifier (realm name defaults to this) |
| `realm.name` | `""` | Realm name override (defaults to `tenant.name`) |
| `realm.displayName` | `""` | Realm display name (defaults to `tenant.name`) |
| `realm.enabled` | `true` | Whether the realm is enabled |
| `user.prefix` | `user` | Username prefix for generated users |
| `user.count` | `0` | Number of users to generate (0 = none) |
| `user.names` | `[]` | Explicit list of usernames to create |
| `hub.realmName` | `hub` | Name of the hub realm to federate into |
| `deployer.domain` | `cluster.example.com` | Cluster domain for Keycloak URL |

## Gotchas

1. **Three charts, specific deployment order.** `keycloak-infra` must deploy first (operator + DB), then `keycloak-resources` (instance + hub realm). `keycloak-realm` can only deploy after both are ready. Sync-waves handle this: namespace at `-20`, DB at `-15`/`-14`, instance at `-13`, hub realm at `-11`, OAuth at `-8`, tenant realm at `-9`.

2. **DB password is auto-generated.** The `pgsql-secret-generator` Job creates the DB credentials Secret with a random 24-character password if it doesn't already exist. Re-running the Job is safe (idempotent).

3. **Hub provisioner is also idempotent.** The `job-hub-provisioner` generates an OAuth client secret and ssoadmin password only on first run. On re-run, it loads the existing secrets.

4. **Two CronJobs run every 2 minutes.** The IdP registration CronJob (`keycloak-realm`) and the cleanup CronJob (`keycloak-resources`) both run every 2 minutes. The registration job federates tenant realms into the hub. The cleanup job detects and removes orphaned tenant resources when a tenant is deleted from GitOps.

5. **Keycloak 26 Organizations feature.** The hub provisioner enables Keycloak Organizations for Home IdP Discovery. Each tenant gets an Organization with a domain matching its realm name, allowing automatic routing to the correct IdP based on username suffix.

6. **User provisioner writes userdata ConfigMaps.** The user-provisioner Job creates a ConfigMap named `tenant-<realm>-userdata-keycloak` in `openshift-gitops`, labeled `demo.redhat.com/tenant-<realm>: "true"`. This is the data round-trip mechanism that passes credentials back to the deployer system.

7. **`keycloak-resources` receives `deployer` values.** The bootstrap Application for `keycloak-resources` forwards `deployer` values (unlike most infra Applications). This is because the Keycloak instance hostname is `sso.{{ .Values.deployer.domain }}`.

8. **Tenant bootstrap owns the keycloak-realm Application.** Unlike the infra charts, `keycloak-realm` is deployed from `tenant/bootstrap/templates/`, not `infra/bootstrap/templates/`. It uses the `tenants` ArgoCD project and includes a finalizer for cleanup.

9. **`scratch/` directory.** The `keycloak-realm` chart contains a `scratch/realm-import.yaml` that uses Jinja2 syntax (not Helm). This is a reference/scratch file from the Ansible-based approach — it is not rendered by Helm.
