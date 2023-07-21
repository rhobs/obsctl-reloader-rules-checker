#   Rules and dashboards

This repository contains 2 kinds of resources:
- In the `rules` folder: **the `PrometheusRule` resources uploaded on RHOBS clusters**.  
- In the `dashboards` folder: **the dashboards configs uploaded on app-sre clusters**.
  - `ConfigMap` resources are used to store those configs.
  - Those dashboards consumes metrics uploaded on the `osd` tenant of RHOBS.  
    Hence there are designed to work with the rules in `rules/osd` folder.

The other folders (`hack`, `docs` and `test`) are pretty self explanatory. As usual/by convention, the `hack` folder contains utility scripts for testing and the CI/CD.

##  Running the tests

Just run the bellow command:
```
make
```

This command will:
- Generate the template file aggregating rules.  
  (only for the `hypershift-platform` tenant, more details on that [here](rules/hypershift-platform/README.md))
- Check the rules syntax with `promtool check rules`.
- Test the rules with `promtool test rules` (tests in [`test/rules`](test/rules) folder).
- Run yaml linter for all `.yaml` files in the repository.

**Once this command finishes, make sure to commit the generated tempplate(s)** and ship them in your MR (Merge Request).

Each above step can also be run separaty running the following commands; respectively:
- `make gen-rules-templates`
- `make check-rules`
- `make test-rules`
- `make yaml-lint`

As `test-rules` target may take quite some time, it is also possible to only run the tests that have been changed (i.e which are not yet committed) with the following command:
```
make test-changed-rules
```

Finally remark that the GitLab build will run this command:
```
make test
```

This command performs the same steps than the `make` command except that it will fail if the generated templates have not been committed.
Run it as well prior creating your MR to make sure the build will succeed. 

##  Promoting the changes

The `PrometheusRule` and `ConfigMap` resources (declared in `rules` and `dashboards` directories) are consumed (on a directory basis) by `app-interface` there:  
[`data/services/osd-operators/cicd/saas/saas-rhobs-rules-and-dashboards.yaml`](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/osd-operators/cicd/saas/saas-rhobs-rules-and-dashboards.yaml)

You have to bump the `ref` attribute of the corresponding target to promote the referenced directory.
- For instance: [MR 57223](https://gitlab.cee.redhat.com/service/app-interface/-/merge_requests/57223)
- The new value has to be a commit hash of the `rhobs-rules-and-dashboards` repository to promote.

As you can see, the `ref` attribute can also be set to a branch name.
That's the case for `stage` targets for which the attribute is set to `main`.  
**Promotion is not needed on staging, changes are consumed and deployed as soon as your MR is merged on the `main` branch.**

##  What about building or delivering?

No binary is produced from this repository.  
The only "deliverables" which are produced are the rule templates; those are internal deliverables as they need to be committed with your change (or GitLab build will fail).

As a reminder, you have to run one of the following command to generate those files:
```
make
make gen-rules-templates
```

## You want to know more?

Take a look at the [documentation](docs).

More specifically, you may want to take a look at the following documents when dealing with rules and Hypershift in mind:
- [An introduction to the Hypershift monitoring architecture](docs/rules/hypershift-monitoring-architecture-introduction.md)
- [Designing rules and writing tests](docs/rules/designing-rules-and-writing-tests.md)
- [Troubleshooting the deployment pipeline](docs/rules/troubleshooting-the-deployment-pipeline.md)
- Preliminary studies used to infer the definitive solution:
  - [Google drive folder (Orange team)](https://drive.google.com/drive/folders/1Yn2fqMoM8_Xy7OfjjRlulxvnM0G7vVsz)
  - [GitHub openshift/enhancements study](https://github.com/openshift/enhancements/blob/master/enhancements/monitoring/hypershift-monitoring.md)