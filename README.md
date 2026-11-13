# CellScope · iOS 显微图像细胞计数

原生 SwiftUI iPhone 应用，支持 iOS 17 及以上。所有图像与检测计算在设备本地进行，不需要服务器、账号或 API Key。

## 已实现

- 相机拍摄、系统相册选图，导入时校正照片方向并限制处理分辨率。
- Neubauer 三模式：4× 完整九宫格自选计数格；10× 四角各拍一张并取平均；红细胞中央五中格。
- 导入时自动定位网格边框，区分中央密集格、完整九宫格和四角大格候选；支持轻微倾斜的四边形对齐，失败时手动框选。
- 手机边框编辑：8 个拖动点、框内整体移动、拖动放大镜、1/5 px 方向键微调；双指缩放与移动。
- 精细尺度局部对比度、轮廓连通域与自动尺寸估计，适配小型相差环状目标，排除长网格和视野边缘。
- 检测参数实时预览：图像与标记常驻，滑块变化后自动更新细胞数、浓度与取液量；合并连续变化并取消旧任务。
- 手动补标、删除、撤销；调整边框或选择分格后自动重新计数。
- 实际面积、腔室深度、总稀释倍数、原液总体积与目标细胞数输入。
- 原液浓度、原液总细胞数、目标对应取液体积，及原液不足提示。
- 本地样本记录（原图、标记、参数与结果可恢复），删除记录。
- 实时计算、直接保存及导出带 BOM 的 UTF-8 CSV 和标记图。
- 各模式独立模拟图：4× 全九格 81 个 / 四角 36 个，10× 四张各 49 个，红细胞标准五中格 20 个；结果及 CSV 标注为模拟数据。

## 启动

**如果 Xcode 显示运行/Launching，但没有 iPhone 窗口：** 本机已复现 Device Hub 崩溃。可先双击项目根目录的 `打开预览.command`，或 `Preview/CellScope 预览.app`，在 Mac 上操作同一套计数界面，预览另有「从本机文件导入」入口。[排查记录与临时入口](docs/startup-diagnosis.md) 说明了已验证结果和仍未恢复的 iOS 模拟器显示问题。

1. 用 Xcode 打开 `CellScope.xcodeproj`，选择 `CellScope` scheme。
2. 选择一个 iPhone 模拟器并运行。首页点「使用模拟图体验」即可走通流程。
3. 真机运行：连接 iPhone，在 Signing & Capabilities 中选择自己的 Team，并将 Bundle Identifier 改为唯一值，再运行。首次使用相机时允许权限。
4. 真机拍摄需要将手机镜头对准显微镜目镜，建议使用目镜转接支架。模拟器没有相机，可选相册或模拟图。

本工程无第三方依赖，不需要 CocoaPods、XcodeGen 或联网下载模型。`scripts/create_project.py` 可重新生成工程（会覆盖工程配置；如已设置自己的签名 Team，重新生成后需重设）。

`python3 scripts/create_project.py --preview` 只生成独立的 Mac Catalyst 预览工程，不改写原 iOS 工程。

## IPA 与 GitHub Release

