package com.example.unityandroid

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.unityandroid.ui.theme.UnityAndroidTheme
import com.unity3d.player.UnityPlayerActivity
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            UnityAndroidTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    Column(
                        modifier = Modifier
                            .padding(innerPadding)
                            .fillMaxSize(),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text("Hello Android!")
                        Spacer(Modifier.height(16.dp))
                        Button(onClick = {
                            startActivity(Intent(this@MainActivity, MyUnityActivity::class.java).apply {
                                putExtra("scene", "SampleScene") // match your Unity scene name
                            })
                        }) {
                            Text("Open Unity Scene")
                        }
                    }
                }
            }
        }
    }
}
