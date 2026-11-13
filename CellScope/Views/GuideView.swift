import SwiftUI

struct GuideView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("让计数更可靠。")
                            .font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
                        Text("先校准区域，再复核标记，最后计算。")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                    }.padding(.vertical, 12)
                    guide("01", "拍摄清晰、完整的网格", "将手机镜头稳定对准显微镜目镜，调整焦距和照明，让细胞边缘与计数板网格都清晰可见。建议使用目镜转接支架。照片仅在本机处理。")
                    guide("02", "自动定位后核对四条边", "导入后会自动寻找连续网格线与等距分格，并按当前模式匹配边框。中央密集网格不能代替完整九宫格或四角大格；模式不匹配时请切换模式或手动框选。自动四边形支持轻微倾斜，定位失败或透视明显时请重拍，或将图像放正后手动框选。标准大格为 1 mm²、深度通常为 0.1 mm，请以实物为准；圆形视野不是计数边框。确认边框和面积后才计算浓度。")
                    guide("4×", "完整九宫格模式", "框住整个 3 × 3 mm 网格，九个大格每格 1 mm²。可统计全部 9 格（9 mm²），或只选四角大格（4 mm²），也可点击示意图自选。只统计高亮格；选格变化后重新检测。")
                    guide("10×", "四角各拍一张再取平均", "依次选择左上 A1、右上 A3、左下 C1、右下 C3，分别拍照或导入，每张框选一个完整 1 × 1 mm 大格。四张图分别确认区域和细胞标记。平均计数 = 四角计数之和 ÷ 4；浓度 = 平均计数 × 总稀释倍数 × 10⁴ cells/mL。缺少任意一张的计数或区域确认时，不显示整组结果；保存和导出前四张都需复核。")
                    guide("RBC", "红细胞中央五中格", "改良 Neubauer 中央大格为 1 × 1 mm，分为 5 × 5 个中格。每个中格 0.2 × 0.2 mm = 0.04 mm²，内含 16 小格。框住中央完整大格，默认计四角加中心的 5 个中格（80 小格），总面积 0.2 mm²。浓度 = 五中格总计数 × 稀释倍数 × 50,000 cells/mL，除以 1000 可得到 cells/µL。稀释倍数须按实际实验输入。本模板不适用中央 4×4 分格的旧式 Neubauer。")
                    guide("尺寸", "自动尺寸与局部对比度", "默认自动估计细胞直径，适配图中较小的环状细胞。检测参数中可关闭自动尺寸并手动调节。低对比度对象可尝试提高灵敏度；这也会增加伪影。可关闭编号后放大检查，避免数字遮挡小细胞。重新检测会替换标记，可撤销恢复。")
                    guide("03", "压线与团块按统一规则复核", "记上不记下、记左不记右：自动候选按对象包围边缘判断是否触及边界，不是只看中心。触及右或下边界时排除；三线边界以中间线为准。相连团块作为一个对象，不自动拆分；人工补标时也只给整个团块一个标记。网格切断、低对比度或大团块仍可能误检，须人工增删校正。手动标记以圈半径估计边缘，压线对象请复核。")
                    guide("04", "输入总稀释倍数", "稀释倍数 = 稀释后的总体积 ÷ 原液体积。例如 10 µL 原液与 10 µL 染液混合，倍数为 2；先 10 倍稀释再与染液 1:1 混合，总倍数为 20。未稀释填 1。")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("计算示例").font(.headline).foregroundStyle(Palette.ink)
                        Text("1 mm² 区域、深度 0.1 mm，计得 50 个细胞，稀释 2 倍：")
                        Text("浓度 = 50 × 2 × 10⁴\n       = 1,000,000 cells/mL\n\n需要 100,000 个细胞\n取原液 = 100 µL")
                            .font(.system(.subheadline, design: .monospaced)).lineSpacing(6).foregroundStyle(Palette.green)
                        Text("原液总体积若为 1 mL，总细胞数为 1,000,000。所需取液体积指稀释前原液，不是上板后的稀释样本。")
                    }.font(.subheadline).foregroundStyle(Palette.muted).surface()
                    VStack(alignment: .leading, spacing: 12) {
                        Label("适用范围", systemImage: "info.circle").font(.headline).foregroundStyle(Palette.ink)
                        Text("本版本用于科研计数辅助。尚未用你的显微镜、细胞类型和拍照条件完成精度验证。不会区分活细胞、死细胞或血细胞亚型，也不会自动拆分粘连细胞。需要活细胞浓度时，请自行仅保留符合实验标准的目标细胞标记。")
                        Text("模拟图是程序绘制的形状：4× 九格各 9 个；10× 四张各 49 个；红细胞模式 25 中格各 4 个，默认五中格共 20 个。仅演示流程，不能代表真实图像精度。")
                        Link("参考：Marienfeld Neubauer 网格规格", destination: URL(string: "https://www.marienfeld-superior.com/counting-grids.html")!)
                        Link("参考：Thermo Fisher 血细胞计数板计数协议", destination: URL(string: "https://www.thermofisher.com/us/en/home/references/gibco-cell-culture-basics/cell-culture-protocols/counting-cells-in-a-hemacytometer.html")!)
                    }.font(.caption).foregroundStyle(Palette.muted).surface()
                }.padding(20)
            }.background(Palette.paper).navigationTitle("操作指南").navigationBarTitleDisplayMode(.inline)
        }
    }
    private func guide(_ number: String, _ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(number: number, title: title, detail: "")
            Text(description).font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(5)
        }.surface()
    }
}
