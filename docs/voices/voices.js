import {API,REPO,parseIssue,verifyAndDownload} from './catalog-core.mjs';
const $ = id => document.getElementById(id);
let voices = [], page=1, loading=false, hasMore=false, skipped=0, partial=false;
const pageCache = new Map();
const mediaUrls = new Set();
function node(tag,text,className) { const el=document.createElement(tag); if (text !== undefined) el.textContent=text; if(className)el.className=className;return el; }
function link(text,url,className) { const a=node('a',text,className);a.href=url;a.target='_blank';a.rel='noopener noreferrer';return a; }
function button(text,handler,className) { const b=node('button',text,className);b.type='button';b.addEventListener('click',handler);return b; }
function revokeMedia() { document.querySelectorAll('audio').forEach(a=>a.pause());for(const u of mediaUrls)URL.revokeObjectURL(u);mediaUrls.clear(); }
async function loadPage(reset=false) {
  if(loading)return;loading=true;$('refresh').disabled=true;$('load-more').disabled=true;$('cards').setAttribute('aria-busy','true');
  if(reset){page=1;voices=[];skipped=0;partial=false;pageCache.clear();render();}
  $('status').textContent='正在读取公开 GitHub 投稿…';
  try {
    // Discovery-only, five-minute in-memory cache. Audio validation always uses fresh data.
    let result=pageCache.get(page);
    if(!result || Date.now()-result.time>300000) {
      const r=await fetch(`${API}/issues?state=open&sort=created&direction=desc&per_page=30&page=${page}`,{headers:{Accept:'application/vnd.github+json'},credentials:'omit',cache:reset?'no-store':'default',signal:AbortSignal.timeout(20000)});
      if(!r.ok)throw new Error(r.status===403||r.status===429?'GitHub 公开 API 暂时限流。稍后点击刷新即可，无需提供令牌。':r.status===404?'声音仓库暂未开放或当前不可用。请稍后再来。':`读取失败（${r.status}），请稍后重试。`);
      const data=await r.json();if(!Array.isArray(data))throw new Error('GitHub 返回了无法识别的列表。');
      result={data,time:Date.now()};pageCache.set(page,result);
    }
    for(const issue of result.data) { if(issue.pull_request)continue;try { const voice=parseIssue(issue);if(!voices.some(v=>v.number===voice.number))voices.push(voice); }catch{skipped++;} }
    hasMore=result.data.length===30;page++;partial=false;render();
  }catch(error){partial=true;$('status').textContent=(voices.length?'已加载的结果仍可浏览；后续页面未能加载。':'')+(error.name==='TimeoutError'?'连接 GitHub 超时，请重试。':error.message);if(!voices.length){$('cards').replaceChildren(node('p','暂时无法加载声音。你可以稍后重试，或前往声音仓库查看投稿。','empty-state'));}}
  finally {loading=false;$('refresh').disabled=false;$('load-more').disabled=false;$('load-more').hidden=!hasMore;$('cards').setAttribute('aria-busy','false');}
}
function render() {
  revokeMedia(); const query=$('search').value.trim().toLocaleLowerCase(),category=$('category').value;
  const categories=[...new Set(voices.map(v=>v.category))].sort();$('category').replaceChildren(new Option('全部分类',''),...categories.map(c=>new Option(c,c)));$('category').value=categories.includes(category)?category:'';
  const filtered=voices.filter(v=>(!category || v.category===category)&&(!query || `${v.title} ${v.description} ${v.author}`.toLocaleLowerCase().includes(query)));
  filtered.sort($('sort').value==='popular'?(a,b)=>b.up-a.up||b.number-a.number:(a,b)=>b.number-a.number);
  $('cards').replaceChildren(...filtered.map(card));
  if(!filtered.length)$('cards').append(node('p',voices.length?'没有匹配的声音。换个关键词或分类试试。':'还没有可展示的声音。你可以成为第一个投稿者，分享一条有明确授权的提示音。','empty-state'));
  if(!partial)$('status').textContent=`已加载 ${voices.length} 条投稿，显示 ${filtered.length} 条。${hasMore?'还有更多，可继续加载。':''}${skipped?` ${skipped} 条格式不完整的投稿已隐藏。`:''} 试听 / 下载前验证。`;
}
function card(voice) {
  const article=node('article',undefined,'voice-card');const top=node('div',undefined,'card-top');top.append(node('span',voice.category,'category-tag'),node('span','≤ 3 秒 · PCM WAV','duration'));
  const date=new Date(voice.created);const meta=node('p',`@${voice.author} · ${Number.isNaN(date.getTime())?'时间未知':date.toLocaleDateString('zh-CN')}`,'meta');
  const controls=node('div',undefined,'card-controls'),audioStatus=node('p','试听 / 下载前检查音频格式和时长。','audio-status');audioStatus.setAttribute('role','status');
  const audio=node('audio');audio.controls=true;audio.preload='none';audio.hidden=true;audio.addEventListener('error',()=>{audioStatus.textContent='文件已通过验证，但当前浏览器无法播放。你可以下载后在 DingDong 中导入。';});
  let localUrl=null, verifiedLabel='';
  audio.addEventListener('play',()=>{document.querySelectorAll('audio').forEach(other=>{if(other!==audio)other.pause();});if(verifiedLabel)audioStatus.textContent=verifiedLabel+' · 正在播放';});
  audio.addEventListener('ended',()=>{if(verifiedLabel)audioStatus.textContent=verifiedLabel+' · 播放完毕';});
  audio.addEventListener('pause',()=>{if(verifiedLabel && !audio.ended && audio.currentTime>0)audioStatus.textContent=verifiedLabel+' · 已暂停';});
  async function audioAction(download) {
    const activeButtons=[...controls.querySelectorAll('button')];activeButtons.forEach(b=>b.disabled=true);audio.pause();audio.removeAttribute('src');audio.hidden=true;
    if(localUrl){URL.revokeObjectURL(localUrl);mediaUrls.delete(localUrl);localUrl=null;}
    verifiedLabel='';audioStatus.textContent='正在读取投稿和 WAV 文件…';
    try {
      const result=await verifyAndDownload(voice.number,AbortSignal.timeout(60000));
      // Do not silently deliver audio after its title/description/license changed from the visible card.
      if(result.voice.title!==voice.title || result.voice.description!==voice.description || result.voice.audioUrl!==voice.audioUrl || result.voice.source!==voice.source || result.voice.license!==voice.license || result.voice.rights!==voice.rights)throw new Error('投稿内容已变更，请刷新列表后重试。');
      if (!article.isConnected) return; // A search/refresh removed this card while fetching.
      localUrl=URL.createObjectURL(new Blob([result.bytes],{type:'audio/wav'}));mediaUrls.add(localUrl);
      verifiedLabel=`已验证 · ${result.wav.duration.toFixed(2)} 秒 · ${(result.bytes.length/1024).toFixed(0)} KiB`;audioStatus.textContent=verifiedLabel;
      if(download){const a=document.createElement('a');a.href=localUrl;a.download=`dingdong-voice-${voice.number}.wav`;a.click();audioStatus.textContent+=' · 已准备下载';}
      else {audio.src=localUrl;audio.hidden=false;try {await audio.play();} catch {audioStatus.textContent+=' · 点击播放器播放';}}
    } catch(error){audioStatus.textContent=error.name==='TimeoutError'?'验证超时，请稍后重试。':error instanceof TypeError?'浏览器无法安全读取附件，可能是网络或跨域限制。未播放或下载未经验证的文件。':error.message;}
    finally {activeButtons.forEach(b=>b.disabled=false);}
  }
  controls.append(button('▶ 试听',()=>audioAction(false)),button('↓ 下载',()=>audioAction(true)),button('订阅',()=>openSubscribe(voice),'subscribe-button'));
  const bottom=node('div',undefined,'card-bottom');bottom.append(link(`👍 ${voice.up}`,voice.issueUrl,'vote-link'),link(`👎 ${voice.down}`,voice.issueUrl,'vote-link'),link('投稿详情 ↗',voice.issueUrl,'issue-link'));
  for(const vote of bottom.querySelectorAll('.vote-link')){vote.title='打开 GitHub Issue 点赞 / 点踩，需要 GitHub 登录';vote.setAttribute('aria-label',`${vote.textContent}；打开 GitHub Issue 添加反应，需登录`);}
  article.append(top,node('h3',voice.title.replace(/^🕵🏻‍♀️\[DOT\]\s*/,'')),node('p',voice.description,'description'),meta,node('p',`授权：${voice.license}`,'license'),controls,audio,audioStatus,bottom);return article;
}
async function copy(text,statusId) {try{await navigator.clipboard.writeText(text);$(statusId).textContent='已复制。';}catch{$(statusId).textContent='浏览器未允许复制，请手动选中并复制文字。';}}
function openSubscribe(voice){$('subscribe-url').value=voice.issueUrl;$('subscribe-status').textContent='';$('subscribe-dialog').showModal();copy(voice.issueUrl,'subscribe-status');}
$('copy-subscribe').addEventListener('click',()=>copy($('subscribe-url').value,'subscribe-status'));
$('close-dialog').addEventListener('click',()=>$('subscribe-dialog').close());
$('copy-prompt').addEventListener('click',()=>copy($('agent-prompt').textContent,'prompt-status'));
$('refresh').addEventListener('click',()=>loadPage(true));$('load-more').addEventListener('click',()=>loadPage());
for(const id of ['search','category','sort'])$(id).addEventListener(id==='search'?'input':'change',render);
window.addEventListener('pagehide',revokeMedia);
loadPage();
