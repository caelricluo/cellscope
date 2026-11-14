package com.cellscope.core

import java.util.concurrent.CancellationException
import kotlin.math.*

internal fun checkCancelled(cancelled: () -> Boolean) { if(cancelled()) throw CancellationException() }
internal object ImageMath {
    fun gaussian(pixels: FloatArray, width: Int, height: Int, sigma: Double, cancelled: () -> Boolean): FloatArray {
        val radius=max(1,ceil(sigma*3).toInt())
        val kernel=FloatArray(2*radius+1) { exp(-(it-radius).toDouble().pow(2)/(2*sigma*sigma)).toFloat() }
        val sum=kernel.sum();for(i in kernel.indices) kernel[i]/=sum
        val horizontal=FloatArray(pixels.size);val output=FloatArray(pixels.size)
        for(y in 0 until height) {
            checkCancelled(cancelled)
            for(x in 0 until width) {
                var value=0f
                for(k in -radius..radius) value+=pixels[y*width+(x+k).coerceIn(0,width-1)]*kernel[k+radius]
                horizontal[y*width+x]=value
            }
        }
        for(y in 0 until height) {
            checkCancelled(cancelled)
            for(x in 0 until width) {
                var value=0f
                for(k in -radius..radius) value+=horizontal[(y+k).coerceIn(0,height-1)*width+x]*kernel[k+radius]
                output[y*width+x]=value
            }
        }
        return output
    }
    fun median(values: List<Double>): Double = if(values.isEmpty()) 0.0 else values.sorted()[values.size/2]
    fun median5(aa: Float,bb: Float,cc: Float,dd: Float,ee: Float): Float {
        var a=aa;var b=bb;var c=cc;var d=dd;var e=ee;var t:Float
        if(a>b){t=a;a=b;b=t};if(d>e){t=d;d=e;e=t}
        if(a>c){t=a;a=c;c=t};if(b>c){t=b;b=c;c=t}
        if(a>d){t=a;a=d;d=t};if(c>d){t=c;c=d;d=t}
        if(b>e){t=b;b=e;e=t};if(b>c){t=b;b=c;c=t}
        return min(c,e)
    }
    class Noise(private val levels: FloatArray, private val columns: Int, private val rows: Int) {
        fun at(x: Int,y: Int): Float {
            val yy=(y/64.0-.5).coerceIn(0.0,(rows-1).toDouble());val y0=yy.toInt();val y1=min(rows-1,y0+1);val fy=(yy-y0).toFloat()
            val xx=(x/64.0-.5).coerceIn(0.0,(columns-1).toDouble());val x0=xx.toInt();val x1=min(columns-1,x0+1);val fx=(xx-x0).toFloat()
            return (1-fy)*((1-fx)*levels[y0*columns+x0]+fx*levels[y0*columns+x1])+fy*((1-fx)*levels[y1*columns+x0]+fx*levels[y1*columns+x1])
        }
    }
    fun localNoise(response: FloatArray,width: Int,height: Int,cancelled: () -> Boolean): Noise {
        val columns=(width+63)/64;val rows=(height+63)/64;val levels=FloatArray(columns*rows){.6f}
        for(ty in 0 until rows) {
            checkCancelled(cancelled)
            for(tx in 0 until columns) {
                val values=ArrayList<Double>(484)
                for(y in ty*64 until min(height,(ty+1)*64) step 3) for(x in tx*64 until min(width,(tx+1)*64) step 3) values.add(response[y*width+x].toDouble())
                if(values.size>=12) { val center=median(values);levels[ty*columns+tx]=(1.4826*median(values.map { abs(it-center) })).toFloat() }
            }
        }
        return Noise(levels,columns,rows)
    }
    fun closing(mask: ByteArray,width: Int,height: Int,cancelled: () -> Boolean): ByteArray {
        val expanded=mask.copyOf();val output=mask.copyOf()
        for(y in 1 until height-1) {
            checkCancelled(cancelled)
            for(x in 1 until width-1) {
                val p=y*width+x
                expanded[p]=(mask[p].toInt() or mask[p-1].toInt() or mask[p+1].toInt() or mask[p-width].toInt() or mask[p+width].toInt()).toByte()
            }
        }
        for(y in 1 until height-1) {
            checkCancelled(cancelled)
            for(x in 1 until width-1) {
                val p=y*width+x
                output[p]=(expanded[p].toInt() and expanded[p-1].toInt() and expanded[p+1].toInt() and expanded[p-width].toInt() and expanded[p+width].toInt()).toByte()
            }
        }
        return output
    }
}
