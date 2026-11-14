package com.cellscope.android

import android.content.Context
import android.content.Intent
import android.graphics.*
import android.net.Uri
import androidx.core.content.FileProvider
import androidx.exifinterface.media.ExifInterface
import com.cellscope.core.*
import java.io.File
import java.io.InputStream
import java.util.UUID
import kotlin.math.*

object ImageService {
    const val GREEN=0xFF0DA678.toInt()
    const val ORANGE=0xFFFF9500.toInt()
    fun load(context: Context,uri: Uri): Bitmap = decode { context.contentResolver.openInputStream(uri) ?: error("Image stream unavailable") }
    fun readNormalized(file: File): Bitmap = decode { file.inputStream() }
    private fun decode(open: ()->InputStream): Bitmap {
        val bounds=BitmapFactory.Options().apply { inJustDecodeBounds=true }
        open().use { BitmapFactory.decodeStream(it,null,bounds) }
        require(bounds.outWidth>0 && bounds.outHeight>0) { "Image format unavailable" }
        val orientation=open().use { ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION,ExifInterface.ORIENTATION_NORMAL) }
        var sample=1
        while(max(bounds.outWidth,bounds.outHeight)/sample>3200) sample*=2
        val options=BitmapFactory.Options().apply {
            inSampleSize=sample;inPreferredConfig=Bitmap.Config.ARGB_8888;inPreferredColorSpace=ColorSpace.get(ColorSpace.Named.SRGB)
        }
        val decoded=open().use { BitmapFactory.decodeStream(it,null,options) } ?: error("Image decode failed")
        val transform=Matrix().apply {
            when(orientation) {
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL->setScale(-1f,1f)
                ExifInterface.ORIENTATION_ROTATE_180->setRotate(180f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL->setScale(1f,-1f)
                ExifInterface.ORIENTATION_TRANSPOSE->{setRotate(90f);postScale(-1f,1f)}
                ExifInterface.ORIENTATION_ROTATE_90->setRotate(90f)
                ExifInterface.ORIENTATION_TRANSVERSE->{setRotate(-90f);postScale(-1f,1f)}
                ExifInterface.ORIENTATION_ROTATE_270->setRotate(-90f)
            }
        }
        val upright=if(transform.isIdentity) decoded else Bitmap.createBitmap(decoded,0,0,decoded.width,decoded.height,transform,true).also { if(it!==decoded) decoded.recycle() }
        val scale=min(1.0,1600.0/max(upright.width,upright.height))
        val reduced=if(scale<1) Bitmap.createScaledBitmap(upright,max(1,(upright.width*scale).roundToInt()),max(1,(upright.height*scale).roundToInt()),true).also { if(it!==upright) upright.recycle() } else upright
        // Flatten transparency onto white so display, grayscale and saved PNG agree.
        return Bitmap.createBitmap(reduced.width,reduced.height,Bitmap.Config.ARGB_8888).also { output ->
            Canvas(output).apply { drawColor(Color.WHITE);drawBitmap(reduced,0f,0f,null) };reduced.recycle()
        }
    }
    fun grayscale(bitmap: Bitmap): GrayImage {
        val colors=IntArray(bitmap.width*bitmap.height);bitmap.getPixels(colors,0,bitmap.width,0,0,bitmap.width,bitmap.height)
        val gray=ByteArray(colors.size)
        for(i in colors.indices) { val c=colors[i];gray[i]=(.299*Color.red(c)+.587*Color.green(c)+.114*Color.blue(c)).roundToInt().coerceIn(0,255).toByte() }
        return GrayImage(bitmap.width,bitmap.height,gray)
    }
    fun thumbnail(file: File): Bitmap? {
        val options=BitmapFactory.Options().apply { inJustDecodeBounds=true };BitmapFactory.decodeFile(file.path,options)
        options.inJustDecodeBounds=false;options.inSampleSize=1
        while(max(options.outWidth,options.outHeight)/options.inSampleSize>160) options.inSampleSize*=2
        return BitmapFactory.decodeFile(file.path,options)
    }
    fun demo(mode: CountMode): Bitmap {
        val bitmap=Bitmap.createBitmap(1000,1000,Bitmap.Config.ARGB_8888);val canvas=Canvas(bitmap);canvas.drawColor(gray(.87))
        val paint=Paint(Paint.ANTI_ALIAS_FLAG)
        fun line(x1: Double,y1: Double,x2: Double,y2: Double,color: Int,width: Float) {paint.style=Paint.Style.STROKE;paint.color=color;paint.strokeWidth=width;canvas.drawLine(x1.toFloat(),y1.toFloat(),x2.toFloat(),y2.toFloat(),paint)}
        fun cell(x: Double,y: Double,r: Double) {paint.style=Paint.Style.FILL;paint.color=gray(.46);canvas.drawCircle(x.toFloat(),y.toFloat(),r.toFloat(),paint);paint.color=gray(.73);canvas.drawCircle(x.toFloat(),y.toFloat(),max(1.0,r-4).toFloat(),paint)}
        if(mode==CountMode.OVERVIEW || mode==CountMode.RBC) {
            val n=mode.divisions;val side=800.0/n
            for(row in 0 until n) for(col in 0 until n) {
                val x=100+col*side;val y=100+row*side;val sub=if(mode==CountMode.RBC || row!=1 || col!=1)4 else 20
                for(k in 1 until sub) { val d=k*side/sub;line(x+d,y,x+d,y+side,gray(.81),1f);line(x,y+d,x+side,y+d,gray(.81),1f) }
                val points=if(mode==CountMode.RBC) listOf(.32,.68) else listOf(.12,.37,.87)
                for(py in points) for(px in points) cell(x+px*side,y+py*side,if(mode==CountMode.RBC)7.0 else 6.0)
            }
            for(k in 0..n) {val p=100+k*side;line(p,100.0,p,900.0,gray(.6),2f);line(100.0,p,900.0,p,gray(.6),2f)}
        } else {
            for(k in 0..4) {val p=100+k*200.0;line(p,100.0,p,900.0,gray(.6),2f);line(100.0,p,900.0,p,gray(.6),2f)}
            val positions=listOf(145,245,345,445,545,645,845)
            for(row in 0..6) for(col in 0..6) cell((positions[col]+(row*7+col*11)%11).toDouble(),(positions[row]+(col*13+row*3)%11).toDouble(),(12+(row+col)%5).toDouble())
        }
        return bitmap
    }
    fun annotated(frame: Frame,grid: Grid): Bitmap = frame.bitmap.copy(Bitmap.Config.ARGB_8888,true).also {
        drawOverlay(Canvas(it),it.width.toFloat(),it.height.toFloat(),frame.data,grid,true)
    }
    fun drawOverlay(canvas: Canvas,width: Float,height: Float,data: FrameData,grid: Grid,labels: Boolean) {
        val quad=data.quad ?: Quad(data.region);val short=min(width,height);val paint=Paint(Paint.ANTI_ALIAS_FLAG)
        fun path(x: Double,y: Double,w: Double,h: Double)=Path().apply {
            val points=listOf(quad.project(x,y),quad.project(x+w,y),quad.project(x+w,y+h),quad.project(x,y+h))
            moveTo((points[0].x*width).toFloat(),(points[0].y*height).toFloat());points.drop(1).forEach { lineTo((it.x*width).toFloat(),(it.y*height).toFloat()) };close()
        }
        val outer=path(0.0,0.0,1.0,1.0)
        val shade=Path().apply { addRect(0f,0f,width,height,Path.Direction.CW);addPath(outer);fillType=Path.FillType.EVEN_ODD }
        paint.color=0x59000000;canvas.drawPath(shade,paint)
        val n=grid.mode.divisions
        if(n>1) for(index in 0 until n*n) {
            val x=(index%n).toDouble()/n;val y=(index/n).toDouble()/n;val p=path(x,y,1.0/n,1.0/n);val selected=index in grid.selected
            paint.style=Paint.Style.FILL;paint.color=if(selected)0x0A0DA678 else 0x6B000000;canvas.drawPath(p,paint)
            paint.style=Paint.Style.STROKE;paint.color=if(selected)0xE60DA678.toInt() else 0x4D0DA678;paint.strokeWidth=max(1f,short*.0015f);canvas.drawPath(p,paint)
            if(selected) {val point=quad.project(x,y);paint.style=Paint.Style.FILL;paint.color=GREEN;paint.textSize=max(10f,short*.014f);paint.typeface=Typeface.DEFAULT_BOLD;canvas.drawText(grid.label(index),(point.x*width+4).toFloat(),(point.y*height+short*.016+3).toFloat(),paint)}
        }
        paint.style=Paint.Style.STROKE;paint.color=GREEN;paint.strokeWidth=max(1.3f,short*.0025f);paint.pathEffect=DashPathEffect(floatArrayOf(short*.012f,short*.006f),0f);canvas.drawPath(outer,paint);paint.pathEffect=null
        data.markers.forEachIndexed { index,marker ->
            val x=(marker.x*width).toFloat();val y=(marker.y*height).toFloat();val radius=(marker.radius*short).toFloat()
            paint.style=Paint.Style.STROKE;paint.color=if(marker.manual)ORANGE else GREEN;paint.strokeWidth=max(1f,short*.0012f);canvas.drawCircle(x,y,radius,paint)
            if(labels) {paint.style=Paint.Style.FILL;paint.textSize=max(9f,short*.008f);paint.typeface=Typeface.DEFAULT_BOLD;canvas.drawText("${index+1}",x+radius,y-radius,paint)}
        }
    }
    private fun gray(value: Double)=Color.rgb((value*255).roundToInt(),(value*255).roundToInt(),(value*255).roundToInt())

