const { greet } = require('./greet');

test('greets a named caller', () => {
  expect(greet('GoldenCI')).toBe('Hello, GoldenCI!');
});

test('falls back to the world when the name is empty', () => {
  expect(greet('')).toBe('Hello, world!');
});
