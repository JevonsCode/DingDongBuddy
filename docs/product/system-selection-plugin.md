# 系统划词插件使用说明

当前源码把 Fuli 的 `examples/dingdong-selection-plugin` 原生能力接入了
DingDong 主程序。这个入口只出现在包含该功能的 macOS 构建里；旧的正式安装包
不会因为 Agent 加载了 Skill 而自动获得划词功能。

## 开始使用

1. 打开 DingDong 的“设置”，找到“系统级划词”，开启开关。
2. 如果显示需要辅助功能权限，点击权限助手，在 macOS“系统设置 → 隐私与安全性
   → 辅助功能”中允许当前运行的 DingDong。DEV 构建与正式应用是不同的权限身份。
3. 返回设置并点击“刷新状态”。显示“运行中”后，在支持辅助功能选区的应用里选中文字。
4. 点击浮层的“复制”“翻译”或“解释”。`⌥⌘C` 可以直接复制；如果应用没有暴露安全的
   选区，插件会提示无法读取，此时请使用应用自己的复制功能。

辅助功能权限由用户授予，不会自动打开。关闭划词开关会移除选区监听、清空暂存选区、
关闭浮层并取消进行中的模型请求；剪贴板历史和 Agent 提醒仍可正常使用。

## 配置翻译和解释

复制不需要模型或 Token。翻译和解释必须有用户配置的可用模型服务。
“运行中”只表示划词监听已启动，不代表模型服务已经启动或验证成功。

| Provider | 需要准备什么 |
| --- | --- |
| Ollama | 自行安装并启动本地服务，填入已安装模型的名称；可选择回复后卸载模型 |
| LM Studio | 启动本地兼容服务，填入服务实际提供的模型名；自动卸载在 LM Studio 内配置 |
| OpenRouter / Gemini | 填入可用服务地址、模型名和你自己的 API Token |
| OpenAI-compatible | 填入兼容服务地址和模型名；远程服务必须为 HTTPS，并使用自己的 Token |

先应用模型设置，再保存 Token。Token 按 Provider、协议、主机和端口隔离存入
macOS 钥匙串；换到其他服务地址时不会沿用原地址的 Token。Token 不写入偏好设置、
日志、剪贴板或 Fuli。状态检查只检查条目是否存在，不加载 Token 正文。

预设模型名只是可编辑的配置默认值，不代表已经下载模型、启动服务或获得免费额度。
例如，已经安装 Ollama 后，可以自行运行 `ollama run qwen3:0.6b` 下载并启动预设模型，
然后填入 `http://127.0.0.1:11434` 和 `qwen3:0.6b`；也可以改用自己已安装的模型。
命令和模型信息见 [Ollama 模型页](https://ollama.com/library/qwen3:0.6b)，
服务接口与卸载参数见 [Ollama API 文档](https://docs.ollama.com/api/chat)。

本地 Provider 只允许回环 HTTP 地址；远程端点必须使用 HTTPS，不接受 URL 内嵌账号、
查询参数或片段，也不会跟随跨源重定向。

只有主动选择翻译或解释才会把当前选区发送给所选 Provider。划词模块不单独持久化
选区；主动点击复制后，文本会进入系统剪贴板，并按你的剪贴板历史设置处理。
每次最多处理 10,000 个字符，网络响应超过 1 MiB 会被拒绝。

## 与 Fuli 示例、Skill 的关系

| 部分 | 用途 | 是否直接启用系统划词 |
| --- | --- | --- |
| Fuli 示例中的 Skill 包 | 向 Agent 提供开发指引和包文件；仍受项目作用域约束 | 否 |
| 示例的 JavaScript `plugin.json` 与权限运行时 | 验证命令声明、权限路由和开关契约 | 否，不是系统选区宿主 |
| 示例的独立 DingDong Selection 应用 | 独立运行的原生菜单栏助手 | 是，使用它自己的辅助功能身份 |
| 当前 DingDong 内置划词插件 | 复用原生选区与模型组件，由 DingDong 管理设置、权限与开关 | 是，无需第二个常驻应用 |

使用 DingDong 内置划词时，不要同时运行独立 DingDong Selection 应用，避免重复浮层
和快捷键监听。内置功能不要求 Fuli 服务常驻，也没有把 JavaScript 示例包装成任意
第三方代码的安全沙箱。原生代码位于 `macos/Runner/SelectionPlugin/`。

## 常见问题

- **找不到设置入口：** 检查是否运行 macOS 上的新构建；旧版本和 Windows 不显示此功能。
- **开启后无浮层：** 检查当前应用的辅助功能权限，再刷新状态；先用 TextEdit 等可暴露
  选区的文本应用验证。密码控件、未知控件和无法安全读取的选区会被拒绝。
- **有两个浮层或复制响应两次：** 退出独立 DingDong Selection 助手，只保留一个宿主。
- **复制能用，翻译失败：** 确认模型服务已经启动，地址和模型名正确；云端还需要有效 Token。
- **切换服务后提示缺少 Token：** 为新地址保存自己的 Token，这是预期的隔离行为。

## 本地验证

在 DingDongBuddy 仓库根目录执行：

```sh
flutter test test/features/selection test/platform/selection_plugin_native_contract_test.dart
xcrun swift test --package-path macos/Runner/SelectionPlugin
flutter test -d macos integration_test/desktop_release_acceptance_test.dart
flutter build macos --debug
```

自动化测试使用明确的内存替身和测试文本，不读取真实钥匙串，不自动授予系统权限，
也不把模拟的模型响应当成真实服务结果。真实模型质量、额度和跨应用兼容性需要在用户
自己的服务和已授权应用中验证。
