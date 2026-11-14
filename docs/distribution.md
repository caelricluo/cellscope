# Distribution / 发布与分发

## English

For Android APK downloads, builds and signing, see [Android](android.md). Version 0.7.0 adds Android; the iOS package remains available in release 0.6.1.

Build the unsigned iPhoneOS arm64 package on macOS:

```sh
scripts/build_unsigned_ipa.sh
```

Outputs:

- `build-release/cellscope.xcarchive`
- `dist/cellscope-<version>-unsigned.ipa`
- `dist/cellscope-<version>-unsigned.json`
- `dist/cellscope-<version>-unsigned.ipa.sha256`

The packager checks the iPhoneOS platform, arm64 architecture, Mach-O platform metadata, bundle identifier and ZIP integrity. The JSON manifest records the version, build number, size and SHA-256 digest.

```sh
cd dist
shasum -a 256 -c cellscope-0.6.1-unsigned.ipa.sha256
```

For device distribution, configure the development team and provisioning settings in Xcode, create a signed archive and export using the chosen Apple distribution method. Unsigned artifacts are provided for building and subsequent signing.

Current source and releases: [caelricluo/cellscope](https://github.com/caelricluo/cellscope).

## 简体中文

Android APK 下载、构建与签名见 [Android 指南](android.md)。0.7.0 新增 Android，iOS 安装包保留在 0.6.1 发行页。

在 macOS 上执行上述脚本，生成未签名 iPhoneOS arm64 IPA、JSON 清单和 SHA-256 文件。产物路径及校验命令见上文。

打包器验证 iPhoneOS 平台、arm64 架构、Mach-O 平台信息、Bundle Identifier 与 ZIP 完整性。JSON 清单记录版本、构建号、文件大小和 SHA-256。

真机分发在 Xcode 中配置开发团队和描述文件，创建已签名 Archive，并按所选 Apple 分发方式导出。未签名产物用于后续构建和签名。

源码与发行文件：[caelricluo/cellscope](https://github.com/caelricluo/cellscope)。
