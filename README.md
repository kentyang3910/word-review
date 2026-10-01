# 词页复习 · iOS 0.1.0 工程

以用户已跑通的 Android 0.2.1 为行为基准，使用 SwiftUI、WidgetKit、App Intents 和 PDFKit 实现。最低 iOS 17，面向用户提供的 iPhone 17 / iOS 26.6.1 测试设备。

**当前交付是源码工程，不是已签名、可直接安装的 IPA。** 当前工作环境为 Windows，没有 Xcode，也没有执行苹果编译器、iOS 模拟器测试或 iPhone 真机测试。静态语法检查不能替代构建。下一步需在 Mac 或云端 macOS 运行构建和测试、修复实际诊断，再配置签名。

## 功能实现

- 中号/大号主屏幕组件，显示三个待复习词条；方框在单词右边。
- 点击方框通过 App Intent 保存状态，无需打开主应用。绿色对勾、淡细删除线保留。
- 剩余超过三个时原位补词；最后三个及以下删除后向上补位，按屏幕当前顺序保留。
- 连续点击时，每个词的反馈截止时间随词一起移动；旧版本/旧轮次按钮不能修改新轮次。
- 本轮全部勾选累计一次，提供重新复习；以手机当地日期跨天重置。
- 点击词条或组件背景打开完整 PDF，右上角显示进度。原生 PDFView 支持缩放和多页滚动。
- 本地 PDF 导入及词表校对；20 MB、50 页、1000 词条限制。
- 固定 HTTPS PDF 或 deck.json 地址同步；原 GitHub Pages 链接可继续使用。words 存在时以清单为准，否则在手机提取。
- PDFKit 字符坐标 + Core Graphics 表格边框识别，保留短语/单元格内换行并跨页去重；无可识别表格时回退至文字规则。没有 OCR。
- App Group 保存 PDF 和状态，文件锁保证主应用与扩展的读改写互斥，原子写入；下载失败保留旧资料。

## iPhone 与安卓的区别

WidgetKit 控制刷新时机。代码请求约 0.7 秒的勾选反馈并生成后续时间线，但不能保证 iOS 在这个时间点精确重绘；系统可能合并更新。状态在点击后立即持久化，后续交互会先处理已到期反馈。需要用真机验证是否能看到短暂绿勾和细线。

应用在进入前台、系统安排的后台刷新以及小组件获取时间线时检查远程资料，设置了节流和缓存。系统省电策略会影响频率，不保证电脑发布后立即到达。主屏幕组件必须由用户添加一次，应用无法静默添加。

这些机制依据苹果官方文档：

- [交互式小组件](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)
- [小组件时间线](https://developer.apple.com/documentation/widgetkit/timeline)
- [共享 App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- [PDFPage 字符与坐标](https://developer.apple.com/documentation/pdfkit/pdfpage)

## 工程文件

| 文件/目录 | 用途 |
| --- | --- |
| WordReview.xcodeproj | 可用 Xcode 打开的项目，含应用、小组件和测试三个 target |
| Core | 复习状态、词表与表格解析；与安卓规则一致的 Swift 移植 |
| Shared | 主应用和小组件共用的数据存储、同步、PDF 提取、卡片视图、点击操作 |
| App | iPhone 主界面、导入校对、PDF 阅读器、后台调度 |
| Widget | 中号/大号桌面小组件与时间线 |
| Config/Settings.xcconfig | 包名、共享组和签名团队配置入口 |
| Tests | 19 项纯逻辑测试 + 4 项 iOS PDFKit/存储测试；尚未执行 |
| Tests/Fixtures/table.pdf | 合成的双页词表测试文件，不是用户的原始 PDF |
| Scripts/validate-mac.sh | Mac 上执行逻辑测试、iOS 模拟器测试和未签名设备构建 |
| .github/workflows/ios-check.yml | 云端 macOS 构建流程，仅配置，尚未上传/运行 |

## 有 Mac 时构建

1. 使用支持 iOS 17 或更新 SDK 的 Xcode。连接实际 iOS 26 手机调试时，Xcode 还需要支持该设备系统。
2. 打开 WordReview.xcodeproj。无需第三方 Swift 包、CocoaPods 或 XcodeGen。
3. 首先运行 `bash Scripts/validate-mac.sh`，排查编译与测试错误。脚本选择本机第一个可用 iPhone 模拟器。
4. 真机安装前，在 `Config/Local.xcconfig` 填写自己的唯一包名、App Group 和 Apple Team ID，或者在 Xcode 中配置。两个 target 必须属于同一团队、启用同一 App Group。
5. 选择实际 iPhone 运行，或按所用开发者账号的权限配置归档和分发。苹果账号、证书和描述文件不包含在本工程中。

本地配置示例（替换成自己的值，不要直接照抄）：

```xcconfig
APP_BUNDLE_ID = com.yourname.wordreview
APP_GROUP_IDENTIFIER = group.com.yourname.wordreview
REVIEW_REFRESH_IDENTIFIER = com.yourname.wordreview.refresh
DEVELOPMENT_TEAM = YOURTEAMID
```

普通 Apple ID 和开发者会员可用的能力/分发方式不同，不能假定普通账号能完成本工程的 App Groups 签名。以苹果账号中实际可用的能力为准：[苹果能力列表](https://developer.apple.com/help/account/reference/supported-capabilities-ios)。不要把登录密码、证书私钥或描述文件提交到公开仓库。

## 没有 Mac 时

准备好的 GitHub Actions 流程使用云端 macOS，执行测试、模拟器构建和未签名的设备构建。它需要把本工程放在仓库根目录；推送到 `ios` 分支会运行。当前未将源代码上传到用户仓库，也没有启动云端任务。

如果沿用现有公开 `kentyang3910/word-review` 仓库，建议只在独立 `ios` 分支添加工程，保留既有资料发布分支和 GitHub Pages 设置。这样会公开本工程源码，因此先取得用户确认。工作流构建产物标注 UNSIGNED，不能直接安装到 iPhone。

要从云端构建继续到手机安装，还需确定苹果签名方案。TestFlight 分发需要具备相应 Apple Developer Program / App Store Connect 权限。签名材料应放入云端构建平台的专用 Secrets，不写入源码；本次没有配置任何签名材料，也没有上传 App Store/TestFlight。

## 手机验收

安装成功后，在应用里连接既有 deck.json 链接。长按主屏幕添加“词页复习”中号或大号组件。依次核对右侧方框、前中后三行原位补词、剩余三个时向上补位、快速连续点击、两轮计数、点击词条阅读 PDF、离线保留、远程替换、跨天和重启后的状态。

需要特别检查原始 9.30 PDF 在 PDFKit 上是否得到完整 30 词条；安卓上的提取验证结果不能当成苹果上的验证结果。如果系统没有按请求显示短暂勾选反馈，需要根据真机结果调整动画方式。
