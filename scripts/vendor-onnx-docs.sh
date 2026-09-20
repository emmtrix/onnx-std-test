#!/usr/bin/env bash
# Refresh the vendored copy of the upstream ONNX documentation.
#
#   scripts/vendor-onnx-docs.sh [ref]
#
# `ref` is a git tag, branch or commit of onnx/onnx; it defaults to the release
# recorded in upstream/onnx/PROVENANCE.md. A release tag is preferred over a
# branch: this copy exists to fix the baseline the standard is drafted against,
# and a branch moves under it.
#
# The script rewrites upstream/onnx/ in place and regenerates the provenance
# header, so the resulting diff shows exactly what changed upstream.

set -euo pipefail

REPO="https://github.com/onnx/onnx.git"
REF="${1:-v1.23.0}"
DEST="upstream/onnx"

command -v git >/dev/null || { echo "git is required" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Fail early and usefully on a ref that does not exist. The version in
# upstream's VERSION_NUMBER names the *next* release and is not a tag, which is
# an easy mistake to make.
if ! git ls-remote --exit-code --tags --heads "$REPO" "$REF" >/dev/null 2>&1; then
  echo "error: '$REF' is neither a tag nor a branch of $REPO" >&2
  echo "available release tags:" >&2
  git ls-remote --tags --refs "$REPO" 2>/dev/null \
    | awk -F'refs/tags/' '{print "  " $2}' | sort -V | tail -8 >&2
  exit 1
fi

echo "Cloning $REPO at $REF ..."
git clone --depth 1 --branch "$REF" "$REPO" "$tmp/onnx" --quiet

commit="$(git -C "$tmp/onnx" rev-parse HEAD)"
date="$(git -C "$tmp/onnx" log -1 --format=%cI)"
version="$(cat "$tmp/onnx/VERSION_NUMBER")"

rm -rf "$DEST/docs" "$DEST/proto"
mkdir -p "$DEST/docs" "$DEST/proto"

# Specification documents. `docs/docsgen/` is excluded: it is the Sphinx
# website generator (conf.py, tutorials, images, minified JavaScript), not
# specification text.
( cd "$tmp/onnx/docs" && tar -c --exclude=docsgen . ) | ( cd "$DEST/docs" && tar -x )

# The Protocol Buffers schema. This is the actual normative serialization
# definition that Clause 9 of the standard restates, so it is vendored with
# the prose.
cp "$tmp/onnx/onnx"/*.proto "$DEST/proto/"

cp "$tmp/onnx/LICENSE" "$DEST/LICENSE"
cp "$tmp/onnx/VERSION_NUMBER" "$DEST/VERSION_NUMBER"

cat > "$DEST/SOURCE.txt" <<EOF
repository: $REPO
ref:        $REF
commit:     $commit
committed:  $date
version:    $version
retrieved:  $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo
echo "Vendored ONNX $version ($REF, $commit) into $DEST"
echo "Update the narrative in $DEST/PROVENANCE.md if the ref changed."
