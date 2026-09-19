import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const root = path.resolve(import.meta.dirname, '..');
const require = createRequire(root + '/.local/vrm-validation/package.json');
const {validateBytes} = require('gltf-validator');
const mobile = process.argv.includes('--mobile');
const folder = root + '/04_GAME_ASSETS/3d/hazard_adopted/' + (mobile ? 'mobile_20260919' : 'optimized_20260919');
const build = JSON.parse(fs.readFileSync(folder + (mobile ? '/manifest.json' : '/optimization.json')));
const report = {};
for (const [name, row] of Object.entries(build.models)) {
  report[name] = {};
  for (const [label, file] of [['source', row.source], ['optimized', row.file]]) {
    const {issues} = await validateBytes(fs.readFileSync(root + '/' + file), {maxIssues: 1000});
    report[name][label] = {...issues, messages: issues.messages.filter(m => m.severity < 2)};
    assert.equal(issues.numErrors, 0, JSON.stringify(report[name][label]));
  }
  const previous = new Set(report[name].source.messages.map(m => JSON.stringify(m)));
  assert(report[name].optimized.messages.every(m => previous.has(JSON.stringify(m))),
    'No new format warnings are accepted');
}
fs.writeFileSync(folder + '/format_validation.json', JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(Object.fromEntries(Object.entries(report).map(([name, row]) => [name,
  {errors: row.optimized.numErrors, inheritedWarnings: row.optimized.numWarnings}]))));
