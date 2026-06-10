#!/usr/bin/env bash
#
# publish-preset.sh <preset-id> <server-dir>
#
# Packages a prebuilt Minecraft server into a whole-server preset:
#   1. Stages the server, stripping regeneratable + secret + builder-specific files
#   2. Uploads it as a GitHub Release asset (handles >100MB; raw URLs can't)
#   3. Points <preset-id>.json at the asset (serverArchive) and pushes the manifest
#
# New servers of this preset are then provisioned automatically by the
# "NetBe Preset Paper" egg, which downloads + extracts the archive over the
# fresh server. Re-run any time you tweak the server — it clobbers the asset.
#
# Usage:  ./publish-preset.sh skyblock /path/to/built/server
#
set -euo pipefail

PRESET_ID="${1:?usage: publish-preset.sh <preset-id> <server-dir>}"
SERVER_DIR="${2:?usage: publish-preset.sh <preset-id> <server-dir>}"

REPO="netbehosting/presets"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TAG="preset-${PRESET_ID}"
ASSET_NAME="server.tar.gz"

[ -d "$SERVER_DIR" ] || { echo "ERROR: server dir not found: $SERVER_DIR" >&2; exit 1; }

STAGE="$(mktemp -d)"
ASSET_DIR="$(mktemp -d)"
TARBALL="${ASSET_DIR}/${ASSET_NAME}"   # basename becomes the release asset name
cleanup() { rm -rf "$STAGE" "$ASSET_DIR"; }
trap cleanup EXIT

echo "==> Staging server (stripping runtime/secret/builder files)..."
rsync -a \
  --exclude 'logs/' --exclude 'cache/' --exclude '.cache/' \
  --exclude 'libraries/' --exclude 'versions/' --exclude '.paper-remapped/' \
  --exclude 'server.jar' --exclude '*.log' --exclude 'session.lock' \
  --exclude '*/playerdata/' --exclude '*/stats/' --exclude '*/advancements/' \
  "$SERVER_DIR"/ "$STAGE"/

# Blank builder/runtime identity files (else the builder gets op on every server!)
for j in ops.json whitelist.json banned-players.json banned-ips.json usercache.json; do
  [ -f "$STAGE/$j" ] && printf '[]\n' > "$STAGE/$j"
done
find "$STAGE" -name 'session.lock' -delete 2>/dev/null || true

# Scrub secrets from server.properties (Pterodactyl rewrites network bits on boot)
if [ -f "$STAGE/server.properties" ]; then
  sed -i \
    -e 's/^management-server-secret=.*/management-server-secret=/' \
    -e 's/^rcon\.password=.*/rcon.password=/' \
    "$STAGE/server.properties"
fi
printf 'eula=true\n' > "$STAGE/eula.txt"

echo "==> Packaging..."
( cd "$STAGE" && tar czf "$TARBALL" . )
echo "    $(du -h "$TARBALL" | cut -f1)  $TARBALL"

echo "==> Uploading to GitHub Release ($TAG)..."
if gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" "${TARBALL}" -R "$REPO" --clobber
else
  gh release create "$TAG" "${TARBALL}" -R "$REPO" \
    --title "Preset: ${PRESET_ID}" \
    --notes "Prebuilt whole-server for the '${PRESET_ID}' preset. Published by publish-preset.sh."
fi
ARCHIVE_URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET_NAME}"

echo "==> Updating manifest ${PRESET_ID}.json -> serverArchive..."
python3 - "$REPO_DIR/${PRESET_ID}.json" "$PRESET_ID" "$ARCHIVE_URL" <<'PY'
import json, os, sys
path, pid, url = sys.argv[1], sys.argv[2], sys.argv[3]
m = json.load(open(path)) if os.path.exists(path) else {"id": pid, "name": pid.replace("-", " ").title()}
m.setdefault("id", pid)
m.setdefault("name", pid.replace("-", " ").title())
m["serverArchive"] = url
# whole-server mode owns the full filesystem; drop hybrid fields if present
for k in ("files", "plugins", "configFiles", "serverProperties"):
    m.pop(k, None)
with open(path, "w") as f:
    json.dump(m, f, indent=2, ensure_ascii=False)
    f.write("\n")
print("    wrote", path)
PY

echo "==> Committing manifest..."
( cd "$REPO_DIR" && git add "${PRESET_ID}.json"
  if git diff --cached --quiet; then
    echo "    manifest already up to date"
  else
    git commit -q -m "Publish whole-server preset: ${PRESET_ID}"
    git push -q origin main
  fi )

echo ""
echo "DONE. '${PRESET_ID}' is live."
echo "  archive: ${ARCHIVE_URL}"
echo "  New servers using preset '${PRESET_ID}' will pull this automatically."
