@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class, androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
package com.cellscope.android

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.*
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cellscope.core.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.text.DateFormat
import java.util.Date
import java.util.UUID
import kotlin.math.roundToInt

private val Ink=Color(0xFF172E29)
private val Green=Color(0xFF147257)
private val Paper=Color(0xFFF5F7F1)
private val Muted=Color(0xFF64776D)
private val Lime=Color(0xFFC8ED92)
private val Scheme=lightColorScheme(primary=Green,onPrimary=Color.White,primaryContainer=Color(0xFFE7F1E9),onPrimaryContainer=Ink,
    secondary=Green,onSecondary=Color.White,secondaryContainer=Color(0xFFE7F1E9),onSecondaryContainer=Green,
    tertiary=Green,tertiaryContainer=Color(0xFFE7F1E9),onTertiaryContainer=Ink,
    surface=Color.White,background=Paper,onSurface=Ink,onBackground=Ink,onSurfaceVariant=Muted,
    surfaceVariant=Paper,outline=Muted.copy(alpha=.45f),outlineVariant=Ink.copy(alpha=.1f))
@Composable fun CellscopeTheme(content: @Composable ()->Unit) {MaterialTheme(colorScheme=Scheme,content=content)}

private enum class Acquire { CAMERA, LIBRARY, DEMO }
@Composable fun CellscopeApp(model: CounterModel) {
    val state by model.state.collectAsStateWithLifecycle()
    val records by model.records.collectAsStateWithLifecycle()
    val context=LocalContext.current
    var tab by rememberSaveable {mutableIntStateOf(0)}
    var settings by rememberSaveable {mutableStateOf(false)}
    var fullscreen by rememberSaveable {mutableStateOf(false)}
    var pendingMode by remember {mutableStateOf<CountMode?>(null)}
    var pendingAcquire by remember {mutableStateOf<Acquire?>(null)}
    var captureUri by rememberSaveable {mutableStateOf<String?>(null)}
    var captureMode by rememberSaveable {mutableStateOf(CountMode.CORNERS.name)}
    var captureCorner by rememberSaveable {mutableStateOf(Corner.A1.name)}
    var captureId by rememberSaveable {mutableStateOf<String?>(null)}
    var libraryMode by rememberSaveable {mutableStateOf(CountMode.CORNERS.name)}
    var libraryCorner by rememberSaveable {mutableStateOf(Corner.A1.name)}
    var libraryId by rememberSaveable {mutableStateOf<String?>(null)}
    val camera=rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        if(success)captureUri?.let {model.importImage(Uri.parse(it),ImportTarget(CountMode.valueOf(captureMode),Corner.valueOf(captureCorner),captureId))}
        captureUri=null
    }
    val library=rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if(uri!=null)model.importImage(uri,ImportTarget(CountMode.valueOf(libraryMode),Corner.valueOf(libraryCorner),libraryId))
    }
    fun launch(action: Acquire) {
        val target=model.importTarget()
        try {when(action) {
            Acquire.CAMERA -> {
                val folder=File(context.cacheDir,"capture").apply {mkdirs()}
                val file=File(folder,"${UUID.randomUUID()}.jpg").apply {createNewFile()}
                val uri=FileProvider.getUriForFile(context,"${context.packageName}.files",file)
                captureUri=uri.toString();captureMode=target.mode.name;captureCorner=target.corner.name;captureId=target.imageId
                camera.launch(uri)
            }
            Acquire.LIBRARY -> {libraryMode=target.mode.name;libraryCorner=target.corner.name;libraryId=target.imageId;library.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))}
            Acquire.DEMO -> model.demo()
        }} catch(_: Exception) {model.notify(if(action==Acquire.CAMERA)R.string.error_camera else R.string.error_image)}
    }
    fun acquire(action: Acquire) {
        if(state.session.current!=null || (action==Acquire.DEMO && state.session.frames.isNotEmpty()))pendingAcquire=action else launch(action)
    }
    fun choose(mode: CountMode) {
        if(mode==state.session.grid.mode)return
        if(!state.session.demo && state.session.frames.isNotEmpty())pendingMode=mode else model.mode(mode)
    }
    Scaffold(containerColor=Paper,bottomBar={
        NavigationBar(containerColor=Color.White,tonalElevation=0.dp) {
            listOf(R.string.nav_count to Icons.Default.Home,R.string.nav_records to Icons.AutoMirrored.Filled.List,R.string.nav_guide to Icons.Default.Info).forEachIndexed { index,(title,icon) ->
                NavigationBarItem(selected=tab==index,onClick={tab=index},icon={Icon(icon,null)},label={Text(stringResource(title))},modifier=Modifier.testTag("tab-$index"))
            }
        }
    }) { inset ->
        Box(Modifier.fillMaxSize().padding(inset),contentAlignment=Alignment.TopCenter) {
            when(tab) {
                0 -> Workspace(model,state,::choose,::acquire,onSettings={model.beginParameters();settings=true},onFullscreen={fullscreen=true})
                1 -> History(model,state,records,onRestored={tab=0})
                else -> Guide()
            }
        }
    }
    pendingMode?.let { mode ->
        AlertDialog(onDismissRequest={pendingMode=null},title={Text(stringResource(R.string.change_mode))},confirmButton={TextButton(onClick={pendingMode=null;model.mode(mode)}){Text(stringResource(R.string.change))}},dismissButton={TextButton(onClick={pendingMode=null}){Text(stringResource(R.string.cancel))}})
    }
    pendingAcquire?.let { action ->
        AlertDialog(onDismissRequest={pendingAcquire=null},title={Text(stringResource(R.string.replace_image))},confirmButton={TextButton(onClick={pendingAcquire=null;launch(action)}){Text(stringResource(R.string.replace))}},dismissButton={TextButton(onClick={pendingAcquire=null}){Text(stringResource(R.string.cancel))}})
    }
    state.message?.let {message ->
        AlertDialog(onDismissRequest=model::dismissMessage,title={Text("cellscope")},text={Text(stringResource(message.resource))},confirmButton={TextButton(onClick=model::dismissMessage){Text(stringResource(R.string.ok))}})
    }
    if(settings && state.session.current!=null)DetectionSheet(model,state){settings=false}
    if(fullscreen && state.session.current!=null)Fullscreen(model,state){fullscreen=false}
}

