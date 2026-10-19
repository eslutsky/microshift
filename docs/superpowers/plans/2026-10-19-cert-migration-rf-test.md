# Cert Migration RF Test Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `test/suites/rpm/upgrade-cert-migration.robot` — a Robot Framework suite that installs MicroShift 5.0, upgrades to 5.1, asserts the cert layout migrated correctly (6 CAs, backup dir, service-ca preserved), then downgrades back to 5.0 and asserts the 12-CA layout was regenerated.

**Architecture:** Single `.robot` file following the `test/suites/rpm/upgrade-successful.robot` pattern. Suite Setup installs the old RPM and starts MicroShift; five sequential test cases exercise upgrade assertions, service-ca fingerprint check, cluster health, downgrade assertions, and post-downgrade health. Tests run in order (state is preserved across cases).

**Tech Stack:** Robot Framework, SSH-based remote execution, openssl CLI on the remote host, MicroShift RPM packages.

## Global Constraints

- Worktree: `/home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation/`
- Test tags must include: `restart    rpm-based-system    slow    certificates`
- Required variables at runtime: `${PREVIOUS_MAJOR_VERSION}`, `${PREVIOUS_MINOR_VERSION}`, `${SOURCE_REPO_URL}`, `${TARGET_VERSION}`, `${USHIFT_HOST}`, `${USHIFT_HOST_USER}`
- Resource imports use relative paths: `../../resources/`
- All remote commands run over SSH via SSHLibrary (via `Command Should Work` or `Execute Command`)
- Tests must run IN ORDER — do not run them individually or in isolation
- No greenboot / OSTree assumptions — RPM-based RHEL host only
- Cert directory base: `/var/lib/microshift/certs`

---

### Task 1: Create the test file skeleton

**Files:**
- Create: `test/suites/rpm/upgrade-cert-migration.robot`

- [ ] **Step 1: Create the file with Settings, Variables, and empty Test Cases + Keywords blocks**

```robotframework
*** Comments ***
# Tests run IN ORDER — each test case depends on the state left by the previous one.
# Do not run individual test cases in isolation.

*** Settings ***
Documentation       Verify CA cert layout migration on RPM upgrade (5.0 → 5.1)
...                 and legacy layout regeneration on downgrade (5.1 → 5.0).
...
...                 Suite Setup installs the 5.0 RPM and starts MicroShift so
...                 the pre-upgrade service-ca fingerprint can be captured.
...                 Test cases then upgrade, assert migration, downgrade, and
...                 assert legacy layout regeneration — in that order.

Resource            ../../resources/common.resource
Resource            ../../resources/microshift-host.resource
Resource            ../../resources/microshift-process.resource
Resource            ../../resources/microshift-rpm.resource
Resource            ../../resources/ostree-health.resource

Suite Setup         Setup
Suite Teardown      Teardown

Test Tags           restart    rpm-based-system    slow    certificates


*** Variables ***
${CERTSDIR}         /var/lib/microshift/certs
${CERTS_PARENT}     /var/lib/microshift


*** Test Cases ***
Certificate Layout Is Migrated On Upgrade
    [Documentation]    Upgrade to 5.1 RPM and verify the 6-CA layout is in place,
    ...                old signer dirs are absent, and a backup dir was created.
    Log    placeholder
    # implementation added in Task 2

Service CA Is Preserved Across Upgrade
    [Documentation]    Verify service-ca fingerprint is identical before and after upgrade.
    Log    placeholder
    # implementation added in Task 3

Cluster Is Healthy After Upgrade
    [Documentation]    Verify microshift healthcheck passes and node is Ready after upgrade.
    Log    placeholder
    # implementation added in Task 4

Legacy Certificate Layout Is Regenerated On Downgrade
    [Documentation]    Reinstall 5.0 RPM and verify the 12-CA layout is regenerated.
    Log    placeholder
    # implementation added in Task 5

Cluster Is Healthy After Downgrade
    [Documentation]    Verify microshift healthcheck passes and node is Ready after downgrade.
    Log    placeholder
    # implementation added in Task 6


*** Keywords ***
Setup
    [Documentation]    Install 5.0 RPM, start MicroShift, capture pre-upgrade service-ca fingerprint.
    Log    placeholder

Teardown
    [Documentation]    Clean up installed packages and close the SSH connection.
    Log    placeholder
```

