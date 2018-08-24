#
# Builds the following images:
# image: metacontroller
#
# To build without the cache set the environment variable
# export DOCKER_BUILD_OPTS=--no-cache
PKG        := k8s.io/metacontroller
API_GROUPS := metacontroller/v1alpha1
DOCKER_BUILD_OPTS ?= --memory-swap -1
REGISTRY ?= ''
GCLOUD_PROJECT ?= $(shell gcloud config list --format 'value(core.project)')
INPUTS = $(shell cat Dockerfile|grep image:|sed 's/^.*image: //')
TARGETS = $(shell echo $(INPUTS)|xargs -d ' ' -I {} echo $(REGISTRY)$(GCLOUD_PROJECT)/{})
SOURCES = $(shell echo $(INPUTS)|sed 's/ /.build /g'|sed 's/$$/.build/')
PUSHES = $(shell echo $(INPUTS)|sed 's/ /.push /g'|sed 's/$$/.push/')
PUSHES_LATEST = $(shell echo $(INPUTS)|sed 's/ /.push_latest /g'|sed 's/$$/.push_latest/')
DEPLOYS = $(shell echo $(INPUTS)|sed 's/ /.deploy /g'|sed 's/$$/.deploy/')
DEPLOYS_LATEST = $(shell echo $(INPUTS)|sed 's/ /.deploy_latest /g'|sed 's/$$/.deploy_latest/')
# set to sleep if you would like to debug from main
DEPLOY_COMMAND ?= ''
UNDEPLOYS = $(shell echo $(INPUTS)|sed 's/ /.undeploy /g'|sed 's/$$/.undeploy/')
VERSIONS = $(shell scripts/buildargs.sh)
TAG ?= $(shell date +v%Y%m%d)-$(shell git describe --tags --always --dirty)-$(shell git diff | shasum -a256 | cut -c -6)
DEBUG ?= false
# modes are attach|exec. "attach" assumes the process is running. "exec" assumes the process is not.
DEBUG_MODE ?= attach
PORT ?= 2345

%.build: generated_files
	@scripts/pull.sh $(REGISTRY)$(GCLOUD_PROJECT)/$* $(TAG)
	@scripts/build.sh $(DOCKER_BUILD_OPTS) --build-arg REGISTRY=$(REGISTRY) --build-arg PROJECT=$(GCLOUD_PROJECT) $(VERSIONS) --target=$* -t $(REGISTRY)$(GCLOUD_PROJECT)/$*:$(TAG) .
	@docker tag $(REGISTRY)$(GCLOUD_PROJECT)/$*:$(TAG) gcr.io/$(GCLOUD_PROJECT)/$*:latest

%.push: $.build
	scripts/push.sh $(REGISTRY)$(GCLOUD_PROJECT)/$* $(TAG)

%.push_latest: %.push
	scripts/push.sh $(REGISTRY)$(GCLOUD_PROJECT)/$* $(TAG)
	scripts/push.sh $(REGISTRY)$(GCLOUD_PROJECT)/$* latest

%.deploy:
	@$(eval DEPLOYED := $(shell scripts/deploy.sh $* $(TAG) $(PORT) $(DEPLOY_COMMAND)))
	@echo Pod is $(DEPLOYED).

%.deploy_latest:
	@$(eval DEPLOYED := $(shell scripts/deploy.sh $* latest $(PORT) $(DEPLOY_COMMAND)))
	@echo Pod is $(DEPLOYED).

%.undeploy:
	@scripts/undeploy.sh $*

all: build push deploy

dep:
	@dep ensure

versions:
	@scripts/buildargs.sh -l

envvars:
	@echo INPUTS=$(INPUTS)
	@echo TARGETS=$(TARGETS)
	@echo SOURCES=$(SOURCES)
	@echo PUSHES=$(PUSHES)
	@echo DEPLOYS=$(DEPLOYS)
	@echo UNDEPLOYS=$(UNDEPLOYS)

debug:
	scripts/debug.sh authz_controller_build manager $(PORT)

deploy_exec_debug:
	@make undeploy
	@DEPLOY_COMMAND=sleep make authz_controller_build.deploy_latest
	@DEBUG_MODE=exec make debug

deploy_attach_debug:
	@make undeploy
	@make authz_controller_build.deploy_latest
	@make debug

$(TARGETS): $(REGISTRY)$(GCLOUD_PROJECT)/%: %.build

build: $(TARGETS)

push: $(PUSHES)

push_latest: $(PUSHES_LATEST)

deploy: $(DEPLOYS)

deploy_latest: $(DEPLOYS_LATEST)

undeploy: $(UNDEPLOYS)

unit-test:
	go test -i ./...
	go test ./...

# Code generators
# https://github.com/kubernetes/community/blob/master/contributors/devel/api_changes.md#generate-code

generated_files: deepcopy clientset lister informer

# also builds vendored version of deepcopy-gen tool
deepcopy:
	@go install ./vendor/k8s.io/code-generator/cmd/deepcopy-gen
	@echo "+ Generating deepcopy funcs for $(API_GROUPS)"
	@deepcopy-gen \
		--input-dirs $(PKG)/apis/$(API_GROUPS) \
		--output-file-base zz_generated.deepcopy

# also builds vendored version of client-gen tool
clientset:
	@go install ./vendor/k8s.io/code-generator/cmd/client-gen
	@echo "+ Generating clientsets for $(API_GROUPS)"
	@client-gen \
		--fake-clientset=false \
		--input $(API_GROUPS) \
		--input-base $(PKG)/apis \
		--clientset-path $(PKG)/client/generated/clientset

# also builds vendored version of lister-gen tool
lister:
	@go install ./vendor/k8s.io/code-generator/cmd/lister-gen
	@echo "+ Generating lister for $(API_GROUPS)"
	@lister-gen \
		--input-dirs $(PKG)/apis/$(API_GROUPS) \
		--output-package $(PKG)/client/generated/lister

# also builds vendored version of informer-gen tool
informer:
	@go install ./vendor/k8s.io/code-generator/cmd/informer-gen
	@echo "+ Generating informer for $(API_GROUPS)"
	@informer-gen \
		--input-dirs $(PKG)/apis/$(API_GROUPS) \
		--output-package $(PKG)/client/generated/informer \
		--versioned-clientset-package $(PKG)/client/generated/clientset/internalclientset \
		--listers-package $(PKG)/client/generated/lister
