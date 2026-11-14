package com.cellscope.android

import android.content.Context
import android.graphics.*
import android.view.*
import com.cellscope.core.*
import com.cellscope.core.Point
import com.cellscope.core.Region
import kotlin.math.*

/** Viewport-sized handles stay usable after zooming. Image-space coordinates
 * are shared by the frame editor, detector, marker edits and PNG export. */
class MicroscopeView(context: Context): View(context) {
    var onTap: (Double,Double)->Unit = {_,_->}
    var onFrame: (Quad)->Unit = {}
    var onHandle: (Handle)->Unit = {}
    private var frame: Frame?=null
    private var grid=Grid()
    private var edit=EditMode.VIEW
    private var busy=false
    private var locating=false
    private var labels=false
    private var selected=Handle.MOVE
    private var zoom=1f
    private var panX=0f
    private var panY=0f
    private var drag: Handle?=null
    private var startQuad: Quad?=null
    private var startPoint=Point(0.0,0.0)
    private var draft: Quad?=null
    private val density=resources.displayMetrics.density
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val scaler=ScaleGestureDetector(context,object: ScaleGestureDetector.SimpleOnScaleGestureListener() {
        override fun onScale(detector: ScaleGestureDetector): Boolean {
            val previous=zoom;zoom=(zoom*detector.scaleFactor).coerceIn(1f,12f)
            panX=detector.focusX-width/2f-(detector.focusX-width/2f-panX)*zoom/previous
            panY=detector.focusY-height/2f-(detector.focusY-height/2f-panY)*zoom/previous
            clampPan();invalidate();return true
        }
    })
    private val gestures=GestureDetector(context,object: GestureDetector.SimpleOnGestureListener() {
        override fun onDown(e: MotionEvent)=true
        override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
            if(edit==EditMode.FRAME) {if(!locating)target(e.x,e.y)?.let {selected=it;onHandle(it);invalidate()};return true}
            if(!busy) imagePoint(e.x,e.y)?.let {onTap(it.x,it.y)}
            return true
        }
        override fun onDoubleTap(e: MotionEvent): Boolean {
            if(edit!=EditMode.VIEW)return false
            zoom=if(zoom>2f)1f else 3f;panX=0f;panY=0f;clampPan();invalidate();return true
        }
        override fun onScroll(e1: MotionEvent?,e2: MotionEvent,distanceX: Float,distanceY: Float): Boolean {
            if(edit==EditMode.VIEW || e2.pointerCount>1) {panX-=distanceX;panY-=distanceY;clampPan();invalidate();return true}
            return false
        }
    })
    init {isClickable=true;importantForAccessibility=IMPORTANT_FOR_ACCESSIBILITY_YES}
    fun configure(frame: Frame?,grid: Grid,edit: EditMode,busy: Boolean,locating: Boolean,labels: Boolean,selected: Handle) {
        if(this.frame?.data?.imageId!=frame?.data?.imageId) {zoom=1f;panX=0f;panY=0f;drag=null;draft=null}
        this.frame=frame;this.grid=grid;this.edit=edit;this.busy=busy;this.locating=locating;this.labels=labels;this.selected=selected
        contentDescription=context.getString(R.string.image_count)+" · "+(frame?.data?.markers?.size ?: 0)
        invalidate()
    }
    private fun scale(): Float {
        val image=frame?.bitmap ?: return 1f
        return min(width.toFloat()/image.width,height.toFloat()/image.height)*zoom
    }
    private fun imageRect(): RectF {
        val image=frame?.bitmap ?: return RectF();val scale=scale();val w=image.width*scale;val h=image.height*scale
        return RectF((width-w)/2+panX,(height-h)/2+panY,(width+w)/2+panX,(height+h)/2+panY)
    }
    private fun imagePoint(x: Float,y: Float,clamp: Boolean=false): Point? {
        val rect=imageRect();if(rect.width()<=0 || rect.height()<=0)return null
        val p=Point(((x-rect.left)/rect.width()).toDouble(),((y-rect.top)/rect.height()).toDouble())
        return if(clamp || (p.x in 0.0..1.0 && p.y in 0.0..1.0))p else null
    }
    private fun screen(p: Point): PointF=imageRect().let {PointF((it.left+p.x*it.width()).toFloat(),(it.top+p.y*it.height()).toFloat())}
    private fun currentQuad()=draft ?: frame?.data?.quad ?: Quad(frame?.data?.region ?: Region())
    private fun target(x: Float,y: Float): Handle? {
        if(frame==null)return null
        val quad=currentQuad()
        val nearest=Handle.entries.filter {it!=Handle.MOVE}.minByOrNull {h->screen(h.point(quad)).let {hypot(x-it.x,y-it.y)}}
        if(nearest!=null && screen(nearest.point(quad)).let {hypot(x-it.x,y-it.y)}<=28*density)return nearest
        val c=quad.corners.map(::screen)
        for((i,handle)in listOf(Handle.TOP,Handle.RIGHT,Handle.BOTTOM,Handle.LEFT).withIndex()) {
            val a=c[i];val b=c[(i+1)%4];val dx=b.x-a.x;val dy=b.y-a.y
            val t=(((x-a.x)*dx+(y-a.y)*dy)/max(1f,dx*dx+dy*dy)).coerceIn(0f,1f)
            if(hypot(x-a.x-t*dx,y-a.y-t*dy)<=20*density)return handle
        }
        val p=imagePoint(x,y) ?: return null;val unit=quad.unproject(p) ?: return null
        return Handle.MOVE.takeIf {unit.x in 0.0..1.0 && unit.y in 0.0..1.0}
    }
    private fun clampPan() {
        val image=frame?.bitmap ?: return;val s=scale()
        val maxX=max(0f,(image.width*s-width)/2);val maxY=max(0f,(image.height*s-height)/2)
        panX=panX.coerceIn(-maxX,maxX);panY=panY.coerceIn(-maxY,maxY)
    }
    override fun onSizeChanged(w: Int,h: Int,oldw: Int,oldh: Int) {super.onSizeChanged(w,h,oldw,oldh);clampPan()}
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if(frame==null)return false
        parent?.requestDisallowInterceptTouchEvent(event.actionMasked!=MotionEvent.ACTION_UP && event.actionMasked!=MotionEvent.ACTION_CANCEL)
        scaler.onTouchEvent(event)
        if(event.pointerCount>1) {if(drag!=null){drag=null;startQuad=null;draft=null};gestures.onTouchEvent(event);return true}
        when(event.actionMasked) {
            MotionEvent.ACTION_DOWN -> if(edit==EditMode.FRAME && !locating) {
                drag=target(event.x,event.y);startQuad=currentQuad();startPoint=imagePoint(event.x,event.y,true) ?: Point(0.0,0.0)
                drag?.let {selected=it;onHandle(it)}
            }
            MotionEvent.ACTION_MOVE -> if(drag!=null && startQuad!=null && !scaler.isInProgress) {
                val p=imagePoint(event.x,event.y,true) ?: return true
                val next=startQuad!!.adjust(drag!!,p.x-startPoint.x,p.y-startPoint.y)
                draft=next;onFrame(next);invalidate();return true
            }
            MotionEvent.ACTION_UP -> {drag=null;startQuad=null;draft=null;performClick();invalidate()}
            MotionEvent.ACTION_CANCEL -> {drag=null;startQuad=null;draft=null;invalidate()}
        }
        gestures.onTouchEvent(event)
        return true
    }
    override fun performClick(): Boolean {super.performClick();return true}
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas);canvas.drawColor(Color.rgb(22,29,26))
        val frame=frame ?: return;val bitmap=frame.bitmap;val rect=imageRect()
        canvas.save();canvas.clipRect(rect);canvas.drawBitmap(bitmap,null,rect,paint)
        canvas.translate(rect.left,rect.top);canvas.scale(rect.width()/bitmap.width,rect.height()/bitmap.height)
        val data=draft?.let {frame.data.copy(quad=it,region=it.bounds)} ?: frame.data
        ImageService.drawOverlay(canvas,bitmap.width.toFloat(),bitmap.height.toFloat(),data,grid,labels);canvas.restore()
        if(edit!=EditMode.FRAME)return
        val quad=currentQuad();paint.pathEffect=null;paint.style=Paint.Style.FILL
        for(h in Handle.entries.filter {it!=Handle.MOVE}) {
            val p=screen(h.point(quad));val r=if(h==selected)9*density else 7*density
            paint.color=if(h==selected)ImageService.GREEN else Color.WHITE;canvas.drawCircle(p.x,p.y,r,paint)
            paint.style=Paint.Style.STROKE;paint.color=ImageService.GREEN;paint.strokeWidth=2*density;canvas.drawCircle(p.x,p.y,r,paint);paint.style=Paint.Style.FILL
        }
        val handle=drag ?: return
        val q=handle.point(quad);val anchor=screen(q);val side=110*density
        val left=(anchor.x-side/2).coerceIn(4*density,max(4*density,width-side-4*density))
        val top=if(anchor.y>side+45*density)anchor.y-side-38*density else min(height-side-4*density,anchor.y+45*density)
        val loupe=RectF(left,max(4*density,top),left+side,max(4*density,top)+side)
        canvas.save();canvas.clipPath(Path().apply {addRoundRect(loupe,18*density,18*density,Path.Direction.CW)})
        canvas.drawColor(Color.BLACK);val s=scale()*3
        canvas.drawBitmap(bitmap,null,RectF((loupe.centerX()-q.x*bitmap.width*s).toFloat(),(loupe.centerY()-q.y*bitmap.height*s).toFloat(),(loupe.centerX()+(1-q.x)*bitmap.width*s).toFloat(),(loupe.centerY()+(1-q.y)*bitmap.height*s).toFloat()),paint.apply {style=Paint.Style.FILL})
        paint.color=ImageService.GREEN;paint.strokeWidth=density;canvas.drawLine(loupe.centerX()-18*density,loupe.centerY(),loupe.centerX()+18*density,loupe.centerY(),paint);canvas.drawLine(loupe.centerX(),loupe.centerY()-18*density,loupe.centerX(),loupe.centerY()+18*density,paint)
        canvas.restore();paint.style=Paint.Style.STROKE;paint.color=Color.WHITE;paint.strokeWidth=3*density;canvas.drawRoundRect(loupe,18*density,18*density,paint)
    }
}
