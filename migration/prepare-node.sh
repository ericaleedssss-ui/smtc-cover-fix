set -euo pipefail
distribution="node-v${NODE_VERSION}-${NODE_PLATFORM}"
extension=tar.gz
[[ "$RUNNER_OS" == Windows ]] && extension=zip
archive="${distribution}.${extension}"
cd "$RUNNER_TEMP"
curl --fail --location --retry 3 "https://nodejs.org/dist/v${NODE_VERSION}/${archive}" -o "$archive"
curl --fail --location --retry 3 "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" -o SHASUMS256.txt
python - "$archive" <<'PY'
import hashlib, pathlib, sys
archive = pathlib.Path(sys.argv[1])
checksums = dict(line.split()[::-1] for line in pathlib.Path('SHASUMS256.txt').read_text().splitlines())
assert hashlib.sha256(archive.read_bytes()).hexdigest() == checksums[archive.name], 'Node checksum mismatch'
PY
if [[ "$RUNNER_OS" == Windows ]]; then
  python -m zipfile -e "$archive" .
  echo "RHINE_NODE_BINARY=$(cygpath -w "$RUNNER_TEMP/$distribution/node.exe")" >> "$GITHUB_ENV"
  echo "RHINE_NODE_LICENSE=$(cygpath -w "$RUNNER_TEMP/$distribution/LICENSE")" >> "$GITHUB_ENV"
else
  tar -xzf "$archive"
  echo "RHINE_NODE_BINARY=$RUNNER_TEMP/$distribution/bin/node" >> "$GITHUB_ENV"
  echo "RHINE_NODE_LICENSE=$RUNNER_TEMP/$distribution/LICENSE" >> "$GITHUB_ENV"
fi
