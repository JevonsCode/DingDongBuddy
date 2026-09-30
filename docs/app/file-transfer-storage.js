// File bodies stay on the device. OPFS keeps large downloads off the JS heap.
export const relayFileLimit = 25 * 1024 * 1024;
export async function openTransferSink({ key, size, fingerprint }) {
  if (!globalThis.navigator?.storage?.getDirectory) {
    if (size > relayFileLimit) throw new Error('storage_unsupported');
    const chunks = [];
    return { offset: 0,
      async write(offset, bytes) { chunks.push(bytes.slice()); this.offset += bytes.length; },
      async checkpoint() {},
      async file() { return new Blob(chunks); },
      async remove() { chunks.length = 0; },
    };
  }
  const root = await navigator.storage.getDirectory();
  const directory = await root.getDirectoryHandle('dingdong-transfers-v2', { create: true });
  // Retire abandoned temporary bodies; never touch files outside our OPFS folder.
  for await (const [name, entry] of directory.entries()) {
    if (entry.kind !== 'file' || !/^[a-f0-9]{64}\.(part|json)$/.test(name) || name.startsWith(key)) continue;
    if ((await entry.getFile()).lastModified < Date.now() - 24 * 60 * 60 * 1000) {
      await directory.removeEntry(name).catch(() => {});
    }
  }
  const handle = await directory.getFileHandle(`${key}.part`, { create: true });
  const metadata = await directory.getFileHandle(`${key}.json`, { create: true });
  let offset = 0;
  try {
    const saved = JSON.parse(await (await metadata.getFile()).text());
    if (saved.size === size && saved.fingerprint === fingerprint) offset = (await handle.getFile()).size;
  } catch { /* An empty or invalid manifest starts a new transfer. */ }
  if (offset > size) offset = 0;
  if (offset !== size) offset -= offset % 32768;
  let writer = await handle.createWritable({ keepExistingData: true });
  await writer.truncate(offset);
  const manifest = await metadata.createWritable();
  await manifest.write(JSON.stringify({ size, fingerprint, updatedAt: Date.now() }));
  await manifest.close();
  return { offset,
    async write(position, bytes) {
      writer ||= await handle.createWritable({ keepExistingData: true });
      await writer.write({ type: 'write', position, data: bytes });
      this.offset = position + bytes.length;
    },
    async checkpoint() { if (writer) { const current = writer; writer = null; await current.close(); } },
    async file() { await this.checkpoint(); return handle.getFile(); },
    async remove() {
      if (writer) { await writer.abort(); writer = null; }
      await directory.removeEntry(`${key}.part`).catch(() => {});
      await directory.removeEntry(`${key}.json`).catch(() => {});
    },
  };
}