@Composable private fun Workspace(model: CounterModel,state: WorkspaceState,choose: (CountMode)->Unit,acquire: (Acquire)->Unit,onSettings: ()->Unit,onFullscreen: ()->Unit) {
    val session=state.session;val current=session.current
    val context=LocalContext.current
    Column(Modifier.widthIn(max=720.dp).fillMaxSize().verticalScroll(rememberScrollState()).imePadding().padding(16.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) {
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(26.dp)).background(Ink).padding(24.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {
            Text("◉  cellscope",color=Lime,fontSize=23.sp,fontWeight=FontWeight.SemiBold)
            Spacer(Modifier.height(8.dp))
            Text(stringResource(R.string.tagline),color=Color.White,fontSize=29.sp,fontWeight=FontWeight.Medium,lineHeight=36.sp)
            Text(stringResource(R.string.subtitle),color=Color.White.copy(alpha=.72f),style=MaterialTheme.typography.bodyMedium)
        }
        if(!state.initialized)LinearProgressIndicator(Modifier.fillMaxWidth())
        Panel {
            SectionTitle(stringResource(R.string.counting_mode))
            FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp),verticalArrangement=Arrangement.spacedBy(4.dp)) {
                CountMode.entries.forEach {mode -> FilterChip(selected=session.grid.mode==mode,onClick={choose(mode)},label={Text(stringResource(modeTitle(mode)))},enabled=state.initialized && !state.storing,modifier=Modifier.testTag("mode-${mode.name}"))}
            }
            Text(stringResource(instruction(session.grid.mode)),style=MaterialTheme.typography.bodyMedium,color=Muted)
        }
        if(session.grid.mode==CountMode.CORNERS)Panel {
            Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){SectionTitle(stringResource(R.string.mode_corners));Text(stringResource(R.string.corners_progress,session.counted.size),color=Green)}
            Row(horizontalArrangement=Arrangement.spacedBy(6.dp)) {
                Corner.entries.forEach {position ->
                    val field=session.frames[position];val selected=position==session.active
                    FilledTonalButton(onClick={model.selectCorner(position)},enabled=!state.storing,shape=RoundedCornerShape(12.dp),contentPadding=PaddingValues(4.dp,12.dp),colors=ButtonDefaults.filledTonalButtonColors(containerColor=if(selected)Green else Paper,contentColor=if(selected)Color.White else Green),modifier=Modifier.weight(1f).testTag("corner-${position.name}")) {
                        Column(horizontalAlignment=Alignment.CenterHorizontally){Text(position.name,fontWeight=FontWeight.SemiBold);Text(field?.let {if(it.data.analyzed)it.data.markers.size.toString() else stringResource(R.string.pending_count)} ?: stringResource(R.string.pending_capture),fontSize=13.sp)}
                    }
                }
            }
            if(session.counted.isNotEmpty())Text(stringResource(R.string.corner_mean,session.totalCount,number(session.totalCount.toDouble()/session.counted.size)),color=Green,modifier=Modifier.testTag("cornerMean"))
        }
        Panel {
            SectionTitle("01 · "+stringResource(R.string.acquire))
            Row(horizontalArrangement=Arrangement.spacedBy(10.dp)) {
                Button(onClick={acquire(Acquire.CAMERA)},enabled=state.initialized && !state.storing,modifier=Modifier.weight(1f).testTag("capture")){Text(stringResource(R.string.capture))}
                FilledTonalButton(onClick={acquire(Acquire.LIBRARY)},enabled=state.initialized && !state.storing,modifier=Modifier.weight(1f).testTag("importPhoto")){Text(stringResource(R.string.import_photo))}
            }
            if(current==null)TextButton(onClick={acquire(Acquire.DEMO)},enabled=state.initialized && !state.busy && !state.storing,modifier=Modifier.testTag("loadDemo")){Text("✦  "+stringResource(R.string.load_demo))}
        }
        if(current!=null)Panel {
            SectionTitle("02 · "+stringResource(R.string.image_count))
            if(session.demo)Text(stringResource(R.string.demo_data),color=Green,style=MaterialTheme.typography.bodySmall,modifier=Modifier.testTag("demoBanner"))
            Box(Modifier.fillMaxWidth().height(310.dp).clip(RoundedCornerShape(16.dp))) {
                ImageCanvas(model,state,Modifier.fillMaxSize())
                val fullscreenLabel=stringResource(R.string.fullscreen)
                TextButton(onClick=onFullscreen,colors=ButtonDefaults.textButtonColors(contentColor=Color.White),modifier=Modifier.align(Alignment.TopEnd).background(Color.Black.copy(alpha=.55f),RoundedCornerShape(14.dp)).semantics {contentDescription=fullscreenLabel}){Text("⤢",fontSize=25.sp)}
                if(state.busy)Text(stringResource(if(state.locating)R.string.locating else R.string.updating),modifier=Modifier.align(Alignment.TopStart).padding(10.dp).background(Color.White.copy(alpha=.9f),RoundedCornerShape(9.dp)).padding(8.dp),color=Green)
            }
            Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {
                TextButton(onClick=model::locate,enabled=!state.busy,modifier=Modifier.testTag("locateGrid")){Text(stringResource(R.string.locate_grid))}
                Spacer(Modifier.weight(1f));Text(stringResource(R.string.labels),style=MaterialTheme.typography.bodySmall);Switch(checked=state.showLabels,onCheckedChange=model::showLabels)
            }
            Text(stringResource(gridStatus(state)),color=Green,style=MaterialTheme.typography.bodySmall,modifier=Modifier.testTag("gridStatus"))
            if(state.located?.central!=null && session.grid.mode!=CountMode.RBC)TextButton(onClick={choose(CountMode.RBC)},modifier=Modifier.testTag("switchToRBC")){Text(stringResource(R.string.switch_rbc))}
            EditToolbar(model,state){model.edit(it);if(it==EditMode.FRAME)onFullscreen()}
            if(session.grid.mode.divisions>1)SquareSelector(model,state)
            Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {
                Text(current.data.markers.size.toString(),fontSize=46.sp,fontWeight=FontWeight.Medium,color=Ink,modifier=Modifier.testTag("cellCount"))
                Text("  "+stringResource(R.string.cells_unit),color=Muted)
                Spacer(Modifier.weight(1f))
                TextButton(onClick=onSettings,enabled=!state.locating,modifier=Modifier.testTag("detectionSettings")){Text(stringResource(R.string.detection_settings))}
            }
            Button(onClick=model::recount,enabled=!state.busy,modifier=Modifier.fillMaxWidth().testTag("recount")){Text(stringResource(R.string.recount))}
        }
        if(session.frames.isNotEmpty()) {
            Panel {
                SectionTitle("03 · "+stringResource(R.string.chamber))
                TextButton(onClick=model::resetChamber,modifier=Modifier.testTag("resetChamber")){Text("↺  "+stringResource(R.string.reset_chamber))}
                OutlinedTextField(value=session.name,onValueChange=model::name,label={Text(stringResource(R.string.sample_name))},singleLine=true,modifier=Modifier.fillMaxWidth().testTag("sampleName"))
                Row(horizontalArrangement=Arrangement.spacedBy(12.dp)) {
                    if(session.grid.mode==CountMode.CUSTOM)NumberField(R.string.area,"mm²",session.inputs.area,{model.input(session.inputs.copy(area=it))},Modifier.weight(1f),tag="area")
                    else ReadOnlyField(R.string.area,"${number(session.grid.area ?: 1.0)} mm²",Modifier.weight(1f))
                    NumberField(R.string.depth,"mm",session.inputs.depth,{model.input(session.inputs.copy(depth=it))},Modifier.weight(1f),tag="depth")
                }
                Row(horizontalArrangement=Arrangement.spacedBy(12.dp)) {
                    NumberField(R.string.dilution,"×",session.inputs.dilution,{model.input(session.inputs.copy(dilution=it))},Modifier.weight(1f),minimum=1.0,tag="dilution")
                    NumberField(R.string.stock_volume,"mL",session.inputs.stockVolume,{model.input(session.inputs.copy(stockVolume=it))},Modifier.weight(1f),tag="stockVolume")
                }
            }
            Panel {
                SectionTitle("04 · "+stringResource(R.string.planning))
                NumberField(R.string.target,stringResource(R.string.cells_unit),session.inputs.target,{model.input(session.inputs.copy(target=it))},Modifier.fillMaxWidth(),tag="target")
                ResultCard(session.result,state.busy)
                val gap=session.result?.shortfall
                if(gap!=null && gap>0)Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Text(stringResource(R.string.volume_shortfall));Text(number(gap)+" µL",modifier=Modifier.testTag("volumeShortfall"))}
                Row(horizontalArrangement=Arrangement.spacedBy(10.dp)) {
                    Button(onClick=model::save,enabled=session.result!=null && !state.busy && !state.storing,modifier=Modifier.weight(1f).testTag("saveRecord")){Text(stringResource(R.string.save))}
                    OutlinedButton(onClick={model.export {uris->try{ImageService.share(context,uris)}catch(_: Exception){model.notify(R.string.error_export)}}},enabled=session.result!=null && !state.busy && !state.storing,modifier=Modifier.weight(1f).testTag("export")){Text(stringResource(R.string.export))}
                }
            }
        } else Panel {
            SectionTitle(stringResource(R.string.empty_title));Text(stringResource(R.string.empty_detail),color=Muted)
        }
        Spacer(Modifier.height(8.dp))
    }
}

