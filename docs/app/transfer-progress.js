import { formatBytes } from './app-formatters.js?shell=46';
const labels = { preparing: '准备传输', transferring: '传输中', verifying: '确认文件',
  waiting: '等待连接恢复', paused: '已暂停', failed: '传输未完成', completed: '传输完成', cancelled: '已取消' };
const issues = { waiting_lan: '等待局域网直连 · 进度已保留', connection_lost: '连接中断 · 恢复后自动继续',
  source_changed: '源文件已改变，请重新选择', storage_error: '存储空间不足或无法写入，请检查后重试',
  storage_unsupported: '此浏览器不支持大文件暂存，请使用支持本地文件存储的浏览器',
  checksum_failed: '文件校验失败，请重试', too_many_transfers: '请等待其他文件完成',
  restart_required: '接收端记录已清除，请重新发送', invalid_offset: '传输进度不一致，请重新发送' };

export function renderTransferProgress(container, session) {
  if (!container) return;
  const transfers = session?.fileTransfers?.transfers || [];
  container.hidden = !transfers.length;
  if (container.dataset.room !== session?.pair?.room) {
    container.replaceChildren(); container.dataset.room = session?.pair?.room || '';
  }
  if (!transfers.length) return;
  let heading = container.querySelector('.transfer-heading');
  if (!heading) {
    heading = document.createElement('h2'); heading.className = 'transfer-heading';
    heading.textContent = '文件传输'; container.append(heading);
  }
  const active = transfers.filter((item) => !['completed', 'cancelled'].includes(item.status));
  const visible = [...active, ...transfers.filter((item) => !active.includes(item)).slice(0, 3)];
  for (const row of container.querySelectorAll('.transfer-row')) {
    if (!visible.some((view) => view.id === row.dataset.id)) row.remove();
  }
  for (const view of visible) {
    let row = [...container.querySelectorAll('.transfer-row')].find((node) => node.dataset.id === view.id);
    if (!row) {
      row = document.createElement('article'); row.className = 'transfer-row'; row.dataset.id = view.id;
      const top = document.createElement('div'); top.className = 'transfer-title-line';
      const title = document.createElement('strong'); title.className = 'transfer-name';
      const percent = document.createElement('span'); percent.className = 'transfer-percent';
      top.append(title, percent);
      const meta = document.createElement('p'); meta.className = 'transfer-meta';
      const progress = document.createElement('progress'); progress.max = 1;
      const bottom = document.createElement('div'); bottom.className = 'transfer-bottom';
      const status = document.createElement('span'); status.className = 'transfer-status';
      const actions = document.createElement('div'); actions.className = 'transfer-actions';
      bottom.append(status, actions); row.append(top, meta, progress, bottom); container.append(row);
    }
    row.dataset.status = view.status;
    row.querySelector('.transfer-name').textContent = view.name;
    const progress = view.size ? Math.min(1, view.bytes / view.size) : view.status === 'completed' ? 1 : 0;
    row.querySelector('.transfer-percent').textContent = `${Math.floor(progress * 100)}%`;
    const bar = row.querySelector('progress'); bar.value = progress;
    bar.setAttribute('aria-label', `${view.name}传输进度`);
    const speed = view.status === 'transferring' && view.bytesPerSecond > 0
      ? ` · ${formatBytes(view.bytesPerSecond)}/s` : '';
    row.querySelector('.transfer-meta').textContent = `${view.sending ? '发送到' : '接收自'} ${session.pair.hostName} · ${formatBytes(view.bytes)} / ${formatBytes(view.size)}${speed}`;
    row.querySelector('.transfer-status').textContent = issues[view.detail] || labels[view.status] || '准备传输';
    const actions = row.querySelector('.transfer-actions');
    const actionNames = ['completed', 'cancelled'].includes(view.status) ? []
      : [['paused', 'waiting', 'failed'].includes(view.status) ? 'resume' : 'pause', 'cancel'];
    while (actions.children.length > actionNames.length) actions.lastElementChild.remove();
    actionNames.forEach((action, index) => {
      let button = actions.children[index];
      if (!button) {
        button = document.createElement('button'); button.type = 'button'; button.className = 'transfer-action';
        button.addEventListener('click', () => { void session.fileTransfers.control(view.id, button.dataset.action).catch(() => {}); });
        actions.append(button);
      }
      button.dataset.action = action;
      button.textContent = { resume: '继续', pause: '暂停', cancel: '取消' }[action];
      button.setAttribute('aria-label', `${button.textContent}传输 ${view.name}`);
    });
  }
}
