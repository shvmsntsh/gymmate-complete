#!/usr/bin/env bash
set -euo pipefail

# Entry point for Vercel's own build step (git-connected preview deploys).
# Vercel's build container starts clean every time: no Flutter SDK, no
# node_modules. This script installs what assemble_site.sh assumes is
# already present locally, then delegates to it so both paths (local
# manual deploy, and CI-triggered preview builds) produce an identical
# combined artifact.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.7}"
FLUTTER_DIR="$ROOT_DIR/.flutter-sdk"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "Installing Flutter SDK $FLUTTER_VERSION..."
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o /tmp/flutter.tar.xz
  rm -rf "$FLUTTER_DIR"
  mkdir -p "$FLUTTER_DIR"
  tar -xf /tmp/flutter.tar.xz -C "$FLUTTER_DIR" --strip-components=1
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
# Vercel's build runs as root; git refuses to touch a directory it
# doesn't own unless explicitly told it's safe, which breaks Flutter's
# internal `git` calls for version/revision info.
git config --global --add safe.directory '*'
flutter config --no-analytics --no-cli-animations
flutter --version

echo "Installing admin frontend dependencies..."
(cd "$ROOT_DIR/gymmate_admin_vite" && npm ci)

bash "$ROOT_DIR/deploy/vercel/assemble_site.sh"
