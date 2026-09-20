# Contributing to GoldenCI

Thanks for considering a contribution.

## Getting started

1. Fork the repo and clone your fork.
2. Try the composite action against one of the `examples/*` projects to confirm your baseline works:
   ```yaml
   uses: ./
   with:
     working-directory: examples/go-example
   ```
3. Make your change. Keep `action.yml` and the reusable workflow (`.github/workflows/golden-ci.yml`) in sync — they share the same steps.

## Pull requests

- Pin any new third-party action by commit SHA, with the version as a trailing comment (see existing steps for the pattern).
- Update `README.md` if you change inputs, outputs, or behavior.
- The `selfcheck` workflow runs GoldenCI against the three example projects on every PR — make sure it's green before requesting review.
- Keep changes scoped; unrelated formatting or reordering makes review harder.

## Reporting bugs / requesting features

Use the issue templates under `.github/ISSUE_TEMPLATE/`.

## Releasing (maintainers)

Push a tag matching `v<major>.<minor>.<patch>` (e.g. `v1.4.0`). The `release` workflow creates the GitHub Release and moves the major tag (e.g. `v1`) to match. See the comment at the top of `.github/workflows/release.yml` for the one manual step required on a new major version.
