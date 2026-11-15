#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
base="$(cat VERSION)"
if git rev-parse --git-dir >/dev/null 2>&1; then
	if git describe --exact-match --tags --match "v$base" HEAD >/dev/null 2>&1; then
		echo "$base"
		exit 0
	fi
	count="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
	sha="$(git rev-parse --short=7 HEAD 2>/dev/null || echo unknown)"
	echo "${base}.r${count}.g${sha}"
else
	echo "$base"
fi
