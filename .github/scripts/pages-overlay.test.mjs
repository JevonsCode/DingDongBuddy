import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,existsSync,rmSync} from 'node:fs';
import {runInNewContext} from 'node:vm';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {addCatalogLinks,pruneMissingProductDocs} from './pages-overlay.mjs';

test('catalog links preserve released content and work from a project site',()=>{
  const html='<nav><a href="https://example.com/release">Download</a></nav><section class="sound-section"></section>';
  const out=addCatalogLinks(html);
  assert.ok(out.includes('href="https://example.com/release"'));
  assert.equal((out.match(/href="https:\/\/xn--8ovp9s\.xn--m8txu\.com\/dingdong-voices\/"/g)||[]).length,2);
  assert.equal(addCatalogLinks(out),out);
  assert.equal(addCatalogLinks('<nav><a href="/dingdongbuddy/voices/">Voices</a></nav>'),'<nav><a href="https://xn--8ovp9s.xn--m8txu.com/dingdong-voices/">Voices</a></nav>');
});

test('homepage and deploy overlay share the independent catalog without duplicate links',()=>{
  const home=readFileSync(new URL('../../docs/index.html',import.meta.url),'utf8');
  const catalog='https://xn--8ovp9s.xn--m8txu.com/dingdong-voices/';
  const links=[...home.matchAll(/href="([^"]+)" data-i18n="(?:nav.voices|sounds.catalog)"/g)];
  assert.equal(links.length,2);
  for(const [,href] of links) assert.equal(href,catalog);
  const deployed=addCatalogLinks(home);
  assert.equal(deployed,home);
  assert.equal((deployed.match(/href="https:\/\/xn--8ovp9s\.xn--m8txu\.com\/dingdong-voices\/"/g)||[]).length,2);
  for(const href of ['./voices/','voices/','/DingDongBuddy/voices/']) {
    const rewritten=addCatalogLinks(`<nav><a href="${href}">Voices</a></nav>`);
    assert.equal(rewritten,`<nav><a href="${catalog}">Voices</a></nav>`);
  }
});

test('legacy entry preserves the DEV query and fragment on redirect',()=>{
  const html=readFileSync(new URL('../../docs/voices/index.html',import.meta.url),'utf8');
  const script=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
  assert.ok(script);
  let destination;
  const window={location:{search:'?app=dev',hash:'#sound',replace:url=>{destination=url;}}};
  runInNewContext(script,{window});
  assert.equal(destination,'https://xn--8ovp9s.xn--m8txu.com/dingdong-voices/?app=dev#sound');
  assert.ok(html.includes('<noscript>'));
});

test('deployment removes deleted product files without publishing unreleased edits',()=>{
  const root=mkdtempSync(join(tmpdir(),'dingdong-pages-'));
  try {
    const stable=join(root,'stable'),current=join(root,'current');
    mkdirSync(join(stable,'screenshots'),{recursive:true});mkdirSync(current);
    writeFileSync(join(stable,'keep.md'),'released');writeFileSync(join(stable,'old.md'),'old');
    writeFileSync(join(stable,'screenshots','old.png'),'old');writeFileSync(join(current,'keep.md'),'unreleased');
    writeFileSync(join(current,'new.md'),'unreleased');
    pruneMissingProductDocs(stable,current);
    assert.equal(readFileSync(join(stable,'keep.md'),'utf8'),'released');
    assert.equal(existsSync(join(stable,'old.md')),false);
    assert.equal(existsSync(join(stable,'screenshots','old.png')),false);
    assert.equal(existsSync(join(stable,'new.md')),false);
    assert.throws(()=>pruneMissingProductDocs(stable,join(root,'missing')));
  } finally {rmSync(root,{recursive:true,force:true});}
});
