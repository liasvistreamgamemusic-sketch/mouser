#!/bin/bash
# リリース用パッケージ (dmg + zip) を作る。使い方: ./package.sh <バージョン>
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?使い方: ./package.sh <バージョン>}"

./build.sh "$VERSION"

# zip (コマンドラインでの取得・展開向け)
ditto -c -k --keepParent Mouser.app "Mouser-${VERSION}.zip"

# dmg (Applications へドラッグするインストーラ形式)
DMG_ROOT="build/dmg-root"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R Mouser.app "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname "Mouser" -srcfolder "$DMG_ROOT" -ov -quiet -format UDZO "Mouser-${VERSION}.dmg"

echo "packaged: Mouser-${VERSION}.dmg, Mouser-${VERSION}.zip"
