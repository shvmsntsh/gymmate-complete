#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEAM_SCOPE="${TEAM_SCOPE:-shvmsntshs-projects}"
VERCEL_BIN="${VERCEL_BIN:-vercel}"
WEB_PROJECT_LINK="$ROOT_DIR/.vercel/project.json"
BACKEND_PROJECT_LINK="$ROOT_DIR/gymmate_backend/.vercel/project.json"
WEB_OUTPUT_DIR="$ROOT_DIR/deploy/vercel/output"
TEMP_WEB_DIR="${TMPDIR:-/tmp}/gymmate-prod-output"

if ! command -v "$VERCEL_BIN" >/dev/null 2>&1; then
  if command -v npx >/dev/null 2>&1; then
    VERCEL_BIN="npx --yes vercel@latest"
  else
    echo "Vercel CLI is required. Install it or set VERCEL_BIN." >&2
    exit 1
  fi
fi

if [ ! -f "$WEB_PROJECT_LINK" ]; then
  echo "Missing root .vercel/project.json for gymmate_mvp." >&2
  exit 1
fi

if [ ! -f "$BACKEND_PROJECT_LINK" ]; then
  echo "Missing gymmate_backend/.vercel/project.json for gymmate-backend." >&2
  exit 1
fi

echo "Deploying backend production..."
(
  cd "$ROOT_DIR/gymmate_backend"
  $VERCEL_BIN deploy --prod --yes --scope "$TEAM_SCOPE"
)

echo "Building combined web production artifact..."
(
  cd "$ROOT_DIR"
  PATH="$ROOT_DIR/../toolchains/node/bin:$PATH" bash deploy/vercel/assemble_site.sh
)

echo "Preparing linked web deploy directory..."
rm -rf "$TEMP_WEB_DIR"
mkdir -p "$TEMP_WEB_DIR/.vercel"
tar -C "$WEB_OUTPUT_DIR" -cf - . | tar -C "$TEMP_WEB_DIR" -xf -
cp "$WEB_PROJECT_LINK" "$TEMP_WEB_DIR/.vercel/project.json"

echo "Deploying gymmatemvp production..."
(
  cd "$TEMP_WEB_DIR"
  $VERCEL_BIN deploy --prod --yes --scope "$TEAM_SCOPE"
)

echo "Production deploy complete:"
echo "- Web: https://gymmatemvp.vercel.app"
echo "- Admin: https://gymmatemvp.vercel.app/admin"
echo "- Backend: https://gymmate-backend.vercel.app"
