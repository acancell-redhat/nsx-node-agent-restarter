- To recreate secret
~~~
oc create configmap -n nsx-system-restarter nsx-node-agent-restarter-script --from-file=restart-nsx-node-agents.sh --dry-run=client -o yaml | tee manifests/configmap.yaml
~~~

