import {existsSync,readdirSync,readFileSync,rmdirSync,statSync,unlinkSync,writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';

export function addCatalogLinks(html) {
  const catalogHref='href="https://xn--8ovp9s.xn--m8txu.com/dingdong-voices/"';
  html=html.replaceAll(/href="(?:\.\/voices\/|voices\/|\/dingdongbuddy\/voices\/|\/DingDongBuddy\/voices\/)"/g,catalogHref);
  html=html.replace(/<nav\b[^>]*>[\s\S]*?<\/nav>/,nav=>nav.includes(catalogHref)?nav:nav.replace('</nav>',`<a ${catalogHref}>声音库 / Voices</a>\n      </nav>`));
  const section=/<section class="sound-section"[\s\S]*?<\/section>/;
  return html.replace(section,block=>block.includes(catalogHref)?block:block.replace('</section>',`<p class="sound-catalog-link"><a ${catalogHref}>声音库 / Community voices →</a></p></section>`));
}

export function pruneMissingProductDocs(released,current) {
  if (!existsSync(released)) return;
  if (!existsSync(current) || !statSync(current).isDirectory()) throw new Error('Current product documentation is unavailable.');
  function visit(directory,relative='') {
    for (const entry of readdirSync(directory,{withFileTypes:true})) {
      const path=join(directory,entry.name), key=join(relative,entry.name);
      if (entry.isDirectory()) {
        visit(path,key);
        if (readdirSync(path).length===0) rmdirSync(path);
      } else if (!existsSync(join(current,key))) {
        unlinkSync(path);
      }
    }
  }
  visit(released);
}

if (process.argv[1]===fileURLToPath(import.meta.url)) {
  const [index,released,current]=process.argv.slice(2);
  if (!index || !released || !current) throw new Error('Expected index and product documentation paths.');
  pruneMissingProductDocs(released,current);
  writeFileSync(index,addCatalogLinks(readFileSync(index,'utf8')));
}