@Composable private fun Panel(content: @Composable ColumnScope.()->Unit) {
    Surface(shape=RoundedCornerShape(23.dp),color=Color.White,border=BorderStroke(1.dp,Ink.copy(alpha=.06f)),modifier=Modifier.fillMaxWidth()) {
        Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(12.dp),content=content)
    }
}
@Composable private fun SectionTitle(text: String){Text(text,color=Ink,style=MaterialTheme.typography.titleMedium,fontWeight=FontWeight.SemiBold)}
@Composable private fun NumberField(title: Int,unit: String,text: String,onChange: (String)->Unit,modifier: Modifier=Modifier,minimum: Double=0.0,tag: String) {
    val keyboard=LocalSoftwareKeyboardController.current
    OutlinedTextField(value=text,onValueChange=onChange,label={Text(stringResource(title))},suffix={Text(unit)},singleLine=true,
        isError=text.isNotBlank() && Inputs.positive(text)?.let {it>=minimum}!=true,
        keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Decimal,imeAction=ImeAction.Done),keyboardActions=KeyboardActions(onDone={keyboard?.hide()}),
        shape=RoundedCornerShape(12.dp),modifier=modifier.testTag(tag))
}
@Composable private fun ReadOnlyField(title: Int,value: String,modifier: Modifier) {
    Column(modifier,verticalArrangement=Arrangement.spacedBy(7.dp)){Text(stringResource(title),style=MaterialTheme.typography.bodySmall,color=Muted);Text(value,modifier=Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Paper).padding(16.dp),fontFamily=FontFamily.Monospace)}
}
@Composable private fun ResultCard(result: CountResult?,busy: Boolean,compact: Boolean=false) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Ink).padding(if(compact)14.dp else 20.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
        Text(stringResource(if(busy)R.string.updating else R.string.live_preview),color=Lime,style=MaterialTheme.typography.labelMedium)
        Text(stringResource(R.string.concentration),color=Color.White.copy(alpha=.75f),style=MaterialTheme.typography.bodySmall)
        Text((result?.let {number(it.concentration)} ?: "—")+" cells/mL",color=Color.White,fontSize=if(compact)21.sp else 28.sp,fontWeight=FontWeight.Medium,modifier=Modifier.testTag(if(compact)"liveConcentration" else "concentration"))
        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) {
            Column(Modifier.weight(1f)) {Text(stringResource(R.string.total_cells),color=Color.White.copy(alpha=.75f),fontSize=12.sp);Text(result?.totalCells?.let(::number) ?: "—",color=Color.White,fontSize=19.sp,modifier=Modifier.testTag(if(compact)"liveTotalCells" else "totalCells"))}
            Column(Modifier.weight(1f),horizontalAlignment=Alignment.End) {Text(stringResource(R.string.required_volume),color=Color.White.copy(alpha=.75f),fontSize=12.sp);Text(result?.requiredMicroliters?.let {number(it)+" µL"} ?: "—",color=Color.White,fontSize=19.sp,modifier=Modifier.testTag(if(compact)"liveRequiredVolume" else "requiredVolume"))}
        }
    }
}
@Composable private fun ImageCanvas(model: CounterModel,state: WorkspaceState,modifier: Modifier=Modifier,override: EditMode?=null) {
    AndroidView(factory={ctx->MicroscopeView(ctx).apply {onTap=model::tap;onFrame=model::updateFrame;onHandle=model::handle}},
        update={it.configure(state.session.current,state.session.grid,override ?: state.edit,state.busy,state.locating,state.showLabels,state.handle)},modifier=modifier.testTag("imageCanvas"))
}
@Composable private fun EditToolbar(model: CounterModel,state: WorkspaceState,onSelect: (EditMode)->Unit) {
    Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(4.dp),verticalAlignment=Alignment.CenterVertically) {
        EditMode.entries.forEach {mode ->
            TextButton(onClick={onSelect(mode)},enabled=!state.locating,colors=ButtonDefaults.textButtonColors(contentColor=if(state.edit==mode)Color.White else Muted),contentPadding=PaddingValues(horizontal=5.dp,vertical=10.dp),modifier=Modifier.weight(1f).background(if(state.edit==mode)Green else Paper,RoundedCornerShape(10.dp)).testTag("edit-${mode.name}")){Text(stringResource(editTitle(mode)),fontSize=13.sp)}
        }
        val undoLabel=stringResource(R.string.undo)
        TextButton(onClick=model::undo,enabled=state.canUndo && !state.busy,contentPadding=PaddingValues(0.dp),modifier=Modifier.width(44.dp).testTag("undo").semantics {contentDescription=undoLabel}){Text("↶",fontSize=26.sp)}
    }
    Text(stringResource(when(state.edit){EditMode.VIEW->R.string.view_hint;EditMode.FRAME->R.string.frame_hint;EditMode.ADD->R.string.add_hint;EditMode.REMOVE->R.string.remove_hint}),style=MaterialTheme.typography.bodySmall,color=Muted)
}
@Composable private fun SquareSelector(model: CounterModel,state: WorkspaceState) {
    val session=state.session;val grid=session.grid;val n=grid.mode.divisions;val data=session.current?.data
    val counts=data?.let {grid.counts(it.markers,it.region,it.quad)} ?: emptyMap()
    SectionTitle(stringResource(R.string.choose_squares))
    Row {TextButton(onClick={model.selectSquares(if(grid.mode==CountMode.OVERVIEW)listOf(0,2,6,8) else listOf(0,4,12,20,24))},enabled=!state.busy,modifier=Modifier.testTag("standardSquares")){Text(stringResource(R.string.standard_squares))};TextButton(onClick={model.selectSquares((0 until n*n).toList())},enabled=!state.busy){Text(stringResource(R.string.all_squares))}}
    Column(verticalArrangement=Arrangement.spacedBy(5.dp)) {
        for(row in 0 until n)Row(horizontalArrangement=Arrangement.spacedBy(5.dp)) {
            for(col in 0 until n){val index=row*n+col;val selected=index in grid.selected
                Surface(onClick={model.toggleSquare(index)},enabled=!state.busy,color=if(selected)Green else Paper,contentColor=if(selected)Color.White else Muted,shape=RoundedCornerShape(9.dp),modifier=Modifier.weight(1f).testTag("square-$index")) {
                    Column(Modifier.padding(vertical=10.dp),horizontalAlignment=Alignment.CenterHorizontally){Text(grid.label(index),fontSize=12.sp);Text(if(selected)counts[index]?.toString() ?: "0" else "—",fontWeight=FontWeight.Medium)}
                }
            }
        }
    }
    Text(stringResource(R.string.grid_area,grid.selected.size,number(grid.area ?: 0.0)),color=Green,modifier=Modifier.testTag("gridArea"))
}

