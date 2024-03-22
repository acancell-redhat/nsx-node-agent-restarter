- Configurations
  - script parameters: `config/nodes-purge.env` 
  - cronjob parameters: `config/cronjob-parameters.yaml` 
- To create and check demo environment
~~~
oc apply -f demo/nsx-node-agent_demo.yaml
oc get daemonset nsx-node-agent -n nsx-system
~~~
- To build resources
~~~
oc kustomize .
~~~
- To build and apply resources (**NOTE The cronjob pod will have _priviledged_ SecurityContext in order to being able to create debug pods inside the nodes**)
~~~
oc apply -k .
~~~
- To test the cronjob
~~~
oc create job --from=cronjob.batch/nodes-purge-cj nodes-purge-job-test -n nsx-system-purger
oc get pod -l job-name=nodes-purge-job-test -n nsx-system-purger -w
oc get pod -l job-name=nodes-purge-job-test -n nsx-system-purger -o name | xargs -I {} oc logs {} -n nsx-system-purger -f
~~~
