# z3-wasm-singlethread

[Z3](https://github.com/Z3Prover/z3) (Microsoft Research, MIT) compiled to a **single-threaded**
WebAssembly ES module, from a **pinned upstream release tag**, in public CI with
**build-provenance attestations** and SHA-256 checksums.

Why: the official [`z3-solver`](https://www.npmjs.com/package/z3-solver) npm package is built with
Emscripten pthreads, which need `SharedArrayBuffer`, which browsers only expose on
cross-origin-isolated pages (`Cross-Origin-Opener-Policy` + `Cross-Origin-Embedder-Policy`
headers). Static hosts such as GitHub Pages cannot set those headers. This build uses no threads
and no shared memory, so it runs in any page or plain Web Worker, in Node and in Deno, with no
special headers and no service-worker workaround.

Built for formal checks of clinical decision rules in
[intEHRgrator](https://github.com/regionstockholm/intehrgrator), but usable by anyone.

[![build](https://github.com/regionstockholm/z3-wasm-singlethread/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/regionstockholm/z3-wasm-singlethread/actions/workflows/build.yml)

> Status: first release **v0.1.0** in preparation (see [CHANGELOG.md](CHANGELOG.md) and
> [RELEASING.md](RELEASING.md)). Not published to npm. Until the release exists, attested
> artefacts are available from the CI runs on `main` (Actions → *build* → artifact
> `z3-wasm-singlethread`), e.g. run
> [40667619572](https://github.com/regionstockholm/z3-wasm-singlethread/actions/runs/40667619572)
> (`z3-built.wasm` SHA-256 `b66e26677b74bc82536196968f03202f34e3c7158def2c7bee679c53466f566a`,
> built before the reproducibility fix below).

## What is built, from what

| Input | Pin | Where |
|---|---|---|
| Z3 source | tag `z3-5.3.2` = commit `b411c90217766c924e6ea3d0b51f452a89fd8fc2` | `versions.env` |
| Emscripten SDK | `3.1.73` = emsdk commit `6abe5123c34a7751a2d5b679e856b2591ba04145` (the version Z3's own wasm CI uses) | `versions.env` |
| GitHub Actions | every action pinned by full commit SHA; Dependabot proposes updates | `.github/workflows/build.yml` |

`scripts/fetch-sources.sh` asks the upstream repositories what the tags point at and **fails if
the tag does not resolve to the pinned commit** (catching a moved tag), then fetches by commit SHA
and checks `HEAD`.

`scripts/build.sh` follows **Z3's own WASM recipe**
([`src/api/js/scripts/build-wasm.ts`](https://github.com/Z3Prover/z3/blob/z3-5.3.2/src/api/js/scripts/build-wasm.ts),
used by Z3's `wasm-release.yml` to publish `z3-solver`) at the pinned tag, with the same emsdk, and
removes only the threading. The full, line-by-line difference is in [BUILD-DIFF.md](BUILD-DIFF.md);
in short:

- libz3: upstream's cmake line unchanged (it already has `-DZ3_SINGLE_THREADED=ON`) plus
  `-DZ3_POLLING_TIMER=ON`, so timeouts work by polling instead of a timer thread;
  `-pthread -s USE_PTHREADS=1` dropped from CXXFLAGS/LDFLAGS; exception handling as upstream
  (`-s DISABLE_EXCEPTION_CATCHING=0`);
- link: instead of upstream's thread-based async wrapper and full C API, a ~40-line wrapper
  (`src/z3w.cc`) with three functions: evaluate SMT-LIB2 text in a fresh context, version, free;
  growable memory instead of upstream's fixed 2 GB (only shared memory needs a fixed size).

The build stops if upstream's `build-wasm.ts` changes (its SHA-256 is pinned in `versions.env`) or
if upstream's `EM_VERSION` differs from our emsdk pin, so BUILD-DIFF.md has to be re-checked on
every Z3 upgrade.

### Why not just use upstream's artefact?

- `z3-solver` (npm) is Z3's official build, published from Z3's public `wasm-release.yml` with an
  npm token. It has no npm provenance attestation, but the published tarball's shasum appears in
  that workflow's public log (for 5.3.2: run 40199605963 on commit `b411c902…`, shasum
  `5bcd8b33…` = the registry's). It always needs pthreads, i.e. `SharedArrayBuffer` and COOP/COEP.
- Z3's GitHub releases contain no WASM artefact (native zips, NuGet, Python wheels only).

Output (`dist/`): `z3-built.wasm`, `z3-built.mjs` (Emscripten glue), `index.mjs`/`index.d.ts`
(direct API), `browser.mjs`/`browser.d.ts` + `worker.mjs` (Worker API with cancel), `BUILDINFO`,
`SHA256SUMS`, `LICENSE`, `Z3-LICENSE.txt`.

## Usage

Browser (recommended: solving runs in a Worker; cancel = terminate the worker):

```js
import { createZ3Worker } from "./dist/browser.mjs";

const z3 = await createZ3Worker(); // fetches + compiles z3-built.wasm once
console.log(z3.version());         // "5.3.2.0"
const out = await z3.evalSmtlib2(`
  (set-option :timeout 2000)
  (declare-fun sbp () Real)
  (assert (not (or (< sbp 90.0) (and (>= sbp 90.0) (<= sbp 139.0)) (>= sbp 140.0))))
  (check-sat) (get-value (sbp))`);
// "sat\n((sbp (/ 279.0 2.0)))"  -> a gap between 139 and 140
// z3.cancel() aborts a long run and starts a fresh worker.
```

Node / Deno (in-thread):

```js
import { init } from "./dist/index.mjs";
const z3 = await init();
z3.evalSmtlib2("(declare-const x Int)(assert (> x 2))(check-sat)(get-model)");
```

Load it lazily (dynamic `import()`) only when the user asks for a check; the WASM is several MB.

## Measured (local build on the maintainers' Linux box, not CI; 2026-10-28)

| exception model | `z3-built.wasm` | gzip -9 | init (Node 20) | 225 real intEHRgrator queries, fresh context each |
|---|---|---|---|---|
| `js` (upstream's, default) | 21.9 MB | 6.1 MB | ~85 ms | 0.53–0.74 s, 0 verdict mismatches |
| `wasm` (`Z3W_EXCEPTIONS=wasm`) | 16.8 MB | 5.4 MB | ~65 ms | 0.33–0.52 s, 0 verdict mismatches |

For comparison, upstream `z3-solver` 5.3.2's threaded wasm is 35.4 MB (8.1 MB gzipped).
Headless Chromium 1161, served by a plain static server **without** COOP/COEP
(`crossOriginIsolated=false`, no `SharedArrayBuffer`), `test/browser/index.html`: module load and
worker start 134 ms, gap query 82 ms (`sat`, `sbp = 279/2`), `:timeout 400` → `unknown`,
`cancel()` of a running query → rejected and fresh worker ready in 22 ms.

## Verifying an artefact

1. **Provenance** (who built it, from which commit of this repo, with which workflow):

   ```sh
   gh attestation verify z3-built.wasm --repo regionstockholm/z3-wasm-singlethread
   ```

   The attestation is a signed SLSA provenance statement (Sigstore) generated by
   `actions/attest-build-provenance` in the `attest` job. It names this repository, the workflow
   file and the commit; from that commit, `versions.env` gives the exact Z3 and emsdk commits.

2. **Checksums**: `sha256sum -c SHA256SUMS` inside the downloaded artifact.

3. **Rebuild yourself** (Linux with git, cmake ≥ 3.16, python3; ninja optional):

   ```sh
   scripts/fetch-sources.sh && scripts/build.sh && node test/smoke.mjs dist
   ```

   `scripts/build.sh` maps the work directory to `.` (`-ffile-prefix-map`), so the output does
   not depend on where the repository is checked out. Two local builds in different directories
   gave the same `z3-built.wasm` (SHA-256 `228258f7523f47b9d50486736a98f3902b7851478056f646a1602b6341453f84`,
   21,895,178 bytes). A CI build of the same commit is expected to match; it uses the same pinned
   toolchain, but other host differences have not been ruled out, so compare with the attested
   `SHA256SUMS`.

### Remaining trust points

- The emsdk installer downloads prebuilt LLVM/Binaryen/Emscripten binaries for the pinned version
  from Google's storage; emsdk's manifest pins the version but this repo does not separately hash
  those toolchain archives.
- GitHub-hosted runners and the pinned GitHub Actions themselves.

## Tests

`test/smoke.mjs` runs unchanged on Node and Deno, in CI on every push and pull request:
version string contains the pinned tag and the pinned commit (Z3 embeds its git hash), integer sat + model, real unsat, the intEHRgrator
blood-pressure gap query (needs a non-integer counterexample), strings, a `:timeout` time box
returning `unknown`, and an SMT-LIB syntax error returned as text.

## Updating Z3

1. Pick a new upstream release tag; resolve its commit (`git ls-remote https://github.com/Z3Prover/z3 refs/tags/<tag>`).
2. Update `Z3_TAG` and `Z3_COMMIT` (and, if Z3's wasm CI changed it, the emsdk pin) in `versions.env` in a pull request.
3. CI builds and smoke-tests the PR; after merge, the `main` build is attested.
4. Cut a release as described in [RELEASING.md](RELEASING.md).

## Releases

GitHub Releases are created from `v*` tags on `main` (see [RELEASING.md](RELEASING.md)); each
release carries the attested files, `SHA256SUMS`, and a deterministic tarball of `dist/`.
Release notes come from [CHANGELOG.md](CHANGELOG.md).

## License

MIT for this repository's scripts, wrapper and tests. The artefacts contain Z3,
Copyright (c) Microsoft Corporation, MIT License (`Z3-LICENSE.txt`), and Emscripten-generated glue
(MIT / University of Illinois/NCSA). This project is not affiliated with Microsoft or the Z3 project.
