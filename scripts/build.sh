#!/usr/bin/env bash
# Build Z3 to single-threaded WASM by following Z3's own recipe
# (src/api/js/scripts/build-wasm.ts at the pinned tag) with the threading flags removed.
# Every deviation from upstream is listed in BUILD-DIFF.md.
# Requires: scripts/fetch-sources.sh already run; cmake >= 3.16; python3; ninja optional.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source versions.env
ROOT=$PWD
WORK="${WORK:-$ROOT/work}"
OUT="${OUT:-$ROOT/dist}"
JOBS="${JOBS:-$(nproc)}"
EXC="${Z3W_EXCEPTIONS_OVERRIDE:-$Z3W_EXCEPTIONS}"

# Guard: the recipe we mirror must be exactly the one BUILD-DIFF.md was written against,
# and the emsdk pin must equal the version upstream's own wasm release workflow uses.
got=$(sha256sum "$WORK/z3/src/api/js/scripts/build-wasm.ts" | cut -d' ' -f1)
[ "$got" = "$Z3_BUILD_WASM_TS_SHA256" ] || {
  echo "Upstream build-wasm.ts changed ($got); re-check BUILD-DIFF.md and update versions.env" >&2; exit 1; }
up_em=$(sed -n "s/^ *EM_VERSION: *\([0-9.]*\).*/\1/p" "$WORK/z3/.github/workflows/wasm-release.yml" | head -1)
[ "$up_em" = "$EMSDK_VERSION" ] || {
  echo "Upstream wasm-release.yml uses EM_VERSION=$up_em, versions.env pins $EMSDK_VERSION" >&2; exit 1; }

"$WORK/emsdk/emsdk" install "$EMSDK_VERSION" >/dev/null
"$WORK/emsdk/emsdk" activate "$EMSDK_VERSION" >/dev/null
# shellcheck disable=SC1091
source "$WORK/emsdk/emsdk_env.sh" >/dev/null 2>&1

case "$EXC" in
  js)   CC_EXC="-s DISABLE_EXCEPTION_CATCHING=0"; LINK_EXC="-fexceptions -s DISABLE_EXCEPTION_CATCHING=0" ;;
  wasm) CC_EXC="-fwasm-exceptions";               LINK_EXC="-fwasm-exceptions" ;;
  *) echo "Z3W_EXCEPTIONS must be js or wasm" >&2; exit 1 ;;
esac
# Reproducibility: strip the checkout location from __FILE__ strings and debug info, so the
# output does not depend on where the work directory is (CI vs. a local rebuild).
REPRO="-ffile-prefix-map=$WORK=."
CC_EXC="$CC_EXC $REPRO"
GEN=(); command -v ninja >/dev/null && GEN=(-G Ninja)

start=$(date +%s)
# Upstream: CXXFLAGS='-pthread -s USE_PTHREADS=1 -s DISABLE_EXCEPTION_CATCHING=0'
#           LDFLAGS='-s WASM_BIGINT -s -pthread -s USE_PTHREADS=1'
#           emcmake cmake ... -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DZ3_SINGLE_THREADED=ON
CXXFLAGS="$CC_EXC" CFLAGS="$CC_EXC" LDFLAGS="-s WASM_BIGINT" \
  emcmake cmake -S "$WORK/z3" -B "$WORK/build" "${GEN[@]}" \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DZ3_SINGLE_THREADED=ON \
  -DZ3_POLLING_TIMER=ON
cmake --build "$WORK/build" --target libz3 --parallel "$JOBS"
lib_seconds=$(( $(date +%s) - start ))

start=$(date +%s)
mkdir -p "$OUT"
# Upstream links the generated async wrapper + libz3 with -pthread/USE_PTHREADS and the full
# low-level API; we link a 3-function wrapper (src/z3w.cc). See BUILD-DIFF.md.
# shellcheck disable=SC2086
emcc src/z3w.cc "$WORK/build/libz3.a" -I "$WORK/z3/src/api" \
  -O3 -std=c++20 $LINK_EXC $REPRO -s WASM_BIGINT \
  -sMODULARIZE=1 -sEXPORT_ES6=1 -sEXPORT_NAME=createZ3Module \
  -sENVIRONMENT=web,worker,node \
  -sINITIAL_MEMORY=64MB -sALLOW_MEMORY_GROWTH=1 -sMAXIMUM_MEMORY=4GB -sSTACK_SIZE=20MB \
  -sEXPORTED_FUNCTIONS='["_z3w_eval_smtlib2","_z3w_version","_z3w_free","_malloc","_free"]' \
  -sEXPORTED_RUNTIME_METHODS='["UTF8ToString","stringToNewUTF8"]' \
  -o "$OUT/z3-built.mjs"
link_seconds=$(( $(date +%s) - start ))
cp src/index.mjs src/index.d.ts src/worker.mjs src/browser.mjs src/browser.d.ts LICENSE "$OUT/"
cp "$WORK/z3/LICENSE.txt" "$OUT/Z3-LICENSE.txt"

{
  echo "z3_tag=$Z3_TAG"
  echo "z3_commit=$Z3_COMMIT"
  echo "emsdk_version=$EMSDK_VERSION"
  echo "emsdk_commit=$EMSDK_COMMIT"
  echo "emcc=$(emcc --version | head -1)"
  echo "exceptions=$EXC"
  echo "cmake=-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DZ3_SINGLE_THREADED=ON -DZ3_POLLING_TIMER=ON CXXFLAGS=$CC_EXC"
  echo "libz3_build_seconds=$lib_seconds"
  echo "link_seconds=$link_seconds"
  echo "wasm_bytes=$(stat -c %s "$OUT/z3-built.wasm")"
  echo "wasm_gzip9_bytes=$(gzip -9c "$OUT/z3-built.wasm" | wc -c)"
} > "$OUT/BUILDINFO"
( cd "$OUT" && sha256sum -- * | grep -v ' SHA256SUMS$' > SHA256SUMS )
ls -l "$OUT"
cat "$OUT/BUILDINFO"
