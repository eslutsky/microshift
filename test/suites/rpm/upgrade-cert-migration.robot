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

Service CA Is Preserved Across Upgrade
    [Documentation]    Verify service-ca fingerprint is identical before and after upgrade.
    ...                PRE_SERVICE_CA_FP is captured in Suite Setup before the 5.0 → 5.1 upgrade.
    ${post_fp}=    Command Should Work
    ...    openssl x509 -noout -fingerprint -sha256 -in ${CERTSDIR}/service-ca/ca.crt
    Should Be Equal As Strings    ${PRE_SERVICE_CA_FP}    ${post_fp}
    ...    msg=service-ca fingerprint changed across upgrade — service-ca was not preserved

Cluster Is Healthy After Upgrade
    [Documentation]    Verify microshift healthcheck passes and node is Ready after upgrade.
    Wait For MicroShift Healthcheck Success
    Setup Kubeconfig
    Command Should Work    oc wait node --all --for=condition=Ready --timeout=60s

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

Cluster Is Healthy After Downgrade
    [Documentation]    Verify microshift healthcheck passes and node is Ready after downgrade.
    Wait For MicroShift Healthcheck Success
    Setup Kubeconfig
    Command Should Work    oc wait node --all --for=condition=Ready --timeout=60s


*** Keywords ***
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

Teardown
    [Documentation]    Remove installed packages and close the SSH connection.
    Cleanup MicroShift
    Uninstall MicroShift RPM Packages
    Logout MicroShift Host
