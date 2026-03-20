#!/usr/bin/env sh

set -eu

MODULE_FILE="${1:-android-app/module.yaml}"
VERSION_CODE="${VERSION_CODE:-}"
VERSION_NAME="${VERSION_NAME:-}"

if [ -z "$VERSION_CODE" ] || [ -z "$VERSION_NAME" ]; then
  echo "VERSION_CODE and VERSION_NAME must be set" >&2
  exit 1
fi

python3 - "$MODULE_FILE" "$VERSION_CODE" "$VERSION_NAME" <<'PY'
from pathlib import Path
import re
import sys

module_file = Path(sys.argv[1])
version_code = sys.argv[2]
version_name = sys.argv[3]

text = module_file.read_text()
text, code_count = re.subn(r'(^\s*versionCode:\s*).+$', rf'\g<1>{version_code}', text, flags=re.MULTILINE)
text, name_count = re.subn(r'(^\s*versionName:\s*).+$', rf'\g<1>"{version_name}"', text, flags=re.MULTILINE)

if code_count != 1 or name_count != 1:
    raise SystemExit("Could not update versionCode/versionName in module file")

module_file.write_text(text)
PY
