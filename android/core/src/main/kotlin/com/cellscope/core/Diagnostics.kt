package com.cellscope.core

import java.io.File

/** CLI for reproducible detector comparisons. Input: binary 8-bit PGM. */
fun main(args: Array<String>) {
    require(args.isNotEmpty()) { "Usage: diagnose <image.pgm> [CORNERS|RBC|OVERVIEW|CUSTOM] [sensitivity]" }
    val bytes=File(args[0]).readBytes();var offset=0
    fun token(): String {
        while(offset<bytes.size) {
            if(bytes[offset].toInt()==35) {while(offset<bytes.size && bytes[offset].toInt()!=10)offset++}
            else if(bytes[offset].toInt()<=32)offset++ else break
        }
        val start=offset
        while(offset<bytes.size && bytes[offset].toInt()>32)offset++
        return String(bytes,start,offset-start,Charsets.US_ASCII)
    }
    require(token()=="P5");val w=token().toInt();val h=token().toInt();require(token()=="255")
    require(offset<bytes.size && bytes[offset].toInt()<=32)
    if(bytes[offset].toInt()==13 && bytes.getOrNull(offset+1)?.toInt()==10)offset+=2 else offset++
    require(bytes.size-offset==w*h)
    val image=GrayImage(w,h,bytes.copyOfRange(offset,bytes.size))
    val mode=args.getOrNull(1)?.let(CountMode::valueOf) ?: CountMode.CORNERS
    val settings=mode.settings.copy(sensitivity=args.getOrNull(2)?.toDouble() ?: .55)
    val located=GridDetector.detect(image);val quad=located.alignment(mode)
    val report=CellDetector.analyze(image,quad?.bounds ?: Region(),settings,Grid(mode),quad)
    fun Quad?.json()=this?.corners?.joinToString(prefix="[",postfix="]"){"[${it.x},${it.y}]"} ?: "null"
    println("{\"width\":$w,\"height\":$h,\"mode\":\"$mode\",\"sensitivity\":${settings.sensitivity},\"count\":${report.markers.size},\"corner\":${located.corner.json()},\"central\":${located.central.json()},\"overview\":${located.overview.json()}}")
}
