#!/bin/bash

VERSION=$(grep "## Version" WowPoker.toc | sed 's/## Version: //')
ADDON_NAME="WowPoker"
ZIPNAME="${ADDON_NAME}-${VERSION}.zip"

echo "Packaging ${ADDON_NAME} v${VERSION}..."

rm -f "$ZIPNAME"

mkdir -p build/$ADDON_NAME

cp WowPoker.toc Locale.lua Protocol.lua Deck.lua GameLogic.lua \
   CardTextures.lua UI.lua Menu.lua Core.lua README.md \
   build/$ADDON_NAME/

cd build
zip -r "../$ZIPNAME" $ADDON_NAME
cd ..
rm -rf build

echo "Created $ZIPNAME"
echo ""
echo "Upload to:"
echo "  - CurseForge: https://www.curseforge.com/wow/addons"
echo "  - Wago: https://addons.wago.io"
echo "  - WoWInterface: https://www.wowinterface.com"
