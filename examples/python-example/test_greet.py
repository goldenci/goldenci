from greet import greet


def test_greets_a_named_caller() -> None:
    assert greet("GoldenCI") == "Hello, GoldenCI!"


def test_falls_back_to_the_world() -> None:
    assert greet("") == "Hello, world!"
