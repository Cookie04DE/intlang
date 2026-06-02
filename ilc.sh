#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <file> [compiler]"
  exit 1
fi

input="$1"

if [ ! -d compilers ] || [ -z "$(ls compilers/ 2>/dev/null)" ]; then
  echo "Error: no compilers found in compilers/ — have you run the bootstrap script?"
  exit 1
fi
last_compiler="$(ls compilers/ | sort -V | tail -n1)"
compiler="${2:-compilers/$last_compiler}"

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
