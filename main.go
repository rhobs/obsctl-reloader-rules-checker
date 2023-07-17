// The package providing the 'obsctl-reloader-rules-checker' utility
package main

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/go-git/go-git/v5"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"gopkg.in/yaml.v3"
)

const objectNamePattern = "[a-z0-9]([-a-z0-9]*[a-z0-9])?"
const promRuleAPIVersion = "monitoring.coreos.com/v1"
const promRuleKind = "PrometheusRule"
const tmplAPIVersion = "template.openshift.io/v1"
const tmplKind = "Template"

var objectNameRegexp = *regexp.MustCompile(fmt.Sprintf("^%s$", objectNamePattern))

type labelsObj struct {
	Tenant string `yaml:",omitempty"`
}

type metadataObj struct {
	Name   string
	Labels labelsObj `yaml:",omitempty"`
}

type genericObj struct {
	APIVersion string `yaml:"apiVersion"`
	Kind       string
	Metadata   metadataObj
	Spec       yaml.Node
}

type ruleGroupObj struct {
	Name     string
	Interval string `yaml:",omitempty"`
}

type ruleGroupsObj struct {
	Groups []yaml.Node
}

type parameterObj struct {
	Name  string
	Value string
}

type templateObj struct {
	APIVersion string `yaml:"apiVersion"`
	Kind       string
	Metadata   metadataObj
	Labels     labelsObj
	Parameters []parameterObj
	Objects    []*genericObj
}

type testObj struct {
	RuleFiles []string `yaml:"rule_files"`
}

var errSkipped = errors.New("unexpected error: skipped file not detected as skipped")

func visitDir(dirPath string, isLogging bool, callBack func(bool, string) error) {
	gitDirPath := filepath.Join(dirPath, ".git")

	err := filepath.WalkDir(dirPath, func(path string, dirEntry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		isDir := dirEntry.IsDir()

		if isDir && (path == dirPath || path == gitDirPath) {
			return nil
		}

		err = callBack(isDir, path)

		if errors.Is(err, errSkipped) {
			if isLogging && !isDir {
				log.Infof("[%s] skipped!\n", path)
			}
		} else if err == nil {
			if isLogging {
				log.Infof("[%s] done\n", path)
			}
		} else {
			log.Fatalf("[%s] %s\n", path, err.Error())
		}

		return nil
	})

	if err != nil {
		log.Fatalf("unable to list files in '%s' directory: %v\n", dirPath, err)
	}
}

func runAndOutputCommand(name string, arg ...string) (string, error) {
	cmdOut := strings.Builder{}
	cmd := exec.Command(name, arg...)

	cmd.Stdout = &cmdOut
	cmd.Stderr = &cmdOut

	err := cmd.Run()
	return cmdOut.String(), err
}

func isNamedAsAUnitTest(path string) bool {
	return strings.HasSuffix(path, "_test.yaml") || strings.HasSuffix(path, "_test.yml")
}

func isNamedAsARuleFile(path string) bool {
	return (strings.HasSuffix(path, ".yaml") || strings.HasSuffix(path, ".yml")) && !isNamedAsAUnitTest(path)
}

func loadPrometheusRule(ruleFilePath string) (*genericObj, error) {
	fileContent, err := os.ReadFile(filepath.Clean(ruleFilePath))

	if err != nil {
		return nil, err
	}

	var obj genericObj

	if err := yaml.Unmarshal(fileContent, &obj); err != nil {
		return nil, fmt.Errorf("does not store a Kube object serialized in YAML: %w", err)
	}

	if obj.Kind != promRuleKind {
		return nil, fmt.Errorf("not a '%s' object", promRuleKind)
	}

	if obj.APIVersion != promRuleAPIVersion {
		return nil, fmt.Errorf("'apiVersion' not set to '%s'", promRuleAPIVersion)
	}

	return &obj, nil
}

func storeAsYaml(data interface{}, filePath string) error {
	fileContent, err := yaml.Marshal(data)

	if err != nil {
		return err
	}

	return os.WriteFile(filePath, fileContent, 0600)
}

