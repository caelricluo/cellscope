# Development / 开发指南

## English

The application targets iOS 17+ and uses SwiftUI, UIKit and Foundation. The image-processing core has no third-party dependencies.

```text
cellscope/                    Application, views, image services and records
cellscope/en.lproj/           English UI and permission strings
cellscope/zh-Hans.lproj/      Simplified Chinese UI and permission strings
Sources/cellscopeCore/        Detection, grid geometry, calculations and localization helpers
Tests/cellscopeCoreTests/     Swift Package tests
cellscopeUITests/             iOS interaction and localization tests
scripts/                     Project generation, diagnostics and packaging
```

```sh
swift test -c release
python3 scripts/check_localizations.py
xcrun simctl addmedia booted Tests/Fixtures/three-cells.png
xcodebuild -project cellscope.xcodeproj -scheme cellscope \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
```

Use an available simulator name on the development machine. `python3 scripts/create_project.py` regenerates the iOS project; `--preview` generates the separate Catalyst project. Regeneration replaces project build settings.

Photo import UI tests use the synthetic image in `Tests/Fixtures/three-cells.png`; seed it into the selected simulator before running the UI suite. New image records use a PNG format field; records without that field retain their JPEG filenames.

The detector runs outside the main actor. Parameter and region changes are debounced by 180 ms. Earlier jobs are cancelled, and revision checks prevent stale results from replacing the current image or corner. Grayscale data is cached per active image.

Localization is maintained in standard `.strings` resources. `tr` resolves static strings and `trf` formats translated templates. Chinese and English resources share identical keys and format placeholders. The bundle identifier remains stable for application updates; the legacy sample directory is migrated when necessary.

For image-level diagnostics on macOS:

```sh
swiftc -O Sources/cellscopeCore/*.swift scripts/analyze_image.swift -o /tmp/cellscope-analyze
/tmp/cellscope-analyze image.jpg result.json singleLarge 1 automatic
```

The optional arguments select counting mode, sensitivity (`0...1`) and polarity (`automatic`, `dark`, `bright`). JSON includes grid geometry, detection settings, markers and rejection totals. Counts are populated when an automatic reference is available for the requested mode.

## 简体中文

应用面向 iOS 17 及以上，使用 SwiftUI、UIKit 和 Foundation。图像处理核心无第三方依赖，目录结构和验证命令见上文。

根据本机设备列表选择可用的模拟器名称。`python3 scripts/create_project.py` 重新生成 iOS 工程；`--preview` 生成独立 Catalyst 工程。重新生成会替换工程编译配置。

相册导入 UI 测试使用 `Tests/Fixtures/three-cells.png` 合成图，运行前导入目标模拟器。新图像记录带 PNG 格式字段；缺少该字段的历史记录沿用 JPEG 文件名。

识别任务在主线程之外运行。参数和区域变化合并为 180 ms 的请求，取消旧任务，并通过版本检查阻止旧结果覆盖当前图像或角位。灰度数据按当前图像缓存。

macOS 图像诊断命令见上文，可指定计数模式、灵敏度和目标明暗。输出 JSON 包含网格几何、识别参数、标记和筛除数量；找到对应模式的自动边框时输出计数。

本地化使用标准 `.strings` 资源：`tr` 解析普通文本，`trf` 格式化带参数文本。中英文使用相同键和占位符。Bundle Identifier 保持稳定以支持更新，历史样本目录按需迁移。
