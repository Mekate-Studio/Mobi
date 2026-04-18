#!/usr/bin/env sh

set -eu

module_dir="${1:-android-app}"
debug_keystore_target="${module_dir}/debug.keystore"
properties_target="${module_dir}/keystore.properties"

if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool is required to generate local Android debug signing files" >&2
  exit 1
fi

mkdir -p "$module_dir"

if [ ! -f "$debug_keystore_target" ]; then
  keytool -genkeypair \
    -keystore "$debug_keystore_target" \
    -storepass android \
    -keypass android \
    -alias androiddebugkey \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US" \
    -noprompt >/dev/null 2>&1
fi

cat > "$properties_target" <<EOF
storeFile=./$(basename "$debug_keystore_target")
storePassword=android
keyAlias=androiddebugkey
keyPassword=android
EOF
