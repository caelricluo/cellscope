# Changelog / 更新日志

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
