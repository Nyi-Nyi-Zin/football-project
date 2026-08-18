#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
API_BASE_URL="${API_BASE_URL:-https://football-project-k5y7.onrender.com}"
WS_BASE_URL="${WS_BASE_URL:-wss://football-project-k5y7.onrender.com}"
PAGES_WORKTREE="${PAGES_WORKTREE:-/tmp/football-project-pages}"

cd "$PROJECT_ROOT/frontend"
"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" test
"$FLUTTER_BIN" build web --release \
  -t lib/agent_main.dart \
  --base-href /football-project/agent/ \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=WS_BASE_URL="$WS_BASE_URL"
"$FLUTTER_BIN" build apk --release \
  -t lib/agent_main.dart \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=WS_BASE_URL="$WS_BASE_URL"

cd "$PROJECT_ROOT"
git fetch origin gh-pages
git worktree remove -f "$PAGES_WORKTREE" 2>/dev/null || true
git worktree add "$PAGES_WORKTREE" origin/gh-pages
rm -rf "$PAGES_WORKTREE/agent"
cp -R frontend/build/web "$PAGES_WORKTREE/agent"
touch "$PAGES_WORKTREE/.nojekyll"
git -C "$PAGES_WORKTREE" add agent .nojekyll
if ! git -C "$PAGES_WORKTREE" diff --cached --quiet; then
  git -C "$PAGES_WORKTREE" commit -m "deploy: publish agent app from $(git rev-parse --short HEAD)"
  git -C "$PAGES_WORKTREE" push origin HEAD:gh-pages
fi

echo "Agent Web published to /football-project/agent/"
echo "Agent APK: $PROJECT_ROOT/frontend/build/app/outputs/flutter-apk/app-release.apk"