func gitRepoPath(path string) string {
	prevPath := ""

	for path != prevPath {
		gitDirPath := filepath.Join(path, ".git")

		if fileInfo, err := os.Stat(gitDirPath); err == nil && fileInfo.IsDir() {
			return path
		}

		prevPath = path
		path = filepath.Dir(path)
	}

	return ""
}

func splitGitPath(path string) (string, string) {
	absPath, err := filepath.Abs(path)

	if err != nil {
		log.Fatalf("unexpected error: %v\n", err)
	}

	repoAbsPath := gitRepoPath(absPath)

	if repoAbsPath == "" {
		return "", ""
	}

	relPath, err := filepath.Rel(repoAbsPath, absPath)

	if err != nil {
		log.Fatalf("unexpected error: %v\n", err)
	}

	return repoAbsPath, relPath
}

func checkToolIsInstalled(tool string) {
	checkIsInstalledCmd := exec.Command(tool, "--version")

	if err := checkIsInstalledCmd.Run(); err != nil {
		log.Fatalf("%s is not installed as command '%s' failed to run successfully\n", tool, checkIsInstalledCmd.String())
	}
}

func checkRule(ruleFilePath, tenant, tempDirPath string, objNameToFilePath *map[string]string, groupNameToFilePath *map[string]string) error {
	obj, err := loadPrometheusRule(ruleFilePath)

	if err != nil {
		return err
	}

	objName := obj.Metadata.Name

	if otherFilePath, isAlreadyUsed := (*objNameToFilePath)[objName]; isAlreadyUsed {
		return fmt.Errorf("value for 'metadata.name' attribute is reused (there is already a 'PrometheusRule' named '%s' in '%s' file)", objName, otherFilePath)
	}
	(*objNameToFilePath)[objName] = ruleFilePath

	if !objectNameRegexp.MatchString(objName) {
		return fmt.Errorf("'metadata.name' attribute does not match pattern '%s' (value is '%s')", objectNamePattern, objName)
	}

	if tenant != "" && !strings.HasPrefix(objName, tenant+"-") {
		return fmt.Errorf("'metadata.name' attribute does not starts with '%s-' (value is '%s')", tenant, objName)
	}

	objTenant := obj.Metadata.Labels.Tenant
	if objTenant != tenant {
		if tenant == "" {
			return fmt.Errorf("'metadata.labels.tenant' attribute is set while it shouldn't (value is '%s')", objTenant)
		}
		return fmt.Errorf("'metadata.labels.tenant' attribute is not set to '%s' (value is '%s')", tenant, objTenant)
	}

	specFilePath := filepath.Join(tempDirPath, filepath.Base(ruleFilePath))

	if err := storeAsYaml(&obj.Spec, specFilePath); err != nil {
		return fmt.Errorf("unexpected error: %w", err)
	}

	if output, err := runAndOutputCommand("promtool", "check", "rules", specFilePath); err != nil {
		return fmt.Errorf("failed to run 'promtool check rules' on the 'spec' part of the file; output:\n%v", output)
	}

	{
		var ruleGroupsObj ruleGroupsObj

		if err := obj.Spec.Decode(&ruleGroupsObj); err != nil {
			return fmt.Errorf("unexpected error: %w", err)
		}

		for _, ruleGroupNode := range ruleGroupsObj.Groups {
			var ruleGroupObj ruleGroupObj

			if err := ruleGroupNode.Decode(&ruleGroupObj); err != nil {
				return fmt.Errorf("unexpected error: %w", err)
			}

			if otherGroupFilePath, isAlreadyUsed := (*groupNameToFilePath)[ruleGroupObj.Name]; isAlreadyUsed {
				return fmt.Errorf("value for 'spec.groups[].name' attribute is reused (there is already a group named '%s' in '%s' file)", ruleGroupObj.Name, otherGroupFilePath)
			}
			(*groupNameToFilePath)[ruleGroupObj.Name] = ruleFilePath

			// This check is needed because RHOBS servers are running a very old version of Prometheus code in which the interval at this level was mandatory at the time.
			// 'promtool check rules' is parsing the rules with a newer version of Prometheus in which specifying the interval at this level is now optional.
			if ruleGroupObj.Interval == "" {
				return fmt.Errorf("attribute 'spec.groups[].interval' is missing for some group named '%s'", ruleGroupObj.Name)
			}
		}
	}

	return nil
}

