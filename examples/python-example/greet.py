"""Minimal module with exactly one branch to cover.

There is deliberately no ``if __name__ == "__main__"`` block, so every line is
reachable from the tests and coverage lands at 100%.
"""


def greet(name: str = "") -> str:
    """Return a greeting for ``name``; an empty name greets the world."""
    if not name:
        return "Hello, world!"
    return f"Hello, {name}!"
