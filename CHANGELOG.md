# Changelog / 更新日志

## 0.7.0 — Android

- Added a native Kotlin/Jetpack Compose Android application for Android 8.0 and later.
- Ported grid detection, noise-adaptive bright/dark cell detection, projective geometry and counting rules to a tested Kotlin core.
- Added camera and Photo Picker acquisition, four counting modes, live parameter preview, magnified frame editing and one/five-pixel nudges.
- Added independent concentration, total-cell and volume calculations, lossless PNG records, session restoration and CSV/annotation sharing.
- Included English and Simplified Chinese, parameter reset controls and @caelricluo / Codex GPT-6.1 Sol attribution.
- Published an installable development-signed, non-debuggable APK and an unsigned APK. iOS remains at 0.6.1.

- 新增 Kotlin / Jetpack Compose 原生 Android 应用，支持 Android 8.0 及以上。
- 移植网格定位、噪声自适应亮暗细胞检测、透视几何与计数规则，并提供 Kotlin 核心回归测试。
- 支持相机、系统照片选择器、四种计数模式、实时调参、放大框选与 1/5 像素微调。
- 支持独立更新的浓度、细胞总数和取液量计算，以及 PNG 无损样本、工作区恢复、CSV 与标记图分享。
- 提供中英文界面、参数重置及 @caelricluo / Codex GPT-6.1 Sol 署名。
- 提供可安装的开发证书签名非调试 APK 和未签名 APK；iOS 保持 0.6.1。

## 0.6.1

- Kept concentration, total cells and required volume independent while editing stock volume or target count; omitted non-finite derived values.
- Coupled manual diameter limits to maintain an ordered range and clear obsolete counts for invalid settings.
- Fixed repeated photo imports, obsolete import callbacks, cancelled file-picker handling and cancellation of grid work.
- Saved new sample images as lossless PNG while retaining legacy JPEG records; matched manual annotation number colors to their markers.
- Removed advisory footers and repeated small print, simplified action labels and added bilingual copy checks.

- 编辑原液体积或目标细胞数时，浓度、总数与取液量按各自依赖更新，排除非有限数值。
- 手动直径上下限联动，异常设置清除旧计数。
- 修复同一照片重复导入、过期导入回调、文件选择取消提示和网格任务取消。
- 新样本图像无损保存为 PNG，兼容原有 JPEG 记录；手动标记编号与标记颜色保持一致。
- 清理劝告式脚注与重复小字，简化操作文字，并增加中英文文案检查。

## 0.6.0

- Replaced the fixed sensitivity floor with locally noise-adaptive support and seed thresholds; recovered compact faint targets in the highest sensitivity range.
- Added automatic, dark and bright cell appearance controls with live results. Automatic mode groups both polarities once, retaining connected clusters as one object.
- Improved sparse 4×4 grid selection beside dense ruling bands, validated all five lines per axis and expanded tilted-boundary refinement.
- Preserved legacy manual polarity settings and the independent 4×/10×/RBC mode choice.

- 将固定灵敏度下限替换为局部噪声自适应支撑与种子阈值，高灵敏度区间恢复较小浅弱目标。
- 增加自动、深色、浅色目标选择，结果实时更新；自动模式合并亮暗轮廓后统一分组，团块计作一个。
- 改善密集刻线邻近区域的 4×4 网格选择，校验每个方向全部五条线，并扩展倾斜边界拟合。
- 保留旧样本的手动明暗设置，以及独立的 4×、10×、红细胞模式选择。

## 0.5.0

- Made central-grid detection advisory: 4×, 10× and custom mode remain available with the selected frame; the RBC shortcut is optional.
- Added chamber and detection parameter reset controls.
- Displayed concentration and total stock cells during corner acquisition, using only the counted squares; preserved partial groups in save/export.

- 中央网格识别仅提供建议，4×、10× 与自定义模式保留当前边框继续计数，可选快捷切换红细胞模式。
- 增加计数板参数与识别参数重置入口。
- 四角采集中按已计数大格实时显示浓度、原液总细胞数，支持保存和导出当前计数组。

## 0.4.0

- Unified the repository, Xcode project, scheme, app, package and release artifact naming under **cellscope**.
- Added complete English and Simplified Chinese application localization, including formatted counts, statuses, accessibility labels and CSV exports.
- Published formal bilingual documentation and author attribution: **Co-author: Codex GPT-6.1 Sol**.
- Retained touch frame editing, live detection settings and automatic concentration/volume calculations.

- 仓库、Xcode 工程、scheme、App、软件包和发行产物统一使用 **cellscope**。
- 增加完整中英文界面，包括计数、状态、辅助功能文字和 CSV 导出。
- 整理正式双语文档，署名 **Co-author: Codex GPT-6.1 Sol**。
- 保留触控边框编辑、实时识别参数与浓度、体积自动计算。

## 0.3.0

Touch frame handles, adjustment magnifier, pixel controls, live parameter preview, cancellable detection jobs and direct calculation/save/export.

触控边框、调整放大镜、像素微调、实时参数预览、可取消识别任务，以及直接计算、保存和导出。

## 0.2.0

Automatic Neubauer grid alignment and improved detection of small phase-contrast objects.

自动 Neubauer 网格定位与小型相差目标检测改进。

## 0.1.0

Initial native iOS application with counting modes, four-corner acquisition, calculations, sample records and export.

初始原生 iOS 版本，支持计数模式、四角采集、数值计算、样本记录和导出。
