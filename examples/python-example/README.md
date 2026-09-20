# python-example

A minimal module used to prove GoldenCI's Python path end to end: detection via
`pyproject.toml`, `ruff check`, `pytest` with a Cobertura XML coverage report,
and `python -m compileall`.

No `__main__` block on purpose, so coverage is 100% and comfortably clears the
70% gate.

Run it locally:

```
pip install -r requirements-dev.txt && pytest --cov=greet
```

`.github/workflows/ci.yml` here is illustrative only (nested workflows never run).
