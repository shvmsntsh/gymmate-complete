#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/deploy/vercel/output"
ADMIN_DIST_DIR="$ROOT_DIR/gymmate_admin_vite/dist"
MOBILE_DIST_DIR="$ROOT_DIR/gymmate_mobile/build/web"
BACKEND_ORIGIN="${BACKEND_ORIGIN:-https://gymmate-backend.vercel.app}"

echo "Preparing combined Vercel site..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/admin"

echo "Building admin for /admin/..."
(
  cd "$ROOT_DIR/gymmate_admin_vite"
  VITE_PUBLIC_BASE=/admin/ VITE_API_BASE_URL= npm run build
)

echo "Building mobile web app for / ..."
(
  cd "$ROOT_DIR/gymmate_mobile"
  flutter build web --release --dart-define=API_BASE_URL="$BACKEND_ORIGIN"
)

echo "Copying build outputs..."
cp -R "$MOBILE_DIST_DIR"/. "$OUTPUT_DIR"/
cp -R "$ADMIN_DIST_DIR"/. "$OUTPUT_DIR/admin"/

cat > "$OUTPUT_DIR/vercel.json" <<EOF
{
  "rewrites": [
    { "source": "/api/(.*)", "destination": "$BACKEND_ORIGIN/api/\$1" },
    { "source": "/health", "destination": "$BACKEND_ORIGIN/health" },
    { "source": "/admin", "destination": "/admin/index.html" },
    { "source": "/admin/(.*)", "destination": "/admin/index.html" },
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
EOF

echo "Combined site ready at: $OUTPUT_DIR"
