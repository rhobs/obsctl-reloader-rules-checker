# obsctl-reloader-rules-checker

Uploading rules to RHOBS is normally done through [`obsctl-reloader`](https://github.com/rhobs/obsctl-reloader).

The `obsctl-reloader-rules-checker` tool is a command line tool checking that the `PrometheusRule` objects fed to `obsctl-reloader` can safely be consumed.

## Retrieving the tool binary

You can retrieve this tool binary from GitHub [release section](https://github.com/rhobs/obsctl-reloader-rules-checker/releases).

The binary is delivered for all major platforms (Linux, Windows, Mac OS) and for all major architectures.

## Prerequisites before using the tool binary

The `obsctl-reloader-rules-checker` tool relies on the following command line tools:
- [`promtool`](https://prometheus.io/docs/prometheus/latest/command-line/promtool/): this tool is at the heart of `obsctl-reloader-rules-checker`.  
  It is used to check that input files really store `PrometheusRule` objects; the tool is also used to run the rules unittests.
- [`yamllint`](https://github.com/adrienverge/yamllint): this tool is a linter (so a nice to have) used both on the rules and the unittests.  
  It only need to be present if you plan on using the `-y` flag of `obsctl-reloader-rules-checker`.

You have to make sure that those tool are present on your computer when using the `obsctl-reloader-rules-checker` tool binary.

Take a look at the following files to know the versions of those tools to use:
- For `promtool`: [`hack/install-go-tools.sh`](./hack/install-go-tools.sh)
- For `yamllint`: [`hack/install-yamllint-tool.sh`](./hack/install-yamllint-tool.sh)

## Using the tool docker image instead

A docker image wrapping the tool is delivered on quay:
```
quay.io/app-sre/obsctl-reloader-rules-checker
```

**This is actually the preferred way of using the tool as the image contains the `promtool` and `yamllint` dependencies.**

The only prerequisite before using the docker image is to have a container engine (`docker`, `podman`) installed on your computer.

This image can also be used on GitHub and GitLab continuous integrations to assess the corectness of your pull requests and merge requests on rules repositories. More on that later.

## Tool usage

This tool is used to assess the validity of rule files.  
Imagine you have a repository containing rules definitions structured as follows:

```
my-tenant_repo_clone/
├── .yamllint
├── .git/
├── rules/
│   ├── rule1.yaml
│   ├── rule2.yaml
│   └── rule3.yaml
├── tests/
│   ├── test1.yaml
│   └── test2.yaml
└── template/
```

This repository only contains the rules for a single RHOBS tenant, this tenant is named `my-tenant` in above example.

As this tenant may differ a bit between prod and staging, we are gonna call the tool in such a way that it will generate a template; the template gather all the rules and allows to define the exact tenant through the `TENANT` parameter when instantiated.

Let's assume that you are at the root of the clone; you will have to call the tool as follows on Linux/Mac:
- When using the tool binary:
  ```
  obsctl-reloader-rules-checker -t my-tenant -d rules -g template/template.yaml -t tests -y
  ```
- When using the tool docker image:
  ```
  docker run -v "$(pwd):/work" -t quay.io/app-sre/obsctl-reloader-rules-checker:latest -t my-tenant -d rules -g template/template.yaml -t tests -y
  ```
  (replace `docker` container engine by `podman` if needed)

Remark that the flags are the same whether you are using the tool binary or the tool docker image; indeed, as a reminder, the tool docker image is just a wrapper of the tool binary with all the prerequisites needed by it.

Now lets explain the flags used in above example:
- The `-t` flag is used to specify the rules tenant.  
  The tenant is a string used by RHOBS to partition / shard data.  
  As previously said, we are not yet sure of the tenant on which the rules will be uploaded and that's why we are generating a template.  
  The value passed here is just used as a default value for the temaple `TENANT` parameter.
- The `-d` flag locates the directory in which the rules are located.
- The `-g` flag tells to generate a template and gives the path to the file to generate.
- The `-t` flag gives the path to the unittests directory.
- The `-y` flag tells to run `yamllint` on all the rule files and on all the unittests.  
  Remark that the `.yamllint` at the root of the clone repository is telling how those YAML files should be formatted. This file is optional when using the docker image; indeed the tool docker image is bundling a default `yamllint` config file defined [there](./.yamllint).

Use the `-h` or `--help` flag of the tool to know more about the possible usages.

## Tool checks

As previously explained, the purpose of this tool is to check the validity of the given rule files.

Once again, the `-h` / `--help` flag is pretty explicit about those checks. Here is a brief list of those checks:
- Check that all rule files store `PrometheusRule` objects.
- Check that objects have all a different name.
- Check that the `spec` part of those objects are valid against `promtool check rules`.
- Check that the objects names and `tenant` label are properly set.
- Run all the unittests with `promtool test rules`.
- Run `yamllint` on the rule files and the unittests.

## Building the tool binary

**Prerequisites**:
- You have to checkout the code.
- The following tools must be present on your computer:
  - `make`
  - `go` (version 1.19 or later)

To build the binary you just have to run:
```
make build
```

The binary will be delivered in the `bin` folder. `promtool` is also built and installed when running that command.

## Building the tool docker image

**Prerequisites**:
- You have to checkout the code.
- The following tools must be present on your computer:
  - `make`
  - a container engine: either `docker` or `podman`

To build the binary you just have to run:
```
make docker-build
```

The docker image will be tagged as follows is your local registry:
```
obsctl-reloader-rules-checker:latest
```

## Local developement

Local development is not just about building the code. It is also about making sure that your changes will pass all the checks performed by the continous integration (CI) jobs.

**Prerequisites**:
- You have to checkout the code.
- The following tools must be present on your computer:
  - `make`
  - `go` (version 1.19 or later)
  - a container engine: either `docker` or `podman`
  - [`yamllint`](https://github.com/adrienverge/yamllint) (eventually run `make yamllint-tool` to install the tool)
  - [`golangci-lint`](https://golangci-lint.run/usage/install/)

As you can see you have to install some linters on top of "building the code" prerequisites.

**Rapidly checking that your change is okay**. Just run:
```
make
```

**Checking that your change will really pass the CI**. Just run:
```
make pr-checks
```

The difference between the 2 commands are that:
- `make` builds the tool binary while `make pr-checks` build the tool docker image.  
  Building the code outside a docker image is faster as `go` can benefit some  caching when buliding locally.
- `make` will format the code and update `go.mod` and `go.sum` files if needed; you will need to commit those files alongside with your change.  
  `make pr-checks` also updates those files but fails if the differs from what is committed.

**Cleaning the repository clone**. Just run:
```
make clean
```
This will remove the `bin` folder in which the tool binary has been delivered but also the `.bingo` folder which was used to build `promtool`.

## Using the binary wrapper

The [`obsctl-reloader-rules-checker`](./obsctl-reloader-rules-checker) file at the root of the repository is a wrapper of the tool binary.

It accepts the exact same arguments than the tool binary and make sure that:
- The wrapped tool binary is built
- `promtool` and `yamllint` are installed

This allows using the tool out of the box / just after code checkout.

## Delivering the code

Just tag your local clone and push the tag without going through a pull request:
```
git tag 1.0.0
git push git@github.com:rhobs/obsctl-reloader-rules-checker.git main --tags
```

This operation is reserved to repository maintainers.