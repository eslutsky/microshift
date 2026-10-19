# Design: Robot Framework Upgrade/Downgrade CA Migration Test

**Date:** 2026-10-19
**Feature:** OCPSTRAT-2900 — MicroShift CA and Certificate Consolidation
**Author:** eslutsky

---

## Context

MicroShift 5.1 consolidates its PKI from 12 CAs to 6. On first startup after
upgrading from 5.0, `migrateLegacyCertLayout()` detects the old layout by
checking for `certs/kube-control-plane-signer/`, atomically renames `certs/`
to `certs.backup.<version>.<timestamp>/`, restores `service-ca` from the
backup, and generates a fresh 6-CA hierarchy. On downgrade the old binary
regenerates the 12-CA layout from scratch.

This test suite exercises both directions end-to-end on an RPM-based system.

---

## Test File

**Path:** `test/suites/rpm/upgrade-cert-migration.robot`

Follows the pattern of `test/suites/rpm/upgrade-successful.robot`.

---

## Settings

```robotframework
*** Settings ***
Documentation    Verify CA cert migration on RPM upgrade (5.0 → 5.1) and
...              legacy layout regeneration on downgrade (5.1 → 5.0).

Resource    ../../resources/common.resource
Resource    ../../resources/microshift-host.resource
Resource    ../../resources/microshift-process.resource
Resource    ../../resources/ostree-health.resource

Suite Setup     Setup
Suite Teardown  Teardown

Test Tags    restart    rpm-based-system    slow    certificates
```

---

## Variables

```robotframework
*** Variables ***
${CERTSDIR}      /var/lib/microshift/certs
${CERTS_PARENT}  /var/lib/microshift
```

---

## Test Cases

### TC1 — Certificate Layout Is Migrated On Upgrade

Suite Setup installed 5.0 RPM and started MicroShift (12-CA layout).
This TC installs the 5.1 RPM and verifies the migration.

Steps:
1. `Install MicroShift RPM Packages From Repo`
2. `Restart MicroShift` → `Wait For MicroShift Healthcheck Success`
3. Assert **new CA dirs exist:** `client-ca/`, `serving-ca/`, `peer-ca/`
4. Assert **old signer dirs absent:** `kube-control-plane-signer/`, `kube-apiserver-external-signer/`, `etcd-signer/`
5. Assert **backup dir exists:** `ls ${CERTS_PARENT} | grep -q certs\.backup\.`

Keywords: `Verify Remote Directory Exists With Sudo`, `Verify Remote Directory Does Not Exist With Sudo`, `Command Should Work`

---

### TC2 — Service CA Is Preserved Across Upgrade

Pre-condition: TC1 complete (6-CA layout running).

Steps:
1. Read `${POST_FP}=  openssl x509 -noout -fingerprint -sha256 -in ${CERTSDIR}/service-ca/ca.crt`
2. `Should Be Equal As Strings  ${PRE_SERVICE_CA_FP}  ${POST_FP}`

`${PRE_SERVICE_CA_FP}` is captured in Suite Setup before the upgrade.

---

### TC3 — Cluster Is Healthy After Upgrade

Steps:
1. `Wait For MicroShift Healthcheck Success`
2. `Setup Kubeconfig`
3. `Run With Kubeconfig  oc get nodes` — assert node Ready

---

### TC4 — Legacy Certificate Layout Is Regenerated On Downgrade

Pre-condition: TC1–TC3 complete (5.1 RPM, 6-CA layout).

Steps:
1. `Install MicroShift RPM Packages From System Repo` — reinstall 5.0 RPM
2. `Restart MicroShift` → `Wait For MicroShift Healthcheck Success`
3. Assert **old CA dirs regenerated:** `kube-control-plane-signer/`, `etcd-signer/`, `admin-kubeconfig-signer/`
4. Assert **new CA dirs absent:** `client-ca/`, `serving-ca/`, `peer-ca/`

---

### TC5 — Cluster Is Healthy After Downgrade

Same health assertions as TC3.

---

## Suite Keywords

### Setup

```
Login MicroShift Host
Install MicroShift RPM Packages From System Repo
Start MicroShift
Wait For MicroShift Healthcheck Success
Setup Kubeconfig
${fp}=  Command Should Work
...  openssl x509 -noout -fingerprint -sha256 -in ${CERTSDIR}/service-ca/ca.crt
Set Suite Variable  ${PRE_SERVICE_CA_FP}  ${fp}
```

### Teardown

```
Remove Kubeconfig
Logout MicroShift Host
```

---

## Out of Scope

- openssl leaf cert chain verification
- OSTree/greenboot rollback path
- Multi-upgrade/rollback cycles

---

## CI Integration

Requires an RPM-based RHEL host with the 5.0 system repo configured.
Follows the pattern of `el98-rpm@upgrade-successful.sh`.