@Composable private fun DetectionSheet(model: CounterModel,state: WorkspaceState,dismiss: ()->Unit) {
    val data=state.session.current?.data ?: return;val settings=data.settings
    ModalBottomSheet(onDismissRequest=dismiss,sheetState=rememberModalBottomSheetState(skipPartiallyExpanded=true),containerColor=Paper) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(16.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
            Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween,verticalAlignment=Alignment.CenterVertically){SectionTitle(stringResource(R.string.detection_settings));TextButton(onClick=dismiss){Text(stringResource(R.string.done))}}
            ImageCanvas(model,state,Modifier.fillMaxWidth().height(170.dp).clip(RoundedCornerShape(14.dp)),EditMode.VIEW)
            Text("${data.markers.size} "+stringResource(R.string.cells_unit),fontSize=23.sp,fontWeight=FontWeight.Medium,color=Green,modifier=Modifier.testTag("liveCellCount"))
            ResultCard(state.session.result,state.busy,true)
            Panel {
                Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Text(stringResource(R.string.sensitivity));Text("${(settings.sensitivity*100).roundToInt()}%")}
                Slider(value=settings.sensitivity.toFloat().coerceIn(0f,1f),onValueChange={model.settings(settings.copy(sensitivity=it.toDouble()))},modifier=Modifier.testTag("sensitivity"))
                Row(horizontalArrangement=Arrangement.spacedBy(6.dp)) {Polarity.entries.forEach {p->FilterChip(selected=settings.polarity==p,onClick={model.settings(settings.copy(polarity=p))},label={Text(stringResource(when(p){Polarity.AUTO->R.string.auto;Polarity.DARK->R.string.dark;Polarity.BRIGHT->R.string.bright}))},modifier=Modifier.testTag("polarity-${p.name}"))}}
                Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically){Text(stringResource(R.string.auto_size),Modifier.weight(1f));Switch(checked=settings.automaticSize,onCheckedChange={model.settings(settings.copy(automaticSize=it))},modifier=Modifier.testTag("automaticSize"))}
                if(data.estimatedDiameter>0)Text(stringResource(R.string.diameter_estimate,data.estimatedDiameter.roundToInt()),color=Muted)
                if(!settings.automaticSize) {
                    Text(stringResource(R.string.minimum_diameter)+" · "+number(settings.minimumDiameter*100)+"%",modifier=Modifier.testTag("minimumValue"))
                    Slider(value=settings.minimumDiameter.toFloat().coerceIn(.002f,.08f),onValueChange={model.settings(settings.withMinimum(it.toDouble()))},valueRange=0.002f..0.08f,modifier=Modifier.testTag("minimumDiameter"))
                    Text(stringResource(R.string.maximum_diameter)+" · "+number(settings.maximumDiameter*100)+"%",modifier=Modifier.testTag("maximumValue"))
                    Slider(value=settings.maximumDiameter.toFloat().coerceIn(.01f,.16f),onValueChange={model.settings(settings.withMaximum(it.toDouble()))},valueRange=0.01f..0.16f,modifier=Modifier.testTag("maximumDiameter"))
                }
                OutlinedButton(onClick=model::resetSettings,modifier=Modifier.fillMaxWidth().testTag("resetDetection")){Text(stringResource(R.string.reset))}
            }
            Spacer(Modifier.height(12.dp))
        }
    }
}
@Composable private fun Fullscreen(model: CounterModel,state: WorkspaceState,dismiss: ()->Unit) {
    Dialog(onDismissRequest=dismiss,properties=DialogProperties(usePlatformDefaultWidth=false,decorFitsSystemWindows=false)) {
        Column(Modifier.fillMaxSize().background(Paper).safeDrawingPadding().padding(12.dp),verticalArrangement=Arrangement.spacedBy(9.dp)) {
            Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween,verticalAlignment=Alignment.CenterVertically){SectionTitle(stringResource(R.string.frame_editor));TextButton(onClick=dismiss,modifier=Modifier.testTag("closeFullscreen")){Text(stringResource(R.string.done))}}
            ImageCanvas(model,state,Modifier.fillMaxWidth().weight(1f).clip(RoundedCornerShape(12.dp)))
            if(state.edit==EditMode.FRAME)FrameControls(model,state)
            EditToolbar(model,state,model::edit)
            Text("${state.session.current?.data?.markers?.size ?: 0} "+stringResource(R.string.cells_unit),modifier=Modifier.align(Alignment.CenterHorizontally).testTag("fullscreenCount"),fontWeight=FontWeight.SemiBold)
        }
    }
}
@Composable private fun FrameControls(model: CounterModel,state: WorkspaceState) {
    var expanded by remember {mutableStateOf(false)}
    Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween,verticalAlignment=Alignment.CenterVertically) {
        Box {
            TextButton(onClick={expanded=true},modifier=Modifier.testTag("handleSelector")){Text(stringResource(handleTitle(state.handle))+" ▾")}
            DropdownMenu(expanded=expanded,onDismissRequest={expanded=false}) {Handle.entries.forEach {h->DropdownMenuItem(text={Text(stringResource(handleTitle(h)))},onClick={model.handle(h);expanded=false},modifier=Modifier.testTag("handle-${h.name}"))}}
        }
        Row {listOf(1,5).forEach {step->FilterChip(selected=state.nudge==step,onClick={model.nudgeStep(step)},label={Text("$step px")})}}
        val resetLabel=stringResource(R.string.reset_frame)
        TextButton(onClick=model::resetFrame,modifier=Modifier.testTag("resetFrame").semantics {contentDescription=resetLabel}){Text("↺",fontSize=25.sp)}
    }
    Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceEvenly) {
        listOf(Triple("←",-1,0),Triple("↑",0,-1),Triple("↓",0,1),Triple("→",1,0)).forEachIndexed {i,(label,x,y)->FilledTonalButton(onClick={model.nudge(x,y)},modifier=Modifier.size(48.dp).testTag("nudge-$i"),contentPadding=PaddingValues(0.dp),shape=RoundedCornerShape(12.dp)){Text(label,fontSize=23.sp)}}
    }
}

