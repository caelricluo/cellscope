package com.cellscope.android

import android.app.Application
import android.graphics.Bitmap
import android.net.Uri
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cellscope.core.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.UUID
import kotlin.math.*

class CounterModel(application: Application): AndroidViewModel(application) {
    private val mutable=MutableStateFlow(WorkspaceState())
    val state: StateFlow<WorkspaceState> = mutable.asStateFlow()
    private val mutableRecords=MutableStateFlow<List<RecordSummary>>(emptyList())
    val records: StateFlow<List<RecordSummary>> = mutableRecords.asStateFlow()
    val store=RecordStore(application)
    private var analysis: Job?=null
    private var importing: Job?=null
    private var persistence: Job?=null
    private val storageMutex=Mutex()
    private var generation=0L
    private var cachedGray: Pair<String,GrayImage>?=null
    private data class UndoState(val data: FrameData,val grid: Grid)
    private val undo=ArrayDeque<UndoState>()
    private var parameterUndo=false
    init {
        viewModelScope.launch {
            try {
                val loaded=withContext(Dispatchers.IO) { store.loadSession() }
                if(loaded!=null) mutable.update { it.copy(session=loaded) }
            } catch(error: Exception) { fail(R.string.error_history,error) }
            try {refreshRecords()} catch(error: Exception) {fail(R.string.error_history,error)}
            mutable.update { it.copy(initialized=true) }
        }
    }
    fun notify(resource: Int) { mutable.update {it.copy(message=UiMessage(resource))} }
    fun dismissMessage() { mutable.update { it.copy(message=null) } }
    fun input(value: Inputs) { changeSession { it.copy(inputs=value) };persist() }
    fun name(value: String) { changeSession { it.copy(name=value) };persist() }
    fun edit(value: EditMode) { mutable.update { it.copy(edit=value) } }
    fun showLabels(value: Boolean) {mutable.update { it.copy(showLabels=value) }}
    fun handle(value: Handle) {mutable.update { it.copy(handle=value) }}
    fun nudgeStep(value: Int) {mutable.update { it.copy(nudge=value) }}
    fun beginParameters() {parameterUndo=false}
    fun resetChamber() { input(state.value.session.inputs.reset(state.value.session.grid)) }
    fun settings(settings: DetectionSettings) {
        val current=state.value.session.current ?: return
        if(current.data.settings==settings) return
        if(!parameterUndo) {pushUndo();parameterUndo=true}
        changeCurrent { it.copy(data=it.data.copy(settings=settings)) }
        detect()
    }
    fun resetSettings() {settings(state.value.session.grid.mode.settings)}
    fun importTarget()=state.value.session.let { ImportTarget(it.grid.mode,it.active,it.current?.data?.imageId) }
    fun importImage(uri: Uri,target: ImportTarget) {
        if(!state.value.initialized) {
            viewModelScope.launch { state.first {it.initialized};importImage(uri,target) }
            return
        }
        if(!matches(target)) {mutable.update {it.copy(message=UiMessage(R.string.import_cancelled))};return}
        invalidate();val token=generation;mutable.update {it.copy(busy=true)}
        importing=viewModelScope.launch {
            try {
                val id=UUID.randomUUID().toString()
                val bitmap=withContext(Dispatchers.IO) {ImageService.load(getApplication(),uri).also {store.writeWorking(id,it)}}
                if(generation!=token || !matches(target)) return@launch
                val old=state.value.session
                val position=if(old.grid.mode==CountMode.CORNERS)old.active else Corner.A1
                val frame=Frame(FrameData(id,settings=old.grid.mode.settings),bitmap)
                val frames=if(old.demo)emptyMap() else old.frames
                changeSession { it.copy(frames=frames+(position to frame),demo=false,name=if(old.demo)"" else it.name) }
                undo.clear();cachedGray=null;mutable.update {it.copy(canUndo=false,located=null,edit=EditMode.VIEW)}
                detect(locate=old.grid.mode!=CountMode.CUSTOM,debounce=0)
            } catch(_: CancellationException) { }
            catch(error: Exception) {if(generation==token){mutable.update {it.copy(busy=false,locating=false)};fail(R.string.error_image,error)}}
        }
    }
    private fun matches(target: ImportTarget)=state.value.session.let {
        it.grid.mode==target.mode && (it.grid.mode!=CountMode.CORNERS || it.active==target.corner) && it.current?.data?.imageId==target.imageId
    }
    fun demo() {
        invalidate();val token=generation;val mode=state.value.session.grid.mode
        mutable.update {it.copy(busy=true,locating=false)}
        viewModelScope.launch {
            try {
                val id=UUID.randomUUID().toString()
                val bitmap=withContext(Dispatchers.IO) {ImageService.demo(mode).also {store.writeWorking(id,it)}}
                if(generation!=token) return@launch
                val frame=Frame(FrameData(id,settings=mode.settings),bitmap)
                changeSession {it.copy(active=Corner.A1,frames=mapOf(Corner.A1 to frame),demo=true,name="")}
                undo.clear();cachedGray=null;mutable.update {it.copy(canUndo=false,located=null,edit=EditMode.VIEW)}
                detect(debounce=0,populate=mode==CountMode.CORNERS)
            } catch(error: Exception) {if(error !is CancellationException && generation==token){mutable.update {it.copy(busy=false)};fail(R.string.error_image,error)}}
        }
    }
    fun mode(mode: CountMode) {
        if(mode==state.value.session.grid.mode) return
        val source=state.value.session.current;val usingDemo=state.value.session.demo
        invalidate();undo.clear();cachedGray=null
        changeSession { it.copy(grid=Grid(mode),active=Corner.A1,frames=source?.let { frame -> mapOf(Corner.A1 to frame.copy(data=FrameData(frame.data.imageId,settings=mode.settings))) } ?: emptyMap(),inputs=it.inputs.copy(area=Grid(mode).area?.toString() ?: "1",depth="0.1")) }
        mutable.update {it.copy(located=null,edit=EditMode.VIEW,canUndo=false)}
        if(usingDemo) demo() else if(source!=null) detect(locate=mode!=CountMode.CUSTOM,debounce=0) else persist()
    }
    fun selectCorner(position: Corner) {
        if(state.value.session.grid.mode!=CountMode.CORNERS || position==state.value.session.active) return
        invalidate();undo.clear();cachedGray=null;changeSession {it.copy(active=position)}
        mutable.update {it.copy(located=null,canUndo=false,edit=EditMode.VIEW)};persist()
    }
    fun selectSquares(selected: List<Int>) {
        val old=state.value.session.grid;val grid=Grid(old.mode,selected.distinct().sorted())
        if(!grid.valid || grid==old) return
        pushUndo();changeSession {it.copy(grid=grid)};detect()
    }
    fun toggleSquare(index: Int) {
        val selected=state.value.session.grid.selected.toMutableList()
        if(index in selected) {if(selected.size==1)return;selected.remove(index)} else selected.add(index)
        selectSquares(selected)
    }
    fun updateFrame(quad: Quad) {
        if(!quad.valid || state.value.locating) return
        pushUndo()
        changeCurrent {it.copy(data=it.data.copy(quad=quad,region=quad.bounds))};detect()
    }
    fun resetFrame() {updateFrame(state.value.located?.alignment(state.value.session.grid.mode) ?: Quad())}
    fun nudge(dx: Int,dy: Int) {
        val s=state.value;val current=s.session.current ?: return
        val q=current.data.quad ?: Quad(current.data.region)
        updateFrame(q.adjust(s.handle,dx*s.nudge.toDouble()/current.bitmap.width,dy*s.nudge.toDouble()/current.bitmap.height))
    }
    fun recount() {pushUndo();detect(debounce=0)}
    fun locate() {pushUndo();detect(locate=true,debounce=0)}
    private fun detect(locate: Boolean=false,debounce: Long=180,populate: Boolean=false) {
        val session=state.value.session;val current=session.current ?: return
        analysis?.cancel();generation++;val token=generation;val cache=cachedGray?.takeIf {it.first==current.data.imageId}?.second
        mutable.update {it.copy(busy=true,locating=locate)}
        analysis=viewModelScope.launch {
            try {
                delay(debounce)
                if(!current.data.settings.valid) {
                    changeCurrent {it.copy(data=it.data.copy(markers=emptyList(),estimatedDiameter=0.0,analyzed=false))}
                    mutable.update {it.copy(busy=false,locating=false)};persist();return@launch
                }
                val job=currentCoroutineContext().job
                val outcome=withContext(Dispatchers.Default) {
                    val gray=cache ?: ImageService.grayscale(current.bitmap)
                    val located=if(locate)GridDetector.detect(gray){!job.isActive} else null
                    val quad=located?.let {if(session.grid.mode==CountMode.CUSTOM)it.central ?: it.corner ?: it.overview else it.alignment(session.grid.mode)} ?: current.data.quad
                    val region=quad?.bounds ?: current.data.region
                    val report=CellDetector.analyze(gray,region,current.data.settings,session.grid,quad){!job.isActive}
                    AnalysisOutcome(gray,located,quad,region,report)
                }
                if(generation!=token || !isActive) return@launch
                cachedGray=current.data.imageId to outcome.gray
                val updated=current.copy(data=current.data.copy(quad=outcome.quad,region=outcome.region,markers=outcome.report.markers,estimatedDiameter=outcome.report.estimatedDiameter,analyzed=true))
                if(populate) changeSession {old -> old.copy(frames=Corner.entries.associateWith { updated.copy(data=updated.data.copy(markers=updated.data.markers.map {it.copy(id=UUID.randomUUID().toString())})) })}
                else changeCurrent {updated}
                mutable.update {it.copy(busy=false,locating=false,located=if(locate)outcome.located else it.located)}
                persist()
            } catch(_: CancellationException) { }
            catch(error: Exception) {if(generation==token){mutable.update {it.copy(busy=false,locating=false)};fail(R.string.error_detection,error)}}
        }
    }
    private data class AnalysisOutcome(val gray: GrayImage,val located: GridDetection?,val quad: Quad?,val region: Region,val report: DetectionReport)
    fun tap(x: Double,y: Double) {
        val s=state.value;val current=s.session.current ?: return
        if(s.busy || x !in 0.0..1.0 || y !in 0.0..1.0) return
        val data=current.data;val short=min(current.bitmap.width,current.bitmap.height).toDouble()
        when(s.edit) {
            EditMode.ADD -> {
                val r=if(data.settings.automaticSize && data.estimatedDiameter>0)data.estimatedDiameter/short/2 else data.settings.minimumDiameter/2
                val rx=r*short/current.bitmap.width;val ry=r*short/current.bitmap.height
                val marker=Marker(x,y,r,true,Region(x-rx,y-ry,2*rx,2*ry))
                if(s.session.grid.assigned(marker,data.region,data.quad)==null)return
                pushUndo();changeCurrent {it.copy(data=data.copy(markers=data.markers+marker,analyzed=true))}
            }
            EditMode.REMOVE -> {
                val nearest=data.markers.minByOrNull {hypot((it.x-x)*current.bitmap.width,(it.y-y)*current.bitmap.height)} ?: return
                if(hypot((nearest.x-x)*current.bitmap.width,(nearest.y-y)*current.bitmap.height)>max(short*.035,nearest.radius*short*1.8))return
                pushUndo();changeCurrent {it.copy(data=data.copy(markers=data.markers.filterNot {m->m.id==nearest.id}))}
            }
            else -> return
        }
        persist()
    }
    fun undo() {
        if(state.value.busy || undo.isEmpty())return
        val previous=undo.removeLast()
        changeCurrent {it.copy(data=previous.data)}
        changeSession {it.copy(grid=previous.grid)}
        parameterUndo=false
        mutable.update {it.copy(canUndo=undo.isNotEmpty())};persist()
    }
    private fun pushUndo() {
        state.value.session.current?.let {undo.addLast(UndoState(it.data,state.value.session.grid))}
        while(undo.size>50)undo.removeFirst()
        mutable.update {it.copy(canUndo=undo.isNotEmpty())}
    }
    fun save() {
        val s=state.value
        if(s.busy || s.storing || s.session.result==null) return
        mutable.update {it.copy(storing=true)}
        viewModelScope.launch {
            try {withContext(Dispatchers.IO){storageMutex.withLock {store.save(s.session)}};refreshRecords();mutable.update {it.copy(message=UiMessage(R.string.saved))}}
            catch(error: Exception) {if(error !is CancellationException)fail(R.string.error_save,error)}
            finally {mutable.update {it.copy(storing=false)}}
        }
    }
    fun restore(record: RecordSummary,onRestored: ()->Unit) {
        invalidate();val token=generation;mutable.update {it.copy(busy=true)}
        viewModelScope.launch {
            try {
                val restored=withContext(Dispatchers.IO){storageMutex.withLock {store.restore(record)}}
                if(token!=generation)return@launch
                undo.clear();cachedGray=null;mutable.update {it.copy(session=restored,busy=false,locating=false,located=null,edit=EditMode.VIEW,canUndo=false)}
                persist();onRestored()
            } catch(error: Exception) {if(error !is CancellationException && token==generation){mutable.update {it.copy(busy=false)};fail(R.string.error_restore,error)}}
        }
    }
    fun delete(record: RecordSummary) {
        viewModelScope.launch {
            try {withContext(Dispatchers.IO){storageMutex.withLock {store.delete(record)}};refreshRecords()}
            catch(error: Exception){if(error !is CancellationException)fail(R.string.error_delete,error)}
        }
    }
    fun export(onReady: (List<Uri>)->Unit) {
        val s=state.value;if(s.busy || s.storing || s.session.result==null)return
        mutable.update {it.copy(storing=true)}
        viewModelScope.launch {
            try {val uris=withContext(Dispatchers.IO){ImageService.export(getApplication(),s.session)};onReady(uris)}
            catch(error: Exception){if(error !is CancellationException)fail(R.string.error_export,error)}
            finally {mutable.update {it.copy(storing=false)}}
        }
    }
    private suspend fun refreshRecords() {
        val (records,failed)=withContext(Dispatchers.IO){storageMutex.withLock {store.list()}}
        mutableRecords.value=records
        if(failed>0)mutable.update {it.copy(message=UiMessage(R.string.error_history))}
    }
    private fun persist(now: Boolean=false) {
        persistence?.cancel()
        persistence=viewModelScope.launch {
            if(!now)delay(400)
            val snapshot=state.value.session
            try {withContext(Dispatchers.IO){storageMutex.withLock {ensureActive();store.saveSession(snapshot)}}}
            catch(_: CancellationException) { }
            catch(error: Exception){Log.e("cellscope","Session save failed",error)}
        }
    }
    fun flush() {if(state.value.initialized)persist(now=true)}
    private fun invalidate() {
        generation++;analysis?.cancel();importing?.cancel();mutable.update {it.copy(busy=false,locating=false)}
    }
    private fun changeSession(transform: (Session)->Session) {mutable.update {it.copy(session=transform(it.session))}}
    private fun changeCurrent(transform: (Frame)->Frame) {
        changeSession {session -> val p=if(session.grid.mode==CountMode.CORNERS)session.active else Corner.A1
            session.frames[p]?.let {session.copy(frames=session.frames+(p to transform(it)))} ?: session }
    }
    private fun fail(resource: Int,error: Exception) {Log.e("cellscope",getApplication<Application>().getString(resource),error);mutable.update {it.copy(message=UiMessage(resource))}}
}
