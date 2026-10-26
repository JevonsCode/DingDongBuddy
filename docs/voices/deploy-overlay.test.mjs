import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {addCatalogLinks,versionCatalogAssets} from './deploy-overlay.mjs';
test('catalog overlay preserves release links and is idempotent',()=>{
 const html='<nav><a href="https://github.com/JevonsCode/DingDongBuddy/releases/tag/v1.9.1">Download 1.9.1</a></nav><section class="sound-section"><h2>Sounds</h2></section>';
 const out=addCatalogLinks(html);assert.ok(out.includes('releases/tag/v1.9.1'));assert.ok(out.includes('Download 1.9.1'));assert.equal((out.match(/href="\.\/voices\/"/g)||[]).length,2);assert.equal(addCatalogLinks(out),out);
});
test('root-only legacy link is replaced with project-relative route',()=>{assert.equal(addCatalogLinks('<nav><a href="/dingdongbuddy/voices/">Voices</a></nav>'),'<nav><a href="./voices/">Voices</a></nav>');for(const base of ['https://example.test/','https://example.test/DingDongBuddy/'])assert.equal(new URL('./voices/',base).href,base+'voices/');});
test('deployed catalog has all required local files',()=>{for(const name of ['index.html','voices.js','voices.css','catalog-core.mjs'])assert.ok(readFileSync(new URL(name,import.meta.url)).length>0);});

test('asset URLs change with JS, CSS or core content, not with timestamps',()=>{
 const input={html:'<script src="./voices.js"></script><link href="./voices.css">',js:"import './catalog-core.mjs';",css:'body{}',core:'export const version=1;'};
 const first=versionCatalogAssets(input);assert.deepEqual(versionCatalogAssets(input),first);
 assert.match(first.html,/voices\.js\?v=[a-f0-9]{16}/);assert.match(first.html,/voices\.css\?v=[a-f0-9]{16}/);assert.match(first.js,/catalog-core\.mjs\?v=[a-f0-9]{16}/);
 for(const key of ['js','css','core'])assert.notEqual(versionCatalogAssets({...input,[key]:input[key]+'\nchanged'}).html,first.html);
 assert.deepEqual(versionCatalogAssets({...input,html:first.html,js:first.js}),first);
});
