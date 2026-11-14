package com.cellscope.core

import kotlin.math.*

data class DetectionReport(val markers: List<Marker> = emptyList(), val estimatedDiameter: Double = 0.0,
                           val componentsExamined: Int = 0, val rejectedShape: Int = 0,
                           val rejectedContrast: Int = 0, val excludedByRegion: Int = 0)

/** Port of the iOS fine-scale, noise-adaptive detector. Bright/dark supports
 * share a single connected-component pass, so touching clusters stay together. */
object CellDetector {
    private class Component {
        var minX=Int.MAX_VALUE;var minY=Int.MAX_VALUE;var maxX=0;var maxY=0
        var count=0;var sumX=0L;var sumY=0L;var strong=0;var original=0
        val diameter get()=max(maxX-minX+1,maxY-minY+1).toDouble()
        val shortSide get()=min(maxX-minX+1,maxY-minY+1)
        val aspect get()=max((maxX-minX+1).toDouble()/(maxY-minY+1),(maxY-minY+1).toDouble()/(maxX-minX+1))
        val fill get()=count.toDouble()/((maxX-minX+1)*(maxY-minY+1))
    }
    fun analyze(image: GrayImage, region: Region = Region(), settings: DetectionSettings = DetectionSettings(),
                grid: Grid = Grid(CountMode.CUSTOM), quad: Quad? = null,
                cancelled: () -> Boolean = { Thread.currentThread().isInterrupted }): DetectionReport {
        val w=image.width;val h=image.height
        if(w !in 5..2048 || h !in 5..2048 || image.pixels.size!=w*h || !region.valid || !settings.valid || !grid.valid) return DetectionReport()
        checkCancelled(cancelled)
        val short=min(w,h).toDouble()
        val fine=ImageMath.gaussian(image.floats(),w,h,.7,cancelled)
        val background=ImageMath.gaussian(image.floats(),w,h,max(2.5,short/400),cancelled)
        for(p in fine.indices) fine[p]-=background[p]
        val noise=ImageMath.localNoise(fine,w,h,cancelled)
        val sensitivity=settings.sensitivity.coerceIn(0.0,1.0).toFloat();val step=max(8,min(w,h)/85)
        // Keep evidence bits rather than three additional full-resolution float buffers.
        val evidence=ByteArray(w*h);var mask=ByteArray(w*h)
        for(y in 0 until h) {
            checkCancelled(cancelled)
            for(x in 0 until w) {
                val p=y*w+x;val r=fine[p]
                val v=ImageMath.median5(fine[max(0,y-2*step)*w+x],fine[max(0,y-step)*w+x],r,fine[min(h-1,y+step)*w+x],fine[min(h-1,y+2*step)*w+x])
                val horizontal=ImageMath.median5(fine[y*w+max(0,x-2*step)],fine[y*w+max(0,x-step)],r,fine[y*w+min(w-1,x+step)],fine[y*w+min(w-1,x+2*step)])
                val bright=max(0f,r-max(0f,v)-max(0f,horizontal));val dark=max(0f,-r-max(0f,-v)-max(0f,-horizontal))
                val response=when(settings.polarity){Polarity.AUTO->max(bright,dark);Polarity.DARK->dark;Polarity.BRIGHT->bright}
                val localNoise=noise.at(x,y);val floor=max(.8f,1.4f*localNoise)
                val threshold=floor+max(0f,18-floor)*(1-sensitivity)*(1-sensitivity)
                val seed=threshold+max(.7f,.75f*localNoise)
                evidence[p]=((if(response>threshold) 1 else 0)+(if(response>seed) 2 else 0)).toByte()
                if(response>threshold && background[p]>55) mask[p]=1
            }
        }
        mask=ImageMath.closing(mask,w,h,cancelled)
        val components=ArrayList<Component>();var queue=IntArray(min(w*h,4096))
        var examined=0;var rejectedShape=0;var rejectedContrast=0;var excluded=0
        for(seed in mask.indices) {
            if(mask[seed].toInt()!=1) continue
            checkCancelled(cancelled);examined++
            var size=1;var head=0;queue[0]=seed;mask[seed]=0;val c=Component()
            while(head<size) {
                if(head%4096==0) checkCancelled(cancelled)
                val p=queue[head++];val x=p%w;val y=p/w
                c.count++;c.sumX+=x;c.sumY+=y;c.minX=min(c.minX,x);c.maxX=max(c.maxX,x);c.minY=min(c.minY,y);c.maxY=max(c.maxY,y)
                if(evidence[p].toInt() and 1 != 0) c.original++
                if(evidence[p].toInt() and 2 != 0) c.strong++
                for(ny in max(0,y-1)..min(h-1,y+1)) for(nx in max(0,x-1)..min(w-1,x+1)) {
                    val next=ny*w+nx
                    if(mask[next].toInt()==1) {
                        mask[next]=0
                        if(size==queue.size) queue=queue.copyOf(min(w*h,queue.size*2))
                        queue[size++]=next
                    }
                }
            }
            if(c.diameter<3 || c.diameter>short*.25 || c.count<6 || c.aspect>=5 || c.fill<.16) { rejectedShape++;continue }
            if(c.strong<3 || c.strong.toDouble()/max(1,c.original)<.25) {rejectedContrast++;continue}
            components.add(c)
        }
        val isolated=components.filter { it.aspect<2 && it.diameter<=short*.15 && it.count>=10 }.map { it.diameter }
        val estimated=ImageMath.median(isolated.ifEmpty { components.filter { it.aspect<2 }.map { it.diameter } })
        val recovery=max(0.0,(sensitivity-.7)/.3)
        val minimum=if(settings.automaticSize) max(4.0,if(estimated>0) estimated*(.5-.2*recovery) else 4.0) else max(3.0,settings.minimumDiameter*short)
        val maximum=if(settings.automaticSize) max(20.0,estimated*5) else settings.maximumDiameter*short*3
        val markers=ArrayList<Marker>()
        for(c in components) {
            if(c.diameter<minimum || c.diameter>maximum || !(c.shortSide>=4 || (sensitivity>.8 && c.shortSide>=3 && c.aspect<=1.8)) || c.count<max(if(sensitivity>.8)8.0 else 12.0,minimum*minimum*.18)) {rejectedShape++;continue}
            val extent=Region(c.minX.toDouble()/w,c.minY.toDouble()/h,(c.maxX-c.minX+1).toDouble()/w,(c.maxY-c.minY+1).toDouble()/h)
            val marker=Marker((c.sumX.toDouble()/c.count+.5)/w,(c.sumY.toDouble()/c.count+.5)/h,(c.diameter/2+.8)/short,extent=extent)
            if(grid.assigned(marker,region,quad)==null) {excluded++;continue}
            markers.add(marker)
        }
        return DetectionReport(markers.sortedWith(compareBy<Marker>{it.y}.thenBy{it.x}),estimated,examined,rejectedShape,rejectedContrast,excluded)
    }
}
