#!/usr/bin/env bash
# Build (optional), push Quay, deploy both images, print Route URL.
# Safe to run from any directory.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NS="${NAMESPACE:-tektoncd-unified-dashboard}"
REGISTRY="${QUAY_REGISTRY:-quay.io/rh-ee-apalit}"
BACKEND_IMAGE="${BACKEND_IMAGE:-tektoncd-unified-dashboard-backend}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-tektoncd-unified-dashboard-frontend}"
TAG="${TAG:-latest}"
BUILD="${BUILD:-false}"
PUSH="${PUSH:-false}"

BACKEND_REF="${REGISTRY}/${BACKEND_IMAGE}:${TAG}"
FRONTEND_REF="${REGISTRY}/${FRONTEND_IMAGE}:${TAG}"

echo "Repo:     $ROOT"
echo "Images:   $BACKEND_REF"
echo "          $FRONTEND_REF"
echo "Namespace: $NS"
echo ""

if [[ "$BUILD" == "true" ]]; then
  make -C "$ROOT/deploy" docker-build REGISTRY="$REGISTRY" TAG="$TAG" \
    BACKEND_IMAGE="$BACKEND_IMAGE" FRONTEND_IMAGE="$FRONTEND_IMAGE"
fi

if [[ "$PUSH" == "true" ]]; then
  for ref in "$BACKEND_REF" "$FRONTEND_REF"; do
    if ! docker image inspect "$ref" &>/dev/null; then
      echo "ERROR: image not found: $ref (run with BUILD=true first)" >&2
      exit 1
    fi
  done
  docker push "$BACKEND_REF"
  docker push "$FRONTEND_REF"
fi

"${ROOT}/deploy/scripts/ensure-namespace.sh" "$NS"

if [[ -n "${GITHUB_TOKEN:-}" || -n "${GEMINI_API_KEY:-}" ]]; then
  NAMESPACE="$NS" "${ROOT}/deploy/scripts/apply-app-secrets.sh"
else
  echo "Tip: export GITHUB_TOKEN and GEMINI_API_KEY to update cluster secrets."
fi

OVERLAY="$ROOT/deploy/k8s/overlays/openshift"
cd "$OVERLAY"
kustomize edit set namespace "$NS" 2>/dev/null || true
kustomize edit set image \
  "unified-dashboard-backend=${BACKEND_REF}" \
  "unified-dashboard-frontend=${FRONTEND_REF}"
oc apply -k . -n "$NS"

oc rollout status deployment/unified-dashboard-backend -n "$NS" --timeout=10m || true
oc rollout status deployment/unified-dashboard-frontend -n "$NS" --timeout=10m || true

NAMESPACE="$NS" "$ROOT/deploy/scripts/get-app-url.sh"
