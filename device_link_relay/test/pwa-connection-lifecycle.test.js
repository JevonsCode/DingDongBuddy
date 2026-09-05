import assert from 'node:assert/strict';
import test from 'node:test';
import { createConnectionController } from '../../docs/app/app-connection.js';
import { importAesKey, sealEnvelope } from '../../docs/app/app-codecs.js';

function fixture(t) {
  class Socket extends EventTarget {
    static OPEN = 1;
    static CONNECTING = 0;
    readyState = 1;
    sent = [];
    send(value) { this.sent.push(value); }
    close() { this.readyState = 3; this.dispatchEvent(new Event('close')); }
    frame(value) { this.dispatchEvent(new MessageEvent('message', {data: JSON.stringify(value)})); }
  }
  const previous = globalThis.WebSocket;
  globalThis.WebSocket = Socket;
  t.after(() => { globalThis.WebSocket = previous; });
  const pair = {version:1,room:'connection-lifecycle-test',secret:Buffer.alloc(32,1).toString('base64url'),relay:'http://localhost',manualDisconnect:true};
  const session = {pair,socket:null,channel:null,peer:null,connectionGeneration:0,contentGeneration:0,relayGeneration:0,connecting:false,connected:false,items:[],downloads:new Map(),outgoingRequests:new Set(),clipboardRenderRevision:0,remoteCandidates:[],reconnectDelayMs:2400};
  const messages=[];
  let cleared=0;
  const controller=createConnectionController({
    state:{sessions:new Map([[pair.room,session]]),identity:{id:'test',name:'test',platform:'test'}},
    activeSession:()=>session,initialReconnectDelayMs:2400,maximumReconnectDelayMs:30000,
    render(){},savePairings(){},notificationPermission:()=> 'default',async sendSettings(){},
    receiveClipboardSnapshot:m=>messages.push(m),upsertClipboardItem(){},handleRequestRejected(){},receiveAgentEvent(){},receiveAgentState(){},beginDownload(){},receiveDownloadChunk(){},finishDownload(){},
    clearDownloads(s){cleared++;s.downloads.clear();},
  });
  t.after(()=>controller.closeConnection(session));
  return {controller,session,messages,cleared:()=>cleared};
}

test('host loss frees partial downloads and invalidates an in-flight send context',async t=>{
  const f=fixture(t);await f.controller.connect();
  f.session.socket.frame({type:'relay',event:'host_joined'});
  await f.session.relayFrames;
  const old=f.controller.currentSessionContext(f.session);
  f.session.downloads.set('partial',{chunks:[new Uint8Array(1024)]});
  f.session.items.push({id:'clipboard'});
  f.session.socket.frame({type:'relay',event:'host_left'});
  await f.session.relayFrames;
  assert.equal(f.session.downloads.size,0);assert.equal(f.session.items.length,0);
  assert.equal(f.session.connected,false);assert.equal(f.cleared(),1);
  f.session.socket.frame({type:'relay',event:'host_joined'});await f.session.relayFrames;
  await assert.rejects(f.controller.sendMessage({type:'file.chunk'},old),/连接已经变化/);
  await f.controller.sendMessage({type:'clipboard.create',content:'new'},f.controller.currentSessionContext(f.session));
});

test('queued decrypted content cannot repopulate a disconnected feed',async t=>{
  const f=fixture(t);await f.controller.connect();
  f.session.socket.frame({type:'relay',event:'host_joined'});await f.session.relayFrames;
  let release;f.session.incomingMessages=new Promise(resolve=>{release=resolve});
  const key=await importAesKey(f.session.pair.secret);
  f.session.socket.frame({type:'data',payload:await sealEnvelope({type:'clipboard.snapshot',items:[{id:'late'}]},key)});
  await f.session.relayFrames;
  const pending=f.session.incomingMessages;
  f.session.socket.frame({type:'relay',event:'host_left'});await f.session.relayFrames;
  release();await pending;
  assert.deepEqual(f.messages,[]);
});

test('losing relay while the direct channel is open preserves the live transfer',async t=>{
  const f=fixture(t);await f.controller.connect();
  f.session.socket.frame({type:'relay',event:'host_joined'});await f.session.relayFrames;
  f.session.channel={readyState:'open',close(){},send(){}};
  f.session.downloads.set('active',{chunks:[]});
  f.session.socket.frame({type:'relay',event:'host_left'});await f.session.relayFrames;
  assert.equal(f.session.connected,true);assert.equal(f.session.downloads.size,1);assert.equal(f.cleared(),0);
});

test('a ready relay with no host leaves the connecting state and can later connect',async t=>{
  const f=fixture(t);await f.controller.connect();
  assert.equal(f.session.connecting,true);
  f.session.socket.frame({type:'relay',event:'ready'});await f.session.relayFrames;
  assert.equal(f.session.connecting,false);assert.equal(f.session.connected,false);
  f.session.socket.frame({type:'relay',event:'host_joined'});await f.session.relayFrames;
  assert.equal(f.session.connected,true);
});

test('a pinned channel send does not fall back to relay after the channel closes', async t => {
  const f = fixture(t);
  await f.controller.connect();
  f.session.connected = true;
  f.session.relayHostPresent = true;
  const channel = { readyState: 'open', send() {}, close() {} };
  f.session.channel = channel;
  const context = f.controller.currentSessionContext(f.session);
  context.transport = { kind: 'channel', target: channel };
  const relaySentBefore = f.session.socket.sent.length;
  channel.readyState = 'closed';

  await assert.rejects(
    f.controller.sendMessage({ type: 'file.chunk' }, context),
    /连接传输已经变化/,
  );
  assert.equal(f.session.socket.sent.length, relaySentBefore);
});
