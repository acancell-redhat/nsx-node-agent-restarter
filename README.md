- Configurations
  - script parameters: `config/restart-nsx-node-agents.env` 
  - cronjob parameters: `config/cronjob-parameters.yaml` 
- To create and check demo environment
~~~
oc apply -f demo/nsx-node-agent_demo.yaml
oc get daemonset nsx-node-agent -n nsx-system
~~~
- To build restarter resources
~~~
oc kustomize .
~~~
- To build and apply restarter resources
~~~
oc apply -k .
~~~
- To test the restarter cronjob
~~~
oc create job --from=cronjob.batch/nsx-node-agent-restarter-cj nsx-node-agent-restarter-job-test -n nsx-system-restarter
oc get pod -l job-name=nsx-node-agent-restarter-job-test -n nsx-system-restarter -w
oc get pod -l job-name=nsx-node-agent-restarter-job-test -n nsx-system-restarter -o name | xargs -I {} oc logs {} -n nsx-system-restarter -f
~~~
