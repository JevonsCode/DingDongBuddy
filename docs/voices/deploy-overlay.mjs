import {readFileSync,writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
export function addCatalogLinks(html) {
  // Relative URLs work both on a project Pages URL and a root custom domain.
  html=html.replaceAll('href="/dingdongbuddy/voices/"','href="./voices/"');
  if (!/href="\.\/voices\/"/.test(html)) {
    html=html.replace('</nav>','<a href="./voices/">声音库 / Voices</a>\n      </nav>');
  }
  const section=/<section class="sound-section"[\s\S]*?<\/section>/;
  html=html.replace(section,block=>block.includes('href="./voices/"')?block:block.replace('</section>','<p class="sound-catalog-link"><a href="./voices/">声音库 / Community voices →</a></p></section>'));
  return html;
}
export function versionCatalogAssets({html,js,css,core}) {
  const hash=text=>createHash('sha256').update(text).digest('hex').slice(0,16);
  js=js.replace(/'\.\/catalog-core\.mjs(?:\?v=[^']*)?'/,`'./catalog-core.mjs?v=${hash(core)}'`);
  html=html.replace(/src="\.\/voices\.js(?:\?v=[^"]*)?"/,`src="./voices.js?v=${hash(js)}"`)
    .replace(/href="\.\/voices\.css(?:\?v=[^"]*)?"/,`href="./voices.css?v=${hash(css)}"`);
  return {html,js};
}
if (process.argv[1]===fileURLToPath(import.meta.url)) {
  const file=new URL('../index.html',import.meta.url);
  writeFileSync(file,addCatalogLinks(readFileSync(file,'utf8')));
  const here=name=>new URL(name,import.meta.url);
  const built=versionCatalogAssets({html:readFileSync(here('index.html'),'utf8'),js:readFileSync(here('voices.js'),'utf8'),css:readFileSync(here('voices.css'),'utf8'),core:readFileSync(here('catalog-core.mjs'),'utf8')});
  writeFileSync(here('index.html'),built.html);
  writeFileSync(here('voices.js'),built.js);
}
