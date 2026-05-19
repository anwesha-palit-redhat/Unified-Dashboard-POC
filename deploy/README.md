# Deploy Unified Dashboard

## Architecture (2 pods — separate images, one URL)

```
Internet
   │
   ▼
OpenShift Route  (single public URL — only the frontend is exposed)
   │
   ▼
frontend Pod (nginx)  ──proxy /api/*──►  backend Pod (Go API)
   image: .../tektoncd-unified-dashboard-frontend   image: .../tektoncd-unified-dashboard-backend
```

| Workload | Image | Exposed? |
|----------|--------|----------|
| `unified-dashboard-frontend` | Quay `.../tektoncd-unified-dashboard-frontend:tag` | **Yes** — Route points here |
| `unified-dashboard-backend` | Quay `.../tektoncd-unified-dashboard-backend:tag` | **No** — cluster-internal Service only |

The browser only opens the **Route URL**. Nginx serves the UI and forwards `/api` to the backend Service.

### How to find the application URL

After deploy:

```bash
./deploy/scripts/get-app-url.sh
# or:
oc get route unified-dashboard -n tektoncd-unified-dashboard -o jsonpath='https://{.spec.host}{"\n"}'
```

Example: `https://unified-dashboard-tektoncd-unified-dashboard.apps.<cluster-domain>/`

---

## Manual setup (once)

```bash
./deploy/scripts/cluster-login.sh          # oc login + project
export GITHUB_TOKEN=ghp_...                # PAT with public_repo (recommended for org API)
export GEMINI_API_KEY=...                  # Gemini — AI mode complexity analysis
./deploy/scripts/create-github-secret.sh   # optional if CI will manage secrets
```

---

## Automated deploy (GitHub Actions) — includes Quay

Workflow: [`.github/workflows/deploy-openshift.yml`](../.github/workflows/deploy-openshift.yml)

You do **not** need to edit `kustomization.yaml` for Quay when using Actions. The workflow:

1. Logs in to **quay.io**
2. **Builds and pushes** `tektoncd-unified-dashboard-backend` and `tektoncd-unified-dashboard-frontend`
3. Sets image names from `QUAY_REGISTRY` + git sha tag
4. Deploys to OpenShift and applies **GITHUB_TOKEN** + **GEMINI_API_KEY** from Actions secrets
5. Prints the **Route URL** in the job summary

### One-time manual on [quay.io](https://quay.io)

Create two repositories (public or private):

- `<your-org>/tektoncd-unified-dashboard-backend`
- `<your-org>/tektoncd-unified-dashboard-frontend`

Example org: `rh-ee-apalit` → `quay.io/rh-ee-apalit/tektoncd-unified-dashboard-frontend`

If repos are **private**, add an OpenShift pull secret and link it to the `default` service account (or set `imagePullSecrets` on the Deployments).

### GitHub configuration

**Repository variable**

| Name | Example |
|------|---------|
| `QUAY_REGISTRY` | `quay.io/rh-ee-apalit` |

**Secrets**

| Name | Purpose |
|------|---------|
| `QUAY_USERNAME` | Quay user or robot |
| `QUAY_PASSWORD` | Quay password / robot token |
| `OPENSHIFT_SERVER` | `https://api.<cluster>:6443` |
| `OPENSHIFT_TOKEN` | OpenShift login token |
| `GH_PAT` | (optional) PAT for tektoncd API; if unset, uses built-in `GITHUB_TOKEN` |
| `GEMINI_API_KEY` | Gemini API key for AI mode (issue complexity analysis) |

**Run:** Actions → **Deploy to OpenShift** → Run workflow (namespace `tektoncd-unified-dashboard`, optional `quay_registry` override).

---

## Local build + Quay push

Run from the **repository root** (or use the deploy script — it resolves paths automatically):

```bash
cd /path/to/UnifiedDashboard
export QUAY_REGISTRY=quay.io/rh-ee-apalit
export TAG=latest
docker login quay.io
make -C deploy docker-build REGISTRY=$QUAY_REGISTRY TAG=$TAG
# OpenShift needs amd64 (default in Makefile). For local compose on Apple Silicon: DOCKER_PLATFORM= make -C deploy docker-up
docker push $QUAY_REGISTRY/tektoncd-unified-dashboard-backend:$TAG
docker push $QUAY_REGISTRY/tektoncd-unified-dashboard-frontend:$TAG
```

One-shot build, push, and deploy:

```bash
export GITHUB_TOKEN=ghp_...
export GEMINI_API_KEY=...
export TAG=local-test-1
BUILD=true PUSH=true ./deploy/scripts/deploy-openshift.sh
```

---

## Deploy to OpenShift (manual)

```bash
export NS=tektoncd-unified-dashboard
export QUAY_REGISTRY=quay.io/rh-ee-apalit
export TAG=latest

cd deploy/k8s/overlays/openshift
kustomize edit set namespace "$NS"
kustomize edit set image \
  unified-dashboard-backend=$QUAY_REGISTRY/tektoncd-unified-dashboard-backend:$TAG \
  unified-dashboard-frontend=$QUAY_REGISTRY/tektoncd-unified-dashboard-frontend:$TAG
oc apply -k . -n "$NS"

./deploy/scripts/get-app-url.sh
```

---

## Container base images (Red Hat UBI)

| Stage | Image |
|-------|--------|
| Go build | `registry.access.redhat.com/ubi9/go-toolset` (Go 1.25) |
| Go runtime | `registry.access.redhat.com/ubi9/ubi-minimal` |
| Frontend build | `registry.access.redhat.com/ubi9/nodejs-22` (+ Bun for `bun run build`) |
| Frontend runtime | `registry.access.redhat.com/ubi9/nginx-124` |

Pulling from `registry.access.redhat.com` is public for UBI; no subscription required.

## Local Docker Compose

```bash
cp backend/.env.example backend/.env   # GITHUB_TOKEN, GEMINI_API_KEY
DOCKER_PLATFORM= make -C deploy docker-up   # host arch for local dev
open http://localhost:8080
```

---

## Roll out one component only

```bash
oc set image deployment/unified-dashboard-backend \
  backend=$QUAY_REGISTRY/tektoncd-unified-dashboard-backend:$TAG -n tektoncd-unified-dashboard
oc set image deployment/unified-dashboard-frontend \
  frontend=$QUAY_REGISTRY/tektoncd-unified-dashboard-frontend:$TAG -n tektoncd-unified-dashboard
```

## Tekton

See `deploy/tekton/pipeline.yaml` — same two images; deploy task patches each Deployment separately.
