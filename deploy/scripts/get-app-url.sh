#!/usr/bin/env bash
# Print the public URL for the dashboard Route.
set -euo pipefail

NAMESPACE="${NAMESPACE:-tektoncd-unified-dashboard}"
ROUTE_NAME="${ROUTE_NAME:-unified-dashboard}"

if ! oc get route "${ROUTE_NAME}" -n "${NAMESPACE}" &>/dev/null; then
  echo "No route ${ROUTE_NAME} in ${NAMESPACE}. Apply deploy/k8s/route-openshift.yaml first."
  exit 1
fi

HOST="$(oc get route "${ROUTE_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.host}')"
echo ""
echo "Dashboard URL:  https://${HOST}/"
echo "Health check:   https://${HOST}/api/health"
echo ""
oc get route "${ROUTE_NAME}" -n "${NAMESPACE}"
