# 系统截图快捷键与划词插件

本文描述当前开发版。已发布版本的功能以对应 Release 为准。

在“资源管理 → 插件”中，点击插件名称、整行或“管理”打开详情。
Jev 保留原有配置；Windows 划词可在详情中启用并配置模型。

一级“插件”管理 DingDong 自己的可选功能。其他 Agent 客户端的插件清单位于
“资源 → Agent 插件”，目前按需读取本机名称、来源和配置状态。

## 系统截图快捷键

打开“资源管理 → 插件 → 截图 → 管理”：

1. 点击“截图快捷键”下的组合键按钮，按下自己的组合键；可恢复默认值。
   默认 Windows 为 **Ctrl+Alt+A**，macOS 为 **⌘⌥A**。
2. 打开“启用截图”。按所设快捷键，或点击“立即截图”。
3. 在系统截图工具中选择区域、编辑、复制或保存。

Windows 将自定义快捷键映射到 **Win+Shift+S**；macOS 打开系统“截屏”工具。
截图的界面、权限、标注、复制、自动保存与文件位置由系统工具及其现有设置处理。
DingDong 不修改系统快捷键，不读取截图像素，也不创建自己的框选或编辑窗口。

只有系统截图这一种方式，不提供编辑器切换或第三方截图组件入口。
系统快捷键本身继续可用；Windows 的 Win+Shift+S 不能再次注册为 DingDong 快捷键，
避免映射回自身。快捷键被系统或其他程序占用时，显示冲突并保留原配置。

配置单独保存在本机，重启保留。旧版本中的方式字段被忽略，已保存的快捷键和
启用状态继续使用；下次保存时去掉方式字段。保存失败会恢复原有快捷键。
停用或退出 DingDong 会释放自定义快捷键、取消尚未发出的唤起；已打开的系统工具由系统管理。
Linux 暂不支持此入口。

## Windows 划词

此前 Windows 无法划词的原因是仅 macOS 接入了原生选区监听和浮层；配置模型
无法补上缺失的平台实现。本次补齐 Windows UI Automation 取词、原生触发监听、
DingDong 浮条和模型结果面板。开源来源及适配范围见 [嵌入式组件说明](embedded-plugin-sources.md)。

在详情启用后，支持的程序内选择文字可显示复制、翻译、解释、润色浮条。
仅点击模型动作或追问才发送文字；自动读取不模拟复制，不修改剪贴板。
密码框、无法读取选区的程序不弹浮条。Token 使用系统安全存储，子窗口不接收密钥。
自动化测试覆盖请求取消、延迟结果、停用、坐标换算及模型协议；真实跨应用兼容性、
多屏高 DPI 和实际模型服务仍需人工验收。

## 验证

```powershell
flutter analyze
flutter test test/features/screenshot test/features/selection test/features/jev test/features/agent_plugins test/features/settings/workspace_shortcuts_test.dart
powershell -File scripts/test_screenshot_native.ps1 -FlutterRoot <Flutter SDK 根目录>
```

Windows 原生测试验证快捷键注册、冲突回退、重复请求、取消等待与停用清理，
不打开系统截图或采集屏幕。系统工具实际唤起、实体键盘与跨应用行为需在各平台验收。
`scripts/test_windows_selection_native.ps1` 验证原生取词的取消及生命周期；
系统拒绝前台焦点时，真实控件测试会明确跳过，不计为兼容性通过。
