package com.cellscope.core

import kotlin.math.*

data class GridDetection(val central: Quad? = null, val overview: Quad? = null, val corner: Quad? = null, val lineSupport: Double = 0.0) {
    fun alignment(mode: CountMode): Quad? = when(mode) { CountMode.OVERVIEW->overview; CountMode.CORNERS->corner; CountMode.RBC->central; CountMode.CUSTOM->null }
}

object GridDetector {
    private data class Lattice(val start: Double,val end: Double,val score: Double,val support: Double)
    fun detect(image: GrayImage,cancelled: () -> Boolean = { Thread.currentThread().isInterrupted }): GridDetection {
        var result=GridDetection();val w=image.width;val h=image.height
        if(w !in 80..2048 || h !in 80..2048 || image.pixels.size!=w*h) return result
        val g=ImageMath.gaussian(image.floats(),w,h,.7,cancelled);var cornerScore=Double.NEGATIVE_INFINITY
        for(polarity in listOf(1f,-1f)) {
            checkCancelled(cancelled)
            val vx=FloatArray(w*h);val hy=FloatArray(w*h);var xp=DoubleArray(w);var yp=DoubleArray(h)
            val xn=IntArray(w);val yn=IntArray(h);val delta=max(3,min(w,h)/288)
            for(y in delta until h-delta) {
                checkCancelled(cancelled)
                for(x in delta until w-delta) {
                    val p=y*w+x;if(g[p]<=65) continue
                    vx[p]=max(0f,polarity*(g[p]-(g[p-delta]+g[p+delta])/2))
                    hy[p]=max(0f,polarity*(g[p]-(g[p-delta*w]+g[p+delta*w])/2))
                    xp[x]+=vx[p];yp[y]+=hy[p];xn[x]++;yn[y]++
                }
            }
            for(x in 0 until w) xp[x]=if(xn[x]>h*2/5) xp[x]/xn[x] else 0.0
            for(y in 0 until h) yp[y]=if(yn[y]>w*2/5) yp[y]/yn[y] else 0.0
            xp=smooth(xp);yp=smooth(yp)
            val a=fits(xp,20,cancelled).firstOrNull();val b=fits(yp,20,cancelled).firstOrNull()
            if(a!=null && b!=null && compatible(a,b)) {
                val quad=refine(a,b,vx,hy,w,h)
                if(quad?.valid==true) {
                    val strength=min(a.support,b.support)
                    if(result.central==null || strength>result.lineSupport) {
                        val outer=Quad(quad.project(-1.0,-1.0),quad.project(2.0,-1.0),quad.project(2.0,2.0),quad.project(-1.0,2.0))
                        result=result.copy(central=quad,lineSupport=strength,overview=outer.takeIf { it.valid && visible(it,g,w,h) && edgesSupported(it,vx,hy,w,h) })
                    }
                }
            }
            if(result.central==null) {
                val xs=fits(xp,4,cancelled).take(8);val ys=fits(yp,4,cancelled).take(8)
                for(x in xs) for(y in ys) {
                    checkCancelled(cancelled)
                    if(!compatible(x,y) || x.score+y.score<=cornerScore) continue
                    val quad=refine(x,y,vx,hy,w,h,true) ?: continue
                    if(!quad.valid || !visible(quad,g,w,h) || !edgesSupported(quad,vx,hy,w,h) || !subdivisionsSupported(x,y,vx,hy,w,h)) continue
                    result=result.copy(corner=quad,lineSupport=min(x.support,y.support));cornerScore=x.score+y.score
                }
            }
        }
        return if(result.central!=null) result.copy(corner=null) else result
    }
    private fun smooth(p: DoubleArray): DoubleArray = p.copyOf().also { out ->
        for(i in 2 until p.size-2) out[i]=(p[i-2]+4*p[i-1]+6*p[i]+4*p[i+1]+p[i+2])/16
    }
    private fun fits(p: DoubleArray,intervals: Int,cancelled: () -> Boolean): List<Lattice> {
        val noise=ImageMath.median(p.filter { it>0 });val peaks=ArrayList<Int>()
        for(i in 8 until p.size-8) if(p[i]>=p[i-1] && p[i]>p[i+1]) {
            var left=p[i];var right=p[i]
            for(k in i-8 until i) left=min(left,p[k]);for(k in i+1..i+8) right=min(right,p[k])
            if(p[i]-max(left,right)>(if(intervals==20).65 else .3) && p[i]>max(1.2,noise+.5)) {
                val last=peaks.lastOrNull()
                if(last!=null && i-last<8) {if(p[i]>p[last]) peaks[peaks.lastIndex]=i} else peaks.add(i)
            }
        }
        if(peaks.size<intervals+1) return emptyList()
        val candidates=ArrayList<Lattice>();val minSpan=p.size*(if(intervals==20).18 else .42)
        for(a in peaks) {
            checkCancelled(cancelled)
            for(b in peaks) {
                if(b<=a || b-a<minSpan || b-a>p.size*.94) continue
                val step=(b-a).toDouble()/intervals
                if(step<(if(intervals==20)8 else 15)) continue
                val values=(0..intervals).map { k ->
                    val index=(a+k*step).roundToInt();val radius=if(intervals==20) min(4,max(2,(step*.12).toInt())) else max(4,(step*.11).toInt())
                    (max(0,index-radius)..min(p.lastIndex,index+radius)).maxOf { p[it] }
                }
                val hits=values.count { it>max(1.8,noise+.8) };val median=ImageMath.median(values)
                if(hits<(if(intervals==20)19 else 5) || median<=noise+1 || p[a]<=noise+1 || p[b]<=noise+1) continue
                val mean=values.sumOf { min(it,10.0) }/values.size
                var score=mean+median+hits*.3+.6*(p[a]+p[b])
                if(intervals==4) {
                    val tolerance=max(10.0,step*.12)
                    val penalty=peaks.filter { q -> q>a && q<b && (0..4).all { abs((q-a)-it*step)>tolerance } }.sumOf { min(10.0,max(0.0,p[it]-noise)) }
                    score=mean+min(10.0,median)+hits*.3+.6*(min(10.0,p[a])+min(10.0,p[b]))-penalty
                }
                candidates.add(Lattice(a.toDouble(),b.toDouble(),score,hits.toDouble()/(intervals+1)))
            }
        }
        return candidates.sortedByDescending { it.score }
    }
    private fun compatible(x: Lattice,y: Lattice): Boolean {
        val ratio=(x.end-x.start)/(y.end-y.start)
        return ratio>.72 && ratio<1.38
    }
    private fun subdivisionsSupported(x: Lattice,y: Lattice,vx: FloatArray,hy: FloatArray,w: Int,h: Int): Boolean {
        for(k in 1..3) {
            if(side(vx,x.start+(x.end-x.start)*k/4,y.start,y.end,true,w,h,max(10,((x.end-x.start)*.035).toInt()))==null ||
                side(hy,y.start+(y.end-y.start)*k/4,x.start,x.end,false,w,h,max(10,((y.end-y.start)*.035).toInt()))==null) return false
        }
        return true
    }
    private fun side(response: FloatArray,position: Double,low: Double,high: Double,vertical: Boolean,w: Int,h: Int,search: Int=10): Pair<Double,Double>? {
        val points=ArrayList<Pair<Double,Double>>();val size=if(vertical)w else h;val length=if(vertical)h else w
        for(bin in 0..15) {
            val from=max(1,(low+(high-low)*bin/16).toInt());val to=min(length-2,(low+(high-low)*(bin+1)/16).toInt())
            val lo=max(1,position.toInt()-search);val hi=min(size-2,position.toInt()+search)
            if(to<=from || hi<=lo) continue
            val profile=DoubleArray(hi-lo+1)
            for(q in lo..hi) {for(t in from..to) profile[q-lo]+=response[if(vertical)t*w+q else q*w+t];profile[q-lo]/=(to-from+1)}
            fun strength(i: Int): Double {val distance=abs(i+lo-position)/search;return profile[i]/(1+(if(search>10)4 else 0)*distance*distance)}
            val strongest=profile.indices.maxByOrNull { strength(it) } ?: continue
            if(profile[strongest]<=1.5) continue
            var peak=strongest
            val ridges=(1 until profile.size-1).filter { profile[it]>profile[it-1] && profile[it]>=profile[it+1] && profile[it]>profile[strongest]*.4 }
            for(i in 0 until ridges.size-2) {
                val a=ridges[i];val b=ridges[i+1];val c=ridges[i+2]
                if(b-a in 2..6 && c-b in 2..6 && strongest in listOf(a,b,c)) {peak=b;break}
            }
            var weight=0.0;var coordinate=0.0
            for(i in max(0,peak-3)..min(profile.lastIndex,peak+3)) {val v=max(0.0,profile[i]-profile[peak]*.5);weight+=v;coordinate+=v*(i+lo)}
            if(weight>0) points.add((from+to)/2.0 to coordinate/weight)
        }
        if(points.size<10) return null
        fun regression(p: List<Pair<Double,Double>>): Pair<Double,Double> {
            val mx=p.sumOf { it.first }/p.size;val my=p.sumOf { it.second }/p.size
            val numerator=p.sumOf { (it.first-mx)*(it.second-my) };val denominator=p.sumOf { (it.first-mx).pow(2) }
            val slope=if(denominator>0) numerator/denominator else 0.0
            return my-slope*mx to slope
        }
        val first=regression(points);val retained=points.filter { abs(it.second-first.first-first.second*it.first)<4 }
        if(retained.size<9) return null
        return regression(retained).takeIf { abs(it.second)<.08 }
    }
    private fun refine(x: Lattice,y: Lattice,vx: FloatArray,hy: FloatArray,w: Int,h: Int,sparse: Boolean=false): Quad? {
        val sx=if(sparse) max(10,((x.end-x.start)*.04).toInt()) else 10
        val sy=if(sparse) max(10,((y.end-y.start)*.04).toInt()) else 10
        val l=side(vx,x.start,y.start,y.end,true,w,h,sx) ?: return null
        val r=side(vx,x.end,y.start,y.end,true,w,h,sx) ?: return null
        val t=side(hy,y.start,x.start,x.end,false,w,h,sy) ?: return null
        val b=side(hy,y.end,x.start,x.end,false,w,h,sy) ?: return null
        fun intersection(v: Pair<Double,Double>,line: Pair<Double,Double>): Point {
            val xx=(v.first+v.second*line.first)/(1-v.second*line.second);val yy=line.first+line.second*xx
            return Point(xx/w,yy/h)
        }
        return Quad(intersection(l,t),intersection(r,t),intersection(r,b),intersection(l,b))
    }
    private fun visible(q: Quad,g: FloatArray,w: Int,h: Int) = q.corners.all { g[(it.y*h).toInt().coerceIn(0,h-1)*w+(it.x*w).toInt().coerceIn(0,w-1)]>70 }
    private fun edgesSupported(q: Quad,vx: FloatArray,hy: FloatArray,w: Int,h: Int): Boolean {
        val corners=q.corners
        for(edge in 0..3) {
            val a=corners[edge];val b=corners[(edge+1)%4];val vertical=edge%2==1;var hits=0
            for(k in 1..99) {
                val f=k/100.0;val x=((a.x+(b.x-a.x)*f)*w).toInt();val y=((a.y+(b.y-a.y)*f)*h).toInt();var value=0f
                for(delta in -3..3) {val xx=(x+if(vertical)delta else 0).coerceIn(0,w-1);val yy=(y+if(vertical)0 else delta).coerceIn(0,h-1);value=max(value,if(vertical)vx[yy*w+xx] else hy[yy*w+xx])}
                if(value>3) hits++
            }
            if(hits<65) return false
        }
        return true
    }
}
