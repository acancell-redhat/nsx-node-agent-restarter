#!/usr/bin/env bash

# Activate verbose mode 
[[ ${DEBUG} == "true" ]] && set -x

# Bash "fail fast" mode. See https://sipb.mit.edu/doc/safe-shell/ and https://stackoverflow.com/a/35800451
# In this script it is important in order to manage "oc" failures (ex. timeouts)
set -eEo pipefail

echo "INFO Start of operations"

# List and count ALL nsx_node_agent pods
# IFS=$'\n' nsx_node_agent_pods_all=($(oc get pod --no-headers -o name -n nsx-system -l component==nsx-node-agent --sort-by '{.spec.nodeName}')) # NOTE https://www.shellcheck.net/wiki/SC2207
mapfile -t nsx_node_agent_pods_all < <(oc get pod --no-headers -o name -n nsx-system -l component==nsx-node-agent --sort-by '{.spec.nodeName}')
echo "INFO nsx_node_agent Pods all list:"
printf '  %s\n' "${nsx_node_agent_pods_all[@]}"
nsx_node_agent_pods_all_n=${#nsx_node_agent_pods_all[@]}
echo "INFO nsx_node_agent Pods all count: ${nsx_node_agent_pods_all_n}"
# List and count only FULLY RUNNING (= all containers ok) nsx_node_agent pods
# IFS=$'\n' nsx_node_agent_pods_running=($(oc get pod --no-headers -n nsx-system -l component==nsx-node-agent --sort-by '{.spec.nodeName}' --field-selector status.phase==Running | grep -P '(\d+)\/\1[^\d]' | awk '{print "pod/"$1}')) # NOTE https://www.shellcheck.net/wiki/SC2207
mapfile -t nsx_node_agent_pods_running < <(oc get pod --no-headers -n nsx-system -l component==nsx-node-agent --sort-by '{.spec.nodeName}' --field-selector status.phase==Running | grep -P '(\d+)\/\1[^\d]' | awk '{print "pod/"$1}')
echo "INFO nsx_node_agent Pods running list:"
printf '  %s\n' "${nsx_node_agent_pods_running[@]}"
nsx_node_agent_pods_running_n=${#nsx_node_agent_pods_running[@]}
echo "INFO nsx_node_agent Pods running count: ${nsx_node_agent_pods_running_n}"

# Abort if count of FULLY RUNNING (= all containers ok) nsx_node_agent pods < count of ALL nsx_node_agent pods. This prevents killing any nsx_node_agent if initially there are already problems
if [[ ${nsx_node_agent_pods_running_n} -lt $nsx_node_agent_pods_all_n ]]; then
    echo "ERROR Number of fully running NSX NODE AGENT pods is ${nsx_node_agent_pods_running_n} which is less than the expected $nsx_node_agent_pods_all_n"
    echo "ERROR Aborting and exiting"
 	  exit 1
fi

# List and count ALL nodes
mapfile -t nodes_all < <(oc get node --no-headers --sort-by '{.metadata.name}' | awk '{print $1}')
echo "INFO Nodes all list:"
printf '  %s\n' "${nodes_all[@]}"
nodes_all_n=${#nodes_all[@]}
echo "INFO Nodes all count: ${nodes_all_n}"
# List and count READY nodes
mapfile -t nodes_ready < <(oc get node --no-headers --sort-by '{.metadata.name}' | grep Ready | awk '{print $1}')
echo "INFO Nodes ready list:"
printf '  %s\n' "${nodes_ready[@]}"
nodes_ready_n=${#nodes_ready[@]}
echo "INFO Nodes ready count: ${nodes_ready_n}"

# Abort if count of READY nodes < count of ALL nodes. This prevents killing any node if initially there are already problems
if [[ ${nodes_ready_n} -lt ${nodes_all_n} ]]; then
    echo "ERROR Number of ready Nodes is ${nodes_ready_n} which is less than the expected ${nodes_all_n}"
    echo "ERROR Aborting and exiting"
 	  exit 1
fi

# The following should come from env variables. If not, it uses their default values.
echo "INFO Value of DELAY_READY_MINUTES: ${DELAY_READY_MINUTES:=2}"
echo "INFO Value of DELAY_NEXT_MINUTES: ${DELAY_NEXT_MINUTES:=15}"

echo "INFO Total Nodes to purge: ${nodes_all_n}"
for node in "${nodes_all[@]}"; do
  nodes_to_purge_n=$(( ${nodes_all_n} - ${nodes_purged_n:=0} ))
  echo "INFO Count of remaining Nodes to purge: $(( ${nodes_to_purge_n} ))"

  echo "INFO Next Node is: ${node}"
  echo "INFO Purging Node ${node} ..."
  # See: https://access.redhat.com/solutions/55818, https://access.redhat.com/solutions/4982351, https://www.tecmint.com/clear-ram-memory-cache-buffer-and-swap-space-on-linux/
  oc debug node/${node} -- chroot /host bash -c "echo 'INFO Currently inside Node: ' ${HOSTNAME}; echo 'INFO Before drop_caches:'; cat /proc/slabinfo | grep -E 'active_objs|^dentry'; echo 'INFO Applying drop_caches ...'; echo 2 > /proc/sys/vm/drop_caches; echo 'INFO After drop_caches:'; cat /proc/slabinfo | grep -E 'active_objs|^dentry'; echo 'INFO Exiting Node: ' ${HOSTNAME}"

  echo "INFO Waiting ${DELAY_READY_MINUTES} minutes (\"DELAY_READY_MINUTES\") before checking Node ${node} status"
  sleep $(( ${DELAY_READY_MINUTES} * 60 ))
  if [[ -n $(oc get node --no-headers --sort-by '{.metadata.name}' | grep Ready | awk '{print $1}' | grep ${node}) ]]; then
    echo "INFO Node ${node} is still ready after purge"
  else
    echo "ERROR Node ${node} is NOT ready after purge"
    echo "ERROR Aborting and exiting"
 	  exit 1
  fi
  
  nodes_purged_n="$((nodes_purged_n+1))"
  echo "INFO Count of Nodes purged so far: ${nodes_purged_n}"
  if [[ ${nodes_purged_n} -ne ${nodes_all_n} ]]; then
    echo "INFO Waiting ${DELAY_NEXT_MINUTES} minutes (\"DELAY_NEXT_MINUTES\") before purging next Node ..."
	  echo "INFO Next Node will be purged at:" $(date -u -d "now +${DELAY_NEXT_MINUTES}min")
    sleep $(( ${DELAY_NEXT_MINUTES} * 60 ))
  else
    echo "INFO All Nodes purged"
  fi

done

echo "INFO End of operations"