#!/bin/zsh
# Compila Vigilia en Release y la instala en /Applications.
set -euo pipefail

cd "${0:A:h}/.."

DERIVED=build/DerivedData
APP="$DERIVED/Build/Products/Release/Vigilia.app"
DEST=/Applications/Vigilia.app

echo "→ Compilando en Release…"
xcodebuild -project Vigilia.xcodeproj -scheme Vigilia -configuration Release -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED" -quiet build

echo "→ Cerrando Vigilia si está abierta…"
# Cualquier copia (instalada o de desarrollo): dos a la vez se pelearían por el bot.
pkill -f "Vigilia.app/Contents/MacOS/Vigilia" || true
sleep 1

echo "→ Instalando en $DEST…"
rm -rf "$DEST"
ditto "$APP" "$DEST"

echo "→ Abriendo Vigilia…"
open "$DEST"

echo "✓ Vigilia instalada en $DEST"
