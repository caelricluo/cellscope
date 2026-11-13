# GitHub 发布与 IPA 打包

源码仓库：`caelricluo/Cellcounter`（私有）。

## 当前 IPA 的性质

本次交付为 **iPhoneOS arm64 Release 未签名 IPA**，文件名包含 `unsigned`。它不是模拟器 App，也不是可直接安装到普通 iPhone 的发行包。

本机没有可用 iOS 签名证书和 provisioning profile，因此没有生成安装授权，也没有发布到 TestFlight 或 App Store。安装前需要使用有效 Apple 签名及与 App 标识、设备或分发方式匹配的 provisioning profile。请不要把证书私钥、`.p12`、`.p8` 或开发者账号密码提交到 Git。

Apple 官方流程见 [创建 App Archive](https://help.apple.com/xcode/mac/current/en.lproj/devf37a1db04.html) 和 [导出 iOS App](https://help.apple.com/xcode/mac/current/en.lproj/dev23ea8b877.html)。

## 可重现构建

```sh
scripts/build_unsigned_ipa.sh
```

脚本从当前 iOS 工程执行 `Release` Archive，然后校验并打包：

- Archive：`build-release/CellScope.xcarchive`
- 详细编译日志：`build-release/archive.log`
- IPA：`dist/CellScope-<version>-unsigned.ipa`
- 清单：`dist/CellScope-<version>-unsigned.json`
- SHA-256：`dist/CellScope-<version>-unsigned.ipa.sha256`

打包脚本校验 `iPhoneOS` 平台、`arm64` 架构、Mach-O iOS 平台标记、无 provisioning profile、无 `_CodeSignature`，并检查 ZIP 完整性和 Bundle Identifier。不会使用模拟器产物冒充 IPA。

校验下载文件：

```sh
cd dist
shasum -a 256 -c CellScope-0.2.0-unsigned.ipa.sha256
```

GitHub Release 附件提供 IPA、清单及校验文件；源码和构建脚本通过 Git 管理。构建目录、IPA、证书、私钥和个人 Xcode 状态均被 `.gitignore` 排除。

## 之后生成可安装的版本

1. 在 Xcode 中登录你自己的 Apple 开发者账号。
2. 为 iOS target 设置 Team 和你拥有的唯一 Bundle Identifier。
3. 根据开发、已注册设备、TestFlight 或 App Store 分发需求准备签名资产。
4. 重新创建已签名 Archive，在 Organizer 中选择相应分发方式导出；也可使用自己的 `ExportOptions.plist` 调用 `xcodebuild -exportArchive`。

未签名构建使用的 `CODE_SIGNING_ALLOWED=NO` 仅用于这次源码交付；正式签名构建需要移除此覆盖参数。
