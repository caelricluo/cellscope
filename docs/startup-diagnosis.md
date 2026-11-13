# Xcode 打不开运行窗口：排查与临时入口

## 当前结论

iOS 工程能通过默认 Xcode 编译，Issue Navigator 显示 No Issues。模拟运行的后台进程可以启动，但本机 Xcode 27.2 的 Device Hub 在创建实时设备视图时反复崩溃。因此，**后台测试通过不等于桌面上的模拟器窗口可用**。

观察到的 Device Hub 崩溃包括：

- `EXC_BAD_ACCESS / SIGBUS`：`swift_retain` 与 Observation 栈。
- `NSInvalidArgumentException / SIGABRT`：`AXPTranslator` 的 unrecognized selector。
- `EXC_BREAKPOINT / SIGTRAP`：AppKit 窗口约束更新栈。

停止调试、关闭当前模拟器、备份并临时移除 Device Hub 的设备和检查器选择后，其静态管理窗口可打开，但启动实时视图仍然崩溃。另一台现有 iPhone 模拟器也复现。原设备/检查器选择已恢复，未擦除模拟器数据。

Apple 的 [Device Hub 文档](https://developer.apple.com/documentation/xcode/device-hub) 说明新版通过该工具显示模拟设备；[Xcode 27.2 版本说明](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes) 也记录了较早 macOS 27.2 测试版上 Device Hub 意外退出的修复。当前现象与工具环境故障一致，但尚未证明就是版本说明中的同一个缺陷。

## 已提供的可操作临时入口

在 Finder 中打开项目的 `Preview` 文件夹，双击 **CellScope 预览.app**，或双击项目根目录的 **打开预览.command**。

这是同一套 SwiftUI、UIKit 标注与核心算法的 Mac Catalyst 本地预览，不依赖 Device Hub。它使用独立 bundle ID `com.cellscope.counter.preview`，不会替换原 iOS App；本地记录也属于独立容器。

已在真实 Mac 窗口中验证：49 个候选检测、删除到 48、撤销到 49、补标到 50、撤销、浓度/取液量、保存记录、结束进程后重启与恢复记录。

预览中可使用相册导入或模拟图体验。它不代替 iPhone 目镜拍照的真机验证。

## 重建预览

```sh
python3 scripts/create_project.py --preview
xcodebuild -project CellScopePreview.xcodeproj -scheme CellScope \
  -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath build-preview CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build
```

普通 iOS 工程仍然是 `CellScope.xcodeproj`；预览工程是独立的 `CellScopePreview.xcodeproj`。脚本的 `--preview` 不会重写 iOS 工程或其 Info.plist。

## 仍未恢复的部分

本机 Device Hub 的实时 iPhone 窗口尚未恢复。iOS GUI 验证需要可正常工作的 Xcode/Device Hub 环境，或使用已连接、已签名的物理 iPhone。没有修改系统安全设置，没有上传崩溃日志，也没有通过重置模拟器删除数据。