@Composable private fun History(model: CounterModel,state: WorkspaceState,records: List<RecordSummary>,onRestored: ()->Unit) {
    var selected by remember {mutableStateOf<RecordSummary?>(null)}
    var deleting by remember {mutableStateOf<RecordSummary?>(null)}
    if(records.isEmpty())Column(Modifier.fillMaxSize().padding(30.dp),verticalArrangement=Arrangement.Center,horizontalAlignment=Alignment.CenterHorizontally){SectionTitle(stringResource(if(state.initialized)R.string.empty_records else R.string.loading));Text(stringResource(R.string.empty_records_detail),color=Muted)}
    else LazyColumn(Modifier.widthIn(max=720.dp).fillMaxSize(),contentPadding=PaddingValues(16.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
        item {Text(stringResource(R.string.nav_records),fontSize=28.sp,fontWeight=FontWeight.SemiBold,color=Ink)}
        items(records,key={it.id}) {record ->
            val thumbnail by produceState<android.graphics.Bitmap?>(null,record.id) {value=withContext(Dispatchers.IO){model.store.thumbnail(record)}}
            Surface(onClick={selected=record},enabled=!state.busy && !state.storing,shape=RoundedCornerShape(18.dp),color=Color.White,modifier=Modifier.fillMaxWidth().testTag("record-${record.id}")) {
                Row(Modifier.padding(14.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)) {
                    thumbnail?.let {Image(it.asImageBitmap(),null,modifier=Modifier.size(64.dp).clip(RoundedCornerShape(12.dp)))}
                    Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(4.dp)) {
                        Text(record.name.ifBlank {if(record.demo)stringResource(R.string.demo_name,stringResource(modeTitle(record.mode))) else stringResource(R.string.unnamed)},fontWeight=FontWeight.SemiBold)
                        Text(DateFormat.getDateTimeInstance(DateFormat.SHORT,DateFormat.SHORT).format(Date(record.date)),style=MaterialTheme.typography.bodySmall,color=Muted)
                        Text("${record.count} "+stringResource(R.string.cells_unit)+(if(record.corners>0)" · ${record.corners}/4" else ""),color=Green)
                    }
                    TextButton(onClick={deleting=record},enabled=!state.busy,modifier=Modifier.testTag("delete-${record.id}")){Text("×",fontSize=23.sp)}
                }
            }
        }
    }
    selected?.let {record ->AlertDialog(onDismissRequest={selected=null},title={Text(stringResource(R.string.load_sample_title))},confirmButton={TextButton(onClick={selected=null;model.restore(record,onRestored)}){Text(stringResource(R.string.load_sample))}},dismissButton={TextButton(onClick={selected=null}){Text(stringResource(R.string.cancel))}})}
    deleting?.let {record ->AlertDialog(onDismissRequest={deleting=null},title={Text(stringResource(R.string.delete_record_title))},confirmButton={TextButton(onClick={deleting=null;model.delete(record)}){Text(stringResource(R.string.delete_record))}},dismissButton={TextButton(onClick={deleting=null}){Text(stringResource(R.string.cancel))}})}
}
@Composable private fun Guide() {
    val uri=LocalUriHandler.current
    Column(Modifier.widthIn(max=720.dp).fillMaxSize().verticalScroll(rememberScrollState()).padding(18.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) {
        Text(stringResource(R.string.guide_heading),fontSize=30.sp,fontWeight=FontWeight.SemiBold,color=Ink)
        Text(stringResource(R.string.guide_intro),color=Muted)
        listOf(R.string.guide_acquire_title to R.string.guide_acquire,R.string.guide_frame_title to R.string.guide_frame,R.string.guide_modes_title to R.string.guide_modes,R.string.guide_rules_title to R.string.guide_rules,R.string.guide_parameters_title to R.string.guide_parameters,R.string.guide_formula_title to R.string.guide_formula,R.string.guide_records_title to R.string.guide_records).forEach { (title,body) ->Panel {SectionTitle(stringResource(title));Text(stringResource(body),style=MaterialTheme.typography.bodyMedium,color=Muted,lineHeight=24.sp)}}
        Panel {
            SectionTitle("cellscope")
            Text(stringResource(R.string.author)+": @caelricluo",modifier=Modifier.testTag("authorCredit"))
            Text(stringResource(R.string.coauthor)+": Codex GPT-6.1 Sol",modifier=Modifier.testTag("coauthorCredit"))
            Text(stringResource(R.string.version,BuildConfig.VERSION_NAME),color=Muted)
            TextButton(onClick={uri.openUri("https://github.com/caelricluo/cellscope")}){Text("GitHub ↗")}
        }
    }
}
private fun instruction(mode: CountMode)=when(mode){CountMode.OVERVIEW->R.string.instruction_overview;CountMode.CORNERS->R.string.instruction_corners;CountMode.RBC->R.string.instruction_rbc;CountMode.CUSTOM->R.string.instruction_custom}
private fun editTitle(mode: EditMode)=when(mode){EditMode.VIEW->R.string.view;EditMode.FRAME->R.string.frame;EditMode.ADD->R.string.add;EditMode.REMOVE->R.string.remove}
private fun handleTitle(handle: Handle)=when(handle){Handle.TOP_LEFT->R.string.handle_tl;Handle.TOP->R.string.handle_top;Handle.TOP_RIGHT->R.string.handle_tr;Handle.RIGHT->R.string.handle_right;Handle.BOTTOM_RIGHT->R.string.handle_br;Handle.BOTTOM->R.string.handle_bottom;Handle.BOTTOM_LEFT->R.string.handle_bl;Handle.LEFT->R.string.handle_left;Handle.MOVE->R.string.handle_move}
private fun gridStatus(state: WorkspaceState)=when {state.locating->R.string.locating;state.located?.overview!=null->R.string.grid_overview;state.located?.central!=null->R.string.grid_central;state.located?.corner!=null->R.string.grid_corner;state.session.current?.data?.quad!=null->R.string.frame_restored;else->R.string.grid_none}
