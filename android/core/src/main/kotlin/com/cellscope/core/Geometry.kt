package com.cellscope.core

import kotlin.math.*

data class Point(val x: Double, val y: Double)
enum class Handle(val indices: List<Int>) {
    TOP_LEFT(listOf(0)), TOP(listOf(0,1)), TOP_RIGHT(listOf(1)), RIGHT(listOf(1,2)),
    BOTTOM_RIGHT(listOf(2)), BOTTOM(listOf(2,3)), BOTTOM_LEFT(listOf(3)), LEFT(listOf(3,0)), MOVE(listOf(0,1,2,3));
    fun point(quad: Quad): Point = indices.map { quad.corners[it] }.let { Point(it.sumOf(Point::x)/it.size,it.sumOf(Point::y)/it.size) }
}
data class Quad(val topLeft: Point, val topRight: Point, val bottomRight: Point, val bottomLeft: Point) {
    constructor(region: Region = Region()): this(Point(region.x,region.y),Point(region.x+region.width,region.y),
        Point(region.x+region.width,region.y+region.height),Point(region.x,region.y+region.height))
    val corners get() = listOf(topLeft,topRight,bottomRight,bottomLeft)
    val bounds get(): Region {
        val c = corners; val x = max(0.0,c.minOf(Point::x)); val y = max(0.0,c.minOf(Point::y))
        return Region(x,y,min(1.0,c.maxOf(Point::x))-x,min(1.0,c.maxOf(Point::y))-y)
    }
    val valid get(): Boolean {
        val c = corners
        if(c.any { !it.x.isFinite() || !it.y.isFinite() || it.x !in 0.0..1.0 || it.y !in 0.0..1.0 }) return false
        for(i in 0..3) {
            val a=c[i];val b=c[(i+1)%4];val d=c[(i+2)%4]
            if((b.x-a.x)*(d.y-b.y)-(b.y-a.y)*(d.x-b.x) <= 1e-8) return false
        }
        return bounds.valid && matrix() != null
    }
    private fun matrix(): DoubleArray? {
        val a=topLeft;val b=topRight;val c=bottomRight;val d=bottomLeft
        val dx1=b.x-c.x;val dx2=d.x-c.x;val dx3=a.x-b.x+c.x-d.x
        val dy1=b.y-c.y;val dy2=d.y-c.y;val dy3=a.y-b.y+c.y-d.y
        var g=0.0;var h=0.0
        if(abs(dx3)+abs(dy3)>1e-12) {
            val den=dx1*dy2-dx2*dy1
            if(abs(den)<=1e-12) return null
            g=(dx3*dy2-dx2*dy3)/den;h=(dx1*dy3-dx3*dy1)/den
        }
        return doubleArrayOf(b.x-a.x+g*b.x,d.x-a.x+h*d.x,a.x,b.y-a.y+g*b.y,d.y-a.y+h*d.y,a.y,g,h,1.0)
    }
    fun project(x: Double, y: Double): Point {
        val m=matrix() ?: return Point(Double.NaN,Double.NaN);val z=m[6]*x+m[7]*y+1
        return Point((m[0]*x+m[1]*y+m[2])/z,(m[3]*x+m[4]*y+m[5])/z)
    }
    fun unproject(p: Point): Point? {
        val m=matrix() ?: return null
        val a=m[0];val b=m[1];val c=m[2];val d=m[3];val e=m[4];val f=m[5];val g=m[6];val h=m[7]
        val v=doubleArrayOf(e-f*h,c*h-b,b*f-c*e,f*g-d,a-c*g,c*d-a*f,d*h-e*g,b*g-a*h,a*e-b*d)
        val z=v[6]*p.x+v[7]*p.y+v[8]
        if(abs(z)<=1e-12) return null
        return Point((v[0]*p.x+v[1]*p.y+v[2])/z,(v[3]*p.x+v[4]*p.y+v[5])/z).takeIf { it.x.isFinite() && it.y.isFinite() }
    }
    fun unitMarker(marker: Marker): Marker? {
        if(!valid) return null
        val p=unproject(Point(marker.x,marker.y)) ?: return null
        var e: Region?=null
        marker.extent?.let { extent ->
            val mapped=Quad(extent).corners.map { unproject(it) ?: return null }
            val x=mapped.minOf(Point::x);val y=mapped.minOf(Point::y)
            e=Region(x,y,mapped.maxOf(Point::x)-x,mapped.maxOf(Point::y)-y)
        }
        return marker.copy(x=p.x,y=p.y,extent=e)
    }
    fun adjust(handle: Handle, dx: Double, dy: Double): Quad {
        if(!valid || !dx.isFinite() || !dy.isFinite()) return this
        val p=corners.toMutableList();val selected=handle.indices.map { p[it] }
        val x=dx.coerceIn(-selected.minOf(Point::x),1-selected.maxOf(Point::x))
        val y=dy.coerceIn(-selected.minOf(Point::y),1-selected.maxOf(Point::y))
        handle.indices.forEach { p[it]=Point(p[it].x+x,p[it].y+y) }
        val q=Quad(p[0],p[1],p[2],p[3])
        return q.takeIf { it.valid && it.bounds.width>=.04 && it.bounds.height>=.04 &&
            (0..3).all { i -> hypot(p[i].x-p[(i+1)%4].x,p[i].y-p[(i+1)%4].y)>=.025 } } ?: this
    }
}