- [ ] **Step 2: Verify the file parses without syntax errors**

```bash
cd /home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation
python3 -c "
import subprocess, sys
r = subprocess.run(['python3', '-m', 'robot', '--dryrun',
    '--variable', 'USHIFT_HOST:placeholder',
    '--variable', 'PREVIOUS_MAJOR_VERSION:5',
    '--variable', 'PREVIOUS_MINOR_VERSION:0',
    '--variable', 'SOURCE_REPO_URL:http://placeholder',
    '--variable', 'TARGET_VERSION:5.1.0',
    'test/suites/rpm/upgrade-cert-migration.robot'],
    capture_output=True, text=True)
print(r.stdout[-2000:])
print(r.stderr[-2000:])
" 2>&1 | tail -20
```

Expected: dry-run completes, no syntax errors. (Connection errors are expected since `USHIFT_HOST` is a placeholder.)

- [ ] **Step 3: Commit the skeleton**

```bash
git -C /home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation \
  add test/suites/rpm/upgrade-cert-migration.robot
git -C /home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation \
  commit -m "OCPSTRAT-2900: add cert migration RF test skeleton"
```

---

### Task 2: Implement Setup/Teardown and TC1 (upgrade + layout assertions)

**Files:**
- Modify: `test/suites/rpm/upgrade-cert-migration.robot`

- [ ] **Step 1: Replace the Setup keyword with full implementation**

Replace the `Setup` keyword body:

```robotframework
Setup
    [Documentation]    Install 5.0 RPM, start MicroShift, capture pre-upgrade service-ca fingerprint.
    Check Required Env Variables
    Should Not Be Empty    ${SOURCE_REPO_URL}    SOURCE_REPO_URL variable is required
    Should Not Be Empty    ${TARGET_VERSION}    TARGET_VERSION variable is required
    Login MicroShift Host
    System Should Not Be Ostree
    Install MicroShift RPM Packages From System Repo
    ...    ${PREVIOUS_MAJOR_VERSION}.${PREVIOUS_MINOR_VERSION}.*
    ...    check_warnings=False
    Start MicroShift
    Wait For MicroShift
    ${fp}=    Command Should Work
    ...    openssl x509 -noout -fingerprint -sha256 -in ${CERTSDIR}/service-ca/ca.crt
    Set Suite Variable    ${PRE_SERVICE_CA_FP}    ${fp}
```

- [ ] **Step 2: Replace the Teardown keyword**

```robotframework
Teardown
    [Documentation]    Remove installed packages and close the SSH connection.
    Cleanup MicroShift
    Uninstall MicroShift RPM Packages
    Logout MicroShift Host
```

- [ ] **Step 3: Implement TC1 — "Certificate Layout Is Migrated On Upgrade"**

Replace the `Certificate Layout Is Migrated On Upgrade` test body:

