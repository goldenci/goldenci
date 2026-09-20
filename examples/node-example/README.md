# node-example

A minimal CommonJS module used to prove GoldenCI's Node path end to end:
detection via `package.json`, flat-config ESLint, Jest with a
`json-summary` coverage report, and `npm run build --if-present`.

No CLI entry point on purpose, so coverage is 100% and comfortably clears the
70% gate. `package-lock.json` is committed because both `npm ci` and
`actions/setup-node`'s npm cache require it.

Run it locally:

```
npm ci && npm test
```

`.github/workflows/ci.yml` here is illustrative only (nested workflows never run).
