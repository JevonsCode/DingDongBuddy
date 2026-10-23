# Skill version history

Open **Resource Manager**, select a Skill and use the **Version history** icon
in its detail header. If the editor has unsaved changes, resolve them before
opening history.

## Compare and restore

1. Select the left and right versions independently. The default comparison is
   the previous version against the latest; nonadjacent and reversed comparisons
   are supported.
2. Select a file to inspect additions, deletions and text changes. Binary files
   are identified as binary changes; executable permission changes and the
   Skill name/source URL are included in the comparison.
3. To restore, choose the desired version on the right and confirm the version
   named in the restore dialog. The complete saved document and package are
   restored together, including scripts, references, assets and binary files.

Restoration appends a new version. It preserves the current resource ID,
enablement, scope, Agent delivery configuration, groups, notes and usage
counters. Agent copies use the existing synchronization path. Restoration uses
the local snapshot and does not fetch the source URL again.

## What gets recorded

| Action | History behavior |
| --- | --- |
| Load an existing Skill for the first time after upgrading | Records the currently available content as the initial version |
| Save a new Skill | Records version 1 after the save succeeds |
| Manually save or refresh online | Records a version when the name, source URL, document or package changes |
| Save or refresh without a content change | Does not create a duplicate version |
| Change scope, enablement, notes or delivery configuration | Does not create a content version |
| Restore a version | Appends a new version and records which version it restored |

History is local and survives application restarts. It starts with content
available when recording begins; earlier remote revisions cannot be recovered.
One saved version can be viewed but has no second version to compare. History
is not automatically shared with paired devices.

## 中文操作速查

打开“资源管理”，选择 Skill，点击详情顶部的“版本历史”图标。左右两端可独立选择
版本，包括不相邻版本；选择文件后查看增加、删除和文本差异，二进制文件显示变更提示。
要恢复时，将目标版本选在右侧，并确认弹窗中的版本号。

手动保存、在线刷新在内容变化时留存完整包；恢复会追加新版本，保留当前作用域、
启用状态和 Agent 交付设置。历史保存在本机，重启后仍在；开始记录之前的版本无法补回。

[All user guides](README.md)