func checkRules(rulesDirPath, tenant string, isGeneratingTemplate bool) {
	log.Infoln("checking rules...")

	tempDirPath, err := os.MkdirTemp("", "obsctl-reloader-checking-rules-temp-dir")
	if err != nil {
		log.Fatalf("unable to create a temporary directory: %v\n", err)
	}

	defer os.RemoveAll(tempDirPath)

	objNameToFilePath := make(map[string]string)
	groupNameToFilePath := make(map[string]string)

	visitDir(rulesDirPath, true,
		func(isDir bool, path string) error {
			if isDir {
				if isGeneratingTemplate {
					return errSkipped
				}
				return errors.New("subdirectories are not allowed when not generating a template (see --rules-dir flag)")
			}

			if !isNamedAsARuleFile(path) {
				if isGeneratingTemplate {
					return errSkipped
				}
				return errors.New("file is not named as a rule file (see --rules-dir flag)")
			}

			return checkRule(path, tenant, tempDirPath, &objNameToFilePath, &groupNameToFilePath)
		})
}

func lintFile(filePath string) error {
	if output, err := runAndOutputCommand("yamllint", filePath); err != nil {
		return fmt.Errorf("failed to run 'yamllint'; output:\n%v", output)
	}

	return nil
}

func lintFiles(rulesDirPath, testsDirPath string) {
	log.Infoln("running YAML linter...")

	visitDir(rulesDirPath, true,
		func(isDir bool, path string) error {
			if isDir || !isNamedAsARuleFile(path) {
				return errSkipped
			}

			return lintFile(path)
		})

	visitDir(testsDirPath, true,
		func(isDir bool, path string) error {
			if isDir || !isNamedAsAUnitTest(path) {
				return errSkipped
			}

			return lintFile(path)
		})
}

const templateHeaderFormat = `
THIS FILE IS GENERATED FROM THE FILES IN THE %s FOLDER
Do not edit it manually!

Generate it again by running the following command%s:
docker run -v "$(pwd):/work" quay.io/app-sre/obsctl-reloader-rules-checker:latest -t %s %s

-> Eventually replace the 'docker' container engine by the engine installed on
   your computer (for instance: 'podman').
-> Eventually replace the image version by the version used for your rules.
-> Eventually replace the targeted image by the below image in case you built
   the image locally:
   localhost/obsctl-reloader-rules-checker:latest
-> Eventually replace everything that precedes the '-t' option by the path to
   tool in case you have the tool installed or built locally on your computer. 

If your Makefile supports it, you should also be able to generate this file
again by running one of those commands at the root of your rules repository
clone:
- make
- make gen-template

You can find more information on the tool used underneath by taking a look at
its repository:
https://github.com/rhobs/obsctl-reloader-rules-checker

Commit this file alongside with your changes on the rules or the build of your
pull request / merge request will fail.`

