package com.cellscope.android

import android.content.Context
import android.content.ContentValues
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import android.os.LocaleList
import android.app.LocaleManager
import android.provider.MediaStore
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.lifecycle.ViewModelProvider
import androidx.exifinterface.media.ExifInterface
import androidx.compose.ui.geometry.Offset
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.By
import androidx.test.uiautomator.Until
import com.cellscope.core.*
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import java.io.File
import kotlin.math.min
import kotlin.math.exp
import kotlin.math.pow

@RunWith(AndroidJUnit4::class)
class WorkflowTests {
    @get:Rule val compose=createEmptyComposeRule()
    private lateinit var scenario: ActivityScenario<MainActivity>
    private lateinit var model: CounterModel
    private val context get()=ApplicationProvider.getApplicationContext<Context>()
    private val device get()=UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    @Before fun launch() {
        context.filesDir.deleteRecursively();context.cacheDir.deleteRecursively()
        context.getSystemService(LocaleManager::class.java).applicationLocales=LocaleList.forLanguageTags("en")
        scenario=ActivityScenario.launch(MainActivity::class.java)
        scenario.onActivity {model=ViewModelProvider(it)[CounterModel::class.java]}
        compose.waitUntil(20_000){model.state.value.initialized}
    }
    @After fun close() {scenario.close()}
    private fun action(block: ()->Unit) {compose.runOnIdle(block)}
    private fun click(tag: String) {compose.onNodeWithTag(tag).performScrollTo().performClick()}
    private fun ready() {compose.waitUntil(40_000){!model.state.value.busy && model.state.value.session.current?.data?.analyzed==true};compose.waitForIdle();assertNull(model.state.value.message)}
    private fun demo(mode: CountMode) {action {model.mode(mode);model.demo()};ready()}
    private fun count()=model.state.value.session.current!!.data.markers.size
    private fun dismissMessage() {action {model.dismissMessage()}}
    private fun screenshot(name: String) {val file=File(context.getExternalFilesDir(null),"$name.png");device.takeScreenshot(file);device.executeShellCommand("mkdir -p /sdcard/Pictures/cellscope-tests");device.executeShellCommand("cp ${file.absolutePath} /sdcard/Pictures/cellscope-tests/$name.png")}

