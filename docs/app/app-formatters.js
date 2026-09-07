// Pure display formatting keeps DOM rendering free of protocol details.
function iconForKind(kind) {
  const icons = {
    url: "../assets/symbols/link.png",
    command: "../assets/symbols/command.png",
    code: "../assets/symbols/code.png",
    json: "../assets/symbols/code.png",
    path: "../assets/symbols/path.png",
    file: "../assets/symbols/path.png",
    image: "../assets/symbols/image.png",
  };
  return icons[kind] || "../assets/symbols/text.png";
}

function kindLabel(kind) {
  const labels = {
    url: "链接",
    command: "命令",
    code: "代码",
    json: "JSON",
    path: "路径",
    file: "文件",
    image: "图片",
  };
  return labels[kind] || "文本";
}

function formatTime(value) {
  const date = validDate(value);
  if (!date) return "未记录";
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour12: false,
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function validDate(value) {
  if (value === null || value === undefined || value === "") return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function formatLifecycleTime(value) {
  const date = validDate(value);
  if (!date) return "未记录";
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).format(date);
}

function formatDuration(milliseconds) {
  if (!Number.isFinite(milliseconds) || milliseconds < 0) return "";
  let seconds = Math.floor(milliseconds / 1000);
  if (seconds < 1) return "不足 1 秒";
  const days = Math.floor(seconds / 86_400);
  seconds %= 86_400;
  const hours = Math.floor(seconds / 3600);
  seconds %= 3600;
  const minutes = Math.floor(seconds / 60);
  seconds %= 60;
  const parts = [];
  if (days) parts.push(`${days} 天`);
  if (hours) parts.push(`${hours} 小时`);
  if (minutes) parts.push(`${minutes} 分`);
  if (seconds || parts.length === 0) parts.push(`${seconds} 秒`);
  return parts.join(" ");
}

function formatBytes(value) {
  if (!Number.isFinite(value)) return "";
  if (value < 1024) return `${value} B`;
  if (value < 1024 * 1024) return `${Math.round(value / 1024)} KB`;
  return `${(value / (1024 * 1024)).toFixed(1)} MB`;
}


export {
  formatBytes,
  formatDuration,
  formatLifecycleTime,
  formatTime,
  iconForKind,
  kindLabel,
  validDate,
};
