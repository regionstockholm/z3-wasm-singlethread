# CI workflow (pending installation)

`build.yml` is the GitHub Actions workflow for this repository. It lives here because the bot
account that created the repository has a token without the `workflow` scope, and GitHub refuses
pushes that create files under `.github/workflows/` from such tokens.

To activate it, a maintainer moves it into place:

```sh
git mv ci/build.yml .github/workflows/build.yml && git commit -m "Activate CI" && git push
```

(or, for the bot account: `gh auth refresh -h github.com -s workflow`, then the same commands).