func generateTemplate(rulesDirPath, tenant, templatePath string) {
	log.Infoln("generating template...")

	tmplObj := templateObj{
		APIVersion: tmplAPIVersion,
		Kind:       tmplKind,
		Metadata: metadataObj{
			Name: "all-rules",
		},
		Labels: labelsObj{
			Tenant: "${TENANT}",
		},
		Parameters: []parameterObj{
			{Name: "TENANT", Value: tenant},
		},
	}

	visitDir(rulesDirPath, false,
		func(isDir bool, path string) error {
			if isDir || !isNamedAsARuleFile(path) {
				return errSkipped
			}

			obj, err := loadPrometheusRule(path)

			if err != nil {
				return err
			}

			obj.Metadata.Name = "${TENANT}-" + obj.Metadata.Name

			tmplObj.Objects = append(tmplObj.Objects, obj)

			return nil
		})

	var tmplNode yaml.Node

	if err := tmplNode.Encode(tmplObj); err != nil {
		log.Fatalf("unexpected error: %v\n", err)
	}

	{
		rulesRepoAbsPath, rulesRelPath := splitGitPath(rulesDirPath)
		tmplRepoAbsPath, tmplRelPath := splitGitPath(templatePath)
		quotedTenant := "'" + tenant + "'"

		if rulesRepoAbsPath != "" && rulesRepoAbsPath == tmplRepoAbsPath {
			tmplNode.HeadComment = fmt.Sprintf(templateHeaderFormat,
				"'"+rulesRelPath+"'",
				" at the root of your clone",
				quotedTenant,
				fmt.Sprintf("-d '%s' -t '%s'", rulesRelPath, tmplRelPath),
			)
		} else {
			tmplNode.HeadComment = fmt.Sprintf(templateHeaderFormat, "RULE", "", quotedTenant, "...")
		}
	}

	if err := storeAsYaml(tmplNode, templatePath); err != nil {
		log.Fatalf("[%s] failed to write template on file: %v\n", templatePath, err)
	}
}

func checkTemplateIsCommitted(templatePath string) {
	log.Infoln("checking template is committed...")

	repoAbsPath, tmplRelPath := splitGitPath(templatePath)

	if repoAbsPath == "" {
		log.Fatalf("[%s] file is not in a Git repository; consider not using --no-uncommitted-template flag\n", templatePath)
	}

	repo, err := git.PlainOpen(repoAbsPath)

	if err != nil {
		log.Fatalf("[%s] not a valid Git repository: %v\n", repoAbsPath, err)
	}

	workTree, err := repo.Worktree()

	if workTree == nil || err != nil {
		log.Fatalf("unexpected error: %v\n", err)
	}

	status, err := workTree.Status()

	if err != nil {
		log.Fatalf("unexpected error: %v\n", err)
	}

	isTmplTracked := !status.IsUntracked(tmplRelPath)
	tmplStatus := status.File(tmplRelPath)

	isUnmodified := func(code git.StatusCode) bool {
		// Just checking the status code against git.Unmodified is not enough as explained here:
		// https://stackoverflow.com/questions/62738651/go-git-reports-a-file-as-untracked-while-it-should-be-unmodified
		return isTmplTracked && (code == git.Untracked || code == git.Unmodified)
	}

	if !isUnmodified(tmplStatus.Staging) || !isUnmodified(tmplStatus.Worktree) {
		log.Fatalf("[%s] template file has not been committed; consider committing it or consider not using --no-uncommitted-template flag\n", templatePath)
	}
}

func runTest(testPath, rulesDirPath string) error {
	testContent, err := os.ReadFile(filepath.Clean(testPath))

	if err != nil {
		return err
	}

	var testObj testObj

	if err := yaml.Unmarshal(testContent, &testObj); err != nil {
		return fmt.Errorf("does not store unit test serialized in YAML: %w", err)
	}

	tempDirPath, err := os.MkdirTemp("", "obsctl-reloader-run-test-temp-dir")
	if err != nil {
		return fmt.Errorf("unable to create a temporary directory: %w", err)
	}

	defer os.RemoveAll(tempDirPath)

	for _, ruleFileRelPath := range testObj.RuleFiles {
		if !isNamedAsARuleFile(ruleFileRelPath) {
			return fmt.Errorf("'%s' file listed by the 'rule_file' attribute is not named as a rule file (see --rules-dir flag)", ruleFileRelPath)
		}

		ruleFilePath := filepath.Join(rulesDirPath, ruleFileRelPath)

		if _, err := os.Stat(ruleFilePath); err != nil {
			return fmt.Errorf("'%s' file listed by the 'rule_file' attribute does not locate an existing file in '%s' (--rules-dir flag): %w", ruleFileRelPath, rulesDirPath, err)
		}

		ruleObj, err := loadPrometheusRule(ruleFilePath)

		if err != nil {
			return fmt.Errorf("unexpected error: %w", err)
		}

		ruleFileTempPath := filepath.Join(tempDirPath, ruleFileRelPath)

		if err := os.MkdirAll(filepath.Dir(ruleFileTempPath), 0700); err != nil {
			return fmt.Errorf("unexpected error: %w", err)
		}

		if err := storeAsYaml(&ruleObj.Spec, ruleFileTempPath); err != nil {
			return fmt.Errorf("unexpected error: %w", err)
		}
	}

	testTempPath := filepath.Join(tempDirPath, filepath.Base(testPath))

	if err := os.WriteFile(testTempPath, testContent, 0600); err != nil {
		return fmt.Errorf("unexpected error: %w", err)
	}

	if output, err := runAndOutputCommand("promtool", "test", "rules", testTempPath); err != nil {
		return fmt.Errorf("failed to run 'promtool test rules'; output:\n%v", output)
	}

	return nil
}

