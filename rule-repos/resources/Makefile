SHELL=/usr/bin/env bash -o pipefail

# Runtime CLI to use for running images
CONTAINER_ENGINE ?= $(shell command -v podman 2>/dev/null || echo docker)
# TODO: replace 'latest' with a fixed version of 'obsctl-reloader-rules-checker' & remove this comment
IMG_VERSION=latest

# TODO:
# - Replace <tenant> keyword with the rule repo tenant / base tenant
# - Make sure the '-d' flag locates the rules folder in the repository 
# - Remove this comment once done

BASE_CMD=$(CONTAINER_ENGINE) run -v "$(shell pwd):/work" --rm --privileged -t quay.io/rhobs/obsctl-reloader-rules-checker:$(IMG_VERSION) -t <tenant> -d rules -y -p

# TODO <adapt-if-template>:
# - Uncomment below instruction if a template needs to be generated
# - Remove below commented instruction iotherwise
# - Eventually adapt the path to the template (value of the '-g' flag)
# - Remove this comment once done

#BASE_CMD:=$(BASE_CMD) -g template.yaml

# TODO:
# - Remove below target if there is no unit test
# - Make sure the '-T' flag locates the unit tests folder in the repository 
# - Remove this comment once done
.PHONY: checks-and-tests
checks-and-tests:
	$(BASE_CMD) -T test

.PHONY: checks
checks:
	$(BASE_CMD)

# TODO <adapt-if-template>:
# - Uncomment below target if a template needs to be generated
# - Remove below commented target otherwise
# - Eventually make sure the '-T' flag locates the unit tests folder in the repository, remove it if there are no unit tests
# - Remove this comment once done

##.PHONY: ci
#ci:
# 	$(BASE_CMD) --no-uncommitted-template -T test
