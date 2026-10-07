import { readFileSync } from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import ts from 'typescript';

const code = ts.transpileModule(readFileSync(new URL('./bannerDesign.ts', import.meta.url), 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 },
}).outputText;
const { defaultDesign, snapPosition, parseDesign, templateDesign, removeButtonDesign, legacyDesign } =
  await import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}`);

test('drag snaps to grid and element center', () => {
  const node = defaultDesign().nodes.button0;
  const grid = snapPosition(node, 7.1, 13.1);
  assert.equal(grid.x, 8); assert.equal(grid.y, 14);
  const center = snapPosition(node, 50 - node.width / 2 + 1, 50 - node.height / 2 + 1);
  assert.equal(center.x + center.width / 2, 50);
  assert.equal(center.y + center.height / 2, 50);
});
test('drag stays inside canvas and free movement does not snap', () => {
  const node = defaultDesign().nodes.mascot;
  assert.equal(snapPosition(node, 1000, -100).x, 100 - node.width);
  assert.equal(snapPosition(node, 1000, -100).y, 0);
  assert.equal(snapPosition(node, 7.3, 8.1, false).x, 7.3);
});
test('design round trip retains independent typography, CTA and mascot settings', () => {
  const design = defaultDesign();
  design.nodes.title = { ...design.nodes.title, color: '#facc15', lineColors: ['#ffffff', '#facc15'], fontFamily: 'Lexend', align: 'center' };
  design.nodes.mascot.flip = true;
  design.nodes.button0.gradient = '#2563eb,#7c3aed';
  assert.deepEqual(parseDesign(JSON.stringify(design)), design);
});
test('malformed and unsupported designs fall back; invalid positions are bounded', () => {
  assert.equal(parseDesign('{'), null);
  assert.equal(parseDesign('{"version":2,"nodes":{}}'), null);
  const design = defaultDesign(); design.nodes.title.x = 200;
  assert.equal(parseDesign(JSON.stringify(design)).nodes.title.x, 100 - design.nodes.title.width);
});
test('all templates fit inside canvas and promotion is centered', () => {
  for (const name of ['promotion', 'information', 'image']) {
    for (const node of Object.values(templateDesign(name).nodes)) {
      assert.ok(node.x >= 0 && node.y >= 0 && node.x + node.width <= 100 && node.y + node.height <= 100);
    }
  }
  const promotion = templateDesign('promotion');
  assert.equal(promotion.nodes.title.align, 'center');
  assert.equal(promotion.nodes.button0.x + promotion.nodes.button0.width / 2, 50);
});
test('removing a CTA keeps the remaining CTA design attached to its action', () => {
  const design = defaultDesign(); design.nodes.button1.color = '#123456';
  assert.equal(removeButtonDesign(design, 0).nodes.button0.color, '#123456');
  assert.equal(design.nodes.button0.color, '#2563eb');
});
test('legacy left mascot and custom coordinates map to percentage layout', () => {
  const design = legacyDesign({ imagePosition: 'LEFT', buttonPosition: 'CUSTOM', buttonTop: 18, buttonLeft: 36 });
  assert.equal(design.nodes.mascot.x, 2); assert.equal(design.nodes.title.x, 36);
  assert.equal(design.nodes.button0.x, 10); assert.equal(design.nodes.button0.y, 10);
});
