export const REPO = 'JevonsCode/dingdong-voices';
export const API = `https://api.github.com/repos/${REPO}`;
export const MAX_BYTES = 5 * 1024 * 1024;
export function attachmentUrl(value) {
  // Repository audio is pinned to an immutable commit, never an editable branch.
  if (typeof value === 'string' && /^https:\/\/raw\.githubusercontent\.com\/JevonsCode\/dingdong-voices\/[a-f0-9]{40}\/audio\/[A-Za-z0-9_-]+\.wav$/.test(value)) return value;
  if (typeof value !== 'string' || !/^https:\/\/github\.com\/user-attachments\/files\/[0-9]+\/[A-Za-z0-9_.-]+\.wav$/i.test(value)) throw new Error('需要 GitHub 上传的 .wav 附件链接。');
  const url = new URL(value);
  if (url.hostname !== 'github.com' || url.username || url.password || url.port || url.search || url.hash) throw new Error('附件地址不符合要求。');
  return value;
}
export function allowedFinalUrl(value) {
  try { attachmentUrl(value); return true; } catch {}
  try { const u = new URL(value); return u.protocol === 'https:' && !u.username && !u.password && !u.port && !u.hash && u.hostname === 'github-production-user-asset-6210df.s3.amazonaws.com' && /^\/[0-9]+\/[A-Za-z0-9_./-]+$/.test(u.pathname); } catch { return false; }
}
export function fieldsFromBody(body) {
  if (typeof body !== 'string' || body.length > 65536) throw new Error('投稿内容无效。');
  const fields = Object.create(null); let key = null;
  for (const line of body.replace(/\r\n/g, '\n').split('\n')) {
    const heading = /^### (.+?)\s*$/.exec(line);
    if (heading) { key = heading[1]; if (Object.hasOwn(fields,key)) throw new Error('投稿含重复字段。'); fields[key] = ''; }
    else if (key) fields[key] += line + '\n';
  }
  for (const k of Object.keys(fields)) fields[k] = fields[k].trim();
  return fields;
}
export function parseIssue(issue) {
  if (!issue || issue.pull_request || issue.state !== 'open' || !Number.isSafeInteger(issue.number) || issue.number < 1 || typeof issue.title !== 'string' || !issue.title.trim() || issue.title.length > 256) throw new Error('这条投稿未开放或已关闭。');
  if (issue.html_url !== `https://github.com/${REPO}/issues/${issue.number}` || !/^[a-zA-Z0-9-]{1,39}$/.test(issue.user?.login || '')) throw new Error('投稿来源或作者无效。');
  const fields = fieldsFromBody(issue.body);
  for (const k of ['Description','Audio','Source','License','Rights confirmation']) if (!fields[k] || fields[k] === '_No response_') throw new Error(`缺少 ${k}。`);
  if (fields.Description.length > 2000 || fields.Source.length > 2000 || fields.License.length > 500) throw new Error('投稿描述或授权说明过长。');
  if (!/- \[x\]/i.test(fields['Rights confirmation'])) throw new Error('缺少权利确认。');
  const urls = fields['Audio'].match(/https:\/\/[^\s<>\[\]()]+/g) || [];
  if (urls.length !== 1) throw new Error('需要且仅可提供一个音频附件。');
  const audioUrl = attachmentUrl(urls[0]);
  return {number:issue.number,title:issue.title,description:fields.Description,audioUrl,license:fields.License,rights:fields['Rights confirmation'],category:fields.Category && fields.Category !== '_No response_' ? fields.Category : '未分类',source:fields.Source,author:issue.user?.login || 'GitHub 用户',created:issue.created_at,up:Math.max(0,Number(issue.reactions?.['+1']) || 0),down:Math.max(0,Number(issue.reactions?.['-1']) || 0),issueUrl:`https://github.com/${REPO}/issues/${issue.number}`};
}
export function canonicalMetadata(voice) { return JSON.stringify([voice.title,voice.description.trim(),voice.audioUrl,voice.source.trim(),voice.license.trim(),voice.rights.trim()]); }
export async function sha256(bytes) { const data = typeof bytes === 'string' ? new TextEncoder().encode(bytes) : bytes; return [...new Uint8Array(await globalThis.crypto.subtle.digest('SHA-256',data))].map(b => b.toString(16).padStart(2,'0')).join(''); }
export function validateWav(input) {
  const bytes = input instanceof Uint8Array ? input : new Uint8Array(input);
  if (bytes.length < 44 || bytes.length > MAX_BYTES) throw new Error('WAV 文件大小必须在有效范围内（最多 5 MiB）。');
  const v = new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
  const str = o => String.fromCharCode(...bytes.subarray(o,o+4));
  if (str(0) !== 'RIFF' || str(8) !== 'WAVE' || v.getUint32(4,true)+8 !== bytes.length) throw new Error('不是有效的 RIFF WAV 文件。');
  let fmt = null, data = null, offset = 12;
  while (offset + 8 <= bytes.length) {
    const kind = str(offset), length = v.getUint32(offset+4,true), start = offset+8, end = start+length;
    if (end > bytes.length) throw new Error('WAV 数据块越界。');
    if (kind === 'fmt ') {
      if (fmt || ![16,18].includes(length) || (length === 18 && v.getUint16(start+16,true) !== 0)) throw new Error('无效的 WAV 格式块。');
      fmt = {format:v.getUint16(start,true),channels:v.getUint16(start+2,true),sampleRate:v.getUint32(start+4,true),byteRate:v.getUint32(start+8,true),align:v.getUint16(start+12,true),bits:v.getUint16(start+14,true)};
    }
    if (kind === 'data') { if (data !== null) throw new Error('重复的 WAV 数据块。'); data = length; }
    offset = end + (length % 2);
  }
  if (offset !== bytes.length || !fmt || data === null || data === 0 || fmt.format !== 1 || ![1,2].includes(fmt.channels) || ![8,16,24,32].includes(fmt.bits) || fmt.sampleRate < 8000 || fmt.sampleRate > 192000 || fmt.align !== fmt.channels*fmt.bits/8 || fmt.byteRate !== fmt.sampleRate*fmt.align || data % fmt.align) throw new Error('只支持有效的标准 PCM WAV。');
  const duration = data / fmt.byteRate;
  if (duration <= 0 || duration > 3) throw new Error('社区声音实际时长不能超过 3 秒。');
  return {duration,bytes:bytes.length,...fmt};
}
export async function readLimited(response) {
  if (!response.ok) throw new Error(`音频下载失败（${response.status}）。`);
  const length = Number(response.headers.get('content-length'));
  if (length > MAX_BYTES) throw new Error('附件超过 5 MiB。');
  if (!response.body?.getReader) throw new Error('浏览器不支持安全下载，请更新浏览器。');
  const reader = response.body.getReader(); const chunks = []; let size = 0;
  try { while (true) { const {done,value} = await reader.read(); if (done) break; size += value.byteLength; if (size > MAX_BYTES) throw new Error('附件超过 5 MiB。'); chunks.push(value); } }
  catch (error) { await reader.cancel().catch(()=>{}); throw error; }
  const result = new Uint8Array(size); let at=0; for (const chunk of chunks) { result.set(chunk,at); at += chunk.length; } return result;
}
export async function fetchJson(url, {fresh=false, signal}={}) {
  const response = await fetch(url,{headers:{Accept:'application/vnd.github+json'},credentials:'omit',cache:fresh?'no-store':'default',signal});
  if (!response.ok) {
    if (response.status === 403 || response.status === 429) throw new Error('GitHub 公开 API 暂时限流，请稍后再试。');
    if (response.status === 404) throw new Error('声音仓库或投稿暂不可用。');
    throw new Error(`GitHub 暂不可用（${response.status}）。`);
  }
  return response.json();
}
export async function verifyAndDownload(number, signal) {
  // Re-read the open submission before every audio action. No moderator gate.
  const voice = parseIssue(await fetchJson(`${API}/issues/${number}`,{fresh:true,signal}));
  const metadataHash = await sha256(canonicalMetadata(voice));
  const response = await fetch(voice.audioUrl,{credentials:'omit',cache:'no-store',signal,referrerPolicy:'no-referrer'});
  if (!allowedFinalUrl(response.url)) { await response.body?.cancel(); throw new Error('附件重定向目标不被允许。'); }
  const bytes = await readLimited(response);
  const wav = validateWav(bytes);
  // Reject concurrent metadata changes or closure during download.
  const current = parseIssue(await fetchJson(`${API}/issues/${number}`,{fresh:true,signal}));
  if (await sha256(canonicalMetadata(current)) !== metadataHash) throw new Error('投稿刚刚发生变更，请重新验证。');
  return {voice:current,bytes,wav};
}
