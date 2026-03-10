#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <file> [compiler]"
  exit 1
fi

input="$1"
compiler="${2:-./ilc_stage2}"

dir="$(cd "$(dirname "$input")" && pwd)"
base="$(basename "$input")"
name="${base%.*}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

asm="$tmpdir/$name.s"
obj="$tmpdir/$name.o"
bin="$dir/$name"

"$compiler" < "$input" > "$asm"

nasm -f elf64 -o "$obj" "$asm"

gcc -no-pie -z noexecstack -o "$bin" "$obj"
