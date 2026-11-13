import AVFoundation
import PhotosUI
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: CounterModel
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            CountWorkspace().tabItem { Label("细胞计数", systemImage: "viewfinder") }.tag(0)
            HistoryView { tab = 0 }.tabItem { Label("样本记录", systemImage: "clock.arrow.circlepath") }.tag(1)
            GuideView().tabItem { Label("操作指南", systemImage: "book.closed") }.tag(2)
        }
        .alert("CellScope", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("知道了", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
        .sheet(isPresented: $model.showShare) { ShareSheet(urls: model.shareFiles) }
        .preferredColorScheme(.light)
    }
}

struct CountWorkspace: View {
    @EnvironmentObject var model: CounterModel
    @State private var selection: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showFullscreen = false
    @State private var showDetectionSettings = false
    @State private var confirmRedetect = false
    @State private var confirmReplace = false
    @State private var pendingAction: (() -> Void)?
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    CountingModePanel(model: model)
                    if model.grid.mode == .singleLarge { CornerFieldsPanel(model: model) }
                    acquisition
                    if model.image != nil {
                        imageEditor
                        calibration
                        calculation
                    } else { emptyWorkflow }
                    Text("本机离线处理 · 图像无需上传").font(.caption2).foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity).padding(.bottom, 8)
                }.padding(.horizontal, 20).padding(.top, 12)
            }
            .background(Palette.paper).clipped().navigationBarHidden(true)
            .scrollDismissesKeyboard(.interactively)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { inputFocused = false } } }
            .fullScreenCover(isPresented: $showCamera) { CameraPicker { model.setImage($0) }.ignoresSafeArea() }
            .fullScreenCover(isPresented: $showFullscreen) { fullscreenEditor }
            .sheet(isPresented: $showDetectionSettings) { detectionSettings }
            .confirmationDialog("重新检测会替换当前标记，可通过撤销恢复。", isPresented: $confirmRedetect, titleVisibility: .visible) {
                Button("重新检测") { model.detect() }
            }
            .confirmationDialog("载入新图会替换当前未保存的样本。", isPresented: $confirmReplace, titleVisibility: .visible) {
                Button("替换当前样本") { pendingAction?(); pendingAction = nil }
                Button("取消", role: .cancel) { pendingAction = nil }
            }
            .onChange(of: selection) { _, item in
                let importField = model.activeField
                let importMode = model.grid.mode
                Task {
                    guard let item else { return }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                            model.message = "无法读取这张照片，请选择其他图像。"; return
                        }
                        guard selection == item else { return }
                        guard model.grid.mode == importMode,
                              importMode != .singleLarge || model.activeField == importField else {
                            model.message = "照片读取期间切换了计数模式或角位，请在目标角位重新导入，避免照片归错位置。"
                            selection = nil
                            return
                        }
                        replace { model.setImage(image) }
                    } catch { model.message = "照片导入失败：\(error.localizedDescription)" }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "viewfinder.circle.fill").font(.title)
                    Text("CellScope").font(.system(.title3, design: .rounded, weight: .bold))
                }
                Spacer()
                Text("POCKET LAB").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(2)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .overlay(Capsule().stroke(.white.opacity(0.25)))
            }.foregroundStyle(Palette.lime)
            VStack(alignment: .leading, spacing: 8) {
                Text("看见每一个细胞。")
                    .font(.system(size: 29, weight: .semibold, design: .rounded)).tracking(-1)
                Text("从显微镜视野，到下一次实验。")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.65))
            }.foregroundStyle(.white)
            HStack(spacing: 7) {
                Circle().fill(Palette.lime).frame(width: 5, height: 5)
                Text("图像计数  /  浓度换算  /  取液规划").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.75))
            }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 26))
    }

    private var acquisition: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(number: "01", title: "采集显微图像", detail: "手机镜头对准目镜，保持计数板网格清晰。")
            HStack(spacing: 12) {
                Button { replace { openCamera() } } label: { Label("拍摄图像", systemImage: "camera") }.buttonStyle(PrimaryButton())
                PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                    Label("从相册导入", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical, 15)
                        .foregroundStyle(Palette.green).background(Palette.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }.accessibilityIdentifier("importPhoto")
            }
            if model.image == nil {
                Button {
                    if model.capturedFields > 0 {
                        pendingAction = { model.loadDemo() }; confirmReplace = true
                    } else { model.loadDemo() }
                } label: {
                    HStack {
                        Image(systemName: "sparkle.magnifyingglass")
                        Text(model.grid.mode == .singleLarge ? "使用四角模拟图体验" : "没有照片？使用模拟图体验")
                        Spacer(); Image(systemName: "arrow.up.right")
                    }.font(.caption).foregroundStyle(Palette.green)
                }.accessibilityIdentifier("loadDemo")
            }
        }.surface()
    }

    private var imageEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(number: "02", title: "框选与细胞复核", detail: model.grid.mode == .custom ? "拖动框选完整计数区域，再自动检测。" : model.grid.mode.instruction)
            if model.isDemo {
                Label(model.demoDescription, systemImage: "testtube.2")
                    .font(.caption).foregroundStyle(Palette.green).accessibilityIdentifier("demoBanner")
            }
            ZStack(alignment: .topTrailing) {
                ImageCanvas(model: model).frame(height: 310).clipShape(RoundedRectangle(cornerRadius: 15))
                Button { showFullscreen = true } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.subheadline)
                        .foregroundStyle(.white).padding(11).background(.black.opacity(0.55), in: Circle())
                }.padding(10).accessibilityLabel("全屏复核")
                if model.isDetecting {
                    ProgressView("正在检测候选细胞…").padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            editingToolbar
            if model.grid.mode.divisions > 1 { GridSquaresPanel(model: model) }
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(model.markers.count)").font(.system(size: 40, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("cellCount")
                    Text("个候选细胞").font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer()
                Button { showDetectionSettings = true } label: { Label("检测参数", systemImage: "slider.horizontal.3").font(.caption) }.disabled(model.isDetecting)
            }
            Button {
                if model.hasAnalyzed { confirmRedetect = true } else { model.detect() }
            } label: { Label(model.hasAnalyzed ? "重新检测" : "自动检测细胞", systemImage: "scope") }
                .buttonStyle(PrimaryButton()).disabled(model.isDetecting).opacity(model.isDetecting ? 0.5 : 1)
                .accessibilityIdentifier("detectCells")
            Toggle(isOn: $model.reviewed) {
                Text("已逐一复核细胞标记").font(.subheadline)
            }.disabled(!model.hasAnalyzed || model.isDetecting)
            Text("绿圈：自动候选 · 橙圈：手动补标。记上不记下、记左不记右；细胞团块按 1 个标记，不拆分。杂质与团块边界仍需人工复核。")
                .font(.caption2).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }.surface()
    }

    private var editingToolbar: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 4) {
                ForEach(EditMode.allCases) { mode in
                    Button { model.mode = mode } label: {
                        Label(mode.rawValue, systemImage: mode.icon).font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .foregroundStyle(model.mode == mode ? .white : Palette.muted)
                            .background(model.mode == mode ? Palette.green : .clear, in: RoundedRectangle(cornerRadius: 9))
                    }.accessibilityIdentifier("mode-\(mode.rawValue)")
                }
                Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward").padding(9) }
                    .disabled(!model.canUndo || model.isDetecting).accessibilityLabel("撤销标记修改")
            }.padding(4).background(Palette.paper, in: RoundedRectangle(cornerRadius: 12))
            Text(modeHint).font(.caption2).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }.disabled(model.isDetecting)
    }
    private var modeHint: String {
        switch model.mode {
        case .inspect: "双指捏合缩放，单指移动图像。按对象边缘判断压线：记上不记下，记左不记右；团块记作一个。"
        case .region: "在图像上拖出矩形；重新框选会清空标记，并要求重新确认物理面积。"
        case .add: "轻点漏检对象中心补标；团块只补一个标记。手动标记边界按圆圈估算，压线对象请复核。"
        case .remove: "轻点误检标记以删除；双指拖动可移动图像。"
        }
    }

    private var calibration: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(number: "03", title: "计数板与稀释参数", detail: model.grid.mode == .custom ? "填写框选矩形对应的实际面积。" : "按所选网格自动确定面积；请确认模板与实物网格对齐。")
            TextField("样本名称（可选）", text: $model.name).font(.subheadline)
                .padding(12).background(Palette.paper, in: RoundedRectangle(cornerRadius: 11)).focused($inputFocused)
            HStack(spacing: 12) {
                if model.grid.mode == .custom {
                    EntryField(title: "框选面积", unit: "mm²", text: Binding(get: { model.inputs.area }, set: { model.inputs.area = $0; model.areaConfirmed = false }))
                } else {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(model.grid.mode == .singleLarge ? "当前大格面积" : "选中格总面积").font(.caption).foregroundStyle(Palette.muted)
                        Text("\(model.grid.areaText ?? "—") mm²").font(.system(.body, design: .monospaced, weight: .medium))
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Palette.paper, in: RoundedRectangle(cornerRadius: 11))
                    }
                }
                EntryField(title: "腔室深度", unit: "mm", text: Binding(get: { model.inputs.depth }, set: { model.inputs.depth = $0; model.areaConfirmed = false }))
            }.focused($inputFocused)
            HStack(spacing: 12) {
                EntryField(title: "总稀释倍数", unit: "×", text: $model.inputs.dilution, minimum: 1)
                EntryField(title: "原液总体积", unit: "mL", text: $model.inputs.suspensionVolume)
            }.focused($inputFocused)
            Text("标准大方格：1 mm²，深度 0.1 mm。1 份原液 + 1 份染液，稀释倍数为 2；多次稀释请相乘。")
                .font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            Toggle(isOn: $model.areaConfirmed) { Text(model.grid.mode == .custom ? "已确认框选区域的实际面积" : "已确认框选与计数板网格对齐").font(.subheadline) }
                .accessibilityIdentifier("confirmArea")
        }.surface()
    }

    private var calculation: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(number: "04", title: "浓度与取液规划", detail: "按稀释前的原始悬液计算，结果随参数实时更新。")
            EntryField(title: "所需细胞数", unit: "个", text: $model.inputs.target).focused($inputFocused)
            if let result = model.result {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label(model.allReviewed ? "已复核结果" : "待复核估算", systemImage: model.allReviewed ? "checkmark.seal" : "exclamationmark.circle")
                        Spacer()
                        if model.isDemo { Text("模拟数据") }
                    }.font(.caption).foregroundStyle(Palette.lime)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("原液细胞浓度").font(.caption).foregroundStyle(.white.opacity(0.7))
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(formatted(result.concentration)).font(.system(size: 32, weight: .medium, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
                                .accessibilityIdentifier("concentration")
                            Text("cells/mL").font(.caption)
                        }
                        if model.grid.mode == .redBloodCells {
                            Text("\(formatted(result.concentration / 1000)) cells/µL").font(.caption).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("原液总细胞数").font(.caption).foregroundStyle(.white.opacity(0.7))
                            Text(formatted(result.totalCells)).font(.system(.title3, design: .rounded, weight: .medium))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            Text("所需原液体积").font(.caption).foregroundStyle(.white.opacity(0.7))
                            Text(result.requiredMicroliters.map { formatted($0) + " µL" } ?? "无法计算")
                                .font(.system(.title3, design: .rounded, weight: .medium)).accessibilityIdentifier("requiredVolume")
                        }
                    }
                }.foregroundStyle(.white).padding(20).background(Palette.ink, in: RoundedRectangle(cornerRadius: 18))
                if result.exceedsAvailable {
                    Label("所需体积超过现有原液，请减少目标细胞数或补充样本。", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                if result.concentration == 0 { Text("计数为 0，无法估算取液体积。请检查框选与标记。").font(.caption).foregroundStyle(.orange) }
            } else {
                Label(model.grid.mode == .singleLarge ? "完成四角四张图的计数与区域确认后，按四格平均显示结果。" : model.areaConfirmed ? "完成细胞计数并填写有效参数后显示结果。" : "确认实际框选面积后显示计算结果。", systemImage: "ruler")
                    .font(.subheadline).foregroundStyle(Palette.muted).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.paper, in: RoundedRectangle(cornerRadius: 14))
            }
            Text("浓度 = 计数 × 稀释倍数 × 1000 ÷ (面积 × 深度)\n取液体积 (µL) = 目标细胞数 ÷ 浓度 × 1000")
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted).lineSpacing(4)
            if model.grid.mode == .singleLarge {
                Text("此处使用四角总计数和总面积 4 mm²；深度为 0.1 mm 时，等价于四角平均计数 × 稀释倍数 × 10⁴。")
                    .font(.caption2).foregroundStyle(Palette.muted)
            }
            Text("计数口径：每个相连细胞团块计作一个对象。").font(.caption2).foregroundStyle(Palette.muted)
            HStack(spacing: 12) {
                Button { model.save() } label: { Label("保存记录", systemImage: "tray.and.arrow.down") }.buttonStyle(PrimaryButton())
                    .accessibilityIdentifier("saveRecord")
                Button { model.export() } label: { Image(systemName: "square.and.arrow.up").font(.title3).padding(15) }
                    .background(Palette.paper, in: RoundedRectangle(cornerRadius: 14)).accessibilityLabel("导出 CSV 和标记图")
            }.disabled(model.result == nil || !model.allReviewed || model.isDetecting)
        }.surface()
    }

    private var emptyWorkflow: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(model.grid.mode == .singleLarge ? "四角各一张，平均后计算。" : "一张图，完成计数与配液。")
                .font(.headline).foregroundStyle(Palette.ink)
            ForEach(Array([("crop", "框选计数区域", "根据网格确认实际面积"), ("scope", "自动标记，人工复核", "调整候选细胞，保留可追溯结果"), ("drop", "得到所需取液体积", "输入稀释倍数与目标细胞数")].enumerated()), id: \.offset) { _, item in
                HStack(spacing: 14) {
                    Image(systemName: item.0).font(.title3).foregroundStyle(Palette.green).frame(width: 28)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.1).font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink)
                        Text(item.2).font(.caption).foregroundStyle(Palette.muted)
                    }
                }
            }
        }.padding(.horizontal, 8).padding(.vertical, 6)
    }

    private var fullscreenEditor: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ImageCanvas(model: model).frame(maxHeight: .infinity)
                editingToolbar.padding(.horizontal)
                Text("\(model.markers.count) 个候选细胞").font(.headline).padding(.bottom).accessibilityIdentifier("fullscreenCount")
            }.background(Palette.paper).navigationTitle("细胞复核").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showFullscreen = false } } }
        }
    }

    private var detectionSettings: some View {
        NavigationStack {
            Form {
                Section("局部对比度") {
                    HStack { Text("检测灵敏度"); Spacer(); Text(model.settings.sensitivity.formatted(.percent.precision(.fractionLength(0)))) }
                    Slider(value: $model.settings.sensitivity, in: 0...1)
                    Toggle("亮细胞 / 暗背景", isOn: $model.settings.brightCells)
                }
                Section("直径占图像短边的比例") {
                    Text("最小：\(model.settings.minimumDiameter.formatted(.percent.precision(.fractionLength(1))))")
                    Slider(value: $model.settings.minimumDiameter, in: 0.004...0.08, step: 0.001)
                    Text("最大：\(model.settings.maximumDiameter.formatted(.percent.precision(.fractionLength(1))))")
                    Slider(value: $model.settings.maximumDiameter, in: 0.01...0.16, step: 0.001)
                    if model.settings.minimumDiameter > model.settings.maximumDiameter {
                        Text("最小直径不能大于最大直径").foregroundStyle(.red)
                    }
                }
                Section {
                    Text("调大灵敏度可找回低对比度细胞，也可能引入杂质。网格、离焦和粘连会影响检测；不会自动判定细胞类型或活死。")
                    Text("参数修改后点击「重新检测」才会更新标记。算法在图像短边等比例缩放后工作，直径比例始终相对整张图像。")
                }.font(.caption)
            }.navigationTitle("检测参数").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showDetectionSettings = false } } }
        }.presentationDetents([.large])
    }

    private func replace(_ action: @escaping () -> Void) {
        if model.image != nil { pendingAction = action; confirmReplace = true } else { action() }
    }
    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            model.message = "当前设备没有可用相机。模拟器中请从相册导入或使用模拟图。"; return
        }
        Task {
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            if allowed { showCamera = true }
            else { model.message = "相机访问未开启，请前往 iOS 设置 → CellScope → 相机开启权限，也可以从相册导入。" }
        }
    }
}
