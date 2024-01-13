#!/usr/bin/env bash
oc create configmap -n nsx-system-restarter nsx-node-agent-restarter-script --from-file=restart-nsx-node-agents.sh --dry-run=client -o yaml
