package studio.mekate.b3

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import studio.mekate.b3.feature.home.HomeScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            HomeScreen()
        }
    }
}
