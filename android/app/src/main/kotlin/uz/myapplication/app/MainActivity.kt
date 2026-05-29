package uz.myapplication.app

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 15+ (SDK 35): tizim paneli ostida kontent — insetlar Flutter SafeArea orqali
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }
}
