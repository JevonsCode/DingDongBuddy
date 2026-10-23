// Run after editing index.html. Keeps the requested /dingdongbuddy/voices/ entry
// on root-hosted documentation without duplicating CSS, JavaScript, or assets.
import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
const source=readFileSync(new URL('./index.html',import.meta.url),'utf8');
const nested=source.replaceAll('href="../','href="../../').replaceAll('src="../','src="../../').replaceAll('href="./voices.css"','href="../../voices/voices.css"').replaceAll('src="./voices.js"','src="../../voices/voices.js"');
const directory=new URL('../dingdongbuddy/voices/',import.meta.url);mkdirSync(directory,{recursive:true});writeFileSync(new URL('index.html',directory),'<!-- Generated from docs/voices/index.html by sync-route.mjs. -->\n'+nested);
