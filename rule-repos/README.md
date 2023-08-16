# Rule repositories

The `obsctl-reloader-rules-checker` tool is designed to check the validity of a rule reposity.

**A rule repository is a Git repository defining the Prometheus rules for a specific RHOBS tenant or for a set of related tenants.**

A rule repository is typically organized as follows:
```
tenant-rhobs-rules/
├── .yamllint
├── Makefile
├── rules/
│   ├── rule1.yaml
│   ├── rule2.yaml
│   └── rule3.yaml
├── tests/
│   ├── test1.yaml
│   └── test2.yaml
└── template.yaml
```

This is only a suggestion, the path to the rule files, unit tests or template can be adjusted.

Also it is advised to name the rule repository after the tenant(s) it target.

Once again this is not an obligation, here some known rule repositories and the RHOBS tenant(s) they target:

| Rule repository  | Tenant(s) | Comment
| ---------------- | --------- | -------
| [`hypershift-platform-rhobs-rules`](https://gitlab.cee.redhat.com/service/hypershift-platform-rhobs-rules) | `hypershift-platform` for prod<br>`hypershift-platform-staging` for staging
| [`osd-rhobs-rules-and-dashboards`](https://gitlab.cee.redhat.com/service/osd-rhobs-rules-and-dashboards) | `osd` for prod & staging | The repository also contains dashboards
| [`redhat-appstudio/o11y`](https://github.com/redhat-appstudio/o11y) | `rhtap` for prod & staging

## The [`resources`](./resources/) folder

It contains the files you need to copy in the new rule repository to create. Namely:
- The [`Makefile`](./resources/Makefile) (used for local devlopment)
- The [`README.md`](./resources/README.md)
- The CI files.

Pay attention to the comments in those files; make sure your proceed to the following adjustement when copying them:
- Replace `<tenant>` with the RHOBS tenant targeted by the new repository.  
  If the rule repository is targeting several tenants: replace `<tenant>` with the "base" tenant which is either one of the tenants or with some prefix common to all targeted tenants.
- Adapt sections tagged with `<adapt-if-template>` regarding whether or not you will generate a template for the rules in your new rule repository.  
  As a reminder, a template:
  - **Aggregates** all the Prometheus rules in a single object/file.
  - **Is handy** in situations where you do not know in advance on what RHOBS tenant the rules will be deployed on.
  - **Is required** when your rule repository targets several RHOBS tenants as the template lets you define the targeted tenant when it is instantiated.
- Choose the right CI file to copy among the following possibilities:
  - The [`.gitlab-ci.yaml`](./resources/.gitlab-ci.yaml) for GitLab CI
  - The [`.github/workflows/pr-checks.yaml`](./resources/.github/workflows/pr-checks.yaml) for GitHub actions

In case of doubt, take a look at the existing rules repositories listed earlier to know how to adjust the files to copy.

## The [`docs`](./docs/) folder

It contains documentation that applies to any rule repository:
- [Creating a new rule repo](./creating-a-new-rule-repo.md): how to use `obsctl-reloader-rules-checker` for local testing & CI (Continuous Integration)
- [Configuring rule repo deployment](./configuring-rule-repo-deployment.md): how to setup [`app-interface`](https://gitlab.cee.redhat.com/service/app-interface) automation to get the rules deployed on RHOBS.
- Also you can find there documents explaining:
  - How to debug the deployment process.
  - How to design rules which be evaluated in an efficient way and how to write tests on them.

The rule repository [`README.md`](./resources/README.md) links this documentation folder.