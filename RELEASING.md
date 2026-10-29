# Releasing

Releases are cut from `main` by pushing a `v*` tag. Only maintainers of
`regionstockholm/z3-wasm-singlethread` can do this.

> Steps 3–4 need the tag trigger and `release` job in `.github/workflows/build.yml`. Until a
> maintainer adds them, the tag push does nothing; see the pull request that added this file for
> the proposed workflow change.

1. **Prepare (pull request).** Set `"version"` in `package.json` to the new version (without
   `v`) and add a `## [x.y.z]` section to `CHANGELOG.md`. Merge to `main` after review; wait for the
   `build` workflow on `main` to pass.
2. **Tag.** On the merged commit:

   ```sh
   git tag -a vX.Y.Z -m "vX.Y.Z" <commit-on-main>
   git push origin vX.Y.Z
   ```

3. **CI.** The tag push runs `.github/workflows/build.yml`: build, Node and Deno smoke tests,
   build-provenance attestation of each file and of `z3-wasm-singlethread-vX.Y.Z.tar.gz`, then a
   **draft** GitHub Release with the files and the `CHANGELOG.md` section as notes. The release job
   refuses tags that are not on `main` or do not match `package.json`.
4. **Check and publish.** Download an asset, run
   `gh attestation verify z3-built.wasm --repo regionstockholm/z3-wasm-singlethread` and
   `sha256sum -c SHA256SUMS`, then publish the draft. Change `## [x.y.z] - unreleased` to the date
   in a follow-up PR.

Upgrading Z3 or Emscripten is a normal pull request that changes `versions.env` (see README,
"Updating Z3"). npm publishing is not set up.
