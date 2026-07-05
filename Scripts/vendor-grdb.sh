#!/bin/bash
# Reproducibly vendors the GRDB database library (approved dependency,
# CLAUDE.md §17) into ThirdParty/GRDB, configured for the SQLCipher variant
# per GRDB's own documented "GRDB+SQLCipher" SPM recipe (README.md
# "Encryption" section): SPM can't parametrize a remote package's manifest,
# so the SQLCipher build of GRDB is only reachable by vendoring source and
# writing a local Package.swift with the relevant flags/dependency already
# turned on. This script re-fetches the pinned upstream revision so a
# reviewer/agent can diff it against what's committed - it does not build
# anything (GRDB is pure Swift + a tiny C shim; ThirdParty/GRDB/Package.swift
# is hand-written, not generated, and is left untouched by this script).
#
# Usage: Scripts/vendor-grdb.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/ThirdParty/GRDB"

PINNED_TAG="v7.11.1"
PINNED_COMMIT="b83108d10f42680d78f23fe4d4d80fc88dab3212"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "== Cloning groue/GRDB.swift @ $PINNED_TAG =="
git clone --quiet --depth 1 --branch "$PINNED_TAG" https://github.com/groue/GRDB.swift.git "$tmp/GRDB.swift"

actual_commit="$(git -C "$tmp/GRDB.swift" rev-parse HEAD)"
if [ "$actual_commit" != "$PINNED_COMMIT" ]; then
    echo "ERROR: $PINNED_TAG resolved to $actual_commit, expected $PINNED_COMMIT." >&2
    echo "       The tag was moved/re-pushed upstream - do not vendor blindly;" >&2
    echo "       treat this like any other supply-chain integrity failure." >&2
    exit 1
fi

echo "== Copying vendored subset (GRDB/ source + GRDBSQLCipher shim + LICENSE) =="
rm -rf "$DEST/GRDB" "$DEST/Sources"
mkdir -p "$DEST"
cp -R "$tmp/GRDB.swift/GRDB" "$DEST/GRDB"
mkdir -p "$DEST/Sources"
cp -R "$tmp/GRDB.swift/Sources/GRDBSQLCipher" "$DEST/Sources/GRDBSQLCipher"
cp "$tmp/GRDB.swift/LICENSE" "$DEST/LICENSE"

echo "== Done. Pinned commit: $PINNED_COMMIT =="
echo "   ThirdParty/GRDB/Package.swift is hand-written and NOT touched by this script."
echo "   Re-run and 'git diff' to confirm no drift from the pinned revision."
