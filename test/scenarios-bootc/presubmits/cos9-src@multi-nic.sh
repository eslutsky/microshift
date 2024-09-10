#!/bin/bash

# Sourced from scenario.sh and uses functions defined there.

scenario_create_vms() {
    prepare_kickstart host1 kickstart-bootc.ks.template cos9-bootc-source
    launch_vm --vmname host1 --boot_blueprint centos9-bootc --vm_nics 2 --bootc_mode
}

scenario_remove_vms() {
    remove_vm host1
}

scenario_run_tests() {
    local -r vmname=$(full_vm_name host1)
    local -r vm_ip1=$("${ROOTDIR}/scripts/devenv-builder/manage-vm.sh" ip -n "${vmname}" | head -1)
    local -r vm_ip2=$("${ROOTDIR}/scripts/devenv-builder/manage-vm.sh" ip -n "${vmname}" | tail -1)

    run_tests host1 \
        --variable "USHIFT_HOST_IP1:${vm_ip1}" \
        --variable "USHIFT_HOST_IP2:${vm_ip2}" \
        suites/network/multi-nic.robot
}
