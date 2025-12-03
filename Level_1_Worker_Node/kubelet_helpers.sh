#!/bin/bash
# Common helpers used by Worker node scripts to parse kubelet/kube-proxy flags without relying on GNU-only grep.

kubelet_process_args() {
    ps -eo args 2>/dev/null | grep -m1 '[k]ubelet' || true
}

kube_proxy_process_args() {
    ps -eo args 2>/dev/null | grep -m1 '[k]ube-proxy' || true
}

extract_flag_from_args() {
    local args="$1"
    local flag="$2"

    if [ -z "$args" ]; then
        return 1
    fi

    printf '%s\n' "$args" | awk -v flag="$flag" '{
        for (i = 1; i <= NF; i++) {
            if ($i == flag) {
                if (i < NF) {
                    print $(i + 1)
                    exit
                }
            } else if (index($i, flag "=") == 1) {
                print substr($i, length(flag) + 2)
                exit
            }
        }
    }'
}

kubelet_arg_value() {
    extract_flag_from_args "$(kubelet_process_args)" "$1"
}

kube_proxy_arg_value() {
    extract_flag_from_args "$(kube_proxy_process_args)" "$1"
}

kubelet_config_path() {
    local value
    value=$(kubelet_arg_value "--config")
    if [ -n "$value" ]; then
        printf '%s\n' "$value"
        return
    fi
    printf '%s\n' "/var/lib/kubelet/config.yaml"
}

kubelet_kubeconfig_path() {
    local value
    value=$(kubelet_arg_value "--kubeconfig")
    if [ -n "$value" ]; then
        printf '%s\n' "$value"
        return
    fi
    printf '%s\n' "/etc/kubernetes/kubelet.conf"
}

kube_proxy_kubeconfig_path() {
    kube_proxy_arg_value "--kubeconfig"
}
