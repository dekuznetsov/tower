#!/usr/bin/env bash
# Deploys RTDB security rules, seeds the tower node, and merges the allowlist.
# Invoked by Terraform (null_resource.backend_deploy). Requires the Firebase CLI
# authenticated non-interactively (e.g. GOOGLE_APPLICATION_CREDENTIALS pointing
# to a service-account key, or FIREBASE_TOKEN set).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
: "${PROJECT_ID:?PROJECT_ID must be set}"

cd "$ROOT" # firebase.json lives at the repo root

echo "==> Deploying RTDB security rules"
firebase deploy --only database --project "$PROJECT_ID" --non-interactive

echo "==> Seeding tower node (/farms/farm_id_1/towers/tower_1)"
firebase database:set /farms/farm_id_1/towers/tower_1 \
  "$HERE/../generated/tower_seed.json" \
  --project "$PROJECT_ID" --confirm

echo "==> Merging allowlist (/allowlist)"
firebase database:update /allowlist \
  "$HERE/../generated/allowlist.json" \
  --project "$PROJECT_ID" --confirm

echo "==> Backend deploy complete."
