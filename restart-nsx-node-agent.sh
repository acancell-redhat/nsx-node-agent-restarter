#!/bin/bash
if ! [ $(oc get pods -n nsx-system --field-selector status.phase==Running | grep -v -P '(\d+)\/\1' | grep nsx-node-agent)]; then
	last_line=$(oc get pod  -o name  -n nsx-system| grep nsx-node-agent | wc -l )
	current_line=0
	oc get pod  -o name  -n nsx-system| grep nsx-node-agent |
	while read -r line
	do 
		oc delete $line -n nsx-system;
		current_line=$(($current_line + 1))
		if [[ $current_line -ne $last_line ]]; then
			echo "The next pod will be restarted at" $(date -d "now +15min");
			sleep 900;
	        fi
	done 
else
	exit 1
fi
