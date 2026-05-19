#!/usr/bin/env bash
# Manual: create backend secrets on the cluster (one-time per namespace).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "Set GITHUB_TOKEN (PAT with public_repo read) or paste when prompted."
  read -r -s -p "GITHUB_TOKEN: " GITHUB_TOKEN
  echo
  export GITHUB_TOKEN
fi

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "Set GEMINI_API_KEY for AI mode, or press Enter to skip."
  read -r -s -p "GEMINI_API_KEY (optional): " GEMINI_API_KEY
  echo
  [[ -n "$GEMINI_API_KEY" ]] && export GEMINI_API_KEY
fi

"${ROOT}/deploy/scripts/apply-app-secrets.sh"