    @Test fun demoAcquisitionAndIndependentCalculations() {
        click("mode-CUSTOM");click("loadDemo");ready();assertEquals(49,count())
        compose.onNodeWithTag("cellCount").assertTextEquals("49")
        click("target");compose.onNodeWithTag("target").performTextClearance()
        assertEquals(980000.0,model.state.value.session.result!!.concentration,1e-7)
        compose.onNodeWithTag("requiredVolume").assertTextEquals("—")
        compose.onNodeWithTag("totalCells").assertTextEquals("98.00 × 10⁴")
        compose.onNodeWithTag("target").performTextInput("100000")
        click("stockVolume");compose.onNodeWithTag("stockVolume").performTextClearance()
        assertNotNull(model.state.value.session.result!!.requiredMicroliters)
        assertNull(model.state.value.session.result!!.totalCells)
        device.pressBack();click("resetChamber")
        assertEquals(Inputs(),model.state.value.session.inputs)
        click("concentration");screenshot("android-results-en")
    }
    @Test fun fourCornersRunningMeanAndManualUndo() {
        demo(CountMode.CORNERS)
        assertEquals(196,model.state.value.session.totalCount)
        assertEquals(4,model.state.value.session.counted.size)
        val marker=model.state.value.session.current!!.data.markers.first()
        action {model.edit(EditMode.REMOVE);model.tap(marker.x,marker.y)}
        assertEquals(195,model.state.value.session.totalCount)
        assertEquals(975000.0,model.state.value.session.result!!.concentration,1e-7)
        click("corner-C3");assertEquals(49,count());click("corner-A1");assertEquals(48,count())
        action {model.edit(EditMode.ADD);model.tap(.5,.55)};assertEquals(49,count())
        action {model.undo()};assertEquals(48,count())
        click("cellCount");screenshot("android-corners-en")
    }
    @Test fun overviewAndRbcSelectionAndUndo() {
        demo(CountMode.OVERVIEW);assertEquals(81,count())
        click("standardSquares");ready();assertEquals(36,count())
        assertEquals(4.0,model.state.value.session.grid.area!!,1e-9)
        action {model.undo()};assertEquals(81,count());assertEquals(9,model.state.value.session.grid.selected.size)
        action {model.mode(CountMode.RBC)};ready();assertEquals(20,count())
        click("square-1");ready();assertEquals(24,count())
        assertEquals(.24,model.state.value.session.grid.area!!,1e-9)
        action {model.undo()};assertEquals(20,count());assertEquals(5,model.state.value.session.grid.selected.size)
        click("cellCount");screenshot("android-rbc-en")
    }
    @Test fun liveSettingsResetAndLatestResult() {
        demo(CountMode.CUSTOM);click("detectionSettings")
        compose.onNodeWithTag("liveCellCount").assertTextContains("49",substring=true)
        click("automaticSize")
        compose.onNodeWithTag("minimumDiameter").performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.SetProgress){it(.08f)}
        ready();assertEquals(0,count());compose.onNodeWithTag("liveCellCount").assertTextContains("0",substring=true)
        compose.onNodeWithTag("liveConcentration").assertTextEquals("0 cells/mL")
        click("resetDetection");ready();assertEquals(49,count())
        action {for(i in 0..20)model.settings(model.state.value.session.current!!.data.settings.copy(sensitivity=i/20.0))}
        ready();assertEquals(1.0,model.state.value.session.current!!.data.settings.sensitivity,0.0)
        assertEquals(49,count());compose.onNodeWithTag("liveCellCount").assertTextContains("49",substring=true)
        screenshot("android-live-settings-en")
    }
    @Test fun frameNudgesAndResetInFullscreen() {
        demo(CountMode.CUSTOM);click("edit-FRAME")
        val before=model.state.value.session.current!!.data.region
        compose.onNodeWithTag("nudge-3").performClick();ready()
        assertEquals(before.x+.001,model.state.value.session.current!!.data.region.x,1e-8)
        compose.onNodeWithTag("handleSelector").performClick()
        compose.onNodeWithTag("handle-TOP_LEFT").performScrollTo().performClick()
        val q=model.state.value.session.current!!.data.quad!!
        compose.onNodeWithTag("nudge-1").performClick();ready()
        assertEquals(q.topLeft.y-.001,model.state.value.session.current!!.data.quad!!.topLeft.y,1e-8)
        compose.onNodeWithTag("resetFrame").performClick();ready()
        assertEquals(Region(),model.state.value.session.current!!.data.region)
        screenshot("android-frame-en")
        compose.onNodeWithTag("closeFullscreen").performClick()
    }
    @Test fun pngHistoryExportAndSessionPersistence() {
        demo(CountMode.CUSTOM)
        action {model.name("Sample, \"A\"");model.input(Inputs(stockVolume=".5"));model.save()}
        compose.waitUntil(20_000){!model.state.value.storing && model.records.value.size==1}
        dismissMessage();val record=model.records.value.single();val original=model.state.value.session.current!!.bitmap
        val restored=model.store.restore(record);val recovered=restored.current!!.bitmap
        assertTrue(original.sameAs(recovered));assertEquals(model.state.value.session.current!!.data.markers,restored.current!!.data.markers)
        val uris=ImageService.export(context,model.state.value.session)
        assertEquals(2,uris.size)
        val csv=context.contentResolver.openInputStream(uris.first())!!.bufferedReader().use {it.readText()}
        assertTrue(csv.startsWith("\uFEFF"));assertTrue(csv.contains("\"Sample, \"\"A\"\"\""));assertTrue(csv.contains("980000.0"))
        context.contentResolver.openInputStream(uris.last())!!.use {assertArrayEquals(byteArrayOf(-119,80,78,71,13,10,26,10),it.readNBytes(8))}
        action {model.mode(CountMode.RBC)};ready()
        compose.onNodeWithTag("tab-1").performClick()
        compose.onNodeWithTag("record-${record.id}").performClick()
        compose.onNodeWithText(context.getString(R.string.load_sample),useUnmergedTree=true).performClick();ready()
        assertEquals(CountMode.CUSTOM,model.state.value.session.grid.mode);assertEquals(49,count())
        action {model.flush()};Thread.sleep(700)
        assertEquals(49,model.store.loadSession()!!.current!!.data.markers.size)
        assertEquals(".5",model.store.loadSession()!!.inputs.stockVolume)
    }
    @Test fun importedCentralGridKeepsCornerModeAvailable() {
        val file=File(context.cacheDir,"central.png").apply {parentFile!!.mkdirs();outputStream().use {ImageService.demo(CountMode.RBC).compress(Bitmap.CompressFormat.PNG,100,it)}}
        action {model.importImage(Uri.fromFile(file),model.importTarget())};ready()
        assertEquals(CountMode.CORNERS,model.state.value.session.grid.mode)
        assertNotNull(model.state.value.located?.central)
        assertNotNull(model.state.value.session.result)
        compose.onNodeWithTag("mode-OVERVIEW").assertIsEnabled()
        compose.onNodeWithTag("mode-CORNERS").assertIsEnabled()
        compose.onNodeWithTag("switchToRBC").assertExists()
        action {model.mode(CountMode.OVERVIEW)};ready()
        assertEquals(CountMode.OVERVIEW,model.state.value.session.grid.mode)
        assertNotNull(model.state.value.session.result)
    }
    @Test fun chineseInterfaceAndCredits() {
        context.getSystemService(LocaleManager::class.java).applicationLocales=LocaleList.forLanguageTags("zh-Hans")
        compose.waitUntil(15_000){compose.onAllNodesWithText("细胞计数").fetchSemanticsNodes().isNotEmpty()}
        scenario.onActivity {model=ViewModelProvider(it)[CounterModel::class.java]}
        demo(CountMode.CUSTOM);click("cellCount");screenshot("android-count-zh")
        compose.onNodeWithTag("tab-2").performClick()
        click("authorCredit");compose.onNodeWithTag("authorCredit").assertTextContains("@caelricluo",substring=true)
        compose.onNodeWithTag("coauthorCredit").assertTextContains("Codex GPT-6.1 Sol",substring=true)
        screenshot("android-guide-zh")
    }

    @Test fun systemPhotoPickerCanImportSameImageTwice() {
        val values=ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME,"cellscope-test-${System.currentTimeMillis()}.png")
            put(MediaStore.Images.Media.MIME_TYPE,"image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH,"Pictures/cellscope")
            put(MediaStore.Images.Media.IS_PENDING,1)
        }
        val uri=context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,values)!!
        try {
            context.contentResolver.openOutputStream(uri)!!.use {ImageService.demo(CountMode.CUSTOM).compress(Bitmap.CompressFormat.PNG,100,it)}
            context.contentResolver.update(uri,ContentValues().apply {put(MediaStore.Images.Media.IS_PENDING,0)},null,null)
            click("mode-CUSTOM")
            fun pick() {
                val previous=model.state.value.session.current?.data?.imageId
                click("importPhoto")
                if(previous!=null)compose.onNodeWithText(context.getString(R.string.replace)).performClick()
                val photo=device.wait(Until.findObject(By.descStartsWith("Photo taken on")),15_000)
                assertNotNull("Photo Picker image",photo);photo.click()
                compose.waitUntil(20_000){model.state.value.session.current?.data?.imageId?.let {it!=previous}==true}
                ready()
            }
            pick();assertEquals(49,count())
            action {model.edit(EditMode.ADD);model.tap(.5,.55)};assertEquals(50,count())
            pick();assertEquals(49,count());assertFalse(model.state.value.session.demo)
            screenshot("android-photo-import-en")
        } finally {context.contentResolver.delete(uri,null,null)}
    }
    @Test fun systemCameraReturnsFullResolutionImage() {
        click("mode-CUSTOM");click("capture")
        val shutter=device.wait(Until.findObject(By.res("com.android.camera2","shutter_button")),15_000)
        assertNotNull("System camera shutter",shutter);shutter.click()
        val done=device.wait(Until.findObject(By.res("com.android.camera2","done_button")),15_000)
        assertNotNull("Captured photo confirmation",done);done.click();ready()
        val bitmap=model.state.value.session.current!!.bitmap
        assertTrue(bitmap.width>1000 || bitmap.height>1000)
        assertTrue(bitmap.width<=1600 && bitmap.height<=1600)
        assertNotNull(model.state.value.session.result)
    }
    @Test fun faintCellsUpdatePolarityAndCalculationsInSheet() {
        val w=420;val h=400;val p=IntArray(w*h)
        for(y in 0 until h)for(x in 0 until w)p[y*w+x]=165+x/35+y/50+(x*17+y*13)%3-1
        for((cx,cy,sign,spread)in listOf(doubleArrayOf(83.0,90.0,1.0,18.0),doubleArrayOf(185.0,110.0,-1.0,18.0),doubleArrayOf(305.0,95.0,1.0,18.0),doubleArrayOf(115.0,260.0,-1.0,18.0),doubleArrayOf(305.0,280.0,1.0,6.5)))
            for(y in cy.toInt()-10..cy.toInt()+10)for(x in cx.toInt()-10..cx.toInt()+10)p[y*w+x]=(p[y*w+x]+sign*11*exp(-((x-cx).pow(2)+(y-cy).pow(2))/spread)).toInt()
        val bitmap=Bitmap.createBitmap(p.map {Color.rgb(it,it,it)}.toIntArray(),w,h,Bitmap.Config.ARGB_8888)
        val file=File(context.cacheDir,"faint.png").apply {parentFile!!.mkdirs();outputStream().use {bitmap.compress(Bitmap.CompressFormat.PNG,100,it)}}
        action {model.mode(CountMode.CUSTOM);model.importImage(Uri.fromFile(file),model.importTarget())};ready()
        click("detectionSettings")
        compose.onNodeWithTag("sensitivity").performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.SetProgress){it(0f)};ready();assertEquals(0,count())
        compose.onNodeWithTag("sensitivity").performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.SetProgress){it(1f)};ready();assertEquals(5,count())
        compose.onNodeWithTag("liveConcentration").assertTextEquals("10.00 × 10⁴ cells/mL")
        click("polarity-DARK");ready();assertEquals(2,count())
        compose.onNodeWithTag("liveTotalCells").assertTextEquals("4.00 × 10⁴")
        click("polarity-BRIGHT");ready();assertEquals(3,count())
        click("polarity-AUTO");ready();assertEquals(5,count())
    }
    @Test fun nativeCanvasAcceptsMarkerTaps() {
        demo(CountMode.CUSTOM);click("edit-ADD")
        compose.onNodeWithTag("imageCanvas").performScrollTo().performTouchInput {click(center)}
        compose.waitUntil(5_000){count()==50}
        click("edit-REMOVE")
        compose.onNodeWithTag("imageCanvas").performScrollTo().performTouchInput {click(center)}
        compose.waitUntil(5_000){count()==49}
        click("undo");assertEquals(50,count())
    }
    @Test fun exifOrientationsAndTransparentPixelsNormalizeCorrectly() {
        val colors=intArrayOf(Color.RED,Color.GREEN,Color.BLUE,Color.YELLOW)
        val bitmap=Bitmap.createBitmap(80,60,Bitmap.Config.ARGB_8888)
        for(y in 0 until 60)for(x in 0 until 80)bitmap.setPixel(x,y,colors[(y/30)*2+x/40])
        val expected=listOf(listOf(0,1,2,3),listOf(1,0,3,2),listOf(3,2,1,0),listOf(2,3,0,1),listOf(0,2,1,3),listOf(2,0,3,1),listOf(3,1,2,0),listOf(1,3,0,2))
        for(orientation in 1..8) {
            val file=File(context.cacheDir,"exif-$orientation.jpg")
            file.outputStream().use {bitmap.compress(Bitmap.CompressFormat.JPEG,100,it)}
            ExifInterface(file).apply {setAttribute(ExifInterface.TAG_ORIENTATION,orientation.toString());saveAttributes()}
            val image=ImageService.load(context,Uri.fromFile(file))
            assertEquals(if(orientation<5)80 else 60,image.width)
            val actual=listOf(image.getPixel(10,10),image.getPixel(image.width-10,10),image.getPixel(10,image.height-10),image.getPixel(image.width-10,image.height-10))
            actual.zip(expected[orientation-1]).forEach {(color,index)->
                assertEquals(Color.red(colors[index]).toDouble(),Color.red(color).toDouble(),5.0)
                assertEquals(Color.green(colors[index]).toDouble(),Color.green(color).toDouble(),5.0)
                assertEquals(Color.blue(colors[index]).toDouble(),Color.blue(color).toDouble(),5.0)
            }
        }
        val transparent=Bitmap.createBitmap(20,20,Bitmap.Config.ARGB_8888)
        val file=File(context.cacheDir,"transparent.png").apply {outputStream().use {transparent.compress(Bitmap.CompressFormat.PNG,100,it)}}
        assertEquals(Color.WHITE,ImageService.load(context,Uri.fromFile(file)).getPixel(10,10))
    }
}