    fun export(context: Context,session: Session): List<Uri> {
        val result=requireNotNull(session.result);val folder=File(context.cacheDir,"exports/${UUID.randomUUID()}").apply { mkdirs() }
        val counted=session.counted
        val rows=mutableListOf(
            listOf(context.getString(R.string.item),context.getString(R.string.value),context.getString(R.string.unit)),
            listOf(context.getString(R.string.sample),session.name,""),listOf(context.getString(R.string.mode),context.getString(modeTitle(session.grid.mode)),""),
            listOf(context.getString(R.string.cell_count_label),session.totalCount.toString(),context.getString(R.string.cells_unit)),
            listOf(context.getString(R.string.area),if(session.grid.mode==CountMode.CORNERS)counted.size.toString() else session.grid.area?.toString() ?: session.inputs.area,"mm²"),
            listOf(context.getString(R.string.depth),session.inputs.depth,"mm"),listOf(context.getString(R.string.dilution),session.inputs.dilution,"×"),
            listOf(context.getString(R.string.stock_volume),session.inputs.stockVolume,"mL"),listOf(context.getString(R.string.concentration),result.concentration.toString(),"cells/mL"),
            listOf(context.getString(R.string.total_cells),result.totalCells?.toString() ?: "—",context.getString(R.string.cells_unit)),
            listOf(context.getString(R.string.target),session.inputs.target,context.getString(R.string.cells_unit)),
            listOf(context.getString(R.string.required_volume),result.requiredMicroliters?.toString() ?: "—","µL"),
            listOf(context.getString(R.string.boundary_rule),context.getString(R.string.boundary_short),""),
            listOf(context.getString(R.string.cluster_rule),context.getString(R.string.cluster_short),""),
            listOf(context.getString(R.string.demo_data),context.getString(if(session.demo)R.string.yes else R.string.no),"")
        )
        if(session.grid.mode==CountMode.CORNERS) {
            counted.forEach { rows.add(listOf(it.first.name,it.second.data.markers.size.toString(),context.getString(R.string.cells_unit))) }
            rows.add(listOf(context.getString(R.string.mean_count),(session.totalCount.toDouble()/counted.size).toString(),context.getString(R.string.per_square)))
        }
        fun quote(text: String)="\""+text.replace("\"","\"\"")+"\""
        val report=File(folder,"cellscope.csv").apply { writeText("\uFEFF"+rows.joinToString("\r\n") { it.joinToString(",",transform=::quote) },Charsets.UTF_8) }
        val files=mutableListOf(report)
        val frames=if(session.grid.mode==CountMode.CORNERS)counted else listOf(Corner.A1 to requireNotNull(session.current))
        frames.forEach { (position,frame) ->
            val target=File(folder,if(session.grid.mode==CountMode.CORNERS)"${position.name}.png" else "cellscope-annotations.png")
            val bitmap=annotated(frame,session.grid)
            try {target.outputStream().use { check(bitmap.compress(Bitmap.CompressFormat.PNG,100,it)) }} finally {bitmap.recycle()}
            files.add(target)
        }
        return files.map { FileProvider.getUriForFile(context,"${context.packageName}.files",it) }
    }
    fun share(context: Context,uris: List<Uri>) {
        val intent=Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type="*/*";putParcelableArrayListExtra(Intent.EXTRA_STREAM,ArrayList(uris));addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            clipData=android.content.ClipData.newUri(context.contentResolver,"cellscope",uris.first()).also { clip -> uris.drop(1).forEach { clip.addItem(android.content.ClipData.Item(it)) } }
        }
        context.startActivity(Intent.createChooser(intent,"cellscope"))
    }
}
fun modeTitle(mode: CountMode)=when(mode) { CountMode.OVERVIEW->R.string.mode_overview;CountMode.CORNERS->R.string.mode_corners;CountMode.RBC->R.string.mode_rbc;CountMode.CUSTOM->R.string.mode_custom }
