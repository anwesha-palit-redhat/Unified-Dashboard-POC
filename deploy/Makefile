# Makefile lives in deploy/; repo root is one level up.
REPO_ROOT := $(abspath ..)

REGISTRY ?= quay.io/rh-ee-apalit
BACKEND_IMAGE ?= tektoncd-unified-dashboard-backend
FRONTEND_IMAGE ?= tektoncd-unified-dashboard-frontend
TAG ?= latest
# OpenShift clusters are usually amd64; set empty to build for host arch (local compose).
DOCKER_PLATFORM ?= linux/amd64
NAMESPACE ?= unified-dashboard

.PHONY: docker-build docker-up docker-down k8s-apply k8s-route tekton-install tekton-run

docker-build:
	docker build $(if $(DOCKER_PLATFORM),--platform $(DOCKER_PLATFORM),) \
		-f $(REPO_ROOT)/deploy/docker/Dockerfile.backend \
		-t $(REGISTRY)/$(BACKEND_IMAGE):$(TAG) $(REPO_ROOT)
	docker build $(if $(DOCKER_PLATFORM),--platform $(DOCKER_PLATFORM),) \
		-f $(REPO_ROOT)/deploy/docker/Dockerfile.frontend \
		-t $(REGISTRY)/$(FRONTEND_IMAGE):$(TAG) $(REPO_ROOT)

docker-up:
	docker compose -f $(REPO_ROOT)/deploy/docker-compose.yml --project-directory $(REPO_ROOT) up --build -d

docker-down:
	docker compose -f $(REPO_ROOT)/deploy/docker-compose.yml --project-directory $(REPO_ROOT) down

k8s-apply:
	oc apply -k $(REPO_ROOT)/deploy/k8s/overlays/openshift/

k8s-url:
	@$(REPO_ROOT)/deploy/scripts/get-app-url.sh

k8s-route:
	kubectl apply -f $(REPO_ROOT)/deploy/k8s/base/route-openshift.yaml -n $(NAMESPACE)

k8s-ingress:
	kubectl apply -f $(REPO_ROOT)/deploy/k8s/ingress.yaml -n $(NAMESPACE)

tekton-install:
	kubectl apply -f $(REPO_ROOT)/deploy/tekton/task-git-clone.yaml -n $(NAMESPACE)
	kubectl apply -f $(REPO_ROOT)/deploy/tekton/task-build-image.yaml -n $(NAMESPACE)
	kubectl apply -f $(REPO_ROOT)/deploy/tekton/pipeline.yaml -n $(NAMESPACE)

tekton-run:
	kubectl create -f $(REPO_ROOT)/deploy/tekton/pipelinerun.yaml -n $(NAMESPACE)
