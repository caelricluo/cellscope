package com.cellscope.android

import android.graphics.Bitmap
import com.cellscope.core.*

enum class EditMode { VIEW, FRAME, ADD, REMOVE }
data class FrameData(val imageId: String, val region: Region = Region(), val quad: Quad? = null,
                     val markers: List<Marker> = emptyList(), val settings: DetectionSettings = DetectionSettings(),
                     val analyzed: Boolean = false, val estimatedDiameter: Double = 0.0)
data class Frame(val data: FrameData,val bitmap: Bitmap)
data class Session(val grid: Grid = Grid(), val active: Corner = Corner.A1, val frames: Map<Corner,Frame> = emptyMap(),
                   val inputs: Inputs = Inputs(), val name: String = "", val demo: Boolean = false) {
    val current get() = frames[if(grid.mode == CountMode.CORNERS) active else Corner.A1]
    val counted get() = Corner.entries.mapNotNull { p -> frames[p]?.takeIf { it.data.analyzed && it.data.settings.valid }?.let { p to it } }
    val totalCount get() = if(grid.mode == CountMode.CORNERS) counted.sumOf { it.second.data.markers.size } else current?.data?.markers?.size ?: 0
    val result get(): CountResult? {
        if(!grid.valid) return null
        return if(grid.mode==CountMode.CORNERS) inputs.calculateCorners(counted.map { it.second.data.markers.size })
        else current?.data?.takeIf { it.analyzed && it.settings.valid }?.let { inputs.calculate(it.markers.size,grid.area) }
    }
}
data class UiMessage(val resource: Int,val detail: String? = null)
data class WorkspaceState(val session: Session = Session(), val busy: Boolean = false, val locating: Boolean = false,
                          val located: GridDetection? = null, val edit: EditMode = EditMode.VIEW, val handle: Handle = Handle.MOVE,
                          val nudge: Int = 1, val showLabels: Boolean = false, val canUndo: Boolean = false,
                          val message: UiMessage? = null, val storing: Boolean = false, val initialized: Boolean = false)
data class RecordSummary(val id: String,val date: Long,val name: String,val demo: Boolean,val mode: CountMode,
                         val count: Int,val corners: Int,val primary: Corner)
data class ImportTarget(val mode: CountMode,val corner: Corner,val imageId: String?)
