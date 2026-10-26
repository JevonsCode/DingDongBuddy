import {readFileSync,writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
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
if (process.argv[1]===fileURLToPath(import.meta.url)) {
  const file=new URL('../index.html',import.meta.url);
  writeFileSync(file,addCatalogLinks(readFileSync(file,'utf8')));
}
