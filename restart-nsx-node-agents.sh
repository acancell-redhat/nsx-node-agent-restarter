#!/usr/bin/env bash

# Bash "fail fast" mode. See https://sipb.mit.edu/doc/safe-shell/ and https://stackoverflow.com/a/35800451
# In this script it is important in order to manage "oc" failures (ex. timeouts)
set -eEo pipefail

echo "INFO Starting operations"

# List and count ALL nsx_node_agent pods
# IFS=$'\n' nsx_node_agent_pods_all=($(oc get pods --no-headers -o name -n nsx-system -l component==nsx-node-agent)) # NOTE https://www.shellcheck.net/wiki/SC2207
mapfile -t nsx_node_agent_pods_all < <(oc get pods --no-headers -o name -n nsx-system -l component==nsx-node-agent)
echo "INFO nsx_node_agent Pods all list:"
printf '%s\n' "${nsx_node_agent_pods_all[@]}" | sort
nsx_node_agent_pods_all_n=${#nsx_node_agent_pods_all[@]}
echo "INFO nsx_node_agent Pods all count:"
echo "${nsx_node_agent_pods_all_n}"
# List and count only FULLY RUNNING (= all containers ok) nsx_node_agent pods
# IFS=$'\n' nsx_node_agent_pods_running=($(oc get pods --no-headers -n nsx-system -l component==nsx-node-agent --field-selector status.phase==Running | grep -P '(\d+)\/\1[^\d]' | awk '{print "pod/"$1}')) # NOTE https://www.shellcheck.net/wiki/SC2207
mapfile -t nsx_node_agent_pods_running < <(oc get pods --no-headers -n nsx-system -l component==nsx-node-agent --field-selector status.phase==Running | grep -P '(\d+)\/\1[^\d]' | awk '{print "pod/"$1}')
echo "INFO nsx_node_agent Pods running list:"
printf '%s\n' "${nsx_node_agent_pods_running[@]}" | sort
nsx_node_agent_pods_running_n=${#nsx_node_agent_pods_running[@]}
echo "INFO nsx_node_agent Pods running count:"
echo "${nsx_node_agent_pods_running_n}"

# The following should come from env variables. If not, it uses their default values.
echo "INFO Value of WAIT_DELETE_MINUTES is ${WAIT_DELETE_MINUTES:=1}"
echo "INFO Value of WAIT_CREATE_MINUTES is ${WAIT_CREATE_MINUTES:=2}"
echo "INFO Value of DELAY_RESTART_MINUTES is ${DELAY_RESTART_MINUTES:=15}"

echo "INFO Total count of Pods to restart is ${nsx_node_agent_pods_all_n}"
for nsx_node_agent_pod in "${nsx_node_agent_pods_all[@]}"; do
  pods_to_restart_n=$(( ${nsx_node_agent_pods_all_n} - ${pods_restarted_n} ))
  echo "INFO Count of remaining Pods to restart is $(( ${pods_to_restart_n} ))"

  echo "INFO Next Pod is ${nsx_node_agent_pod}"
  node_of_pod=$(oc get pod ${nsx_node_agent_pod} -n nsx-system -o jsonpath='{.spec.nodeName}') # NOTE Since nsx_node_agent are in a DaemonSet, the Node will be the same also for the new Pod
  echo "INFO Pod ${nsx_node_agent_pod} is on Node ${node_of_pod}"
  
  echo "INFO Deleting Pod ${nsx_node_agent_pod}"
  echo "INFO Waiting for deletion of Pod ${nsx_node_agent_pod} ..."
  oc delete ${nsx_node_agent_pod} -n nsx-system
  oc wait -n nsx-system --for=delete ${nsx_node_agent_pod} --timeout=$(( ${WAIT_DELETE_MINUTES} * 60 ))s
  
  echo "INFO Waiting for new Pod on node ${node_of_pod} ..."
  oc wait -n nsx-system -l component==nsx-node-agent --field-selector status.phase==Running,spec.nodeName=${node_of_pod} --for=condition=Running ${nsx_node_agent_pod} --timeout=$(( ${WAIT_CREATE_MINUTES} * 60 ))s
  # Check that all containers of Pod are running. Adding 60s delay to try catching situations whether the Containers are restaring
  sleep 60; nsx_node_agent_pod_new=$(oc get pods --no-headers -n nsx-system -l component==nsx-node-agent --field-selector status.phase==Running,spec.nodeName=${node_of_pod} | grep -P '(\d+)\/\1[^\d]' | awk '{print "pod/"$1}')
  if [[ -n $(nsx_node_agent_pod_new) ]]; then
    echo "INFO Pod ${nsx_node_agent_pod_new} and its containers are running"
  else
    echo "ERROR Pod ${nsx_node_agent_pod_new} or its containers failed to run"
	echo "ERROR Current status of Pod ${nsx_node_agent_pod_new}:"
	oc get pods --no-headers -n nsx-system ${nsx_node_agent_pod_new}
	exit 1
  fi
  
  (( pods_restarted_n++ ))
  if [[ ${pods_restarted_n} -ne ${nsx_node_agent_pods_all_n} ]]; then
    echo "INFO Waiting ${DELAY_RESTART_MINUTES} minutes before restarting next Pod"
	echo "INFO Next Pod will be restarted at:" $(date -u -d "now +${DELAY_RESTART_MINUTES}min")
    sleep $(( ${DELAY_RESTART_MINUTES} * 60 ))
  else
    echo "INFO All nsx_node_agent Pods restarted"
  fi
done

echo "INFO All operations completed"