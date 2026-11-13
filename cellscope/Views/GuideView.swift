import SwiftUI

struct GuideView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("拍照、计数、配液。"))
                            .font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
                        Text(tr("边框、标记与计算结果同步更新。"))
                            .font(.subheadline).foregroundStyle(Palette.muted)
                    }.padding(.vertical, 12)
                    guide("01", tr("拍摄清晰、完整的网格"), tr("将手机镜头稳定对准显微镜目镜，调整焦距和照明，让细胞边缘与计数板网格都清晰可见。建议使用目镜转接支架。照片仅在本机处理。"))
                    guide("02", tr("拖动边框微调"), tr("导入图像后自动定位网格。点击「边框」进入全屏，拖动四角或边线改变区域，在框内拖动可整体移动。拖动时放大镜显示落点；底部可选择角点、边线或整体，用方向键按 1 px 或 5 px 微调。双指可缩放和移动图像。"))
                    guide("4×", tr("完整九宫格模式"), tr("框住整个 3 × 3 mm 网格，九个大格每格 1 mm²。可统计全部 9 格（9 mm²），或只选四角大格（4 mm²），也可点击示意图自选。只统计高亮格，改变选择后自动更新。"))
                    guide("10×", tr("四角各拍一张再取平均"), tr("依次选择左上 A1、右上 A3、左下 C1、右下 C3，分别拍照或导入。每张对应一个 1×1 mm 大格，独立保存图像、边框和参数。四角拍完自动取平均并计算浓度，修改任一角的计数后同步更新。"))
                    guide("RBC", tr("红细胞中央五中格"), tr("改良 Neubauer 中央大格为 1 × 1 mm，分为 5 × 5 个中格。每个中格 0.2 × 0.2 mm = 0.04 mm²，内含 16 小格。框住中央完整大格，默认计四角加中心的 5 个中格（80 小格），总面积 0.2 mm²。浓度 = 五中格总计数 × 稀释倍数 × 50,000 cells/mL，除以 1000 可得到 cells/µL。稀释倍数须按实际实验输入。本模板不适用中央 4×4 分格的旧式 Neubauer。"))
                    guide(tr("尺寸"), tr("边调参数边看结果"), tr("打开「检测参数」，上方保留图像与标记，下方调节灵敏度、明暗模式和尺寸。停止拖动滑块片刻后自动刷新数量，关闭面板后直接查看浓度与取液体积。也可关闭编号，或使用补标、删除与撤销调整标记。"))
                    guide("03", tr("压线与团块规则"), tr("记上不记下，记左不记右。按对象边缘判断压线，三线边界取中线。每个相连细胞团块计作一个对象，手动补标时给整个团块一个标记。"))
                    guide("04", tr("输入总稀释倍数"), tr("稀释倍数 = 稀释后的总体积 ÷ 原液体积。例如 10 µL 原液与 10 µL 染液混合，倍数为 2；先 10 倍稀释再与染液 1:1 混合，总倍数为 20。未稀释填 1。"))
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tr("计算示例")).font(.headline).foregroundStyle(Palette.ink)
                        Text(tr("1 mm² 区域、深度 0.1 mm，计得 50 个细胞，稀释 2 倍："))
                        Text(tr("浓度 = 50 × 2 × 10⁴\n       = 1,000,000 cells/mL\n\n需要 100,000 个细胞\n取原液 = 100 µL"))
                            .font(.system(.subheadline, design: .monospaced)).lineSpacing(6).foregroundStyle(Palette.green)
                        Text(tr("原液总体积若为 1 mL，总细胞数为 1,000,000。所需取液体积指稀释前原液，不是上板后的稀释样本。"))
                    }.font(.subheadline).foregroundStyle(Palette.muted).surface()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("cellscope").font(.headline).foregroundStyle(Palette.ink)
                        Text(tr("作者") + ": caelricluo")
                        Text(tr("共同作者") + ": Codex GPT-6.1 Sol").accessibilityIdentifier("coauthorCredit")
                        Link("GitHub", destination: URL(string: "https://github.com/caelricluo/cellscope")!)
                        Label(tr("模拟图与参考"), systemImage: "book").font(.headline).foregroundStyle(Palette.ink)
                        Text(tr("模拟图：4× 九格各 9 个；10× 四张各 49 个；红细胞 25 中格各 4 个，标准五中格共 20 个。"))
                        Link(tr("参考：Marienfeld Neubauer 网格规格"), destination: URL(string: "https://www.marienfeld-superior.com/counting-grids.html")!)
                        Link(tr("参考：Thermo Fisher 血细胞计数板计数协议"), destination: URL(string: "https://www.thermofisher.com/us/en/home/references/gibco-cell-culture-basics/cell-culture-protocols/counting-cells-in-a-hemacytometer.html")!)
                    }.font(.caption).foregroundStyle(Palette.muted).surface()
                }.padding(20)
            }.background(Palette.paper).navigationTitle(tr("操作指南")).navigationBarTitleDisplayMode(.inline)
        }
    }
    private func guide(_ number: String, _ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(number: number, title: title, detail: "")
            Text(description).font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(5)
        }.surface()
    }
}
