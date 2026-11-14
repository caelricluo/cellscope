import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var model: CounterModel
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            CountWorkspace().tabItem { Label(tr("细胞计数"), systemImage: "viewfinder") }.tag(0)
            HistoryView { tab = 0 }.tabItem { Label(tr("样本记录"), systemImage: "clock.arrow.circlepath") }.tag(1)
            GuideView().tabItem { Label(tr("操作指南"), systemImage: "book.closed") }.tag(2)
        }
        .alert("cellscope", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button(tr("确定"), role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
        .sheet(isPresented: $model.showShare) { ShareSheet(urls: model.shareFiles) }
        .preferredColorScheme(.light)
    }
}

struct CountWorkspace: View {
    @EnvironmentObject var model: CounterModel
    @State private var selection: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showFileImport = false
    @State private var showFullscreen = false
    @State private var showDetectionSettings = false
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
                    if model.image != nil { imageEditor }
                    if model.image != nil || model.capturedFields > 0 {
                        calibration
                        calculation
                    } else { emptyWorkflow }
                    Text(tr("本机离线处理 · 图像无需上传")).font(.caption2).foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity).padding(.bottom, 8)
                }.padding(.horizontal, 20).padding(.top, 12)
            }
            .background(Palette.paper).clipped().navigationBarHidden(true)
            .scrollDismissesKeyboard(.interactively)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(tr("完成")) { inputFocused = false } } }
            .fileImporter(isPresented: $showFileImport, allowedContentTypes: [.image]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard let image = UIImage(data: try Data(contentsOf: url)) else { throw CocoaError(.fileReadCorruptFile) }
                    model.setImage(image)
                } catch { model.message = trf("error.file_import", error.localizedDescription) }
            }
            .fullScreenCover(isPresented: $showCamera) { CameraPicker { model.setImage($0) }.ignoresSafeArea() }
            .fullScreenCover(isPresented: $showFullscreen) { fullscreenEditor }
            .sheet(isPresented: $showDetectionSettings) { detectionSettings }
            .confirmationDialog(tr("载入新图会替换当前未保存的样本。"), isPresented: $confirmReplace, titleVisibility: .visible) {
                Button(tr("替换当前样本")) { pendingAction?(); pendingAction = nil }
                Button(tr("取消"), role: .cancel) { pendingAction = nil }
            }
            .onChange(of: selection) { _, item in
                let importField = model.activeField
                let importMode = model.grid.mode
                Task {
                    guard let item else { return }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                            model.message = tr("无法读取这张照片，请选择其他图像。"); return
                        }
                        guard selection == item else { return }
                        guard model.grid.mode == importMode,
                              importMode != .singleLarge || model.activeField == importField else {
                            model.message = tr("照片读取期间切换了计数模式或角位，请在目标角位重新导入，避免照片归错位置。")
                            selection = nil
                            return
                        }
                        replace { model.setImage(image) }
                    } catch { model.message = trf("error.photo_import", error.localizedDescription) }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "viewfinder.circle.fill").font(.title)
                    Text("cellscope").font(.system(.title3, design: .rounded, weight: .bold))
                }
                Spacer()
                Text("IMAGE ANALYSIS").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(2)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .overlay(Capsule().stroke(.white.opacity(0.25)))
            }.foregroundStyle(Palette.lime)
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("显微图像细胞计数"))
                    .font(.system(size: 29, weight: .semibold, design: .rounded)).tracking(-1)
                Text(tr("图像识别与细胞悬液计算"))
                    .font(.subheadline).foregroundStyle(.white.opacity(0.65))
            }.foregroundStyle(.white)
            HStack(spacing: 7) {
                Circle().fill(Palette.lime).frame(width: 5, height: 5)
                Text(tr("图像计数  /  浓度换算  /  取液规划")).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.75))
            }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 26))
    }

    private var acquisition: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(number: "01", title: tr("采集显微图像"), detail: tr("手机镜头对准目镜，保持计数板网格清晰。"))
            HStack(spacing: 12) {
                Button { replace { openCamera() } } label: { Label(tr("拍摄图像"), systemImage: "camera") }.buttonStyle(PrimaryButton())
                PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                    Label(tr("从相册导入"), systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical, 15)
                        .foregroundStyle(Palette.green).background(Palette.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }.accessibilityIdentifier("importPhoto")
            }
            #if targetEnvironment(macCatalyst)
            Button { replace { showFileImport = true } } label: {
                Label(tr("从本机文件导入"), systemImage: "folder") .font(.caption)
            }.accessibilityIdentifier("importFile")
            #endif
            if model.image == nil {
                Button {
                    if model.capturedFields > 0 {
                        pendingAction = { model.loadDemo() }; confirmReplace = true
                    } else { model.loadDemo() }
                } label: {
                    HStack {
                        Image(systemName: "sparkle.magnifyingglass")
                        Text(model.grid.mode == .singleLarge ? tr("载入四角演示样本") : tr("载入演示样本"))
                        Spacer(); Image(systemName: "arrow.up.right")
                    }.font(.caption).foregroundStyle(Palette.green)
                }.accessibilityIdentifier("loadDemo")
            }
        }.surface()
    }

    private var imageEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(number: "02", title: tr("图像与细胞计数"), detail: model.grid.mode == .custom ? tr("调整边框并填写面积，自动计数。") : model.grid.mode.instruction)
            if model.isDemo {
                Label(model.demoDescription, systemImage: "testtube.2")
                    .font(.caption).foregroundStyle(Palette.green).accessibilityIdentifier("demoBanner")
            }
            ZStack(alignment: .topTrailing) {
                ImageCanvas(model: model).frame(height: 310).clipShape(RoundedRectangle(cornerRadius: 15))
                Button { showFullscreen = true } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.subheadline)
                        .foregroundStyle(.white).padding(11).background(.black.opacity(0.55), in: Circle())
                }.padding(10).accessibilityLabel(tr("全屏查看"))
                if model.isDetecting {
                    ProgressView(model.isLocatingGrid ? tr("定位中") : tr("更新中")).font(.caption).padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(10).allowsHitTesting(false)
                }
            }
            HStack {
                Button { model.locateGrid() } label: { Label(tr("自动定位边框"), systemImage: "viewfinder") }
                .accessibilityIdentifier("locateGrid")
                Spacer()
                Toggle(tr("编号"), isOn: $model.showMarkerLabels).fixedSize()
            }.font(.caption).disabled(model.isDetecting)
            if !model.gridStatus.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(model.gridStatus, systemImage: model.alignment == nil ? "viewfinder" : "checkmark.viewfinder")
                        .font(.caption).foregroundStyle(model.alignment == nil ? Palette.muted : Palette.green)
                        .accessibilityIdentifier("gridDetectionStatus")
                    if model.gridDetection?.central != nil && model.grid.mode != .redBloodCells {
                        Button(tr("使用中央红细胞计数区")) { model.changeCountingMode(.redBloodCells) }
                            .font(.caption.weight(.semibold)).disabled(model.isDetecting).accessibilityIdentifier("switchToRBC")
                    }
                }.fixedSize(horizontal: false, vertical: true)
            }
            editingToolbar
            if model.grid.mode.divisions > 1 { GridSquaresPanel(model: model) }
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(model.markers.count)").font(.system(size: 40, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("cellCount")
                    Text(tr("个细胞")).font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer()
                Button { showDetectionSettings = true } label: { Label(tr("检测参数"), systemImage: "slider.horizontal.3").font(.caption) }.disabled(model.isLocatingGrid)
            }
            Button { model.detect() } label: { Label(model.hasAnalyzed ? tr("重新检测") : tr("自动检测细胞"), systemImage: "scope") }
                .buttonStyle(PrimaryButton()).disabled(model.isDetecting).opacity(model.isDetecting ? 0.5 : 1)
                .accessibilityIdentifier("detectCells")
            Text(tr("绿色：自动标记 · 橙色：手动补标")).font(.caption2).foregroundStyle(Palette.muted)
        }.surface()
    }

    private var editingToolbar: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 4) {
                ForEach(EditMode.allCases) { mode in
                    Button { model.mode = mode; if mode == .region { showFullscreen = true } } label: {
                        Label(mode.title, systemImage: mode.icon).font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .foregroundStyle(model.mode == mode ? .white : Palette.muted)
                            .background(model.mode == mode ? Palette.green : .clear, in: RoundedRectangle(cornerRadius: 9))
                    }.accessibilityIdentifier("mode-\(mode.rawValue)")
                }
                Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward").padding(9) }
                    .disabled(!model.canUndo || model.isDetecting).accessibilityLabel(tr("撤销标记修改"))
            }.padding(4).background(Palette.paper, in: RoundedRectangle(cornerRadius: 12))
            Text(modeHint).font(.caption2).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }.disabled(model.isLocatingGrid)
    }
    private var modeHint: String {
        switch model.mode {
        case .inspect: tr("双指缩放，单指移动图像；点击「边框」微调计数区域。")
        case .region: tr("拖动角点或边线调整，拖动框内整体移动；双指缩放、移动图像。")
        case .add: tr("点击细胞中心补标，团块标记一次；双指移动图像。")
        case .remove: tr("轻点误检标记以删除；双指拖动可移动图像。")
        }
    }

    private var calibration: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(number: "03", title: tr("计数板与稀释参数"), detail: model.grid.mode == .custom ? tr("填写计数区域的实际面积。") : tr("面积按所选网格计算。"))
            Button { model.resetChamberParameters() } label: {
                Label(tr("重置计数板参数"), systemImage: "arrow.counterclockwise")
            }.font(.caption.weight(.semibold)).accessibilityIdentifier("resetChamberParameters")
            Text(tr("恢复面积、深度、稀释倍数和原液体积")).font(.caption2).foregroundStyle(Palette.muted)
            TextField(tr("样本名称（可选）"), text: $model.name).font(.subheadline)
                .padding(12).background(Palette.paper, in: RoundedRectangle(cornerRadius: 11)).focused($inputFocused)
            HStack(spacing: 12) {
                if model.grid.mode == .custom {
                    EntryField(title: tr("框选面积"), unit: "mm²", text: $model.inputs.area)
                } else {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(model.grid.mode == .singleLarge ? tr("当前大格面积") : tr("选中格总面积")).font(.caption).foregroundStyle(Palette.muted)
                        Text("\(model.grid.areaText ?? "—") mm²").font(.system(.body, design: .monospaced, weight: .medium))
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Palette.paper, in: RoundedRectangle(cornerRadius: 11))
                    }
                }
                EntryField(title: tr("腔室深度"), unit: "mm", text: $model.inputs.depth)
            }.focused($inputFocused)
            HStack(spacing: 12) {
                EntryField(title: tr("总稀释倍数"), unit: "×", text: $model.inputs.dilution, minimum: 1)
                EntryField(title: tr("原液总体积"), unit: "mL", text: $model.inputs.suspensionVolume)
            }.focused($inputFocused)
            Text(tr("标准大方格：1 mm²，深度 0.1 mm。1 份原液 + 1 份染液，稀释倍数为 2；多次稀释请相乘。"))
                .font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }.surface()
    }

    private var calculation: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(number: "04", title: tr("浓度与取液规划"), detail: tr("按稀释前的原始悬液计算，结果随参数实时更新。"))
            EntryField(title: tr("所需细胞数"), unit: tr("个"), text: $model.inputs.target).focused($inputFocused)
            if let result = model.result {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label(model.isDetecting ? tr("更新中") : tr("实时计算"), systemImage: "function")
                        Spacer()
                        if model.isDemo { Text(tr("模拟数据")) }
                    }.font(.caption).foregroundStyle(Palette.lime)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("原液细胞浓度")).font(.caption).foregroundStyle(.white.opacity(0.7))
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
                            Text(tr("原液总细胞数")).font(.caption).foregroundStyle(.white.opacity(0.7))
                            Text(formatted(result.totalCells)).font(.system(.title3, design: .rounded, weight: .medium)).accessibilityIdentifier("totalCells")
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(tr("所需原液体积")).font(.caption).foregroundStyle(.white.opacity(0.7))
                            Text(result.requiredMicroliters.map { formatted($0) + " µL" } ?? "—")
                                .font(.system(.title3, design: .rounded, weight: .medium)).accessibilityIdentifier("requiredVolume")
                        }
                    }
                }.foregroundStyle(.white).padding(20).background(Palette.ink, in: RoundedRectangle(cornerRadius: 18))
                if result.exceedsAvailable {
                    Label(tr("所需体积超过现有原液，请减少目标细胞数或补充样本。"), systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                if result.concentration == 0 { Text(tr("计数为 0")).font(.caption).foregroundStyle(.orange) }
            } else {
                Label(model.grid.mode == .singleLarge ? trf("fields.progress", model.completedFields) : tr("导入图像、填写参数后自动计算。"), systemImage: "ruler")
                    .font(.subheadline).foregroundStyle(Palette.muted).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.paper, in: RoundedRectangle(cornerRadius: 14))
            }
            Text(tr("浓度 = 计数 × 稀释倍数 × 1000 ÷ (面积 × 深度)\n取液体积 (µL) = 目标细胞数 ÷ 浓度 × 1000"))
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted).lineSpacing(4)
            if model.grid.mode == .singleLarge {
                Text(trf("fields.calculation", model.completedFields))
                    .font(.caption2).foregroundStyle(Palette.muted)
            }
            Text(tr("计数口径：每个相连细胞团块计作一个对象。")).font(.caption2).foregroundStyle(Palette.muted)
            HStack(spacing: 12) {
                Button { model.save() } label: { Label(tr("保存记录"), systemImage: "tray.and.arrow.down") }.buttonStyle(PrimaryButton())
                    .accessibilityIdentifier("saveRecord")
                Button { model.export() } label: { Image(systemName: "square.and.arrow.up").font(.title3).padding(15) }
                    .background(Palette.paper, in: RoundedRectangle(cornerRadius: 14)).accessibilityLabel(tr("导出 CSV 和标记图"))
            }.disabled(model.result == nil || model.isDetecting)
        }.surface()
    }

    private var emptyWorkflow: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(model.grid.mode == .singleLarge ? tr("四角各一张，平均后计算。") : tr("一张图，完成计数与配液。"))
                .font(.headline).foregroundStyle(Palette.ink)
            ForEach(Array([("crop", tr("自动定位边框"), tr("拖动角点与边线微调")), ("scope", tr("实时识别细胞"), tr("调整参数，即时查看标记")), ("drop", tr("得到所需取液体积"), tr("输入稀释倍数与目标细胞数"))].enumerated()), id: \.offset) { _, item in
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
                if model.mode == .region { frameControls.padding(.horizontal) }
                editingToolbar.padding(.horizontal)
                Text(trf("cell_count", model.markers.count)).font(.headline).padding(.bottom).accessibilityIdentifier("fullscreenCount")
            }.background(Palette.paper).navigationTitle(tr("图像与细胞")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(tr("完成")) { showFullscreen = false } } }
        }
    }

    private var frameControls: some View {
        VStack(spacing: 0) {
            HStack {
                Menu {
                    Picker(tr("微调位置"), selection: $model.activeHandle) {
                        ForEach(GridHandle.allCases) { Text($0.title).tag($0) }
                    }
                } label: { Label(model.activeHandle.title, systemImage:"scope").font(.caption.weight(.semibold)).frame(minHeight:44) }
                .accessibilityIdentifier("frameHandleSelector")
                Spacer()
                Picker(tr("步长"), selection: $model.nudgePixels) { Text("1 px").tag(1); Text("5 px").tag(5) }
                    .pickerStyle(.segmented).frame(width:120)
                Spacer()
                Button { model.resetFrame() } label: { Image(systemName:"arrow.counterclockwise").frame(width:44,height:44) }
                    .accessibilityLabel(tr("重置边框"))
            }
            HStack(spacing:24) {
                ForEach([("arrow.left",-1,0),("arrow.up",0,-1),("arrow.down",0,1),("arrow.right",1,0)], id: \.0) { item in
                    Button { model.nudgeFrame(dx:item.1,dy:item.2) } label: {
                        Image(systemName:item.0).frame(width:44,height:44).background(Palette.green.opacity(0.08),in:RoundedRectangle(cornerRadius:10))
                    }.buttonRepeatBehavior(.enabled).accessibilityIdentifier("nudge-"+item.0)
                }
            }
        }.foregroundStyle(Palette.green)
    }

    private var detectionSettings: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ImageCanvas(model: model, modeOverride: .inspect).frame(height: 230).clipped()
                HStack {
                    Text(trf("cell_count", model.markers.count)).font(.headline.monospacedDigit()).accessibilityIdentifier("liveCellCount")
                    Spacer()
                    if model.isDetecting { ProgressView().controlSize(.small); Text(tr("更新中")).font(.caption) }
                    else { Text(tr("实时预览")).font(.caption) }
                }.foregroundStyle(Palette.green).padding(.horizontal,20).padding(.vertical,12)
                if let result = model.result {
                    HStack {
                        Text(trf("live.concentration", formatted(result.concentration))).accessibilityIdentifier("liveConcentration")
                        Spacer()
                        Text(result.requiredMicroliters.map { trf("live.volume", formatted($0)) } ?? tr("取液 —"))
                    }.font(.caption).foregroundStyle(Palette.muted).padding(.horizontal,20).padding(.bottom,6)
                    Text(trf("live.total_cells", formatted(result.totalCells)))
                        .font(.caption).foregroundStyle(Palette.muted).padding(.horizontal,20).padding(.bottom,10)
                        .frame(maxWidth:.infinity,alignment:.leading).accessibilityIdentifier("liveTotalCells")
                }
                Form {
                    Section(tr("局部对比度")) {
                        HStack { Text(tr("检测灵敏度")); Spacer(); Text(model.settings.sensitivity.formatted(.percent.precision(.fractionLength(0)))) }
                        Slider(value: $model.settings.sensitivity, in: 0...1).accessibilityIdentifier("sensitivitySlider")
                        Picker(tr("目标明暗"), selection: $model.settings.polarity) {
                            Text(tr("自动")).tag(DetectionPolarity.automatic)
                            Text(tr("深色")).tag(DetectionPolarity.dark)
                            Text(tr("浅色")).tag(DetectionPolarity.bright)
                        }.pickerStyle(.segmented).accessibilityIdentifier("cellPolarityPicker")
                    }
                    Section(tr("细胞尺寸")) {
                        Toggle(tr("自动估计细胞直径"), isOn: $model.settings.automaticSize).accessibilityIdentifier("automaticSizeToggle")
                        if model.estimatedDiameterPixels > 0 { Text(trf("diameter.estimate", Int(model.estimatedDiameterPixels))).font(.caption) }
                        if !model.settings.automaticSize {
                            Text(trf("diameter.minimum", model.settings.minimumDiameter.formatted(.percent.precision(.fractionLength(1)))))
                            Slider(value: $model.settings.minimumDiameter, in: 0.002...0.08, step: 0.001).accessibilityIdentifier("minimumDiameterSlider")
                            Text(trf("diameter.maximum", model.settings.maximumDiameter.formatted(.percent.precision(.fractionLength(1)))))
                            Slider(value: $model.settings.maximumDiameter, in: 0.01...0.16, step: 0.001).accessibilityIdentifier("maximumDiameterSlider")
                            if model.settings.minimumDiameter > model.settings.maximumDiameter { Text(tr("最小直径需小于最大直径")).foregroundStyle(.red) }
                        }
                    }
                }
            }.navigationTitle(tr("实时检测参数")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(tr("重置")) { model.resetDetectionSettings() }.accessibilityIdentifier("resetDetectionSettings")
                    }
                    ToolbarItem(placement: .confirmationAction) { Button(tr("完成")) { showDetectionSettings = false } }
                }
                .onAppear { model.beginParameterEditing() }
        }.presentationDetents([.large])
    }

    private func replace(_ action: @escaping () -> Void) {
        if model.image != nil { pendingAction = action; confirmReplace = true } else { action() }
    }
    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            model.message = tr("当前设备没有可用相机。模拟器中请从相册导入或使用模拟图。"); return
        }
        Task {
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            if allowed { showCamera = true }
            else { model.message = tr("相机访问未开启，请前往 iOS 设置 → cellscope → 相机开启权限，也可以从相册导入。") }
        }
    }
}