```robotframework
Certificate Layout Is Migrated On Upgrade
    [Documentation]    Upgrade to 5.1 RPM and verify the 6-CA layout is in place,
    ...                old signer dirs are absent, and a backup dir was created.
    Install MicroShift RPM Packages From Repo    ${SOURCE_REPO_URL}    ${TARGET_VERSION}
    Restart MicroShift
    Wait For MicroShift Healthcheck Success

    # New 6-CA dirs must exist
    Verify Remote Directory Exists With Sudo    ${CERTSDIR}/client-ca
    Verify Remote Directory Exists With Sudo    ${CERTSDIR}/serving-ca
    Verify Remote Directory Exists With Sudo    ${CERTSDIR}/peer-ca
    Verify Remote Directory Exists With Sudo    ${CERTSDIR}/aggregator-signer
    Verify Remote Directory Exists With Sudo    ${CERTSDIR}/service-ca
    Verify Remote Directory Exists With Sudo    ${CERTSDIR}/ingress-ca

    # Old signer dirs must be absent
    Verify Remote Directory Does Not Exist With Sudo    ${CERTSDIR}/kube-control-plane-signer
    Verify Remote Directory Does Not Exist With Sudo    ${CERTSDIR}/kube-apiserver-external-signer
    Verify Remote Directory Does Not Exist With Sudo    ${CERTSDIR}/kube-apiserver-localhost-signer
    Verify Remote Directory Does Not Exist With Sudo    ${CERTSDIR}/kube-apiserver-service-network-signer
    Verify Remote Directory Does Not Exist With Sudo    ${CERTSDIR}/etcd-signer
    Verify Remote Directory Does Not Exist With Sudo    ${CERTSDIR}/admin-kubeconfig-signer

    # Backup dir must exist
    ${backup_count}=    Command Should Work
    ...    ls ${CERTS_PARENT} | grep -c 'certs\\.backup\\.'
    Should Be True    ${backup_count} >= 1
    ...    msg=Expected at least one certs.backup.* directory in ${CERTS_PARENT}
```

- [ ] **Step 4: Commit**

```bash
git -C /home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation \
  add test/suites/rpm/upgrade-cert-migration.robot
git -C /home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation \
  commit -m "OCPSTRAT-2900: implement cert migration RF test - setup and TC1"
```

---

### Task 3: Implement TC2 (service-ca fingerprint preservation)

**Files:**
- Modify: `test/suites/rpm/upgrade-cert-migration.robot`

- [ ] **Step 1: Implement TC2**

Replace the `Service CA Is Preserved Across Upgrade` test body:

```robotframework
Service CA Is Preserved Across Upgrade
    [Documentation]    Verify service-ca fingerprint is identical before and after upgrade.
    ...                PRE_SERVICE_CA_FP is captured in Suite Setup before the 5.0 → 5.1 upgrade.
    ${post_fp}=    Command Should Work
    ...    openssl x509 -noout -fingerprint -sha256 -in ${CERTSDIR}/service-ca/ca.crt
    Should Be Equal As Strings    ${PRE_SERVICE_CA_FP}    ${post_fp}
    ...    msg=service-ca fingerprint changed across upgrade — service-ca was not preserved
```

- [ ] **Step 2: Commit**

```bash
git -C /home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation \
  add test/suites/rpm/upgrade-cert-migration.robot
git -C /home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation \
  commit -m "OCPSTRAT-2900: implement cert migration RF test - TC2 service-ca preservation"
```

---

### Task 4: Implement TC3 (cluster health after upgrade)

**Files:**
- Modify: `test/suites/rpm/upgrade-cert-migration.robot`

- [ ] **Step 1: Implement TC3**

Replace the `Cluster Is Healthy After Upgrade` test body:

```robotframework
Cluster Is Healthy After Upgrade
    [Documentation]    Verify microshift healthcheck passes and node is Ready after upgrade.
    Wait For MicroShift Healthcheck Success
    Setup Kubeconfig
    Command Should Work    oc wait node --all --for=condition=Ready --timeout=60s
```

- [ ] **Step 2: Commit**

```bash
git -C /home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation \
  add test/suites/rpm/upgrade-cert-migration.robot
git -C /home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation \
  commit -m "OCPSTRAT-2900: implement cert migration RF test - TC3 cluster health after upgrade"
```

---

### Task 5: Implement TC4 (downgrade — legacy layout regeneration)

**Files:**
- Modify: `test/suites/rpm/upgrade-cert-migration.robot`

- [ ] **Step 1: Implement TC4**

Replace the `Legacy Certificate Layout Is Regenerated On Downgrade` test body:

