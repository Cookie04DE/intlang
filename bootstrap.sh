#!/usr/bin/env bash
# Compiles all three stages and demonstrates that the output of stage1 and stage2 ilc are the same given the ilc source code
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

compile_ilc () {
  local prev_ilc="$1"
  local out_bin="$2"
  local ilc_source="$3"
  local name="$(basename "$out_bin")"
  local asm="$tmpdir/${name}.s"
  local obj="$tmpdir/${name}.o"
  "$prev_ilc" < "$ilc_source" > "$asm"
  nasm -f elf64 -o "$obj" "$asm"
  gcc -no-pie -z noexecstack -o "$out_bin" "$obj"
}

compile_and_verify_stage () {
  local current_ilc_source="$1"
  local prev_ilc="$2"
  local name="$(basename "${current_ilc_source%.il}")"
  local current_ilc="compilers/$name"
  local current_ilc_verify="$tmpdir/${name}_verify"
  compile_ilc "$prev_ilc" "$current_ilc" "$current_ilc_source"
  compile_ilc "$current_ilc" "$current_ilc_verify" "$current_ilc_source"
  diff <("$current_ilc" < "$current_ilc_source") <("$current_ilc_verify" < "$current_ilc_source")
}

mkdir -p compilers

cargo build --release
cp ./target/release/intlang ./compilers/0

prev_compiler=./compilers/0

while IFS= read -r stage; do
  compile_and_verify_stage "$stage" "$prev_compiler"
  prev_compiler="compilers/$(basename "${stage%.il}")"
done < <(ls ilc_stages/*.il | sort -V)

echo "Done!"