私有仓库为 [caelricluo/Cellcounter](https://github.com/caelricluo/Cellcounter)。[v0.3.0 prerelease](https://github.com/caelricluo/Cellcounter/releases/tag/v0.3.0) 提供 **未签名 iPhoneOS arm64 IPA**，需要有效 Apple 签名和 provisioning profile 后才能安装到 iPhone。可在 Mac 上运行 `scripts/build_unsigned_ipa.sh` 重建，输出位于 `dist/`，包含 IPA、JSON 清单和 SHA-256 文件。详见 [发布与打包说明](docs/distribution.md)。

## 计算与校准

| 模式 | 需要框选的物理区域 | 实际计入的面积 | 统计方式 |
| --- | --- | --- | --- |
| 4× 完整九宫格 | 完整 3×3 mm 网格 | 全九格 9 mm²；四角 4 mm²；自选按格数计算 | 只统计高亮大格，显示分格计数 |
| 10× 单大格四角分拍 | 四张图各框住 1×1 mm 完整大格 | 四张合计 4 mm² | 左上 A1、右上 A3、左下 C1、右下 C3 分别计数后取平均 |
| 红细胞 | 中央 1×1 mm 完整大格（5×5 中格） | 默认四角加中心 5 中格 × 0.04 = 0.2 mm² | 只统计选中中格；可自选，也可统计全部 25 中格 |
| 自定义 | 面积已知的矩形 | 手动填写 | 保留原有自由计数流程 |

这些模式以 **Neubauer improved（改良式）** 为模板。厂家 [Marienfeld 的网格规格](https://www.marienfeld-superior.com/counting-grids.html) 给出了 3×3 个 1 mm² 大格、中央 25 个 0.04 mm² 中格，以及每个中格的 16 个 0.0025 mm² 小格。中央分格不同的旧式 Neubauer 请用自定义模式。

10× 四角图像完成计数后自动显示平均与整组结果。其他模式完成识别后立即计算，无需面积确认或复核开关。每张照片的原图、ROI、标记和检测参数分别保存，切换角位不会丢失当前图的标记。稀释倍数和原液体积属于整组样本，请使用相同制样条件。

```text
观测体积 (mL) = 框选面积 (mm²) × 腔室深度 (mm) ÷ 1000
原液浓度 (cells/mL) = 标记细胞数 × 总稀释倍数 ÷ 观测体积
原液总细胞数 = 原液浓度 × 原液总体积 (mL)
所需原液体积 (µL) = 目标细胞数 ÷ 原液浓度 × 1000
```

例如 1 mm²、深度 0.1 mm 的大格内有 50 个细胞，稀释倍数为 2：原液浓度为 1,000,000 cells/mL，100,000 个细胞需要 100 µL 原液。参照 [Thermo Fisher 血细胞计数板计数协议](https://www.thermofisher.com/us/en/home/references/gibco-cell-culture-basics/cell-culture-protocols/counting-cells-in-a-hemacytometer.html)。

标准模式按所选网格给出计数面积，腔室深度默认 0.1 mm。自定义模式填写区域面积。面积、深度、稀释倍数、原液体积与目标细胞数修改后立即参与计算。自动四边形在网格坐标内映射计数分区，适配轻微倾斜；明显旋转、严重透视或缺边时应重拍或手动校准。原始图像不做重采样变形。

按用户指定口径：**记上不记下，记左不记右；相连团块计为一个对象。** 自动候选使用对象包围边缘判断压线，触及右/下边界时排除，触及上/左边界时计入；三线边界以中间线对齐。手动补标的边缘用标记圆估算，边界对象需复核。旧记录缺少对象边缘数据时保留原有记录，不静默重算；重新检测后使用新规则。

默认深度 0.1 mm 时，10× 浓度 = 四角平均计数 × 总稀释倍数 × 10⁴ cells/mL；红细胞五中格浓度 = 五中格总计数 × 总稀释倍数 × 50,000 cells/mL。平均值保留小数参与计算，不先取整。红细胞模式同时显示 cells/µL。

## 检测实现与适用范围

`CellDetector.swift` 使用高斯精细尺度与局部背景差分恢复细胞暗环/亮目标，进行一像素闭运算，再按连通域形状、对比度及估计尺寸筛选。相连支持域作为一个对象，不用分水岭拆分。直接在整图检测后按对象边缘与所选分格筛选，避免先裁剪把边界团块切断。手动直径上限对团块允许放宽至 3 倍。

`GridDetector.swift` 独立提取明/暗两种极性的长支撑线，拟合中央 20 个细格间隔或四角 4 个分格间隔，再从局部线条稳健拟合四边形。三线束取中线。完整九宫格还必须有可见的外侧四边证据，不会把裁切的中央大格直接外推为 9 mm²。识别结果与当前模式不匹配时暂停自动计数，保留手动框选入口；导入后自动计数；手动调整边框后自动重算。

0.2.0 已用用户提供的 1440×1440 原图做本地回归：同一自动中央区域旧版 69 个候选，新版 207 个；标准五中格 39 个。局部预选的 19 个清晰对象，旧版命中 4 个，新版命中 19 个（7 px 中心匹配、一对一）。**候选数量与局部命中不等于全图真值或准确率**，没有完成全图逐细胞标注。原始附件、诊断图与本地审计坐标保留本机，不提交仓库。见 [本轮图像回归](docs/image-analysis.md)。

算法仍是传统图像处理，不含经训练的细胞分类模型。离焦、低对比度、大团块和杂质仍可能漏检/误检；不判断活死或细胞亚型。请用代表性样本与人工计数对照，可使用补标、删除和撤销编辑标记。

10× 记录包含四张独立大格图，CSV 包含每角计数、四角平均及整组结果，导出四张独立标记图。4× 和红细胞模式导出所选分格的计数与一张标记图。原液浓度和取液量基于所保留的计数对象；团块按 1 个，因此不是团块内部单细胞总数的估计。需要活细胞浓度时须按实验标准手动筛选目标标记。

## 验证

```sh
# 无需模拟器的计算与检测测试
swift test

# iOS 模拟器编译
xcodebuild -project CellScope.xcodeproj -scheme CellScope \
  -sdk iphonesimulator -configuration Debug -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build

# 选择本机存在的 iPhone 模拟器名称
xcodebuild -project CellScope.xcodeproj -scheme CellScope \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
  -parallel-testing-enabled NO test
```

核心测试覆盖标准与自定义计数体积、四角平均的小数精度、Neubauer 面积、红细胞单位换算、压线规则、相连团块、旧标记解码、无效输入、原液不足和明暗检测。UI 测试覆盖三模式实际检测、四角选格、全屏补标/删除/撤销、逐角计数、保存与重启后的本地历史。0.3.0 新增边框微调与参数实时预览流程，详情见 [交互更新](docs/live-interaction.md)。实际测试结果与界面截图见 [验证记录](docs/verification.md)。

## 结构

```text
CellScope/                    SwiftUI 界面、相机/相册、标注视图、本地存储
Sources/CellCounterCore/       与 UI 解耦的检测与计算逻辑
Tests/CellCounterCoreTests/    Swift Package 核心单元测试
CellScopeUITests/             iOS 端到端 UI 测试
CellScope.xcodeproj/          可直接打开的 Xcode 工程及共享 scheme
scripts/                     工程生成、代码绘制图标脚本
```

Android 尚未实现，本次按需求先完成 iOS。