func runTests(testsDirPath, rulesDirPath string) {
	log.Infoln("running the unit tests...")

	visitDir(testsDirPath, true,
		func(isDir bool, path string) error {
			if isDir || !isNamedAsAUnitTest(path) {
				return errSkipped
			}

			return runTest(path, rulesDirPath)
		})
}

const longDesc = `Perform the following checks on the rules to make sure that they can be consumed by obsctl-reloader:

- Eventually check that the given directory (--rules-dir flag) only stores rule files (see flag description).
- Check that all rule files store 'PrometheusRule' objects.
- Check that the names of all those objects are valid and unique.
- Check the spec part of those objects with 'promtool check rules'.
- Check that the objects spec.groups comply with RHOBS specific requirements.
- If --gen-template flag is not set:
  - Check that the names given to those objects starts with the given tenant (--tenant flag).
  - Check that those objects define a 'tenant' label set to the given tenant. 
- If --gen-template flag is set:
  - Make sure that the objects in the given directory do not set a 'tenant' label
  - Generate a template gathering those objects.
    For each object embedded that way:
	- Prefix it name with the template 'TENANT' parameter.
	- Define a 'tenant' label set to the template 'TENANT' parameter.
    Template default value for the 'TENANT' parameter is the value passed to the --tenant flag unless it is not set.
    Path to the file storing that template is given by the --gen-template flag itself.
  - Fail if --no-uncommitted-template is set and the generated template file is not part of a commit.

- Run the unit tests in the location given by the --tests-dir flag with 'promtool test rules'.
  Some adapation is made to let the 'rule_files' attribute list the paths of 'PrometheusRule' files in (and relative to) the rules directory (--rules-dir flag).

- Eventually run the YAML linter on all the rule files and the unit tests if --yaml-lint flag is set.

You can learn more on obsctl-reloader there:
https://github.com/rhobs/obsctl-reloader

Be sure 'promtool' is installed prior running this tool or it will fail.
Similarly make sure 'yamllint' if installed when using the --yaml-lint flag.`

const rulesDirFlagDesc = `path to the directory containing the rule files
  Only '.yaml' and '.yml' suffixed files are considered as rule files.
  Unit test (i.e. files suffixed by '_test.yaml' or '_test.yml') are not considered as rule files.
  If a template is generated (--gen-template flag set): 
  - Non rule files are ignored.
    (Remark that --rules-dir an  --tests-dir flags may have the same value in that case)
  - Directory is walked recursively.
  If no template is generated:
  - Directory is not walked recursively.
  - The checks fails if the directory contains files other than rule files.
  Defaults to the current working directory ('.').`
const tenantFlagDesc = `the tenant targeted by the given rules
  Flag is mandatory unless --gen-template is set in which case it is optional.`
