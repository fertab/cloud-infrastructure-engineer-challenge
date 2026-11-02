#!/usr/bin/env bash
# Builds a Lambda zip. Only the final JSON line goes to stdout: Terraform reads it.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

name="${1:?lambda name required}"
root="$(cd "$(dirname "$0")/.." && pwd)"
dest="$root/build/$name"
zip_path="$root/build/$name.zip"

rm -rf "$dest"
mkdir -p "$dest" "$root/build"

python3 -m pip install \
  --quiet \
  --disable-pip-version-check \
  --requirement "$root/lambda/requirements.txt" \
  --target "$dest" \
  >&2

cp "$root/lambda/common/"*.py "$dest/"
cp "$root/lambda/$name/handler.py" "$dest/handler.py"
curl -fsSL "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem" -o "$dest/global-bundle.pem"
find "$dest" -type d -name '__pycache__' -prune -exec rm -rf {} +
find "$dest" -name '*.pyc' -delete
find "$dest" -name RECORD -print0 | while IFS= read -r -d '' record; do
  grep -v '\.pyc' "$record" > "${record}.tmp" || true
  mv "${record}.tmp" "$record"
done

python3 - "$dest" "$zip_path" <<'PY'
import hashlib, os, sys, zipfile
dest, zip_path = sys.argv[1:]
files = []
for root, dirs, names in os.walk(dest):
    dirs.sort()
    for name in sorted(names):
        files.append(os.path.join(root, name))
with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for path in files:
        info = zipfile.ZipInfo(os.path.relpath(path, dest))
        info.date_time = (2020, 1, 1, 0, 0, 0)
        info.external_attr = 0o644 << 16
        with open(path, "rb") as handle:
            archive.writestr(info, handle.read())
digest = hashlib.sha256(open(zip_path, "rb").read()).digest()
import base64
print(__import__("json").dumps({"path": zip_path, "hash": base64.b64encode(digest).decode()}))
PY
