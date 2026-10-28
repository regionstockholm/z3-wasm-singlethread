# How this build differs from Z3's official WASM build

Z3's official JavaScript/WASM package, [`z3-solver`](https://www.npmjs.com/package/z3-solver),
is built by [`src/api/js/scripts/build-wasm.ts`](https://github.com/Z3Prover/z3/blob/z3-5.3.2/src/api/js/scripts/build-wasm.ts)
and published by Z3's [`wasm-release.yml`](https://github.com/Z3Prover/z3/blob/z3-5.3.2/.github/workflows/wasm-release.yml)
workflow (emsdk 3.1.73). This repository follows the same recipe at the same tag with the same
Emscripten version and changes only what is needed to remove threads. `scripts/build.sh` refuses to
build if upstream `build-wasm.ts` no longer has the SHA-256 recorded in `versions.env`, or if
upstream's `EM_VERSION` differs from our emsdk pin, so this list cannot silently go stale.

Upstream does not publish a single-threaded artefact: the `z3-5.3.2` GitHub release has native
zips, NuGet packages and Python wheels only, and `z3-solver` always needs pthreads.

## libz3 (the solver itself)

| | upstream `build-wasm.ts` | this repo | why |
|---|---|---|---|
| cmake | `-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DZ3_SINGLE_THREADED=ON` | same **+ `-DZ3_POLLING_TIMER=ON`** | Without threads, `scoped_timer` (used by `:timeout`) would try to start a `std::thread`; `POLLING_TIMER` makes Z3 check the deadline while it works instead. |
| CXXFLAGS | `-pthread -s USE_PTHREADS=1 -s DISABLE_EXCEPTION_CATCHING=0` | `-s DISABLE_EXCEPTION_CATCHING=0` | Threading flags removed: no `SharedArrayBuffer`, so no COOP/COEP headers needed. Optional `Z3W_EXCEPTIONS=wasm` uses `-fwasm-exceptions` instead (see below). |
| LDFLAGS | `-s WASM_BIGINT -s -pthread -s USE_PTHREADS=1` | `-s WASM_BIGINT` | Threading flags removed. |

Note that upstream already builds the solver with `-DZ3_SINGLE_THREADED=ON`; its pthreads exist
only so that the JavaScript API can run `check()` and similar calls on a background thread and
return promises.

## Link step (the JS-facing module)

| | upstream | this repo | why |
|---|---|---|---|
| C wrapper | generated `async-fns.cc` (runs ~20 long calls on `std::thread`) + all ~800 C API functions exported | `src/z3w.cc`: 3 functions (evaluate SMT-LIB2 text in a fresh context, version, free) | The generated wrapper and the TypeScript high-level API (`PThread.terminateAllThreads` in `kill-threads.ts`) depend on threads, so they cannot be reused unchanged. Off-main-thread solving and cancellation come from running the whole module in a plain Worker (`browser.mjs`). |
| threads | `-pthread -s USE_PTHREADS=1 -s PTHREAD_POOL_SIZE=0` | none | the point of this repo |
| memory | `-s TOTAL_MEMORY=2GB` (fixed; required for shared memory) | `INITIAL_MEMORY=64MB`, `ALLOW_MEMORY_GROWTH=1`, `MAXIMUM_MEMORY=4GB` | Without shared memory the heap can grow, so a page does not reserve 2 GB up front. |
| stack | `TOTAL_STACK=20MB` | `STACK_SIZE=20MB` | same value (new name for the same setting) |
| optimisation | no `-O` on the link (libz3 itself is `Release`), `-g2` | `-O3`, no `-g` | smaller/faster glue and wasm-opt pass; names are not needed |
| module format | `MODULARIZE=1`, CommonJS `z3-built.js`, `EXPORT_NAME=initZ3` | `MODULARIZE=1`, `EXPORT_ES6=1`, `z3-built.mjs`, `EXPORT_NAME=createZ3Module` | ES module for direct browser/Deno import |
| runtime methods | `PThread, ccall, FS, UTF8ToString, intArrayFromString, addFunction, removeFunction` | `UTF8ToString, stringToNewUTF8` | only what the wrapper uses |
| exceptions | `-fexceptions -s DISABLE_EXCEPTION_CATCHING=0` | same by default | |

## Optional: native WebAssembly exceptions

`Z3W_EXCEPTIONS=wasm` in `versions.env` replaces upstream's JavaScript-based exception emulation
with `-fwasm-exceptions` (supported by all current browsers, Node ≥ 17, Deno). In a local
measurement this made `z3-built.wasm` 23 % smaller (16.8 MB vs 21.9 MB) and the 225-query
intEHRgrator run ~35 % faster, at the cost of one more deviation from upstream. The default stays
`js` to keep the diff to threading only.
