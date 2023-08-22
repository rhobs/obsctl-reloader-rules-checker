<!--
  TODO:
  - Replace <tenant> keyword with the rule repo tenant / base tenant in this document
  - Remove this comment once done
-->
#   <tenant> RHOBS rules

This repository contains the rules for the `<tenant>` tenant.

<!--
  TODO: Remove below sentence if the repository is not hosted on GitLab
-->
In GitLab, you can identify the rules for the other RHOBS tenants [by filtering the repositories](https://gitlab.cee.redhat.com/explore/projects/topics/rhobs-rules) with the `rhobs-rules` topic.

<!--
  TODO:
  - Rename below paragraph to 'Running the checks' if there is no unit test
  - Remove this comment once done
-->
##  Running the checks and the tests

Just run the bellow command:
```
make
```

This command will:
- Check the [rules](./rules/) syntax with `promtool check rules`.
<!--
  TODO <adapt-if-template>:
  - Uncomment below bullet if a template needs to be generated
  - Remove below commented bullet otherwise
  - Remove this comment once done
-->
<!-- - Generate the [template file](./template.yaml) aggregating the rules. -->
<!--
  TODO:
  - Remove below bullet if there is no unit test
  - Remove this comment once done
-->
- Run the rules [unit tests](./test/) with `promtool test rules`.
<!--
  TODO:
  - Inline to have one sentence if there is only one bullet remaining
  - Remove this comment once done
-->

<!--
  TODO <adapt-if-template>:
  - Uncomment below sentence if a template needs to be generated
  - Remove below commented sentence otherwise
  - Remove this comment once done
-->
<!-- **Once this command finishes, make sure to ship the generated template with your commit.** -->

<!--
  TODO:
  - Remove below paragraph if there is no unit test
  - Remove this comment once done
-->
## Just running the checks

Running the unit tests may take quite some time; it is possible to by-pass them by running the following command:
```
make checks
```

<!--
  TODO <adapt-if-template>:
  - Uncomment below paragraph if a template needs to be generated
  - Remove below commented paragraph otherwise
  - Remove this comment once done
-->
<!-- ## Making sure your change will pass the CI

The continous integration (CI) is also checking that the template matches the rules it is generated from.

Run the following command to perform this additional check on top of `make`:
```
make ci
```

This additional check will make sure there is no difference between the template which has been regenerated from the rules and the template which has been committed.

Run this command prior shiping your change to make sure it will pass the CI.  -->

##  Promoting the changes

<!--
  TODO:
  - Replace <saas-name> with the service name in app-interface
  - Make sure 'rules' link really locates the rules folder; adapt if needed
  - Remove this comment once done
-->
The `PrometheusRule` in the [rules](./rules/) folder are consumed by `app-interface` there:  
[`data/services/osd-operators/cicd/saas/<saas-name>.yaml`](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/osd-operators/cicd/saas/<saas-name>.yaml)

You have to bump the `ref` attribute for the production target.
The new value has to be the hash of your change last commit or the hash of the descendant commit.

You can automate the `app-interface` MR creation with [`promote.sh`](https://github.com/openshift/ops-sop/blob/master/v4/utils/promote.sh) as follows:
```
promote.sh <saas-name>
```

<!--
  TODO:
  - Make sure that the default branch is really named `main`; adapt if needed
  - Remove this comment once done
-->
Remark that promotion only applies to the production target.
`ref` is set to `main` on staging; your change is automatically promoted & deployed when merging your change on that branch.

##  What about building or delivering?

No binary is produced from this repository.  
<!--
  TODO <adapt-if-template>:
  - Uncomment below sentence if a template needs to be generated
  - Remove below commented sentence otherwise
  - Eventually adapt the link to the template file
  - Remove this comment once done
-->
<!-- The only "deliverable" is the [template file](./template.yaml) which needs to be committed with your change or the CI build will fail.

As a reminder, you have to run one of the following command to generate it:
```
make
make checks
``` -->

## Want to know more?

Take a look at the following documents:  
https://github.com/rhobs/obsctl-reloader-rules-checker/tree/main/rule-repos/docs

Those documents are common to all repositories hosting RHOBS rules and using `obsctl-reloader-rules-checker` tool for local testing and the CI (continuous Integration).