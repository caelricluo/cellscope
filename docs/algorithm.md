# Algorithm and calculations / 算法与计算

## English

Images are normalized to an upright orientation and a maximum edge of 1,600 pixels. Fine-scale Gaussian contrast separates dark phase-contrast rims or bright objects from the local background. A one-pixel closing joins recovered supports. Connected components are filtered by contrast, support area, geometry and an estimated or manually selected size. Connected clusters are retained as single objects.

Grid detection is independent of cell detection. Directional bright/dark responses identify repeated rulings. A central grid is fitted to 20 small-square intervals; corner candidates use four subdivision intervals. Local line fits produce a quadrilateral. A full nine-square reference additionally requires visible outer-ruling evidence.

The selected squares are projected into the quadrilateral reference. Object extents determine boundary inclusion: top/left are included, bottom/right are excluded. Triple-line bundles use their middle ruling. Extents near tilted boundaries are conservatively represented by transformed image-axis bounds.

For area `A` in mm², depth `d` in mm, dilution `D`, count `N`, stock volume `V` in mL and target `T`:

```text
Sampled volume = A × d / 1000 mL
Concentration C = N × D × 1000 / (A × d) cells/mL
Total stock cells = C × V
Required stock volume = T × 1000 / C µL
```

Four 1 mm² corners at 0.1 mm depth use `mean(N) × D × 10⁴ cells/mL`. The standard five RBC groups cover 0.2 mm² and use `N × D × 50,000 cells/mL`.

The implementation uses deterministic image processing rather than a trained cell classifier. Verification covers synthetic fixtures and a representative-image regression; no dataset-wide precision or recall is reported. Detection parameters, object selection and physical chamber dimensions define the counting result.

Grid references: [Marienfeld](https://www.marienfeld-superior.com/counting-grids.html) and [Thermo Fisher](https://www.thermofisher.com/us/en/home/references/gibco-cell-culture-basics/cell-culture-protocols/counting-cells-in-a-hemacytometer.html).

## 简体中文

图像先校正方向，并将长边限制为 1,600 像素。精细尺度高斯对比度分离暗相差环或亮目标，一像素闭运算连接恢复出的轮廓。连通域按对比度、支撑面积、几何形状及自动/手动尺寸筛选，相连团块保留为一个对象。

网格与细胞独立检测。通过明暗方向响应提取重复刻线，中央网格拟合 20 个细格间隔，四角候选拟合四个分格间隔；局部直线拟合生成四边形。完整九宫格还要求外框线证据。

选中分格映射至四边形参考区域，并按对象边缘执行记上不记下、记左不记右。三线束取中线；倾斜边界附近使用图像轴向包围范围投影，采用较保守的边界范围。

计算公式及单位见上文。默认深度 0.1 mm 时，四角浓度为平均计数 × 稀释倍数 × 10⁴ cells/mL；红细胞标准五中格面积为 0.2 mm²，浓度为五中格计数 × 稀释倍数 × 50,000 cells/mL。

实现采用确定性图像处理，并非训练式细胞分类模型。验证包含合成测试和代表图像回归，未提供数据集层面的精确率或召回率。识别参数、目标选择和实际腔室尺寸共同决定计数结果。
