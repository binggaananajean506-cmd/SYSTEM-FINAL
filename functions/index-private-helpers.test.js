const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const assert = require('node:assert/strict');
const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
function privateHelper(name) {
  const declarations = [...source.matchAll(new RegExp(`^function ${name}\\([^]*?^}`, 'gm'))];
  assert.ok(declarations.length, `${name} is defined`);
  return vm.runInNewContext(`${declarations.at(-1)[0]}; ${name}`);
}

test('optionalText preserves the effective hoisted trimming and length contract', () => {
  const optionalText = privateHelper('optionalText');
  assert.equal(optionalText('  hello  ', 3), 'hel');
  assert.equal(optionalText('x'.repeat(601)).length, 601);
  assert.equal(optionalText(null, 10), '');
  assert.equal(optionalText(0, 10), '');
  assert.equal(optionalText('abc', 0), '');
});

test('timestampMillis preserves effective Timestamp, Date, string and invalid contracts', () => {
  const timestampMillis = privateHelper('timestampMillis');
  assert.equal(timestampMillis({ toMillis: () => 123 }), 123);
  const date = new Date('2026-10-17T01:02:03.456Z');
  // The existing implementation parses String(Date), which drops milliseconds.
  assert.equal(timestampMillis(date), 1792198923000);
  assert.equal(timestampMillis('2026-10-17T01:02:03.456Z'), 1792198923456);
  for (const value of [undefined, null, '', 0, 'invalid', new Date(NaN), {}]) {
    assert.equal(timestampMillis(value), null);
  }
});
