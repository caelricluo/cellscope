package com.cellscope.core

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CancellationException
import kotlin.math.*

class CoreTests {
    private val whole=Region(0.0,0.0,1.0,1.0)
    private fun fixture(bright: Boolean=false): GrayImage {
        val w=200;val h=160;val pixels=ByteArray(w*h){(if(bright)25 else 225).toByte()}
        for((cx,cy,r) in listOf(Triple(40,40,5),Triple(100,80,6),Triple(160,120,5),Triple(20,130,1))) {
            for(y in 0 until h) for(x in 0 until w) if((x-cx)*(x-cx)+(y-cy)*(y-cy)<=r*r) pixels[y*w+x]=(if(bright)200 else 65).toByte()
        }
        for(x in 0 until w) pixels[15*w+x]=(if(bright)200 else 65).toByte()
        return GrayImage(w,h,pixels)
    }
    @Test fun standardConcentrationAndVolume() {
        val r=Inputs().calculate(50)!!
        assertEquals(1_000_000.0,r.concentration,1e-8);assertEquals(1_000_000.0,r.totalCells!!,1e-8)
        assertEquals(100.0,r.requiredMicroliters!!,1e-8);assertEquals(0.0,r.shortfall!!,1e-8)
    }
    @Test fun customAreaDepthAndDilution() {
        val r=Inputs(area="0.04",depth="0.2",dilution="20",stockVolume="0.5",target="5000000").calculate(10)!!
        assertEquals(25_000_000.0,r.concentration,1e-6);assertEquals(12_500_000.0,r.totalCells!!,1e-6);assertEquals(200.0,r.requiredMicroliters!!,1e-6)
    }
    @Test fun invalidFundamentalInputs() {
        for(invalid in listOf("0","-2","NaN","Infinity","","abc","1e999")) assertNull(invalid,Inputs(area=invalid).calculate(30))
        assertNull(Inputs(dilution="0.5").calculate(30));assertNull(Inputs().calculate(-1))
    }
    @Test fun zeroCountHasConcentrationWithoutRequiredVolume() {val r=Inputs().calculate(0)!!;assertEquals(0.0,r.concentration,0.0);assertNull(r.requiredMicroliters)}
    @Test fun targetEditingKeepsOtherResults() {
        for(target in listOf("","0","-1","abc","NaN","Infinity")) {val r=Inputs(target=target).calculate(50)!!;assertEquals(1_000_000.0,r.concentration,0.0);assertEquals(1_000_000.0,r.totalCells!!,0.0);assertNull(r.requiredMicroliters)}
    }
    @Test fun stockEditingKeepsOtherResults() {
        for(stock in listOf("","0","-1","NaN","abc")) {val r=Inputs(stockVolume=stock).calculate(50)!!;assertEquals(1_000_000.0,r.concentration,0.0);assertEquals(100.0,r.requiredMicroliters!!,0.0);assertNull(r.totalCells);assertNull(r.availableMicroliters)}
    }
    @Test fun overflowDoesNotLeakNonFiniteResults() {
        val zero=Inputs(stockVolume="1e307").calculate(0)!!;assertNull(zero.availableMicroliters);assertEquals(0.0,zero.totalCells!!,0.0)
        val dense=Inputs(stockVolume="1e307").calculate(50)!!;assertNull(dense.totalCells);assertNull(dense.availableMicroliters)
        val tiny=Inputs(area="1e308",target="1e308").calculate(10)!!;assertTrue(tiny.concentration.isFinite());assertNull(tiny.requiredMicroliters)
    }
    @Test fun decimalCommaAndVolumeShortfall() {val r=Inputs(stockVolume="0,01").calculate(50)!!;assertEquals(90.0,r.shortfall!!,1e-8);assertEquals(.1,Inputs.positive(" 0,1 ")!!,0.0)}
    @Test fun fourCornerMeanKeepsFractionalPrecision() {val r=Inputs().calculateCorners(listOf(48,49,49,49))!!;assertEquals(975_000.0,r.concentration,1e-8)}
    @Test fun partialCornersUseAvailableArea() {
        assertEquals(400_000.0,Inputs().calculateCorners(listOf(20))!!.concentration,1e-8)
        assertEquals(500_000.0,Inputs().calculateCorners(listOf(20,30))!!.totalCells!!,1e-8)
        assertNull(Inputs().calculateCorners(emptyList()));assertNull(Inputs().calculateCorners(listOf(1,2,3,4,5)));assertNull(Inputs().calculateCorners(listOf(-1)))
    }
    @Test fun gridAreasAndSelections() {
        assertEquals(9.0,Grid(CountMode.OVERVIEW).area!!,0.0)
        assertEquals(4.0,Grid(CountMode.OVERVIEW,listOf(0,2,6,8)).area!!,0.0)
        assertEquals(.2,Grid(CountMode.RBC).area!!,1e-12);assertNull(Grid(CountMode.CUSTOM).area)
        assertFalse(Grid(CountMode.OVERVIEW,listOf(0,0)).valid);assertFalse(Grid(CountMode.RBC,listOf(25)).valid)
    }
    @Test fun centerBoundaryRuleAndNaN() {val g=Grid(CountMode.CUSTOM);assertNotNull(g.index(.1,.1,Region()));assertNull(g.index(.9,.5,Region()));assertNull(g.index(Double.NaN,.5,Region()))}
    @Test fun extentBoundaryRule() {
        val g=Grid(CountMode.CUSTOM);val r=Region(.2,.2,.6,.6)
        assertNotNull(g.assigned(Marker(.195,.4,.01,extent=Region(.18,.39,.02,.02)),r))
        assertNull(g.assigned(Marker(.79,.4,.01,extent=Region(.78,.39,.02,.02)),r))
        assertNotNull(g.assigned(Marker(.4,.195,.01,extent=Region(.39,.18,.02,.02)),r))
        assertNull(g.assigned(Marker(.4,.79,.01,extent=Region(.39,.78,.02,.02)),r))
    }
    @Test fun internalBoundaryAssignedOnce() {
        val g=Grid(CountMode.OVERVIEW);val m=Marker(1.0/3-.005,.1,.01,extent=Region(1.0/3-.015,.09,.02,.02))
        assertEquals(1,g.assigned(m,whole));assertEquals(1,g.counts(listOf(m),whole).values.sum())
    }
    @Test fun projectiveMappingRoundTrip() {
        val q=Quad(Point(.2,.15),Point(.8,.2),Point(.75,.85),Point(.15,.75));assertTrue(q.valid)
        for(x in listOf(0.0,.3,1.0))for(y in listOf(0.0,.7,1.0)){val p=q.unproject(q.project(x,y))!!;assertEquals(x,p.x,1e-10);assertEquals(y,p.y,1e-10)}
    }
    @Test fun projectedExtentUsesPhysicalGrid() {
        val q=Quad(Region(.2,.2,.6,.6));val g=Grid(CountMode.CUSTOM)
        assertNotNull(g.assigned(Marker(.195,.4,.01,extent=Region(.18,.39,.02,.02)),q.bounds,q))
        assertNull(g.assigned(Marker(.79,.4,.01,extent=Region(.78,.39,.02,.02)),q.bounds,q))
    }
    @Test fun frameTranslationClampsTogether() {val q=Quad(Region(.2,.3,.5,.4));val m=q.adjust(Handle.MOVE,.9,-1.0);assertEquals(.5,m.bounds.x,1e-12);assertEquals(0.0,m.bounds.y,1e-12);assertEquals(.5,m.bounds.width,1e-12)}
    @Test fun cornersAndEdgesRetainPerspective() {
        val q=Quad(Region(.2,.2,.6,.6));val m=q.adjust(Handle.TOP_LEFT,.03,.04)
        assertEquals(.23,m.topLeft.x,1e-12);assertEquals(q.topRight,m.topRight)
        assertEquals(.78,m.adjust(Handle.RIGHT,-.02,0.0).bottomRight.x,1e-12)
        assertEquals(q,q.adjust(Handle.TOP_LEFT,.7,.7));assertEquals(q,q.adjust(Handle.MOVE,Double.NaN,0.0))
    }
    @Test fun diameterLimitsStayOrdered() {
        val a=DetectionSettings(automaticSize=false).withMinimum(.08);assertEquals(.08,a.maximumDiameter,0.0);assertTrue(a.valid)
        val b=a.withMaximum(.02);assertEquals(.02,b.minimumDiameter,0.0);assertTrue(b.valid)
        assertEquals(b,b.withMinimum(Double.NaN));assertFalse(b.copy(minimumDiameter=.03).valid)
    }
    @Test fun detectorRejectsGridAndDebrisAndUsesRegion() {
        val r=CellDetector.analyze(fixture(),whole);assertEquals(3,r.markers.size)
        assertEquals(.2025,r.markers.first().x,.005)
        assertEquals(2,CellDetector.analyze(fixture(),Region(.4,.3,.5,.6)).markers.size)
    }
    @Test fun brightCellsAndMalformedImages() {
        assertEquals(3,CellDetector.analyze(fixture(true),whole,DetectionSettings(polarity=Polarity.BRIGHT)).markers.size)
        assertTrue(CellDetector.analyze(GrayImage(20,20,byteArrayOf()),whole).markers.isEmpty())
        assertTrue(CellDetector.analyze(fixture(),Region(width=-1.0)).markers.isEmpty())
        assertTrue(CellDetector.analyze(fixture(),whole,DetectionSettings(sensitivity=Double.NaN)).markers.isEmpty())
    }
    @Test fun automaticSizeIgnoresUnusedManualLimits() {
        val s=DetectionSettings(minimumDiameter=.08,maximumDiameter=.04)
        assertEquals(3,CellDetector.analyze(fixture(),whole,s).markers.size)
        assertTrue(CellDetector.analyze(fixture(),whole,s.copy(automaticSize=false)).markers.isEmpty())
    }
    @Test fun touchingClumpRemainsOneObject() {
        val w=200;val h=160;val p=ByteArray(w*h){225.toByte()}
        for(cx in listOf(70,82))for(y in 0 until h)for(x in 0 until w)if((x-cx).toDouble().pow(2)+(y-70).toDouble().pow(2)<=64)p[y*w+x]=60
        assertEquals(1,CellDetector.analyze(GrayImage(w,h,p),whole).markers.size)
    }
    @Test fun smallPhaseRingsClumpsAndIntersections() {
        val w=400;val p=ByteArray(w*w){180.toByte()}
        for(q in 40..360 step 40)for(a in 20 until 380){p[q*w+a]=225.toByte();p[a*w+q]=225.toByte()}
        val centers=listOf(Triple(63,63,3),Triple(102,103,4),Triple(182,183,5),Triple(263,262,4),Triple(270,262,4))
        for((cx,cy,r)in centers)for(y in cy-r..cy+r)for(x in cx-r..cx+r){val d=hypot((x-cx).toDouble(),(y-cy).toDouble());if(d<=r)p[y*w+x]=(if(d>=r-1.5)70 else 235).toByte()}
        val r=CellDetector.analyze(GrayImage(w,w,p),whole);assertEquals(4,r.markers.size);assertTrue(r.estimatedDiameter<=16)
        centers.take(3).forEach { (x,y,_) -> assertTrue(r.markers.any {hypot(it.x*w-x,it.y*w-y)<2}) }
    }
    @Test fun faintMixedPolarityAndSmallTargets() {
        val w=420;val h=400;val p=ByteArray(w*h)
        for(y in 0 until h)for(x in 0 until w)p[y*w+x]=(165+x/35+y/50+(x*17+y*13)%3-1).toByte()
        val centers=listOf(doubleArrayOf(83.0,90.0,1.0,18.0),doubleArrayOf(185.0,110.0,-1.0,18.0),doubleArrayOf(305.0,95.0,1.0,18.0),doubleArrayOf(115.0,260.0,-1.0,18.0),doubleArrayOf(305.0,280.0,1.0,6.5))
        for((cx,cy,sign,spread)in centers)for(y in cy.toInt()-10..cy.toInt()+10)for(x in cx.toInt()-10..cx.toInt()+10){val r2=(x-cx).pow(2)+(y-cy).pow(2);p[y*w+x]=((p[y*w+x].toInt() and 255)+sign*11*exp(-r2/spread)).toInt().coerceIn(0,255).toByte()}
        val image=GrayImage(w,h,p);val settings=DetectionSettings(sensitivity=1.0)
        val r=CellDetector.analyze(image,whole,settings);assertEquals(5,r.markers.size)
        centers.forEach { (x,y,_,_)->assertTrue(r.markers.any {hypot(it.x*w-x,it.y*h-y)<3}) }
        assertTrue(CellDetector.analyze(image,whole,settings.copy(sensitivity=0.0)).markers.isEmpty())
        assertEquals(3,CellDetector.analyze(image,whole,settings.copy(polarity=Polarity.BRIGHT)).markers.size)
        assertEquals(2,CellDetector.analyze(image,whole,settings.copy(polarity=Polarity.DARK)).markers.size)
    }
    @Test fun maximumSensitivityRejectsFlatNoiseAndRulingEnds() {
        val w=400;val p=ByteArray(w*w)
        for(y in 0 until w)for(x in 0 until w)p[y*w+x]=(170+x/40+(x*17+y*13)%3-1).toByte()
        for(q in 40..360 step 80)for(a in 10 until 390){p[q*w+a]=205.toByte();p[a*w+q]=135.toByte()}
        assertTrue(CellDetector.analyze(GrayImage(w,w,p),whole,DetectionSettings(sensitivity=1.0)).markers.isEmpty())
    }
    private fun lattice(full: Boolean=false,dark: Boolean=false): GrayImage {
        val w=900;val p=ByteArray(w*w){(if(dark)220 else 150).toByte()};val start=if(full)350 else 150;val span=if(full)200 else 600
        fun line(a: Int,b: Int,c: Int,d: Int){for(y in b..d)for(x in a..c)p[y*w+x]=(if(dark)95 else 240).toByte()}
        for(k in 0..20){val q=start+k*span/20;line(q,start,q,start+span);line(start,q,start+span,q)}
        if(full)for(k in 0..3){val q=150+k*200;line(q,150,q,750);line(150,q,750,q)}
        return GrayImage(w,w,p)
    }
    @Test fun centralGridCannotBecomeCroppedOverviewOrCorner() {
        for(dark in listOf(false,true)){val r=GridDetector.detect(lattice(dark=dark));val q=r.central!!;assertEquals(1.0/6,q.topLeft.x,.008);assertEquals(5.0/6,q.bottomRight.y,.008);assertNull(r.overview);assertNull(r.corner);assertNull(r.alignment(CountMode.CORNERS))}
    }
    @Test fun overviewRequiresObservedOuterRulings() {val q=GridDetector.detect(lattice(full=true)).overview!!;assertEquals(1.0/6,q.topLeft.x,.012);assertEquals(5.0/6,q.bottomRight.y,.012)}
    @Test fun cornerTripleLineUsesMiddle() {
        val w=600;val p=ByteArray(w*w){180.toByte()}
        for(k in 0..4)for(delta in listOf(-4,0,4)){val q=100+k*100+delta;for(a in 100..500){p[a*w+q]=235.toByte();p[q*w+a]=235.toByte()}}
        val r=GridDetector.detect(GrayImage(w,w,p));val q=r.corner!!;assertEquals(100.0,q.topLeft.x*w,2.0);assertEquals(500.0,q.bottomRight.y*w,2.0);assertNull(r.central)
    }
    @Test fun circleAndBlankAreNotCountingBorders() {
        val w=300;val p=ByteArray(w*w){10}
        for(y in 0 until w)for(x in 0 until w)if((x-150).toDouble().pow(2)+(y-150).toDouble().pow(2)<140*140)p[y*w+x]=180.toByte()
        for(image in listOf(GrayImage(w,w,p),GrayImage(w,w,ByteArray(w*w){180.toByte()}))){val r=GridDetector.detect(image);assertNull(r.central);assertNull(r.overview);assertNull(r.corner)}
    }
    @Test fun tiltedSparseCornerBesideDenseBands() {
        val w=900;val h=960;val p=ByteArray(w*h){180.toByte()}
        val verticals=(60..300 step 24).toList()+(420..780 step 120).toList();val horizontals=(180..660 step 120).toList()+(684..900 step 24).toList()
        for(y in 20 until 920)for(x in 20 until 880){val xx=x-.018*(y-420);val yy=y+.01*(x-540);val v=yy in 160.0..920.0 && verticals.any {abs(xx-it)<1.2};val line=xx in 40.0..850.0 && horizontals.any {abs(yy-it)<1.2};p[y*w+x]=(if(v||line)115 else 175+x/100+y/160).toByte()}
        val result=GridDetector.detect(GrayImage(w,h,p));val q=result.corner!!;assertNull(result.central)
        for((point,xx,yy) in listOf(Triple(q.topLeft,300.0,180.0),Triple(q.topRight,780.0,180.0),Triple(q.bottomLeft,300.0,660.0),Triple(q.bottomRight,780.0,660.0))) {val x=point.x*w;val y=point.y*h;assertEquals(xx,x-.018*(y-420),5.0);assertEquals(yy,y+.01*(x-540),5.0)}
    }
    @Test fun directionalMedianMatchesOrderStatistic() {
        for(a in 0..4)for(b in 0..4)for(c in 0..4)for(d in 0..4)for(e in 0..4){val v=listOf(a,b,c,d,e).map(Int::toFloat);assertEquals(v.sorted()[2],ImageMath.median5(v[0],v[1],v[2],v[3],v[4]))}
    }
    @Test fun resetsKeepTargetAndSelectedArea() {val r=Inputs(target="50000",depth=".2",dilution="5",stockVolume=".5").reset(Grid(CountMode.RBC));assertEquals("50000",r.target);assertEquals("0.2",r.area);assertEquals("0.1",r.depth);assertEquals("2",r.dilution);assertEquals("1",r.stockVolume)}
    @Test(expected=CancellationException::class) fun cellWorkCanBeCancelled() {CellDetector.analyze(fixture(),whole,cancelled={true})}
    @Test(expected=CancellationException::class) fun gridWorkCanBeCancelled() {GridDetector.detect(lattice(),cancelled={true})}
}
