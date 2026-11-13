# Contributing / 贡献指南

## English

1. Open `cellscope.xcodeproj` and select the `cellscope` scheme.
2. Keep numerical and image-processing code in `Sources/cellscopeCore/`; keep presentation and storage code in `cellscope/`.
3. Run `swift test -c release`, `python3 scripts/check_localizations.py`, and an iOS Simulator build.
4. For interaction changes, run the affected `cellscopeUITests` workflows and include screenshots where useful.
5. Add user-facing text to both `en.lproj` and `zh-Hans.lproj`. Use `tr` for strings and `trf` for formatted values. Update both README languages when behavior changes.
6. Describe the changed behavior and validation in the pull request.

Do not commit build products, sample images containing personal information, signing assets or local application records. Build products belong in release attachments.

## 简体中文

1. 打开 `cellscope.xcodeproj`，选择 `cellscope` scheme。
2. 数值与图像处理代码放在 `Sources/cellscopeCore/`，界面及存储代码放在 `cellscope/`。
3. 执行 `swift test -c release`、`python3 scripts/check_localizations.py` 和 iOS 模拟器编译。
4. 交互修改执行对应的 `cellscopeUITests` 流程，并按需提供截图。
5. 界面文字同步维护 `en.lproj` 与 `zh-Hans.lproj`；普通文字使用 `tr`，带参数文字使用 `trf`。功能变化同步更新中英文 README。
6. 在 Pull Request 中说明最终行为与验证结果。

构建产物、含个人信息的样本图像、签名资产和本地样本记录不提交仓库。发行产物通过 Release 附件分发。