```robotframework
Legacy Certificate Layout Is Regenerated On Downgrade
    [Documentation]    Reinstall 5.0 RPM and verify the old 12-CA layout is regenerated from scratch.
    ...                The old binary does not recognize the 6-CA layout and falls back to fresh-start,
    ...                recreating all legacy signer dirs.
    Install MicroShift RPM Packages From System Repo
    ...    ${PREVIOUS_MAJOR_VERSION}.${PREVIOUS_MINOR_VERSION}.*
    ...    check_warnings=False
    Restart MicroShift
    Wait For MicroShift Healthcheck Success

    # Legacy signer dirs must be regenerated
    Verify Remote Directory Exists With Sudo    ${CERTSDIR}/kube-control-plane-signer
    Verify Remote Directory Exists With Sudo    ${CERTSDIR}/etcd-signer
    Verify Remote Directory Exists With Sudo    ${CERTSDIR}/admin-kubeconfig-signer
    Verify Remote Directory Exists With Sudo    ${CERTSDIR}/kube-apiserver-external-signer

    # New 6-CA dirs must be absent (old binary generates the old layout only)
    Verify Remote Directory Does Not Exist With Sudo    ${CERTSDIR}/client-ca
    Verify Remote Directory Does Not Exist With Sudo    ${CERTSDIR}/serving-ca
    Verify Remote Directory Does Not Exist With Sudo    ${CERTSDIR}/peer-ca
```

- [ ] **Step 2: Commit**

```bash
git -C /home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation \
  add test/suites/rpm/upgrade-cert-migration.robot
git -C /home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation \
  commit -m "OCPSTRAT-2900: implement cert migration RF test - TC4 downgrade layout regeneration"
```

---

### Task 6: Implement TC5 (cluster health after downgrade) and push

**Files:**
- Modify: `test/suites/rpm/upgrade-cert-migration.robot`

- [ ] **Step 1: Implement TC5**

Replace the `Cluster Is Healthy After Downgrade` test body:

```robotframework
Cluster Is Healthy After Downgrade
    [Documentation]    Verify microshift healthcheck passes and node is Ready after downgrade.
    Wait For MicroShift Healthcheck Success
    Setup Kubeconfig
    Command Should Work    oc wait node --all --for=condition=Ready --timeout=60s
```

- [ ] **Step 2: Run a local dry-run to catch any syntax issues**

```bash
cd /home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation
python3 -m robot --dryrun \
    --variable USHIFT_HOST:placeholder \
    --variable USHIFT_HOST_USER:root \
    --variable PREVIOUS_MAJOR_VERSION:5 \
    --variable PREVIOUS_MINOR_VERSION:0 \
    --variable SOURCE_REPO_URL:http://placeholder \
    --variable TARGET_VERSION:5.1.0 \
    test/suites/rpm/upgrade-cert-migration.robot 2>&1 | tail -20
```

Expected: all 5 test cases listed with `DRY RUN` status, no `ERROR` lines.

- [ ] **Step 3: Commit and push**

```bash
git -C /home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation \
  add test/suites/rpm/upgrade-cert-migration.robot
git -C /home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation \
  commit -m "OCPSTRAT-2900: implement cert migration RF test - TC5 cluster health after downgrade"
git -C /home/eslutsky/dev/microshift-dev/repos/microshift/.worktrees/ocpstrat-2900-cert-consolidation \
  push fork ocpstrat-2900-cert-consolidation
```

- [ ] **Step 4: Update project CLAUDE.md checklist**

In `/home/eslutsky/dev/microshift-dev/projects/OCPSTRAT-2900/CLAUDE.md`, mark the RF test item as done:

Change:
```
- [ ] Write Robot Framework upgrade/downgrade migration test
```
To:
```
- [x] Write Robot Framework upgrade/downgrade migration test — test/suites/rpm/upgrade-cert-migration.robot (2026-10-19)
```
