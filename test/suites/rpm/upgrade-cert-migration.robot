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
