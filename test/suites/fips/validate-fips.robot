*** Settings ***
Documentation       Tests related to FIPs Validation

Resource            ../../resources/common.resource
Resource            ../../resources/selinux.resource
Library             Collections

Suite Setup         Setup
Suite Teardown      Teardown


*** Variables ***
${USHIFT_HOST}      ${EMPTY}
${USHIFT_USER}      ${EMPTY}


*** Test Cases ***
FIPs Validation
    [Documentation]    Performs a FIPs validation against the host
    Fips Should Be Enabled

Microshift Fips Binary
    [Documentation]    Performs a FIPs validation against the microshfit binary
    Microshift Binary Should Dynamicly Link OpenSSL


*** Keywords ***
Setup
    [Documentation]    Test suite setup
    Check Required Env Variables
    Login MicroShift Host

Teardown
    [Documentation]    Test suite teardown
    Logout MicroShift Host

Microshift Binary Should Dynamicly Link OpenSSL
    [Documentation]    Check if Microshift binary is FIPs compliant.
    ${stdout}    ${rc}=    Execute Command
    ...    go tool nm /usr/bin/microshift | grep -i " _cgo.*DLOPEN_OPENSSL"
    ...    sudo=True    return_rc=True
    Should Be Equal As Integers    0    ${rc}

Fips Should Be Enabled
    [Documentation]    Check if FIPs is enabled on RHEL.
    ${stdout}    ${stderr}    ${rc}=    Execute Command
    ...    bash -x fips-mode-setup --check
    ...    sudo=True    return_rc=True    return_stderr=True
    Should Be Equal As Integers    0    ${rc}
    Should Be Equal As Strings    ${stdout}    FIPS mode is enabled.
