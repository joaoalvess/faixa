#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-$(/usr/bin/xcode-select -p)}"
DERIVED_DATA="$ROOT_DIR/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Release/Faixa.app"
INSTALL_PATH="/Applications/Faixa.app"

cd "$ROOT_DIR"
/opt/homebrew/bin/xcodegen generate --quiet

/usr/bin/xcodebuild \
  -project "$ROOT_DIR/Faixa.xcodeproj" \
  -scheme Faixa \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  -quiet \
  build

/usr/bin/pkill -x Faixa || true
/bin/rm -rf "$INSTALL_PATH"
/bin/cp -R "$APP_PATH" "$INSTALL_PATH"
/usr/bin/open "$INSTALL_PATH"

echo "Faixa instalado em $INSTALL_PATH"
