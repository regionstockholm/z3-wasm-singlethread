# Changelog

All notable changes to this project. Versions follow [Semantic Versioning](https://semver.org/);
the Z3 version inside each release is listed separately because it is pinned independently.

## [0.1.0] - unreleased

First release. Z3 **5.3.2** (tag `z3-5.3.2`, commit `b411c90217766c924e6ea3d0b51f452a89fd8fc2`)
compiled to a single-threaded WebAssembly ES module with Emscripten **3.1.73**.

- Runs without threads or `SharedArrayBuffer`, so pages need no COOP/COEP headers (works on GitHub
  Pages), and in Node ≥ 20 and Deno.
- Build follows Z3's own `src/api/js/scripts/build-wasm.ts` at the pinned tag with only the
  threading removed, plus `-DZ3_POLLING_TIMER=ON` so `:timeout` works without a timer thread.
  Every deviation is listed in [BUILD-DIFF.md](BUILD-DIFF.md).
- API: `init()` → `{ version(), evalSmtlib2(text) }` (`index.mjs`), and a Worker-based
  `createZ3Worker()` with `cancel()` (`browser.mjs`). Each evaluation uses a fresh Z3 context.
- Builds are independent of the checkout path (`-ffile-prefix-map`), so a rebuild of the same
  commit with the same toolchain should give the same `z3-built.wasm`.
- CI pins every action by SHA, checks that upstream tags resolve to the pinned commits, runs the
  smoke test on Node and Deno, and publishes SLSA build-provenance attestations; verify with
  `gh attestation verify <file> --repo regionstockholm/z3-wasm-singlethread`.
- Assets: `z3-built.wasm`, `z3-built.mjs`, `index.mjs`/`.d.ts`, `browser.mjs`/`.d.ts`,
  `worker.mjs`, `SHA256SUMS`, `BUILDINFO`, licences, and `z3-wasm-singlethread-v0.1.0.tar.gz`
  with all of them. The SHA-256 of each file is in `SHA256SUMS` and in the release's attestation.
- Not published to npm.
