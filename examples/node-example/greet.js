// CommonJS on purpose (no "type": "module" in package.json) so Jest needs no
// Babel transform. No CLI entry point, so every line is covered by the tests.

/**
 * Return a greeting for `name`. An empty name greets the world.
 *
 * @param {string} name
 * @returns {string}
 */
function greet(name) {
  if (!name) {
    return 'Hello, world!';
  }
  return `Hello, ${name}!`;
}

module.exports = { greet };
