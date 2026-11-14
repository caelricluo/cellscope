# cellscope

[English](README.md) · [简体中文](README.zh-CN.md)

**cellscope** is a native iOS application for counting cells in microscope images of improved Neubauer hemocytometers. It combines grid alignment, editable cell detection, concentration calculations and suspension volume planning in an on-device workflow.

## Features

- Capture images with the camera or import from the photo library.
- Keep the selected counting mode when a central grid is detected; switch to RBC mode with an optional shortcut.
- Restore chamber or detection parameters with reset controls.
- Locate grid boundaries automatically; adjust corners, sides or the entire frame using touch handles, a magnifier and 1/5 px controls.
- Detect faint cells with noise-adaptive sensitivity and automatic, dark or bright target selection.
- View images, markers, cell counts, concentration, total stock cells and required volume while tuning detection parameters.
- Count a full 3×3 grid, four separately photographed corner squares, selected central RBC groups or a custom area.
- Apply top/left inclusion and bottom/right exclusion. Count each connected cluster as one object.
- Save samples locally and export CSV reports with annotated images.
- Use English or Simplified Chinese according to the device's app language.

## Get started

Requires **iOS 17+**. Development and packaging require macOS and Xcode with an iOS SDK.

```sh
git clone https://github.com/caelricluo/cellscope.git
cd cellscope
open cellscope.xcodeproj
```

Select the **cellscope** scheme and an iPhone simulator or device. Choose a counting mode, then capture/import an image or load a demo sample. Results update automatically as the frame, markers and calculation parameters change.

For a desktop preview, run `Open cellscope.command`. The Mac Catalyst preview uses the same application code and also supports importing a local image file.

## Counting modes

| Mode | Reference region | Counted area |
| --- | --- | --- |
| Full grid | Complete 3×3 mm grid | 9 mm², four corners at 4 mm², or selected large squares |
| Four corners | Separate A1, A3, C1 and C3 images | 1–4 counted 1 mm² squares; running mean, then the full four-corner mean |
| RBC | Central 1×1 mm square with 5×5 groups | Standard four corners plus center: 0.2 mm² |
| Custom | User-defined region | Enter the physical area in mm² |

```text
Sampled volume (mL) = area (mm²) × chamber depth (mm) / 1000
Stock concentration (cells/mL) = count × dilution / sampled volume
Total stock cells = concentration × stock volume (mL)
Required stock volume (µL) = target cells / concentration × 1000
```

## Build and test

```sh
swift test -c release
python3 scripts/check_localizations.py
xcodebuild -project cellscope.xcodeproj -scheme cellscope \
  -sdk iphonesimulator -configuration Release \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
scripts/build_unsigned_ipa.sh
```

The packaging script creates an unsigned iPhoneOS arm64 IPA, a JSON manifest and a SHA-256 file in `dist/`. Device installation uses an appropriately signed build. See [distribution](docs/distribution.md).

## Documentation

[User guide](docs/user-guide.md) · [Development](docs/development.md) · [Algorithm and calculations](docs/algorithm.md) · [Verification](docs/verification.md) · [Changelog](CHANGELOG.md)

Releases are available from [GitHub Releases](https://github.com/caelricluo/cellscope/releases).

## Authors

- Author: [caelricluo](https://github.com/caelricluo)
- Co-author: **Codex GPT-6.1 Sol**

See [AUTHORS.md](AUTHORS.md) and [CONTRIBUTING.md](CONTRIBUTING.md).
