#   Deploying rules on a new tenant

##  1. Tweaking the `app-interface` repository

### a. Deploying the rules in the RHOBS namespace consumed by `obsctl-reloader`

Add a new item in the `resourceTemplates` section of the following file:  
[`data/services/osd-operators/cicd/saas/saas-rhobs-rules-and-dashboards.yaml`](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/osd-operators/cicd/saas/saas-rhobs-rules-and-dashboards.yaml)

1. Define the `url` attribute:  
   ```
   url: https://gitlab.cee.redhat.com/service/rhobs-rules-and-dashboards
   ```
2. Define the `path` attribute:
   - For single tenant rules folders this is the relative path of the folder within the `rhobs-rules-and-dashboards` repository.  
     For instance:
     ```
     path: /rules/osd
     ```
   - For multi tenants rules folder this is the relative path of the template in the folder.
     For instance:
     ```
     path: /rules/hypershift-platform/template.yaml
     ```
3. Define the `provider` attribute if the rules folder does not map other tenants (i.e. single tenant):
   ```
   provider: directory
   ```
4. Define the targets; normally one per environment:
   - Take a look at what has been done for the `osd` and `hypershift-platform` rules folder to know the proper yaml structure.
   - The `$ref` attribute references a "namespace" file:
     - The given path is rooted on the [`/data`](https://gitlab.cee.redhat.com/service/app-interface/-/tree/master/data) directory.  
       Make sure this path locates an existing `app-interface` file from there.
     - The `$schema` in the namespace file must be `/openshift/namespace-1.yml`.  
       Those kind of files are used to locate a namespace within a cluster.  
       Make sure that the `name` and `cluster` attributes in that file matches the settings for the tenant as described in the following document:  
       [Troubleshooting the deployment pipeline](./troubleshooting-the-deployment-pipeline.md#introduction)
   - If the rules folder is multi tenant, you will have to define the `TENANT` parameter to pass when instantiating the template in each target.  
     As the default value for that parameter is the rules folder name, you can eventually skip this definition if the whished tenant value matches the folder name.

If there is already a `resourceTemplate` for the rules folder mapping your tenant:
- This means this folder is multi tenant as you want to add a new tenant for it.
- You can skip step 1.
- Append `/template.yaml` to the `path` attribute in step 2.
- Remove the `provider` attribute definition (see step 3) as it is only valid for single tenants folder.
- Make sure there is a `template.yaml` file in the rules folder. 

### b. Instantiating the `obsctl-reloader` template to work on the new tenant.

Edit the following file:  
[`data/services/rhobs/observatorium-mst/cicd/saas.yaml`](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/rhobs/observatorium-mst/cicd/saas.yaml)

Locates the `targets` of the item named `observatorium-mst-common` in `resourceTemplates` section.

Retain the targets for which the namespaces (i.e. `$ref` attribute) matches the ones considered in the previous sub-section; on all those targets:
1. Add your tenant to the `MANAGED_TENANTS` parameter. Remark that this is a `,` separated list.
2. Pass the name of the secret handling RHOBS credentials for your tenant through a new parameter:
   - The secret name can be whatever you want; you will just need to be consistent on the next sub-section.
   - The parameter name could also be whatever you want:
     - You just need to match the definition given in the `obsctl-reloader` template (see [next section](#2-changing-the-obsctl-reloader-template-in-rhobsconfiguration-repository))
     - Nonetheless for the seek of consistency in that template, we ask you to name it as follows: `<TENANT>_RELOADER_SECRET_NAME`  
     - Replace dashes with underscores.
   - For instance:
     ```
     HYPERSHIFT_PLATFORM_STAGING_RELOADER_SECRET_NAME: rhobs-hypershift-platform-staging-tenant
     ```
   - Remark that telling the secret name to the `obsctl-reloader` template will no longer be needed once [RHOBS-481](https://issues.redhat.com/browse/RHOBS-481) is implemented.
3. Eventually bump the `ref` attribute to use a new version of the `obsctl-reloader` template providing the new `<TENANT>_RELOADER_SECRET_NAME` parameter.  
   **This means that the `rhobs/configuration` PR need to be merged BEFORE the `app-interface` MR.**

### c. Defining the tenant secret on each RHOBS instance.

Edit the "namespace" files describing the destination on which the rules are deployed (see [the first sub-section](#a-deploying-the-rules-in-the-rhobs-namespace-consumed-by-obsctl-reloader)).  
For instance, for the `osd` tenant, here are files to consider:
- [`data/services/rhobs/observatorium-mst/namespaces/app-sre-stage-01/observatorium-mst-stage.yml`](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/rhobs/observatorium-mst/namespaces/app-sre-stage-01/observatorium-mst-stage.yml)  
- [`data/services/rhobs/observatorium-mst/namespaces/telemeter-prod-01/observatorium-mst-production.yml`](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/rhobs/observatorium-mst/namespaces/telemeter-prod-01/observatorium-mst-production.yml)

In each file, define how the tenant secret used by `obsctl-reloader` is going to be pulled from [vault](https://vault.devshift.net/ui/vault/secrets) by adding an `openshiftResources` item:
- Define the `name` attribute:  
  - Make sure to use the same value than the one given in the previous sub-section to the `<TENANT>_RELOADER_SECRET_NAME` template parameter.
  - The given value will be used to name the `secret` object consumed by `obsctl-reloader` to authenticate on RHOBS for the tenant.  
    This secret will be located the namespace where `obsctl-reloader` is running.
  For instance:
  ```
  name: rhobs-osd-tenant
  ```
- Define the `provider` attribute as follows to have an indirection to vault:
  ```
  provider: vault-secret
  ```
- Define the `path` attribute; this is the path within vault.  
  For instance:
  ```
  path: osd-sre/hive-stage/observatorium-tenant/grafana-proxy-credentials
  ```
  - Paths starting with `app-interface/` may not be accessible to you, but they can be accessed by `app-interface` CI/CD.
  - Paths starting with `osd-sre/` can be accessed by both SRE people and the CI/CD.
- Make sure to define a `tenant` label.   
  This label will be used by `obsctl-reloader` to perform secret discovery once [RHOBS-481](https://issues.redhat.com/browse/RHOBS-481) is implemented.  
  For instance:
  ```
  labels:
    tenant: osd
  ```
- Do not hesitate to take a look at the other secrets defined in the namespace file or take a look at other namesapce file to know how to define the secret.
- In case you are modifying an existing item, or if the secret in vault changed: do not forget to increase the `version` attribute consequently.

## 2. Changing the `obsctl-reloader` template in `rhobs/configuration` repository

Finally, until [RHOBS-481](https://issues.redhat.com/browse/RHOBS-481) is implemented, you have to tell `obsctl-reloader` how to read RHOBS credentials (client id + client secret) from the secret.  
As a reminder, the secret name is passed through the `<TENANT>_RELOADER_SECRET_NAME` template parameter.

Edit the following file which is defining the `obsctl-reloader` template:  
[`resources/services/observatorium-template.yaml`](https://github.com/rhobs/configuration/blob/main/resources/services/observatorium-template.yaml)

Define 2 new environment variables on the `obsctl-reloader` container:
- First variable must be named `<TENANT>_CLIENT_ID` and read the client id field of the secret.  
  For instance:
  ```
  - name: HYPERSHIFT-PLATFORM_CLIENT_ID
    valueFrom:
      secretKeyRef:
        key: client-id
        name: ${HYPERSHIFT_PLATFORM_RELOADER_SECRET_NAME}
        optional: true
  ```
- Second variable must be named `<TENANT>_CLIENT_SECRET` and read the client secret field of the secret.
- Pay attention:
  - To the secret field name which is not very consistent (`client_id` vs `client-id`).  
    Open the secret in [vault](https://vault.devshift.net/ui/vault/secrets) (if possible) to make sure of the field name.
  - To the variable name, **dashes in `<TENANT>` must not be replaced with underscores!**  

Define the `<TENANT>_RELOADER_SECRET_NAME` template parameter:
- Make sure the parameter name matches the one used when intantiating the template (see [first section](#b-instantiating-the-obsctl-reloader-template-to-work-on-the-new-tenant)).
- Remark that the parameter name contains no dashes; they should be replaced with underscores.
- For instance:
  ```
  - name: HYPERSHIFT_PLATFORM_STAGING_RELOADER_SECRET_NAME
    value: rhobs-hypershift-platform-staging-tenant
  ```

Here is the MR that you can use as an example/template which added `hypershift-platform-staging` tenant on `rhobs/configuration` repository: [!384](https://github.com/rhobs/configuration/pull/384/files)

## Final thoughts
As a reminder `obsctl-reloader` is a tool uploading to RHOBS the `prometheusrule` objects found in the namespace where it is running:
- The tenants it manages are defined by its `MANAGED_TENANTS` parameter.
- The tenant label on each `PrometheusRule` object tells on which tenant the rules it contains must be uploaded.
- The tenant label on the secret will tell which secret to use for a given tenant once [RHOBS-481](https://issues.redhat.com/browse/RHOBS-481) is implemented.
- For now, as explained above, a `<TENANT>_RELOADER_SECRET_NAME` parameter has to be defined to give the secret name, and 2 environement variables have to be defined to explicitely read from this secret.
- You can find more doc on the tool [here](https://github.com/rhobs/obsctl-reloader). As you will see `obsctl-reloader` is a wrapper around `obsctl` which consumes Kube objects instead of regular files and is therefore typically suitable with `app-interface` which deploys Kube objects.