# One folder per targeted RHOBS tenant

Files in each folder have to be:
- `.yaml` files defining `PrometheusRule` objects.
- Indicate on which tenant the rules are going to be uploaded by defining a `tenant` label in the `metadata` section.
- You can name the files as you want; however a good practice is to specify the object type before the extension  
  So the filenames should end with the `.prometheusrule.yaml` suffix.

# Test rules

Put tests into `test/rules/<TENANT>` directory.
You can validate and unit test alerts and recording rules with 
`make test-rules`. 

https://prometheus.io/docs/prometheus/latest/configuration/unit_testing_rules/

Running `make check-runbooks` will test alerts for broken runbook/SOP links.

# Registering a new tenant

You have to register each folder in `app-interface` repository as follows:
1. **Get the rules defined in the folder be deployed on RHOBS as `prometheusrule` objects.**  
   Edit [data/services/osd-operators/cicd/saas/saas-rhobs-rules-and-dashboards.yaml](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/osd-operators/cicd/saas/saas-rhobs-rules-and-dashboards.yaml) file to add your folder in the `resourceTemplates` section:
   - Copy/paste an existing item for which the `path` attribute starts with `/rules`.
   - On the copied item: change the `path` attribute to the relative path of your folder to register.
   - You normally keep the same `targets` section unless you do not want to upload the rules on the same RHOBS instances.  
     Make sure to target a namespace on which `obsctl-reloader` is defined (`observatorium-mst-<env>` normally).
2. **Configure `obsctl-reloader` to work on the new tenant.**  
   Edit [data/services/rhobs/observatorium-mst/cicd/saas.yaml](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/rhobs/observatorium-mst/cicd/saas.yaml) file.  
   For all `targets` of the item named `observatorium-mst-common` in `resourceTemplates` section:
   - Add your tenant to the `MANAGED_TENANTS` parameter. Remark that this is a `,` separated list.
   - Create a `<TENANT>_RELOADER_SECRET_NAME` parameter giving the name of secret handling the credentials for your tenant.  
     This will no longer be needed once [RHOBS-481](https://issues.redhat.com/browse/RHOBS-481) is implemented.
3. **Define the tenant secret on each RHOBS instance.**  
   Edit the files referenced in step #1 `targets`; those files are normally the following ones:  
   [data/services/rhobs/observatorium-mst/namespaces/app-sre-stage-01/observatorium-mst-stage.yml](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/rhobs/observatorium-mst/namespaces/app-sre-stage-01/observatorium-mst-stage.yml)  
   [data/services/rhobs/observatorium-mst/namespaces/telemeter-prod-01/observatorium-mst-production.yml](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/rhobs/observatorium-mst/namespaces/telemeter-prod-01/observatorium-mst-production.yml)  
   In each file, define how the tenant secret used by `obsctl-reloader` is going to be pulled from [vault](https://vault.devshift.net/ui/vault/secrets) by adding an `openshiftResources` item:
   - `name` is going to be the name of the `secret` object deployed on the namespace defined by the file where `obsctl-reloader` is running.  
     Make sure to use the same value than the one given in step #2 for `<TENANT>_RELOADER_SECRET_NAME` parameter.
   - `provider` must be set to `vault-secret` to have an indirection to vault.
   - `path` is the path in vault.  
     Remarks that paths starting with `app-interface/` may not be accessible to you, but they can be accessed by `app-interface` CI/CD. You can use path starting with `osd-sre/` that you can normally access.
   - Make sure to define a `tenant` label.   
     This label will be used by `obsctl-reloader` to perform secret discovery once [RHOBS-481](https://issues.redhat.com/browse/RHOBS-481) is implemented.
   - You can use item named `rhobs-osd-tenant` as a template for the secret definition to create there.
   - In case you are modifying an existing item, or if the secret in vault changed: do not forget to increase the `version` attribute consequently.  

Finally, until [RHOBS-481](https://issues.redhat.com/browse/RHOBS-481) is implemented, you also have to modify `rhobs/configuration` repository as follows:
1. **Define environment variables used by `obsctl-reloader` as credentials for the tenant.**  
   Edit [resources/services/observatorium-template.yaml](https://github.com/rhobs/configuration/blob/main/resources/services/observatorium-template.yaml) file.
   Add 2 environment variables for the `obsctl-reloader` container reading secret for which the name is handled by the `<TENANT>_RELOADER_SECRET_NAME` parameter:
   - First variable must be named `<TENANT>_CLIENT_ID` and read the client id field of the secret.
   - Second variable must be named `<TENANT>_CLIENT_SECRET` and read the client secret field of the secret.
   - Pay attention to the field name which is not very consistent (`client_id` vs `client-id`); eventually open the secret in [vault](https://vault.devshift.net/ui/vault/secrets) to make sure of the field name.

# More on `obsctl-reloader`

As a reminder `obsctl-reloader` is a tool uploading to RHOBS the `prometheusrule` objects found in the namespace where it is running:
- The tenants it manages are defined by its `MANAGED_TENANTS` parameter.
- The tenant label on each `PrometheusRule` object tells on which tenant the rules it contains must be uploaded.
- The tenant label on the secret will tell which secret to use for a given tenant once [RHOBS-481](https://issues.redhat.com/browse/RHOBS-481) is implemented.
- For now, as explained above, a `<TENANT>_RELOADER_SECRET_NAME` parameter has to be defined to give the secret name, and 2 environement variables have to be defined to explicitely read from this secret.
- You can find more doc on the tool [here](https://github.com/rhobs/obsctl-reloader). As you will see `obsctl-reloader` is a wrapper around `obsctl` which consumes Kube objects instead of regular files and is therefore typically suitable with `app-interface` which deploys Kube objects.