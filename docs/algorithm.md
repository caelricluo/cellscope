# Algorithm and calculations / 算法与计算

## English

Images are normalized to an upright orientation and a maximum edge of 1,600 pixels. Fine-scale Gaussian contrast separates dark phase-contrast rims or bright objects from the local background. A tiled median absolute deviation of the signed response estimates local noise, with interpolated thresholds between tiles. Sensitivity maps quadratically from the upper contrast threshold to the local noise floor. Directional medians suppress continuous rulings without cutting out entire grid bands. Automatic polarity combines bright and dark supports before a single connected-component pass; manual polarity remains available. A one-pixel closing joins recovered supports. Connected components are filtered by contrast, support area, geometry and an estimated or manually selected size. Components require multiple seed pixels above their local support threshold. At high sensitivity, compact smaller supports are accepted; elongated three-pixel ruling ends are rejected. Connected clusters are retained as single objects.

Grid detection is independent of cell detection. Directional bright/dark responses identify repeated rulings. A central grid is fitted to 20 small-square intervals; corner candidates use four subdivision intervals. Corner detection retains multiple horizontal/vertical hypotheses, penalizes additional dense rulings within a sparse candidate, and checks all five lines in each direction. Wider, distance-weighted line searches tolerate modest tilt without favoring a distant adjacent ruling. Local line fits produce a quadrilateral. A full nine-square reference additionally requires visible outer-ruling evidence.

The selected squares are projected into the quadrilateral reference. Object extents determine boundary inclusion: top/left are included, bottom/right are excluded. Triple-line bundles use their middle ruling. Extents near tilted boundaries are conservatively represented by transformed image-axis bounds.

For area `A` in mm², depth `d` in mm, dilution `D`, count `N`, stock volume `V` in mL and target `T`:

```text
Sampled volume = A × d / 1000 mL
Concentration C = N × D × 1000 / (A × d) cells/mL
Total stock cells = C × V
Required stock volume = T × 1000 / C µL
```

Concentration is calculated from area, depth and dilution. Stock volume determines total cells and available volume; target count determines required volume. An empty stock or target field leaves the other results visible.

At 0.1 mm depth, 1–4 counted large squares use `mean(N) × D × 10⁴ cells/mL`. The standard five RBC groups cover 0.2 mm² and use `N × D × 50,000 cells/mL`.

Detection uses deterministic image processing. Verification covers cell detection, grid alignment, boundary rules, calculations, image persistence and UI workflows.

Grid references: [Marienfeld](https://www.marienfeld-superior.com/counting-grids.html) and [Thermo Fisher](https://www.thermofisher.com/us/en/home/references/gibco-cell-culture-basics/cell-culture-protocols/counting-cells-in-a-hemacytometer.html).

## 简体中文

图像先校正方向，并将长边限制为 1,600 像素。精细尺度高斯对比度分离暗相差环或亮目标，在带符号对比度响应上分块计算绝对中位差估计局部噪声，并插值生成连续阈值；灵敏度通过二次曲线映射至局部噪声下限。方向中位数抑制连续刻线，保留跨线目标。自动明暗模式先合并亮暗支撑，再执行一次连通域分组，也可手动选择单一明暗。一像素闭运算连接恢复出的轮廓。连通域按对比度、支撑面积、几何形状及自动/手动尺寸筛选，每个目标需包含多个高于局部支撑阈值的种子像素；高灵敏度时接纳较小的紧凑轮廓，并排除细长的三像素刻线端点。相连团块保留为一个对象。

网格与细胞独立检测。通过明暗方向响应提取重复刻线，中央网格拟合 20 个细格间隔，四角候选拟合四个分格间隔；四角网格保留多组横纵候选，对稀疏候选内多余的密集刻线扣分，并验证两个方向的全部五条线；按距离加权的加宽搜索兼容轻微倾斜，局部直线拟合生成四边形。完整九宫格还要求外框线证据。

选中分格映射至四边形参考区域，并按对象边缘执行记上不记下、记左不记右。三线束取中线；倾斜边界附近使用图像轴向包围范围投影，采用较保守的边界范围。

浓度按面积、深度和稀释倍数计算；原液体积决定总细胞数和可用体积，目标细胞数决定所需体积。清空原液体积或目标数时，其余结果继续显示。

计算公式及单位见上文。默认深度 0.1 mm 时，采集中按已计数的 1–4 个大格计算浓度：平均计数 × 稀释倍数 × 10⁴ cells/mL；红细胞标准五中格面积为 0.2 mm²，浓度为五中格计数 × 稀释倍数 × 50,000 cells/mL。

识别采用确定性图像处理。验证覆盖细胞检测、网格定位、压线规则、数值计算、图像保存与界面流程。
