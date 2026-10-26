import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {addCatalogLinks} from './deploy-overlay.mjs';
test('catalog overlay preserves release links and is idempotent',()=>{
 const html='<nav><a href="https://github.com/JevonsCode/DingDongBuddy/releases/tag/v1.9.1">Download 1.9.1</a></nav><section class="sound-section"><h2>Sounds</h2></section>';
 const out=addCatalogLinks(html);assert.ok(out.includes('releases/tag/v1.9.1'));assert.ok(out.includes('Download 1.9.1'));assert.equal((out.match(/href="\.\/voices\/"/g)||[]).length,2);assert.equal(addCatalogLinks(out),out);
});
test('root-only legacy link is replaced with project-relative route',()=>{assert.equal(addCatalogLinks('<nav><a href="/dingdongbuddy/voices/">Voices</a></nav>'),'<nav><a href="./voices/">Voices</a></nav>');for(const base of ['https://example.test/','https://example.test/DingDongBuddy/'])assert.equal(new URL('./voices/',base).href,base+'voices/');});
test('deployed catalog has all required local files',()=>{for(const name of ['index.html','voices.js','voices.css','catalog-core.mjs'])assert.ok(readFileSync(new URL(name,import.meta.url)).length>0);});
