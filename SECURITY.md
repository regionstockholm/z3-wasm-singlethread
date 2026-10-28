# Security policy

## Reporting a vulnerability

Please report suspected vulnerabilities **privately** through GitHub's
[private vulnerability reporting](https://github.com/regionstockholm/z3-wasm-singlethread/security/advisories/new)
("Security" tab → "Report a vulnerability"). Do not open a public issue for security problems.

We aim to acknowledge reports within 7 days.

## Scope

- **This repository**: the build scripts, the pinned versions (`versions.env`), the CI workflow,
  the small C/JS wrapper and the produced artefacts.
- **Z3 itself**: bugs in the solver should be reported upstream at
  <https://github.com/Z3Prover/z3>. If a Z3 issue makes the published WASM unsafe to use, tell us
  too so we can rebuild from a fixed tag.
- **Emscripten / emsdk**: report upstream at <https://github.com/emscripten-core/emsdk>.

## Supply-chain expectations

- Artefacts are only trustworthy if they come from this repository's GitHub Actions workflow
  and carry a valid build-provenance attestation (see README, "Verifying an artefact").
- Changes to `versions.env` (new Z3 tag / commit, new emsdk version) must be reviewed by a
  maintainer; CI refuses to build if an upstream tag does not resolve to the pinned commit.
