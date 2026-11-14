package com.cellscope.android

import android.content.Context
import android.graphics.Bitmap
import android.util.AtomicFile
import com.cellscope.core.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

/** Each record is committed as one directory. PNG image data and metadata become
 * visible together, and one damaged record cannot overwrite the remaining library. */
class RecordStore(private val context: Context) {
    private val working=File(context.filesDir,"working").apply { mkdirs() }
    private val records=File(context.filesDir,"records").apply { mkdirs() }
    private val sessionFile=AtomicFile(File(context.filesDir,"session.json"))
    fun workingImage(id: String): File { UUID.fromString(id);return File(working,"$id.png") }
    fun writeWorking(id: String,bitmap: Bitmap) { writePng(workingImage(id),bitmap) }
    fun saveSession(session: Session) {
        atomicWrite(sessionFile,encode(session).toString().toByteArray(Charsets.UTF_8))
        val active=session.frames.values.map { it.data.imageId }.toSet();val cutoff=System.currentTimeMillis()-3_600_000
        working.listFiles()?.filter { it.extension=="png" && it.nameWithoutExtension !in active && it.lastModified()<cutoff }?.forEach { it.delete() }
    }
    fun loadSession(): Session? {
        if(!sessionFile.baseFile.exists()) return null
        val json=JSONObject(String(sessionFile.readFully(),Charsets.UTF_8))
        return decode(json) { _, data -> ImageService.readNormalized(workingImage(data.imageId)) }
    }
    fun save(session: Session): RecordSummary {
        val selected=if(session.grid.mode==CountMode.CORNERS) session.counted.toMap() else
            mapOf(Corner.A1 to requireNotNull(session.current))
        require(selected.isNotEmpty())
        val primary=session.active.takeIf { it in selected } ?: selected.keys.first()
        val capture=session.copy(active=primary,frames=selected)
        val id=UUID.randomUUID().toString();val date=System.currentTimeMillis()
        val pending=File(records,"$id.pending").apply { mkdirs() };val destination=File(records,id)
        try {
            selected.forEach { (position,frame) -> writePng(File(pending,"${position.name}.png"),frame.bitmap) }
            val json=encode(capture).put("id",id).put("date",date)
            File(pending,"record.json").writeText(json.toString(),Charsets.UTF_8)
            check(pending.renameTo(destination)) { "Unable to commit record" }
            return summary(json)
        } catch(error: Exception) { pending.deleteRecursively();throw error }
    }
    fun list(): Pair<List<RecordSummary>,Int> {
        var failed=0
        val entries=records.listFiles()?.filter { it.isDirectory && !it.name.endsWith(".pending") }.orEmpty().mapNotNull { folder ->
            try {summary(JSONObject(File(folder,"record.json").readText(Charsets.UTF_8)))} catch(_: Exception) {failed++;null}
        }
        return entries.sortedByDescending { it.date } to failed
    }
    fun restore(record: RecordSummary): Session {
        val folder=recordFolder(record.id);val json=JSONObject(File(folder,"record.json").readText(Charsets.UTF_8))
        return decode(json) { position,_ -> ImageService.readNormalized(File(folder,"${position.name}.png")) }.let { session ->
            session.copy(frames=session.frames.mapValues { (_,frame) ->
                val id=UUID.randomUUID().toString();writeWorking(id,frame.bitmap);frame.copy(data=frame.data.copy(imageId=id))
            })
        }
    }
    fun thumbnail(record: RecordSummary) = ImageService.thumbnail(File(recordFolder(record.id),"${record.primary.name}.png"))
    fun delete(record: RecordSummary) { check(recordFolder(record.id).deleteRecursively()) { "Unable to delete record" } }
    private fun recordFolder(id: String): File { UUID.fromString(id);return File(records,id) }
    private fun summary(json: JSONObject): RecordSummary {
        val mode=CountMode.valueOf(json.getString("mode"));val entries=json.getJSONArray("frames").objects()
        return RecordSummary(json.getString("id"),json.getLong("date"),json.optString("name"),json.optBoolean("demo"),mode,
            entries.sumOf { it.getJSONArray("markers").length() },if(mode==CountMode.CORNERS)entries.size else 0,Corner.valueOf(json.getString("active")))
    }
    private fun encode(session: Session): JSONObject = JSONObject().apply {
        put("schema",1);put("mode",session.grid.mode.name);put("selected",JSONArray(session.grid.selected));put("active",session.active.name)
        put("name",session.name);put("demo",session.demo)
        put("inputs",JSONObject().apply {
            put("area",session.inputs.area);put("depth",session.inputs.depth);put("dilution",session.inputs.dilution)
            put("stockVolume",session.inputs.stockVolume);put("target",session.inputs.target)
        })
        put("frames",JSONArray().apply { session.frames.forEach { (position,frame) ->
            val data=frame.data
            put(JSONObject().apply {
                put("position",position.name);put("imageId",data.imageId);put("region",data.region.json());put("quad",data.quad?.json())
                put("analyzed",data.analyzed);put("estimatedDiameter",data.estimatedDiameter)
                put("settings",JSONObject().apply {
                    put("sensitivity",data.settings.sensitivity);put("minimum",data.settings.minimumDiameter);put("maximum",data.settings.maximumDiameter)
                    put("automaticSize",data.settings.automaticSize);put("polarity",data.settings.polarity.name)
                })
                put("markers",JSONArray().apply { data.markers.forEach { marker -> put(JSONObject().apply {
                    put("id",marker.id);put("x",marker.x);put("y",marker.y);put("radius",marker.radius);put("manual",marker.manual);put("extent",marker.extent?.json())
                }) } })
            })
        } })
    }
    private fun decode(json: JSONObject,image: (Corner,FrameData)->Bitmap): Session {
        val mode=CountMode.valueOf(json.getString("mode"));val selected=json.getJSONArray("selected").let { a -> (0 until a.length()).map { a.getInt(it) } }
        val grid=Grid(mode,selected);require(grid.valid)
        val inputs=json.getJSONObject("inputs").let { Inputs(it.optString("area","1"),it.optString("depth","0.1"),it.optString("dilution","2"),it.optString("stockVolume","1"),it.optString("target","100000")) }
        val frames=json.getJSONArray("frames").objects().associate { entry ->
            val position=Corner.valueOf(entry.getString("position"));val s=entry.getJSONObject("settings")
            val settings=DetectionSettings(s.getDouble("sensitivity"),s.getDouble("minimum"),s.getDouble("maximum"),Polarity.valueOf(s.getString("polarity")),s.getBoolean("automaticSize"))
            require(settings.valid)
            val markers=entry.getJSONArray("markers").objects().map { m ->
                val x=m.getDouble("x");val y=m.getDouble("y");val radius=m.getDouble("radius")
                require(x.isFinite() && y.isFinite() && radius.isFinite() && radius>0)
                Marker(x,y,radius,m.optBoolean("manual"),m.optJSONObject("extent")?.region(),m.getString("id"))
            }
            val region=entry.getJSONObject("region").region();require(region.valid)
            val quad=entry.optJSONArray("quad")?.let { a ->
                require(a.length()==8);Quad(Point(a.getDouble(0),a.getDouble(1)),Point(a.getDouble(2),a.getDouble(3)),Point(a.getDouble(4),a.getDouble(5)),Point(a.getDouble(6),a.getDouble(7))).also { require(it.valid) }
            }
            val data=FrameData(entry.getString("imageId"),region,quad,markers,settings,entry.optBoolean("analyzed"),entry.optDouble("estimatedDiameter",0.0))
            position to Frame(data,image(position,data))
        }
        return Session(grid,Corner.valueOf(json.getString("active")),frames,inputs,json.optString("name"),json.optBoolean("demo"))
    }
    private fun writePng(file: File,bitmap: Bitmap) {
        val atomic=AtomicFile(file);val stream=atomic.startWrite()
        try { check(bitmap.compress(Bitmap.CompressFormat.PNG,100,stream));atomic.finishWrite(stream) }
        catch(error: Exception) { atomic.failWrite(stream);throw error }
    }
    private fun atomicWrite(file: AtomicFile,bytes: ByteArray) {
        val stream=file.startWrite()
        try { stream.write(bytes);file.finishWrite(stream) } catch(error: Exception) {file.failWrite(stream);throw error}
    }
}
private fun Region.json()=JSONObject().put("x",x).put("y",y).put("width",width).put("height",height)
private fun JSONObject.region()=Region(getDouble("x"),getDouble("y"),getDouble("width"),getDouble("height"))
private fun Quad.json()=JSONArray(corners.flatMap { listOf(it.x,it.y) })
private fun JSONArray.objects()=(0 until length()).map { getJSONObject(it) }
