package com.cellscope.android

import android.content.ActivityNotFoundException
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.ViewModelProvider

class MainActivity: ComponentActivity() {
    private lateinit var counter: CounterModel
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        counter=ViewModelProvider(this)[CounterModel::class.java]
        setContent { CellscopeTheme { CellscopeApp(counter) } }
    }
    override fun onStop() {super.onStop();if(::counter.isInitialized)counter.flush()}
}
