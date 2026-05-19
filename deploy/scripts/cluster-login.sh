#!/usr/bin/env bash
# Manual: log in to OpenShift before running oc/kubectl locally.
set -euo pipefail

echo "Log in with your cluster API URL and token (from the OpenShift web console → Copy login command)."
echo "Example:"
echo '  oc login --token=<token> --server=https://api.<cluster>:6443'
echo ""
echo "Then pick your namespace:"
echo "  oc project tektoncd-unified-dashboard"
echo ""
read -r -p "Press Enter after oc login succeeds, or Ctrl-C to abort..."
oc whoami
oc project -q
