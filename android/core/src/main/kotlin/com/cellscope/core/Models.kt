package com.cellscope.core

import java.util.Locale
import java.util.UUID
import kotlin.math.*

data class Region(val x: Double = .1, val y: Double = .1, val width: Double = .8, val height: Double = .8) {
    val valid get() = listOf(x,y,width,height).all { it.isFinite() } && x >= 0 && y >= 0 &&
        width > 0 && height > 0 && x+width <= 1.000001 && y+height <= 1.000001
    fun contains(px: Double, py: Double) = px >= x && py >= y && px < x+width && py < y+height
}
data class Marker(val x: Double, val y: Double, val radius: Double, val manual: Boolean = false,
                  val extent: Region? = null, val id: String = UUID.randomUUID().toString())
enum class Polarity { AUTO, DARK, BRIGHT }
data class DetectionSettings(val sensitivity: Double = .55, val minimumDiameter: Double = .012,
                             val maximumDiameter: Double = .065, val polarity: Polarity = Polarity.AUTO,
                             val automaticSize: Boolean = true) {
    val valid get() = sensitivity.isFinite() && minimumDiameter.isFinite() && maximumDiameter.isFinite() &&
        (automaticSize || (minimumDiameter > 0 && maximumDiameter >= minimumDiameter && maximumDiameter <= 1))
    fun withMinimum(value: Double) = if (value.isFinite() && value > 0 && value <= 1)
        copy(minimumDiameter = value, maximumDiameter = max(value,maximumDiameter)) else this
    fun withMaximum(value: Double) = if (value.isFinite() && value > 0 && value <= 1)
        copy(maximumDiameter = value, minimumDiameter = min(value,minimumDiameter)) else this
}
data class GrayImage(val width: Int, val height: Int, val pixels: ByteArray) {
    fun floats() = FloatArray(pixels.size) { (pixels[it].toInt() and 255).toFloat() }
}
enum class CountMode {
    OVERVIEW, CORNERS, RBC, CUSTOM;
    val divisions get() = when(this) { OVERVIEW -> 3; RBC -> 5; else -> 1 }
    val squareArea get() = if(this == RBC) .04 else 1.0
    val defaults get() = when(this) { OVERVIEW -> (0..8).toList(); RBC -> listOf(0,4,12,20,24); else -> listOf(0) }
    val settings get() = if(this == OVERVIEW || this == RBC) DetectionSettings(minimumDiameter=.006,maximumDiameter=.035) else DetectionSettings()
}
enum class Corner { A1, A3, C1, C3 }
data class Grid(val mode: CountMode = CountMode.CORNERS, val selected: List<Int> = mode.defaults) {
    val valid get() = selected.isNotEmpty() && selected.distinct().size == selected.size && selected.all { it in 0 until mode.divisions*mode.divisions }
    val area get(): Double? = if(mode != CountMode.CUSTOM && valid) selected.size*mode.squareArea else null
    fun label(index: Int) = if(mode == CountMode.OVERVIEW) "${listOf("A","B","C")[index/3]}${index%3+1}" else "${index+1}"
    fun square(index: Int, region: Region): Region {
        val n = mode.divisions.toDouble()
        return Region(region.x+(index%mode.divisions)*region.width/n,region.y+(index/mode.divisions)*region.height/n,region.width/n,region.height/n)
    }
    fun index(x: Double, y: Double, region: Region): Int? {
        if(!region.valid || !region.contains(x,y)) return null
        val n = mode.divisions
        return min(n-1,floor((y-region.y)/region.height*n).toInt())*n + min(n-1,floor((x-region.x)/region.width*n).toInt())
    }
    fun assigned(marker: Marker, region: Region, quad: Quad? = null): Int? {
        if(quad != null) return quad.unitMarker(marker)?.let { assigned(it,Region(0.0,0.0,1.0,1.0)) }
        if(!valid || !region.valid) return null
        val e = marker.extent ?: return index(marker.x,marker.y,region)?.takeIf { it in selected }
        if(!listOf(e.x,e.y,e.width,e.height).all { it.isFinite() } || e.width < 0 || e.height < 0) return null
        val right = e.x+e.width; val bottom = e.y+e.height; val epsilon = 1e-10
        return selected.sorted().firstOrNull {
            val square = square(it,region)
            right >= square.x-epsilon && bottom >= square.y-epsilon && e.x < square.x+square.width &&
                e.y < square.y+square.height && right < square.x+square.width-epsilon && bottom < square.y+square.height-epsilon
        }
    }
    fun counts(markers: List<Marker>, region: Region, quad: Quad? = null): Map<Int,Int> =
        markers.mapNotNull { assigned(it,region,quad) }.groupingBy { it }.eachCount()
}
data class Inputs(val area: String = "1", val depth: String = "0.1", val dilution: String = "2",
                  val stockVolume: String = "1", val target: String = "100000") {
    fun reset(grid: Grid) = Inputs(area=grid.area?.toString() ?: "1",target=target)
    fun calculate(count: Int, areaOverride: Double? = null): CountResult? {
        if(count < 0) return null
        val a = areaOverride ?: positive(area) ?: return null
        val d = positive(depth) ?: return null
        val dilution = positive(dilution)?.takeIf { it >= 1 } ?: return null
        val sampled = a*d/1000
        if(!a.isFinite() || a <= 0 || !sampled.isFinite() || sampled <= 0) return null
        val c = count*dilution/sampled
        if(!c.isFinite()) return null
        val stock = positive(stockVolume)
        val total = stock?.let { (c*it).takeIf(Double::isFinite) }
        val available = stock?.let { (it*1000).takeIf(Double::isFinite) }
        val required = positive(target)?.takeIf { c > 0 }?.let { (it/c*1000).takeIf(Double::isFinite) }
        return CountResult(c,total,required,available)
    }
    fun calculateCorners(counts: List<Int>): CountResult? {
        if(counts.size !in 1..4 || counts.any { it < 0 }) return null
        val sum = counts.sumOf { it.toLong() }
        if(sum > Int.MAX_VALUE) return null
        return calculate(sum.toInt(),counts.size.toDouble())
    }
    companion object {
        fun positive(text: String): Double? = text.trim().replace(',','.').toDoubleOrNull()?.takeIf { it.isFinite() && it > 0 }
    }
}
data class CountResult(val concentration: Double, val totalCells: Double?, val requiredMicroliters: Double?, val availableMicroliters: Double?) {
    val shortfall get() = requiredMicroliters?.let { needed -> availableMicroliters?.let { max(0.0,needed-it) } }
}
fun number(value: Double): String = when {
    abs(value) >= 1_000_000 -> String.format(Locale.getDefault(),"%.2f × 10⁶",value/1_000_000)
    abs(value) >= 10_000 -> String.format(Locale.getDefault(),"%.2f × 10⁴",value/10_000)
    else -> java.text.DecimalFormat("0.##").format(value)
}
