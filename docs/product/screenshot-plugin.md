# 截图插件与插件详情

本说明对应截图开发分支；当前正式版 1.9.1 尚不包含这次新增的截图插件。

在“资源管理 → 插件”中，点击插件名称或整行即可打开详情，使用返回按钮回到列表。
Jev 保留原有配置；划词在 Windows 上显示平台支持说明。

## Windows 截图

1. 打开“截图”详情，启用插件。默认全局快捷键为 **Ctrl+Alt+A**。
2. 点击快捷键按钮，再按自己的组合键；可恢复截图默认值。与叮咚现有快捷键
   重复，或被系统/其他程序占用时，显示冲突并保留原配置。
3. 用快捷键或“立即截图”冻结当前桌面，拖动框选区域。
4. 使用浮动工具条添加矩形、箭头或文字。文字输入后按 Enter 确认，Esc 放弃
   当前文字；之后 Esc 取消截图。右键或“重选”重新框选。
5. 点击“复制”或按 Ctrl+C / Enter，复制图片；点击“保存”或按 Ctrl+S，选择 PNG
   保存位置。Ctrl+Z 撤销最后一个标注。

复制/保存失败会在截图浮层提示，可重试或取消。取消保存对话框会返回编辑。
关闭插件会释放快捷键并关闭正在编辑的截图。叮咚退出后快捷键不再生效。

截图覆盖 Windows 虚拟桌面，保留物理像素尺寸。不同屏幕之间没有显示器覆盖的
空白区域显示为黑色。界面仅提供基础矩形、箭头和文字标注；未实现飞书的滚动
长截图、OCR、贴图或马赛克。macOS/Linux 详情会明确提示截图暂未支持。

截图只在内存中处理，不联网，不自动保存。主动复制后，系统剪贴板会收到图片，
叮咚的剪贴板历史是否收录由现有剪贴板监控设置决定。取消后释放截图内存。
配置用一个独立偏好键保存，由主程序串行处理；详情窗口不单独注册快捷键。

## 划词检查结论

当前 Windows 划词不能使用：`lib/main.dart` 只在 macOS 注入原生划词网关，
实际选区监听及模型交互在 `macos/Runner/SelectionPlugin/`。Windows runner
没有对应的选区监听/浮层。模型地址、Token 或开启设置不能补上原生实现。

本次只让 Windows 用户能在插件详情看到原因，没有实现或宣称修复 Windows 划词。
已有划词 Dart 测试覆盖配置/状态/网关替身，不代表真实跨应用划词已验收。

## 验证

```powershell
flutter analyze
flutter test test/features/screenshot test/features/selection test/features/jev test/features/agent_plugins test/features/settings/workspace_shortcuts_test.dart
powershell -File scripts/test_screenshot_native.ps1 -FlutterRoot <Flutter SDK 根目录>
```

原生测试显示临时测试画面，在主屏幕区域验证真实捕获、PNG 裁剪/矩形像素、
箭头及文字/撤销、取消与关闭。测试替换剪贴板和文件对话框接口，不修改用户剪贴板。