const yamlLintFlagDesc = "run 'yamllint' on the rule files and the unit tests"
const genTemplateFlagDesc = "path to the template to generate"
const noUncommittedTemplateFlagDesc = `fails if the generated template is not committed
  Typically used by the build system to ensure that the template is part of a commit.
  Typically not used when working locally and regenerating the template upon changes on the rules.
  Cannot be set when --gen-template is not set as the aim of this flag is to make sure that the template is committed with the rules it is generated from.`
const testsDirFlagDesc = `path to the directory containing the promtool unit tests
  Promtool unit tests are not run if this flag is not set.
  Consider not setting this flag to save some time (when you just want to generate the template for example).
  Directory is walked recursively.
  Only files suffixed with '_test.yaml' or '_test.yml' are considered as unit tests; the other files are ignored.`

func main() {
	var rulesDirPath, givenTenant, expectedRulesTenant, templatePath, testsDirPath string
	var isRunningLinter, isExpectingCommittedTemplate bool

	rootCmd := &cobra.Command{
		Use:  filepath.Base(os.Args[0]),
		Long: longDesc,
		Run: func(cmd *cobra.Command, args []string) {
			exitOnErroneousUsage := func() {
				err := cmd.Usage()
				if err != nil {
					cmd.Printf("Unexpected error while printing usage: %v\n", err)
				}
				os.Exit(1)
			}

			checkFlagIsDirOrExit := func(flagValue, flagName string) {
				if fileInfo, err := os.Stat(flagValue); err != nil || !fileInfo.IsDir() {
					cmd.Printf("%s flag does not locate a directory\n", flagName)
					exitOnErroneousUsage()
				}
			}

			if rulesDirPath != "" {
				checkFlagIsDirOrExit(rulesDirPath, "--rules-dir")
			} else {
				rulesDirPath = "."
			}

			if templatePath == "" {
				if givenTenant == "" {
					cmd.PrintErrln("--tenant flag is mandatory when --gen-template flag is not set")
					exitOnErroneousUsage()
				}

				if isExpectingCommittedTemplate {
					cmd.PrintErrln("--no-uncommitted-template flag cannot be set when --gen-template flag is not set")
					exitOnErroneousUsage()
				}

				expectedRulesTenant = givenTenant
			} else {
				if fileInfo, err := os.Stat(filepath.Dir(templatePath)); err != nil || !fileInfo.IsDir() {
					cmd.PrintErrln("--gen-template does not locate a file is an existing directory")
					exitOnErroneousUsage()
				}
			}

			if testsDirPath != "" {
				checkFlagIsDirOrExit(testsDirPath, "--tests-dir")
			}

			checkToolIsInstalled("promtool")
			if isRunningLinter {
				checkToolIsInstalled("yamllint")
			}

			checkRules(rulesDirPath, expectedRulesTenant, templatePath != "")

			if isRunningLinter {
				lintFiles(rulesDirPath, testsDirPath)
			}

			if templatePath != "" {
				generateTemplate(rulesDirPath, givenTenant, templatePath)
				if isExpectingCommittedTemplate {
					checkTemplateIsCommitted(templatePath)
				}
			}

			if testsDirPath != "" {
				runTests(testsDirPath, rulesDirPath)
			}
			log.Infoln("ALL DONE OK! :-)")
		},
	}

	rootCmd.Flags().StringVarP(&rulesDirPath, "rules-dir", "d", "", rulesDirFlagDesc)
	rootCmd.Flags().StringVarP(&givenTenant, "tenant", "t", "", tenantFlagDesc)
	rootCmd.Flags().BoolVarP(&isRunningLinter, "yaml-lint", "y", false, yamlLintFlagDesc)
	rootCmd.Flags().StringVarP(&templatePath, "gen-template", "g", "", genTemplateFlagDesc)
	rootCmd.Flags().BoolVar(&isExpectingCommittedTemplate, "no-uncommitted-template", false, noUncommittedTemplateFlagDesc)
	rootCmd.Flags().StringVar(&testsDirPath, "tests-dir", "", testsDirFlagDesc)

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
