*** Settings ***
Documentation       Tests for Workload partitioning

Resource            ../../resources/microshift-config.resource
Resource            ../../resources/common.resource
Resource            ../../resources/systemd.resource
Resource            ../../resources/microshift-process.resource
Resource            ../../resources/microshift-network.resource

Suite Setup         Setup Suite With Namespace
Suite Teardown      Teardown Suite With Namespace

*** Variables ***
${CPUsControlPlanes}    2
${SystemdCrioDropIn}    /etc/systemd/system/crio.service.d/microshift-cpuaffinity.conf
${SystemdMicroshiftDropIn}    /etc/systemd/system/microshift.service.d/microshift-cpuaffinity.conf
${crioConfigFile}    /etc/crio/crio.conf.d/20-microshift-wp.conf

*** Test Cases ***
Control Plane Pods Must Be Annotated
   [Documentation]    Verify that all the Control Plane pods are properly annotated.
   All Pods Should Be Annotated As Management

Workload Partitioning Should Work
    [Documentation]    Verify that all the Control Plane pods are properly annotated.
    Configure Kubelet For Workload Partitioning    ${CPUsControlPlanes}    
    Configure crio For Workload Partitioning    ${CPUsControlPlanes} 
    Configure CPUAffinity In Systemd    ${CPUsControlPlanes}    ${SystemdCrioDropIn}
    Configure CPUAffinity In Systemd    ${CPUsControlPlanes}    ${SystemdMicroshiftDropIn}
    Systemctl    restart    crio.service
    Restart MicroShift
    Microshift Services Should be Running On Reserved CPU    ${CPUsControlPlanes}
    All Management Pods Should Run On Reserved CPU    ${CPUsControlPlanes}
#TODO: cleanup,undo all the configuration
#TODO: add workloads and check their CPU

*** Keywords ***

Configure Kubelet For Workload Partitioning
    [Documentation]    configure microshift with kubelet CPU configuration
    [Arguments]    ${cpus}

    ${kubelet_config}=    CATENATE    SEPARATOR=\n
    ...    apiServer:
    ...    \ \ subjectAltNames:
    ...    \ \ -\ ${USHIFT_HOST}
    ...    kubelet:
    ...    \ \ reservedSystemCPUs: "${cpus}"
    ...    \ \ cpuManagerPolicy: static
    ...    \ \ cpuManagerPolicyOptions:
    ...    \ \ \ \ full-pcpus-only: "true"
    ...    \ \ cpuManagerReconcilePeriod: 5s

    Upload MicroShift Config    ${kubelet_config}

Configure crio For Workload Partitioning
    [Arguments]    ${cpus}
    ${crioConfiguration}=    CATENATE    SEPARATOR=\n
    ...    [crio.runtime]
    ...    infra_ctr_cpuset = "${cpus}"

    ...    [crio.runtime.workloads.management]
    ...    activation_annotation = "target.workload.openshift.io/management"
    ...    annotation_prefix = "resources.workload.openshift.io"
    ...    resources = { "cpushares" = 0, "cpuset" = "${cpus}" }

    Upload String To File    ${crioConfiguration}    ${crioConfigFile}

Configure CPUAffinity In Systemd
    [Arguments]    ${cpus}    ${targetFile}
    ${systemdCPUAffinity}=    CATENATE    SEPARATOR=\n
    ...    [Service]
    ...    CPUAffinity=${cpus}
    ...    
    Upload String To File    ${systemdCPUAffinity}    ${targetFile}

All Management Pods Should Run On Reserved CPU
    [Arguments]    ${cpus}
    [Documentation]    Verify all the PODs runs on explicit reserved CPU
    ${stdout}    ${stderr}    ${rc}=    Execute Command
    ...    crictl ps -q | xargs sudo crictl inspect | jq -rs '[.[] | select(.info.runtimeSpec.annotations["target.workload.openshift.io/management"])]'
    ...    sudo=True    return_stdout=True    return_stderr=True    return_rc=True
    Should Be Equal As Integers    ${rc}    0

    ${json_status}=    Json Parse    ${stdout}
    FOR    ${pod}    IN    @{json_status}
        ${pod_info}=    Catenate    SEPARATOR=
        ...    container: ${pod}[info][runtimeSpec][annotations][io.kubernetes.pod.name]
        ...    ${EMPTY} pod: ${pod}[status][metadata][name]
        ...    ${EMPTY} pid: ${pod}[info][pid]
        ...    ${EMPTY} namespace: ${pod}[info][runtimeSpec][annotations][io.kubernetes.pod.namespace]
    
        IF    ${pod}[info][runtimeSpec][linux][resources][cpu][cpus] != ${cpus}
            Fail    ${pod_info}
        END
        Proccess Should Be Running On Host CPU    ${pod}[info][pid]    ${cpus}
    END    

Microshift Services Should be Running On Reserved CPU
    [Arguments]    ${cpus}
    ${pid}=    MicroShift Process ID
    Proccess Should Be Running On Host CPU    ${pid}    ${cpus}

    ${pid}=    Crio Process ID
    Proccess Should Be Running On Host CPU    ${pid}    ${cpus}

    ${pid}=    MicroShift Etcd Process ID
    Proccess Should Be Running On Host CPU    ${pid}    ${cpus}

Proccess Should Be Running On Host CPU
    [Arguments]    ${pid}    ${cpus}
    [Documentation]    Verify all the PODs runs on explicit reserved CPU
    ${stdout}    ${stderr}    ${rc}=    Execute Command
    ...    taskset -cp ${pid} | awk '{print $6}'
    ...    sudo=True    return_stdout=True    return_stderr=True    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Strings    ${stdout}    ${cpus}


All Pods Should Be Annotated As Management
    [Documentation]    Obtains list of Deployments created by CSV.
    ${pods_raw}=    Oc Get All Pods
    @{pods}=    Split String    ${pods_raw}
    FOR    ${pod}    IN    @{pods}
        ${ns}    ${pod}=    Split String    ${pod}    \@
        Pod Must Be Annotated    ${ns}    ${pod}
    END

Pod Must Be Annotated
    [Documentation]    Check management annotation for specified pod and namespace.
    [Arguments]    ${ns}    ${pod}
    ${management_annotation}=    Oc Get JsonPath
    ...    pod
    ...    ${ns}
    ...    ${pod}
    ...    .metadata.annotations.target\\.workload\\.openshift\\.io/management
    Should Not Be Empty    ${management_annotation}

Oc Get All Pods
    [Documentation]    Returns the running pods across all namespaces,
    ...    Returns the command output as formatted string <name-space>@<pod-name>

    ${data}=    Oc Get JsonPath
    ...    pods
    ...    ${EMPTY}
    ...    ${EMPTY}
    ...    range .items[*]}{\.metadata\.namespace}{"@"}{\.metadata\.name}{"\\n"}{end
    RETURN    ${data}

Crio Process ID
    [Documentation]    Return the current crio process ID
    ${stdout}    ${stderr}    ${rc}=    Execute Command
    ...    pidof crio
    ...    return_stdout=True    return_stderr=True    return_rc=True
    Log    ${stderr}
    RETURN    ${stdout}