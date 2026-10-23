# Connected devices and transfer history

Open **Connected Devices** from the desktop header or tray menu. The manager
separates **Online devices** from **Connection history**: a saved pairing in
history is not an active connection. The header count includes connected
devices only. Disconnect, reconnect or delete each pairing independently.

## Pair and share

- **Phone:** scan the computer's pairing QR code. Scan another computer to add
  it without replacing existing pairings. On the phone, use the online status
  beside the header to switch the active computer. Its clipboard, files,
  reminders and drafts stay separate from the other computers.
- **Computer:** paste the other computer's pairing link into **Connect another
  computer**. Computer-to-computer notifications and automatic clipboard sync
  start off. Enable automatic sync separately for a trusted computer if wanted.
- **Send one item:** choose **Send to Device** on a desktop clipboard item.
  On a phone, enter or paste text or select a file and tap **Send**. The PWA does
  not read or monitor the phone's system clipboard.

Automatic delivery to a phone starts with new clipboard items copied after
pairing. Older items require an explicit send. On Android the web app can be
used without installation; iPhone and iPad require adding it to the Home Screen
before Web Push can be enabled. OS permission and delivery rules still apply.

## Routes and active transfers

Automatic mode prefers direct WebRTC and falls back to the end-to-end encrypted
relay. Local-network mode uses the service for pairing/signalling but sends
content only over the direct channel. The relay stores no clipboard or file
body. Computer-to-computer local links require both computers to be reachable
on the local network.

Updated clients remove the 25 MB product limit only after verifying a local
route. Relay, cross-network, unknown and legacy routes keep the limit. Large
files wait for a verified local connection. Desktop and phone show confirmed
progress, transferred size and speed, with pause, resume and cancel controls.

Keep both ends open to resume an interrupted active transfer. Closing the
sender requires sending again. Large phone downloads need browser local file
storage and enough available quota; they do not bypass browser storage limits.

## Past file records

Select **Transfer history** in the desktop device manager's header. It retains
up to 100 records locally, newest first, for completed, sent, failed or cancelled
file transfers. They survive app restart; deleting a paired device also removes
its history records.

These are file-transfer metadata, not a file backup or a log of every clipboard
sync. Archived records cannot resume a transfer after restart. They also do not
prove that a phone browser finished saving a downloaded file to disk. To send
again, use an available source file or clipboard item while its source computer
is connected.

## 中文操作速查

从顶部或托盘打开“连接设备”。“在线设备”表示当前已连接，“连接历史”表示保留的
配对；历史里有设备不代表它在线。手机扫码，电脑粘贴对方配对链接；自动同步按设备
单独开启。手机只会在你输入或选文件并点击发送后分享内容，不监听系统剪贴板。

点击顶部“传输历史”查看最近 100 条已结束文件记录。记录保存在本机，重启后仍在，
删除配对设备也会移除该设备记录。历史不是文件备份，也不能用于重启后续传；活动
传输断线续传需要双端保持打开，大文件还需要已核验的局域网连接。

[All user guides](README.md)
