## Folders and tenants

Two possibilities for each folder:
- The folder targets only one RHOBS tenant.
  - In that case the folder should be named after the tenant.
- The folder targets several tenants:
  - Those tenants are normally used for the same purpose but on different environments.
    (ex: `hypershift-platform` and `hypershift-platform-staging` tenants)
  - The common prefix of the tenants should normally be used to name the folder.

In all cases: a RHOBS tenant is only mapped by one folder.

## Inside each folder

Each folder contains `.yaml` files. There are 2 kind of yaml files:
- Files defining `PrometheusRule` objects.
- And the `template.yaml` file aggregating those rules in just one file.

The `template.yaml` is only present for multi tenant folders:
- It overrides each  `PrometheusRule` with the value passed to its `TENANT` parameter:
  - The name is prefixed with the passed tenant.
  - The `tenant` label is set to be the passed tenant.
- Rules are therefore only fully defined when instantiating the template with the targeted tenant.
- This file is generated and should not much bother about it.  
  Just follow the instructions in [the root `README.md`](../README.md#running-the-tests) to make sure the file is bundled in your merge request.

For single tenant folders:
- You have to set the `tenant` label for each `PrometheusRule` object yourself as there is no template doing it for you.
- Similarly, you probably need to prefix the rule name with the tenant.  
  Indeed rules might be deployed by `app-interface` on a location shared with other tenants... and prefixing the rule name with the tenant can help to avoid collisions there.

## Testing rules

Tests are located elsewhere: there are in the [`test/rules`](../test/rules/) directory.

This directory follows the same structure than this directory:  
Tests for a folder in this directory are located in a folder with the same name on the test directory.

You can run the unit tests by shooting the following command at the root of your clone: 
```
make
```

## You want to know more?

Take a look at:
- [The root `README.md`](../README.md#running-the-tests) to know more about running the tests and generating or generating the rules templates.
- [Adding a new rules folder](../docs/rules/adding-a-new-rules-folder.yaml)