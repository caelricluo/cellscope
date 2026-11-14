# Verification / 验证记录

## 0.5.0

**English:** 26 core tests and 8 UI workflows passed. A dedicated Debug fixture runs an actual central-grid image through both 4× and 10× counting, recounting, concentration/total display, save and restore. Seven Release workflows cover parameter resets, marker editing, live detection, localization and four-corner averaging. Chamber reset restores numerical inputs while retaining the target count and selected area.

**简体中文：** 26 项核心测试与 8 项 UI 流程通过。专用 Debug 样本使用中央网格图像，验证 4×、10× 均可计数、重新检测、显示浓度与总数，并保存和恢复。7 项 Release 流程验证参数重置、标记编辑、实时识别、本地化和四角平均。计数板重置保留目标细胞数与所选面积。

Test bundles / 测试包：`TestResults/CentralModeChoiceFinal.xcresult`、`TestResults/ModeAndResetRelease.xcresult`。

## 0.4.0

## English

Version **0.4.0** is verified with Xcode 27.2 and an iPhone 17 Pro simulator running iOS 26.4.

- **24 core tests passed:** volume and concentration formulas; dilution validation; four-corner mean precision; grid areas; boundary and cluster behavior; small phase-contrast fixtures; grid geometry; frame movement; legacy data compatibility.
- **6 UI workflows passed:** automatic alignment and direct calculation; marker edits and sample restoration; English localization and co-author attribution; frame dragging/nudging/reset; live parameters and concentration updates; counting modes and four-corner averaging.
- **236 localization keys validated** in English and Simplified Chinese, including matching formatted argument placeholders.
- iOS Simulator, iPhoneOS arm64 Release and Mac Catalyst builds completed successfully.

Live parameter tests exercise a 49→0→49 count sequence and corresponding concentration updates without a manual recount or confirmation switch. The English workflow verifies the translated count, settings and **Codex GPT-6.1 Sol** attribution.

The source includes deterministic synthetic fixtures. Representative microscopy-image checks are separate from the automated fixture suite; no dataset-level accuracy claim is made.

Screenshots: [English settings](screenshots/cellscope-en.png), [Chinese settings](screenshots/live-parameters.png), [frame controls](screenshots/frame-handles.png), [calculation](screenshots/calculation.png).

## 简体中文

**0.4.0** 使用 Xcode 27.2、iPhone 17 Pro 模拟器及 iOS 26.4 验证。

- **24 项核心测试通过**：体积与浓度公式、稀释参数、四角平均精度、网格面积、压线与团块、小型相差目标、网格几何、边框移动及旧数据兼容。
- **6 项 UI 流程通过**：自动对齐与直接计算、标记编辑与样本恢复、英文界面与共同作者署名、边框拖动/微调/重置、实时参数与浓度联动、计数模式与四角平均。
- **236 项中英文资源校验通过**，格式化参数占位符保持一致。
- iOS 模拟器、iPhoneOS arm64 Release 及 Mac Catalyst 编译通过。

实时参数测试覆盖数量 49→0→49 和浓度同步更新，不点击重新检测或确认开关。英文流程验证译文、计数、参数面板及 **Codex GPT-6.1 Sol** 署名。

自动测试使用确定性合成样本。代表性显微图像检查独立于该测试集，不据此给出数据集准确率结论。界面截图见上方链接。
