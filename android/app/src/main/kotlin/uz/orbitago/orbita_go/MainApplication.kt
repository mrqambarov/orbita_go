package uz.orbitago.orbita_go

import io.flutter.app.FlutterApplication
import com.yandex.mapkit.MapKitFactory

class MainApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        // Set a valid formatted dummy/placeholder key to prevent Yandex MapKit SDK from throwing AssertionError
        MapKitFactory.setApiKey("d228c257-2e19-48fb-a877-e6f007b8b7b2")
        MapKitFactory.initialize(this)
    }
}
