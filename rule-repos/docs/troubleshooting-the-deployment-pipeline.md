#   Troubleshooting the deployment pipeline

##  Introduction

We first strongly encourage you to read the [section](./hypershift-monitoring-architecture-introduction.md#this-repository-in-action) in the architecture document explaining how hypershift rules are deployed on the targeted RHOBS clusters.

This document mainly focuses on the rules in the `rules/hypershift-platform` folder; rules in the other folder(s) are deployed in a very similar way; there are however some differences:

| Folder                                                          | Environment | Tenant                        | `CLUSTER_NAME`      | `NAMESPACE`                    | Deployed through a template?
| --------------------------------------------------------------- | ----------- | ----------------------------- |------------------- | ------------------------------ | ----------------------------
| [`rules/hypershift-platform`](../../rules/hypershift-platform/) | Production  | `hypershift-platform`         | `rhobsp02ue1`       | `observatorium-mst-production` | Yes
| [`rules/hypershift-platform`](../../rules/hypershift-platform/) | Staging     | `hypershift-platform-staging` | `rhobsp02ue1`       | `observatorium-mst-production` | Yes
| [`rules/osd`](../../rules/osd/)                                 | Staging     | `osd`                         | `app-sre-stage-01`  | `observatorium-mst-stage`      | No
| [`rules/osd`](../../rules/osd/)                                 | Production  | `osd`                         | `telemeter-prod-01` | `observatorium-mst-production` | No

Those differences mainly concern:
- The way the `PrometheusRule`s are copied (through a template or not).
- The destination (RHOBS cluster(s) and namespace) on which the rules are copied.  
  As we will see later, this is the destination where `obsctl-reloader` is running. This is not the final destination of the rules.

The mapping described by the above table is explicited in the following `app-interface` file:  
[`/data/services/osd-operators/cicd/saas/saas-rhobs-rules-and-dashboards.yaml`](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/osd-operators/cicd/saas/saas-rhobs-rules-and-dashboards.yaml)


Remark that:
- The `main` branch is consumed on staging while a fixed commit hash is set for production.  
  You will have to submit a promotion merge request (ex [!67256](https://gitlab.cee.redhat.com/service/app-interface/-/merge_requests/67246/diffs)) to get new changes on `rhobs-rules-and-dashboards` repository be deployed on production while this is automatic for staging.
- Hypershift rules need to be deployed through a template because the destination is the same for staging and production.  
  The template changes the name of the rules on the fly to avoid colisions at the destination.

##  Making sure the `PrometheusRule`s are copied on RHOBS where `obsctl-reloader` is running

Use the introduction table to define the `CLUSTER_NAME` & `NAMESPACE` destination variables.

RHOBS clusters are OSD cluster; this means that, as a SRE, you can connect to them using the following command:
```
ocm backplane login $CLUSTER_NAME
```
- Make sure to run the proper `ocm backplane tunnel` command first. More on that in this [doc](https://github.com/openshift/ops-sop/blob/master/v4/alerts/gettingstarted.md).
- RHOBS clusters are all production clusters (even when they gather metrics for staging clusters).  
  So please make sure to issue the proper `ocm login` command with `--url` set to `production` prior shooting any other `ocm` command.

Once logged, take a look at the `PrometheusRule`s:
```
oc get PrometheusRule -n $NAMESPACE
```
- Check that all rules defined in the folder are present.  
  (remark that the namespace may contain rules for other folder/tenants or rules not even managed by this repository)
- Add the `-o yaml` option to make sure the rules content matches what is defined in the repository.
- As you can see rules deployed through a template have their names prefixed with the tenant.

If the `PrometheusRule`s objects do not match:
1. If you are targetting production:  
   Make sure that the commit hash in [the `app-interface` file](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/osd-operators/cicd/saas/saas-rhobs-rules-and-dashboards.yaml) matches the commit you are taking a look at.  
   If that's not the case, you may want to bump this hash in the `app-interface` file by submitting a promotion PR there.
2. If the rules are deployed through a template:  
   Check that the `template.yaml` file has been correctly generated. This file is located in the folder alongside with the rules it aggregates.
3. If the template is fine or if rules are not deployed through a template:  
   Contact `@app-sre-ic` on [`#sd-app-sre`](https://redhat-internal.slack.com/archives/CCRND57FW) slack channel and ask why the deployment failed.  
   Be specific & provide the following information:
   - Reference the [the `app-interface` file](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/osd-operators/cicd/saas/saas-rhobs-rules-and-dashboards.yaml) supposed to automate the deployment.
   - Give the name of the cluster and the namespace on which those rules are supposed to be deployed.  
     Once again, those informations are given by the `CLUSTER_NAME` & `NAMESPACE` columns of the introduction table.

##  Making sure the `PrometheusRule`s are properly deployed by `obsctl-reloader`

Copying the rules to the place where `obsctl-reloader` is running is only the first step.  
The second part of the process is to get `obsctl-reloader` consume those rules and upload them on RHOBS; as we are already in the RHOBS cluster, this just means copy them elsewhere in the cluster.

### Making sure `obsctl-reloader` is properly running

Connect the RHOBS cluster as previously explained and run the following command:
```
oc get deploy -n $NAMESPACE rules-obsctl-reloader --as backplane-cluster-admin
```

If all is fine, the command output should look as follows:
```
NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
rules-obsctl-reloader   1/1     1            1           187d
```

If pod is not ready, take a look at the last logs:
```
oc logs -n $NAMESPACE deploy/rules-obsctl-reloader --as backplane-cluster-admin --tail=20
```

The logs may tell you that some rules are invalid. For instance:
```
level=debug component=obsctl-syncer msg="saved config in config file"
level=debug component=obsctl-syncer msg="updated token in config file" tenant=hypershift-platform
level=error component=obsctl-syncer msg="rulefmt parsing rules" error=0 groups="unsupported value type"
level=error msg="error setting rules" tenant=hypershift-platform error="1:17435: groupname: \"SLOs-probe\" is repeated in the same file"
```

If that's the case or if you cannot figure out why the pod is down:  
- Contact `@sre-platform-team-orange` on [#sd-sre-team-orange](https://redhat-internal.slack.com/archives/C0189RRTQAV) Slack channel.
- This team is the owner of the `rhobs-rules-and-dashboards` repository; they will know what to do to get the pod up and running again.
- If the pod is down due to invalid rules; it is likely that:
  - They will ask you to correct the rules or correct the rules themselves if you are not responsible of the error.
  - They will add a check in the repository build to prevent such rules to be merged on the repository ever again.  
    You see `obsctl-reloader` is expecting the rules to be valid `PrometheusRule` objects; but it has also its own set of additional requirements on top of that; those requirements need to be checked as well by the repository build.

### Making sure `obsctl-reloader` is really deploying the rules on RHOBS

We will use the `obsctl` binary for that.
- This is the CLI tool wrapped by `obsctl-reloader` pod.
- The tool can be used to upload all rules to RHOBS for a given tenant (this is how `obsctl-reloader` use it) or to get all rules at once (this is what we will do here)

You first need to install that tool; this is described here:  
https://github.com/observatorium/obsctl#installing

Then you need to define the `TENANT`, `RHOBS_API_NAME`, `RHOBS_API_URL` and `VAULT_PATH` variables used in the next commands according the following table:

| Folder                                                          | Environment | `TENANT`                      | `RHOBS_API_NAME`          | `RHOBS_API_URL`                                   | `VAULT_PATH`
| --------------------------------------------------------------- | ----------- | ----------------------------- | ------------------------- | ------------------------------------------------- | ------------
| [`rules/hypershift-platform`](../../rules/hypershift-platform/) | Production  | `hypershift-platform`         | `rhobsp02ue1-prod`        | https://rhobs.rhobsp02ue1.api.openshift.com       | `osd-sre/rhobs-hypershift-platform`
| [`rules/hypershift-platform`](../../rules/hypershift-platform/) | Staging     | `hypershift-platform-staging` | `rhobsp02ue1-prod`        | https://rhobs.rhobsp02ue1.api.openshift.com       | `osd-sre/rhobs-hypershift-platform-staging`
| [`rules/osd`](../../rules/osd/)                                 | Production  | `osd`                         | `obs-mst-prod-us-east-1`  | https://observatorium-mst.api.openshift.com       | `osd-sre/observatorium-credentials`
| [`rules/osd`](../../rules/osd/)                                 | Staging     | `osd`                         | `obs-mst-stage-us-east-1` | https://observatorium-mst.api.stage.openshift.com | `osd-sre/observatorium-staging-credentials`

Remark that you can actually choose an other value for the `RHOBS_API_NAME` variable. It is just that in below examples we will assume that you set this variables according this table.

Next, you have to register the API endpoint for the tenant to target:
```
obsctl context api add --url $RHOBS_API_URL --name $RHOBS_API_NAME
```

The RHOBS credentials are stored in vault, so lets login there first; make sure the VPN is on prior running those commands:
```
export VAULT_ADDR='https://vault.devshift.net'
vault login -method=oidc
```
- The last command will open a popup in your web browser to finish the login.
- You can donwload/install `vault` binary from there:  
  https://developer.hashicorp.com/vault/downloads
- In case you do not want to install the `vault` binary:  
  You can access the `VAULT_PATH` secret through the [vault web UI](https://vault.devshift.net/). If you do so, you have to replace the following sub-commands with the data manually extracted from the secret:
  - `$(vault kv get -field=client-id $VAULT_PATH)`
  - `$(vault kv get -field=client-secret $VAULT_PATH)`

Now lets login on RHOBS
```
obsctl login --api=$RHOBS_API_NAME --oidc.audience=observatorium --oidc.client-id=$(vault kv get -field=client-id $VAULT_PATH) --oidc.client-secret=$(vault kv get -field=client-secret $VAULT_PATH) --oidc.issuer-url='https://sso.redhat.com/auth/realms/redhat-external' --tenant=$TENANT
```

Remark that if you already logged in the past, you may end up being logged on multiple RHOBS tenants. You can see the tenants you are logged on as follows (here I am logged on all tenants described by above table):
```
> obsctl context list
obs-mst-prod-us-east-1
	- osd
obs-mst-stage-us-east-1
	- osd
rhobsp02ue1-prod
	- hypershift-platform
	- hypershift-platform-staging

The current context is: rhobsp02ue1-prod/hypershift-platform
```

The last line tells you what is the active tenant. You can change the active tenant with the `switch` sub-command; for instance:
```
obsctl context switch obs-mst-stage-us-east-1/osd
```

Now we are connected to RHOBS, we can can retrieve the rules with the following command:
```
obsctl metrics get rules.raw
```
- This commands returns ALL the rules for the active tenant. So you better have to pipe the output with `less`.
- The output is in yaml format. This is compatible with the `set` sub-command which expects that format:
  ```
  obsctl metrics get rules.raw >| all_rules.yml
  # Edit the file to change the rules a bit
  obsctl metrics set --rule.file=./all_rules.yml
  ```
  Of course using this `set` sub-command completely bypass the automatic deployment process we are troubleshooting here...
  - Consider using it as a last resort only.
  - The rules munually uploaded that way may be overwritten by the automatic deployment process upon changes in the `rhobs-rules-and-dashboards` repository or in `app-interface`
- There is also a `obsctl metrics get rules` command, but this command prints in json format and its output is not directly usable by any other `obsctl` command.

If the rules printed by this command do not match the rules in the RHOBS cluster namespace:
- Check if the rules in the namespace correctly define a `tenant` label.
  - This label is used by `obsctl-reloader` to known the tenant to target.
  - This label is normally automatically set for rules deployed through a template.
  - Rules without a `tenant` label are not consumed by `obsctl-reloader`.

  Consider submitting a corrective MR in `rhobs-rules-and-dashboards` if the label is not set or not corectly set and if the rule is not deployed through a template.
  
- Check if the tenant is actually considered by `obsctl-reloader`:
  ```
  > oc get deploy -n $NAMESPACE rules-obsctl-reloader --as backplane-cluster-admin -o yaml | grep -F -- '- --managed-tenants'
  ```
  If the `--managed-tenants` option does not list your tenant, then `obsctl-reloader` is not considering it.

- Check if RHOBS credentials are defined in `obsctl-reloader` config for the tenant to target:
  ```
  oc get deploy -n $NAMESPACE rules-obsctl-reloader --as backplane-cluster-admin -o json | jq ".spec.template.spec.containers[].env[] | select(.name | test(\"${TENANT}_CLIENT_.*\"; \"i\"))"
  ```
  The command should normally return 2 variable definitions. For instance for the `hypershift-platform-staging` tenant:
  ```
  {
    "name": "HYPERSHIFT-PLATFORM-STAGING_CLIENT_ID",
    "valueFrom": {
      "secretKeyRef": {
        "key": "client-id",
        "name": "rhobs-hypershift-platform-staging-tenant",
        "optional": true
      }
    }
  }
  {
    "name": "HYPERSHIFT-PLATFORM-STAGING_CLIENT_SECRET",
    "valueFrom": {
      "secretKeyRef": {
        "key": "client-secret",
        "name": "rhobs-hypershift-platform-staging-tenant",
        "optional": true
      }
    }
  }
  ```
  - As you can see one variable must be suffixed with `_CLIENT_ID` while the other is suffixed with `_CLIENT_SECRET`.
  - Both variables are read from a secret, the same secret (named `rhobs-hypershift-platform-staging-tenant` in above example)
  - But a different key (`client-id` vs `client-secret`) is used to fill the variable.

- Check if the secret referenced in `obsctl-reloader` is actually there:
  ```
  oc get secret -n $NAMESPACE <RHOBS_credentials_secret> --as backplane-cluster-admin
  ```
  Replace `<RHOBS_credentials_secret>` with the proper secret name.  
  (ex: `rhobs-hypershift-platform-staging-tenant` for the `hypershift-platform-staging` tenant)  
  Here the example of the expected output:
  ```
  NAME                                       TYPE     DATA   AGE
  rhobs-hypershift-platform-staging-tenant   Opaque   3      134d
  ```

- Finally check if the RHOBS credentials secret defines the fields read to fill the credential variables passed to `obsctl-reloader`.

If any of those checks fail and you don't know how to solve them:
- Contact `@sre-platform-team-orange` on [#sd-sre-team-orange](https://redhat-internal.slack.com/archives/C0189RRTQAV) Slack channel.
- Be specific by indicating which check failed, and what was the error.
- The team will probably have to redo some of the steps described in this document:
  [Deploying rules on a new tenant](./deploying-rules-on-a-new-tenant.md)
