# cellscope

[English](README.md) · [简体中文](README.zh-CN.md)

**cellscope** 是原生 iOS 显微图像细胞计数应用，面向改良 Neubauer 血细胞计数板。应用在设备上完成网格定位、可编辑细胞识别、浓度计算和悬液取液规划。

## 功能

- 使用手机相机拍摄，或从相册导入显微图像。
- 自动定位网格边框；通过角点、边线、整体平移、局部放大镜和 1/5 px 控件微调。
- 调节识别参数时，同屏查看图像、标记、细胞数、浓度和取液量。
- 支持完整九宫格、四角分别拍摄、中央红细胞分格及自定义面积。
- 记上不记下、记左不记右；每个相连团块计作一个对象。
- 本地保存样本，导出 CSV 报告与标记图。
- 根据设备的 App 语言显示简体中文或英文。

## 开始使用

最低系统版本为 **iOS 17**。开发与打包需要 macOS、Xcode 和 iOS SDK。

```sh
git clone https://github.com/caelricluo/cellscope.git
cd cellscope
open cellscope.xcodeproj
```

选择 **cellscope** scheme 和 iPhone 模拟器或设备。选择计数模式后拍摄、导入图像或载入演示样本。边框、标记和计算参数发生变化时，结果自动更新。

在 Mac 上运行 `Open cellscope.command` 可启动 Catalyst 预览。预览使用相同应用代码，并提供本机图像文件导入入口。

## 计数模式

| 模式 | 参考区域 | 计数面积 |
| --- | --- | --- |
| 完整九宫格 | 完整 3×3 mm 网格 | 全九格 9 mm²、四角 4 mm²，或自选大格 |
| 四角分拍 | A1、A3、C1、C3 各一张 | 每格 1 mm²，按四角平均计数换算浓度 |
| 红细胞 | 中央 1×1 mm、5×5 中格 | 默认四角加中心五中格，共 0.2 mm² |
| 自定义 | 自定义区域 | 输入实际面积，单位 mm² |

```text
观测体积 (mL) = 面积 (mm²) × 腔室深度 (mm) ÷ 1000
原液浓度 (cells/mL) = 计数 × 稀释倍数 ÷ 观测体积
原液总细胞数 = 浓度 × 原液体积 (mL)
所需原液体积 (µL) = 目标细胞数 ÷ 浓度 × 1000
```

## 编译与测试

```sh
swift test -c release
python3 scripts/check_localizations.py
xcodebuild -project cellscope.xcodeproj -scheme cellscope \
  -sdk iphonesimulator -configuration Release \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
scripts/build_unsigned_ipa.sh
```

打包脚本在 `dist/` 中生成未签名 iPhoneOS arm64 IPA、JSON 清单及 SHA-256 校验文件。真机安装使用完成相应签名的构建，详见[发布与分发](docs/distribution.md)。

## 文档

[使用指南](docs/user-guide.md) · [开发指南](docs/development.md) · [算法与计算](docs/algorithm.md) · [验证记录](docs/verification.md) · [更新日志](CHANGELOG.md)

安装包位于 [GitHub Releases](https://github.com/caelricluo/cellscope/releases)。

## 作者

- 作者：[caelricluo](https://github.com/caelricluo)
- 共同作者 / Co-author：**Codex GPT-6.1 Sol**

参见 [AUTHORS.md](AUTHORS.md) 和[贡献指南](CONTRIBUTING.md)。
