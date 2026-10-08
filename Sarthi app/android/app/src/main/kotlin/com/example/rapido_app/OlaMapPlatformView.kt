package com.example.rapido_app

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Color as AColor
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.net.Uri
import android.view.Choreographer
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import com.ola.mapsdk.view.OlaMapView
import com.ola.mapsdk.view.OlaMap
import com.ola.mapsdk.view.Marker
import com.ola.mapsdk.view.Polyline
import com.ola.mapsdk.view.Circle
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.annotations.PolylineOptions
import org.maplibre.android.geometry.LatLng
import com.ola.mapsdk.interfaces.OlaMapCallback
import com.ola.mapsdk.model.OlaLatLng
import com.ola.mapsdk.model.OlaMarkerOptions
import com.ola.mapsdk.model.OlaPolylineOptions
import com.ola.mapsdk.model.OlaCircleOptions
import com.ola.mapsdk.utils.PolylineDecoder
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.PI

class OlaMapPlatformView(
    private val context: Context,
    id: Int,
    creationParams: Map<String?, Any?>?,
    messenger: BinaryMessenger
) : PlatformView, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var showUserDot: Boolean = creationParams?.get("showUserDot") as? Boolean ?: true
    private val container: FrameLayout = FrameLayout(context)
    private var olaMapView: OlaMapView? = null
    private var olaMap: OlaMap? = null

    private var pickupMarker: Marker? = null
    private var destMarker: Marker? = null
    private var captainMarker: Marker? = null
    
    private var pickupMarkerPolyline: Polyline? = null
    private var pickupMarkerAccent: Polyline? = null
    private var destInnerPolylines = ArrayList<Polyline>()
    private var destFlagPolyline: Polyline? = null
    private var destNativeCircle: Circle? = null   // OlaMap Circle — outer ring
    private var destInnerCircle: Circle? = null    // OlaMap Circle — white inner dot
    private var pickupNativeCircle: Circle? = null // OlaMap Circle — outer ring
    private var pickupInnerCircle: Circle? = null  // OlaMap Circle — white inner dot
    private var captainNativeCircle: Circle? = null // OlaMap Circle — captain outer ring
    private var captainInnerCircle: Circle? = null  // OlaMap Circle — captain white inner dot
    private var userLiveNativeCircle: Circle? = null // OlaMap Circle — live user outer ring
    private var userLiveInnerCircle: Circle? = null  // OlaMap Circle — live user inner dot
    private var activePolyline: Polyline? = null
    private var activePolylineCasing: Polyline? = null
    private var headingPolyline: Polyline? = null
    
    private var mapLibreMap: MapLibreMap? = null
    private var mlPickupMarkerPolyline: org.maplibre.android.annotations.Polyline? = null
    private var mlPickupMarkerAccent: org.maplibre.android.annotations.Polyline? = null
    private var mlActivePolylineCasing: org.maplibre.android.annotations.Polyline? = null
    private var mlActivePolyline: org.maplibre.android.annotations.Polyline? = null
    private var mlHeadingPolylineCasing: org.maplibre.android.annotations.Polyline? = null
    private var mlHeadingPolyline: org.maplibre.android.annotations.Polyline? = null
    private var headingPolylineCasing: Polyline? = null

    private val methodChannel = MethodChannel(messenger, "sarthi/ola_map_$id")
    private val eventChannel = EventChannel(messenger, "sarthi/ola_map_events_$id")
    private var eventSink: EventChannel.EventSink? = null

    // Queue a camera move to apply as soon as the map is ready
    private var pendingLat: Double? = null
    private var pendingLng: Double? = null
    private var pendingZoom: Double = 16.0
    private var pendingBearing: Double? = null
    private var pendingTilt: Double? = null

    // ── Native Overlay for destination pin ───────────────────────────────────
    // Bypasses OlaMap SDK collision system — always 100% visible
    private var destOverlayView: ImageView? = null
    private var destOverlayPosition: OlaLatLng? = null
    private var overlayBitmap: Bitmap? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var choreographerRunning = false

    // Queue markers to apply as soon as the map is ready
    private var pendingPickupPosition: OlaLatLng? = null
    private var pendingDestPosition: OlaLatLng? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        setupMap()
    }

    // ── Map initialisation ───────────────────────────────────────────────────

    private fun setupMap() {
        val appInfo = context.packageManager.getApplicationInfo(
            context.packageName, PackageManager.GET_META_DATA
        )
        val apiKey = appInfo.metaData?.getString("ola_maps_api_key") ?: ""

        try {
            org.maplibre.android.MapLibre.getInstance(context)
            org.maplibre.android.MapLibre.setConnected(true)
        } catch (e: Exception) {
            Log.e("OlaMap", "Failed to force MapLibre connected state", e)
        }

        olaMapView = OlaMapView(context)
        container.addView(olaMapView)

        // Ensure MapLibre OpenGL lifecycle events trigger when attached to window (essential for physical devices like moto g85 5G)
        container.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) {
                try {
                    olaMapView?.onStart()
                    olaMapView?.onResume()
                } catch (e: Exception) {
                    Log.e("OlaMap", "onViewAttachedToWindow error", e)
                }
            }

            override fun onViewDetachedFromWindow(v: View) {
                try {
                    olaMapView?.onPause()
                    olaMapView?.onStop()
                } catch (e: Exception) {
                    Log.e("OlaMap", "onViewDetachedFromWindow error", e)
                }
            }
        })

        olaMapView?.getMap(apiKey, object : OlaMapCallback {
            override fun onMapReady(map: OlaMap) {
                olaMap = map

                try {
                    val builder = OlaMarkerOptions.Builder()
                    val methods = builder::class.java.methods
                    val methodNames = methods.joinToString(", ") { it.name }
                    Log.d("OlaMap", "OlaMarkerOptions.Builder methods: $methodNames")
                } catch (e: Exception) {
                    Log.e("OlaMap", "Error dumping builder methods", e)
                }

                try {
                    olaMapView?.let { mapView ->
                        val field = mapView.javaClass.getDeclaredField("mapLibreMapView")
                        field.isAccessible = true
                        val mlMapView = field.get(mapView) as? MapView
                        mlMapView?.getMapAsync { mapLibre ->
                            mapLibreMap = mapLibre
                            try {
                                val locationComponent = mapLibre.locationComponent
                                val options = org.maplibre.android.location.LocationComponentOptions.builder(context)
                                    .accuracyAlpha(0f)
                                    .accuracyColor(android.graphics.Color.TRANSPARENT)
                                    .build()
                                locationComponent.applyStyle(options)
                            } catch (e: Exception) {
                                Log.e("OlaMap", "Failed to configure LocationComponent", e)
                            }
                            mapLibre.addOnCameraMoveListener {
                                val target = mapLibre.cameraPosition.target
                                if (target != null) {
                                    val lat = target.latitude
                                    val lng = target.longitude
                                    eventSink?.success(mapOf("event" to "cameraMove", "lat" to lat, "lng" to lng))
                                }
                            }
                            mapLibre.addOnCameraIdleListener {
                                val target = mapLibre.cameraPosition.target
                                if (target != null) {
                                    val lat = target.latitude
                                    val lng = target.longitude
                                    eventSink?.success(mapOf("event" to "cameraIdle", "lat" to lat, "lng" to lng))
                                }
                            }
                            Log.d("OlaMap", "MapLibreMap acquired successfully!")
                        }
                    }
                } catch (e: Exception) {
                    Log.e("OlaMap", "Reflection error getting MapLibreMap", e)
                }

                // Only show native GPS location dot for captain (user app hides it)
                if (showUserDot) {
                    try {
                        map.showCurrentLocation()
                    } catch (e: Exception) {
                        Log.e("OlaMap", "showCurrentLocation error", e)
                    }
                }

                // Apply any camera move that was requested before the map was ready
                val lat = pendingLat
                val lng = pendingLng
                if (lat != null && lng != null) {
                    moveCameraTo(lat, lng, pendingZoom, pendingBearing, pendingTilt)
                    pendingLat = null
                    pendingLng = null
                    pendingBearing = null
                    pendingTilt = null
                }
                
                // Add any pending markers
                pendingPickupPosition?.let {
                    drawPickupTarget(it)
                    pendingPickupPosition = null
                }
                pendingDestPosition?.let {
                    drawDestinationFlag(it)
                    pendingDestPosition = null
                }

                try {
                    val mapClass = map::class.java
                    Log.d("OlaMap", "OlaMap Methods:")
                    mapClass.methods.forEach { Log.d("OlaMap", "Method: ${it.name}(${it.parameterTypes.joinToString { p -> p.simpleName }}) -> ${it.returnType.simpleName}") }
                    Log.d("OlaMap", "OlaMap Fields:")
                    mapClass.declaredFields.forEach { Log.d("OlaMap", "Field: ${it.name} : ${it.type.simpleName}") }
                } catch (e: Exception) {}

                // Notify Flutter that the map is ready
                eventSink?.success(mapOf("event" to "mapReady"))
                // Start frame-by-frame overlay positioning loop
                startOverlayLoop()
            }

            override fun onMapError(error: String) {
                Log.e("OlaMap", "onMapError: $error")
                eventSink?.error("MAP_ERROR", error, null)
            }
        })

        // Also trigger initial start/resume in case container is already attached
        try {
            olaMapView?.onStart()
            olaMapView?.onResume()
        } catch (e: Exception) {
            Log.e("OlaMap", "lifecycle error", e)
        }
    }

    // ── Native Overlay Helpers ────────────────────────────────────────────────

    /** Creates the overlay bitmap lazily from the bundled PNG drawable */
    private fun getOrCreateOverlayBitmap(): Bitmap {
        overlayBitmap?.let { return it }
        return try {
            val resId = context.resources.getIdentifier("ic_dest_pin_overlay", "drawable", context.packageName)
            if (resId != 0) {
                val raw = BitmapFactory.decodeResource(context.resources, resId)
                val scaled = Bitmap.createScaledBitmap(raw, 100, 100, true)
                overlayBitmap = scaled
                scaled
            } else {
                createFallbackPinBitmap().also { overlayBitmap = it }
            }
        } catch (e: Exception) {
            createFallbackPinBitmap().also { overlayBitmap = it }
        }
    }

    /** Programmatic fallback pin: red teardrop with white inner circle */
    private fun createFallbackPinBitmap(): Bitmap {
        val w = 100; val h = 130
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // Outer red circle (head of pin)
        paint.color = Color.parseColor("#EA4335")
        c.drawCircle(w / 2f, w / 2f, w / 2f, paint)

        // Tail triangle
        val path = Path()
        path.moveTo(w * 0.25f, w * 0.78f)
        path.lineTo(w * 0.75f, w * 0.78f)
        path.lineTo(w / 2f, h.toFloat())
        path.close()
        c.drawPath(path, paint)

        // White inner circle
        paint.color = Color.WHITE
        c.drawCircle(w / 2f, w / 2f, w * 0.22f, paint)
        return bmp
    }

    /** Adds or updates the native ImageView overlay positioned over lat/lng */
    private fun showDestinationOverlay(position: OlaLatLng) {
        destOverlayPosition = position
        mainHandler.post {
            if (destOverlayView == null) {
                val iv = ImageView(context)
                iv.setImageBitmap(getOrCreateOverlayBitmap())
                // Elevation ensures it sits above the map surface
                iv.elevation = 32f
                val params = FrameLayout.LayoutParams(100, 100)
                container.addView(iv, params)
                destOverlayView = iv
            }
            updateOverlayPosition()
        }
    }

    /** Removes the native ImageView overlay */
    private fun removeDestinationOverlay() {
        mainHandler.post {
            destOverlayView?.let { container.removeView(it) }
            destOverlayView = null
            destOverlayPosition = null
        }
    }

    /** Projects the stored lat/lng to screen XY and moves the overlay ImageView */
    private fun updateOverlayPosition() {
        val iv = destOverlayView ?: return
        val pos = destOverlayPosition ?: return
        val map = olaMap ?: return

        try {
            // Use OlaMap projection via reflection to get screen point
            val projection = map::class.java
                .methods
                .firstOrNull { it.name == "getProjection" }
                ?.invoke(map)

            if (projection != null) {
                // Try toScreenLocation from MapLibre projection
                val screenPt = projection::class.java
                    .methods
                    .firstOrNull { it.name == "toScreenLocation" }
                    ?.invoke(projection, 
                        projection::class.java.classLoader
                            ?.loadClass("org.maplibre.android.geometry.LatLng")
                            ?.getConstructor(Double::class.java, Double::class.java)
                            ?.newInstance(pos.latitude, pos.longitude)
                    )

                if (screenPt != null) {
                    val x = screenPt::class.java.getMethod("x").invoke(screenPt) as? Number
                    val y = screenPt::class.java.getMethod("y").invoke(screenPt) as? Number
                    if (x != null && y != null) {
                        val px = x.toFloat() - 50f  // center the 100px icon
                        val py = y.toFloat() - 100f // pin tip at coordinate
                        iv.x = px
                        iv.y = py
                        iv.visibility = View.VISIBLE
                        return
                    }
                }
            }
        } catch (e: Exception) {
            Log.d("OlaMap", "Projection fallback: ${e.message}")
        }

        // Fallback: hide if projection fails (avoids icon stuck at 0,0)
        iv.visibility = View.INVISIBLE
    }

    /** Choreographer loop — runs every display frame to reposition the overlay as the map pans/zooms */
    private fun startOverlayLoop() {
        if (choreographerRunning) return
        choreographerRunning = true
        val choreographer = Choreographer.getInstance()
        val frameCallback = object : Choreographer.FrameCallback {
            override fun doFrame(frameTimeNanos: Long) {
                if (!choreographerRunning) return
                if (destOverlayView != null) updateOverlayPosition()
                choreographer.postFrameCallback(this)
            }
        }
        choreographer.postFrameCallback(frameCallback)
    }

    /** Stops the Choreographer loop (e.g. on dispose) */
    private fun stopOverlayLoop() {
        choreographerRunning = false
    }

    // ── Custom Marker Bitmap Fallback ─────────────────────────────────────────

    private fun createMarkerBitmap(isPickup: Boolean): Bitmap {
        if (isPickup) {
            val size = 256
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.textSize = 200f
            paint.textAlign = Paint.Align.CENTER
            
            val metrics = paint.fontMetrics
            val y = (size / 2f) - (metrics.ascent + metrics.descent) / 2f
            canvas.drawText("📍", size / 2f, y, paint)
            return bitmap
        } else {
            // Draw a large red circular marker
            val width = 160
            val height = 160
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.color = Color.parseColor("#EA4335")
            // Draw a white border for better visibility
            val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            borderPaint.color = Color.WHITE
            
            canvas.drawCircle(width / 2f, height / 2f, (width / 2f) - 2f, borderPaint)
            canvas.drawCircle(width / 2f, height / 2f, (width / 2f) - 10f, paint)
            return bitmap
        }
    }

    // ── Safe Drawable Resource Lookup ────────────────────────────────────────

    private fun getResId(name: String): Int {
        return try {
            context.resources.getIdentifier(name, "drawable", context.packageName)
        } catch (e: Exception) {
            0
        }
    }

    private fun cropTransparentMargins(bitmap: Bitmap): Bitmap {
        var top = bitmap.height
        var bottom = 0
        var left = bitmap.width
        var right = 0

        val rowPixels = IntArray(bitmap.width)
        for (y in 0 until bitmap.height) {
            bitmap.getPixels(rowPixels, 0, bitmap.width, 0, y, bitmap.width, 1)
            for (x in 0 until bitmap.width) {
                if (android.graphics.Color.alpha(rowPixels[x]) > 0) {
                    if (x < left) left = x
                    if (x > right) right = x
                    if (y < top) top = y
                    if (y > bottom) bottom = y
                }
            }
        }

        if (left >= right || top >= bottom) return bitmap // Empty or completely transparent

        return Bitmap.createBitmap(bitmap, left, top, right - left + 1, bottom - top + 1)
    }

    private var destDotMarker: com.ola.mapsdk.view.Marker? = null

    // ── Helper to build OlaMarkerOptions ─────────────────────────────────────

    private fun buildMarkerOptions(position: OlaLatLng, isPickup: Boolean, snippetText: String?, isDestDot: Boolean = false): OlaMarkerOptions {
        val builder = OlaMarkerOptions.Builder()
        
        // Reflection dump on first call
        if (!isDestDot && isPickup) {
            val methods = builder::class.java.methods
            val methodNames = methods.joinToString(", ") { it.name }
            Log.d("OlaMap", "OlaMarkerOptions.Builder methods: $methodNames")
        }

        builder.setMarkerId(if (isPickup) "pickup_marker" else if (isDestDot) "destination_dot" else "destination_marker")
            .setPosition(position)

        if (isPickup) {
            val resId = getResId("ic_pickup_pin")
            if (resId != 0) {
                try {
                    val originalBitmap = android.graphics.BitmapFactory.decodeResource(context.resources, resId)
                    val width = 120
                    val height = (originalBitmap.height.toFloat() / originalBitmap.width.toFloat() * width).toInt()
                    val scaledBitmap = Bitmap.createScaledBitmap(originalBitmap, width, height, true)
                    builder.setIconBitmap(scaledBitmap)
                } catch (e: Exception) {
                    try { builder.setIconBitmap(createMarkerBitmap(true)) } catch (e: Exception) {}
                }
            } else {
                try { builder.setIconBitmap(createMarkerBitmap(true)) } catch (e: Exception) {}
            }
        } else if (isDestDot) {
            try {
                val bitmap = Bitmap.createBitmap(32, 40, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                canvas.drawColor(android.graphics.Color.RED)
                builder.setIconBitmap(bitmap)
            } catch (e: Exception) {}
        } else {
            // MapLibre is rendering the ic_dest_pin PNG as a black box due to an alpha/format issue.
            // We use the Canvas-drawn programmatic red flag instead!
            try {
                builder.setIconBitmap(createMarkerBitmap(false))
            } catch (e: Exception) {
                Log.e("OlaMap", "Error creating Canvas destination pin", e)
            }
        }
        
        if (!snippetText.isNullOrEmpty()) {
            builder.setSnippet(snippetText)
        }

        return builder.build()
    }

    private fun drawDestinationFlag(position: OlaLatLng) {
        val map = olaMap ?: return
        Log.d("OlaMap", "drawDestinationFlag: using OlaCircle SDK circle")

        // Remove previous destination visuals
        try { destMarker?.removeMarker() } catch (e: Exception) {}
        try { destDotMarker?.removeMarker() } catch (e: Exception) {}
        try { destInnerPolylines.forEach { it.removePolyline() } } catch (e: Exception) {}
        try { destFlagPolyline?.removePolyline() } catch (e: Exception) {}
        try {
            destNativeCircle?.let {
                it::class.java.methods.firstOrNull { m -> m.name == "removeCircle" }?.invoke(it)
            }
            destInnerCircle?.let {
                it::class.java.methods.firstOrNull { m -> m.name == "removeCircle" }?.invoke(it)
            }
        } catch (e: Exception) {}
        destMarker = null
        destDotMarker = null
        destInnerPolylines.clear()
        destFlagPolyline = null
        destNativeCircle = null
        destInnerCircle = null

        try {
            // Outer ring — red
            val outerOptions = OlaCircleOptions.Builder()
                .setOlaLatLng(position)
                .setRadius(10.0f)
                .setColorHexCode("#EA4335")
                .setCircleOpacity(1.0f)
                .build()
            destNativeCircle = map.addCircle(outerOptions)

            // Inner white dot — creates bullseye effect
            val innerOptions = OlaCircleOptions.Builder()
                .setOlaLatLng(position)
                .setRadius(5.0f)
                .setColorHexCode("#FFFFFF")
                .setCircleOpacity(1.0f)
                .build()
            destInnerCircle = map.addCircle(innerOptions)

            Log.d("OlaMap", "Destination bullseye circle added")
        } catch (e: Exception) {
            Log.e("OlaMap", "addCircle error: ${e.message}", e)
        }
    }

    private fun drawPickupTarget(position: OlaLatLng) {
        val map = olaMap ?: return
        try { pickupMarker?.removeMarker() } catch (_: Exception) {}
        try { pickupMarkerPolyline?.removePolyline() } catch (_: Exception) {}
        try { pickupMarkerAccent?.removePolyline() } catch (_: Exception) {}
        try {
            pickupNativeCircle?.let {
                it::class.java.methods.firstOrNull { m -> m.name == "removeCircle" }?.invoke(it)
            }
        } catch (e: Exception) {}
        pickupMarker = null
        pickupMarkerPolyline = null
        pickupMarkerAccent = null
        pickupNativeCircle = null

        val mapLibre = mapLibreMap
        if (mapLibre != null) {
            mlPickupMarkerPolyline?.let { mapLibre.removeAnnotation(it) }
            mlPickupMarkerAccent?.let { mapLibre.removeAnnotation(it) }
        }
        mlPickupMarkerPolyline = null
        mlPickupMarkerAccent = null
        
        try {
            // Outer ring — green
            val outerOptions = OlaCircleOptions.Builder()
                .setOlaLatLng(position)
                .setRadius(10.0f)
                .setColorHexCode("#22C55E")
                .setCircleOpacity(1.0f)
                .build()
            pickupNativeCircle = map.addCircle(outerOptions)

            // Inner white dot — creates bullseye effect
            val innerOptions = OlaCircleOptions.Builder()
                .setOlaLatLng(position)
                .setRadius(5.0f)
                .setColorHexCode("#FFFFFF")
                .setCircleOpacity(1.0f)
                .build()
            pickupInnerCircle = map.addCircle(innerOptions)
        } catch (e: Exception) {
            Log.e("OlaMap", "Native pickup circle error", e)
        }
    }

    private fun drawCaptainMarker(position: OlaLatLng) {
        val map = olaMap ?: return
        try { captainMarker?.removeMarker() } catch (_: Exception) {}
        try {
            captainNativeCircle?.removeCircle()
            captainInnerCircle?.removeCircle()
        } catch (_: Exception) {}
        captainMarker = null
        captainNativeCircle = null
        captainInnerCircle = null

        try {
            // Outer ring — green (identical to user app current-location bullseye)
            val outerOptions = OlaCircleOptions.Builder()
                .setOlaLatLng(position)
                .setRadius(10.0f)
                .setColorHexCode("#22C55E")
                .setCircleOpacity(1.0f)
                .build()
            captainNativeCircle = map.addCircle(outerOptions)

            // Inner white dot — bullseye center
            val innerOptions = OlaCircleOptions.Builder()
                .setOlaLatLng(position)
                .setRadius(5.0f)
                .setColorHexCode("#FFFFFF")
                .setCircleOpacity(1.0f)
                .build()
            captainInnerCircle = map.addCircle(innerOptions)
        } catch (e: Exception) {
            Log.e("OlaMap", "drawCaptainMarker bullseye error", e)
        }
    }

    private fun drawUserLiveMarker(position: OlaLatLng) {
        val map = olaMap ?: return
        try {
            userLiveNativeCircle?.removeCircle()
            userLiveInnerCircle?.removeCircle()
        } catch (_: Exception) {}
        userLiveNativeCircle = null
        userLiveInnerCircle = null

        // Only draw the green bullseye if the native SDK current location dot is hidden
        if (!showUserDot) {
            try {
                // Outer ring — green
                val outerOptions = OlaCircleOptions.Builder()
                    .setOlaLatLng(position)
                    .setRadius(10.0f)
                    .setColorHexCode("#22C55E")
                    .setCircleOpacity(1.0f)
                    .build()
                userLiveNativeCircle = map.addCircle(outerOptions)

                // Inner white dot
                val innerOptions = OlaCircleOptions.Builder()
                    .setOlaLatLng(position)
                    .setRadius(5.0f)
                    .setColorHexCode("#FFFFFF")
                    .setCircleOpacity(1.0f)
                    .build()
                userLiveInnerCircle = map.addCircle(innerOptions)
            } catch (e: Exception) {
                Log.e("OlaMap", "drawUserLiveMarker bullseye error", e)
            }
        }
    }

    private fun drawHeadingIndicator(position: OlaLatLng, heading: Double) {
        val map = olaMap ?: return
        try { headingPolyline?.removePolyline() } catch (_: Exception) {}
        try { headingPolylineCasing?.removePolyline() } catch (_: Exception) {}
        val mapLibre = mapLibreMap
        if (mapLibre != null) {
            mlHeadingPolylineCasing?.let { mapLibre.removeAnnotation(it) }
            mlHeadingPolyline?.let { mapLibre.removeAnnotation(it) }
        }
        headingPolyline = null
        headingPolylineCasing = null
        mlHeadingPolyline = null
        mlHeadingPolylineCasing = null
    }

    // ── Camera helpers ───────────────────────────────────────────────────────

    private fun moveCameraTo(lat: Double, lng: Double, zoom: Double, bearing: Double? = null, tilt: Double? = null) {
        try {
            val mapLibre = mapLibreMap
            if (mapLibre != null && (bearing != null || tilt != null)) {
                val pos = org.maplibre.android.camera.CameraPosition.Builder()
                    .target(LatLng(lat, lng))
                    .zoom(zoom)
                    .bearing(bearing ?: 0.0)
                    .tilt(tilt ?: 0.0)
                    .build()
                val update = org.maplibre.android.camera.CameraUpdateFactory.newCameraPosition(pos)
                mapLibre.animateCamera(update, 500)
            } else {
                olaMap?.moveCameraToLatLong(OlaLatLng(lat, lng, 0.0), zoom, 500)
            }
        } catch (e: Exception) {
            Log.e("OlaMap", "moveCameraTo error", e)
        }
    }

    // ── PlatformView ─────────────────────────────────────────────────────────

    override fun getView(): View = container

    override fun dispose() {
        stopOverlayLoop()
        removeDestinationOverlay()
        try {
            olaMapView?.onPause()
            olaMapView?.onStop()
            olaMapView?.onDestroy()
            container.removeAllViews()
        } catch (e: Exception) {
            Log.e("OlaMap", "dispose error", e)
        }
    }

    // ── MethodChannel handler ────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {

            "moveCamera" -> {
                val lat  = call.argument<Double>("lat")  ?: 0.0
                val lng  = call.argument<Double>("lng")  ?: 0.0
                val zoom = call.argument<Double>("zoom") ?: 16.0
                val bearing = call.argument<Double>("bearing")
                val tilt = call.argument<Double>("tilt")

                if (olaMap != null) {
                    moveCameraTo(lat, lng, zoom, bearing, tilt)
                } else {
                    pendingLat  = lat
                    pendingLng  = lng
                    pendingZoom = zoom
                    pendingBearing = bearing
                    pendingTilt = tilt
                }
                result.success(null)
            }

            "setPadding" -> {
                val top = call.argument<Double>("top") ?: 0.0
                val left = call.argument<Double>("left") ?: 0.0
                val bottom = call.argument<Double>("bottom") ?: 0.0
                val right = call.argument<Double>("right") ?: 0.0
                
                mapLibreMap?.let { map ->
                    val density = context.resources.displayMetrics.density
                    map.setPadding(
                        (left * density).toInt(),
                        (top * density).toInt(),
                        (right * density).toInt(),
                        (bottom * density).toInt()
                    )
                }
                result.success(null)
            }

            "fitBounds" -> {
                val lat1 = call.argument<Double>("lat1") ?: 0.0
                val lng1 = call.argument<Double>("lng1") ?: 0.0
                val lat2 = call.argument<Double>("lat2") ?: 0.0
                val lng2 = call.argument<Double>("lng2") ?: 0.0

                if (olaMap != null) {
                    try {
                        val points = listOf(
                            OlaLatLng(lat1, lng1, 0.0),
                            OlaLatLng(lat2, lng2, 0.0),
                            // Add virtual padding points so the route remains clear
                            // of the top controls and the draggable bottom sheet.
                            OlaLatLng(
                                minOf(lat1, lat2) - maxOf(kotlin.math.abs(lat1 - lat2) * 0.55, 0.0015),
                                (lng1 + lng2) / 2.0,
                                0.0
                            ),
                            OlaLatLng(
                                maxOf(lat1, lat2) + maxOf(kotlin.math.abs(lat1 - lat2) * 0.15, 0.0005),
                                (lng1 + lng2) / 2.0,
                                0.0
                            )
                        )
                        olaMap?.easeCamera(points, 800)
                    } catch (e: Exception) {
                        val midLat = (lat1 + lat2) / 2.0
                        val midLng = (lng1 + lng2) / 2.0
                        
                        val results = FloatArray(1)
                        android.location.Location.distanceBetween(lat1, lng1, lat2, lng2, results)
                        val distanceMeters = results[0]
                        
                        // Roughly calculate zoom based on distance
                        // Map width is usually a few kilometers at zoom 14.
                        // Add some padding by subtracting zoom.
                        val zoom = when {
                            distanceMeters < 1000 -> 15.0
                            distanceMeters < 3000 -> 14.0
                            distanceMeters < 7000 -> 13.0
                            distanceMeters < 15000 -> 12.0
                            distanceMeters < 30000 -> 11.0
                            distanceMeters < 60000 -> 10.0
                            else -> 9.0
                        }
                        
                        // Because the bottom sheet covers the bottom 40% of the screen,
                        // shift the center slightly SOUTH to push the markers UP on the screen.
                        val latOffset = (lat1 - lat2).let { kotlin.math.abs(it) } * 0.2
                        moveCameraTo(midLat - latOffset, midLng, zoom)
                    }
                } else {
                    val midLat = (lat1 + lat2) / 2.0
                    val midLng = (lng1 + lng2) / 2.0
                    pendingLat = midLat
                    pendingLng = midLng
                    pendingZoom = 14.0
                }
                result.success(null)
            }

            "toggleNativeUserLocation" -> {
                val show = call.argument<Boolean>("show") ?: false
                showUserDot = show
                if (show) {
                    try {
                        olaMap?.showCurrentLocation()
                        // Remove the green live bullseye since native blue dot is back
                        userLiveNativeCircle?.removeCircle()
                        userLiveInnerCircle?.removeCircle()
                        userLiveNativeCircle = null
                        userLiveInnerCircle = null

                        // Also remove the static pickup green marker to avoid duplicate green dots
                        pickupNativeCircle?.removeCircle()
                        pickupInnerCircle?.removeCircle()
                        pickupNativeCircle = null
                        pickupInnerCircle = null
                    } catch (e: Exception) {
                        Log.e("OlaMap", "showCurrentLocation error", e)
                    }
                } else {
                    try {
                        olaMap?.hideCurrentLocation()
                    } catch (e: Exception) {
                        Log.e("OlaMap", "hideCurrentLocation error", e)
                    }
                }
                result.success(null)
            }

            "updateUserLocation" -> {
                val lat = call.argument<Double>("lat")
                val lng = call.argument<Double>("lng")
                val heading = call.argument<Double>("heading")
                if (lat != null && lng != null) {
                    val pos = OlaLatLng(lat, lng, 0.0)
                    drawUserLiveMarker(pos)
                    if (heading != null) {
                        drawHeadingIndicator(pos, heading)
                    }
                }
                result.success(null)
            }

            "callPhone" -> {
                val phone = call.argument<String>("phone")?.trim().orEmpty()
                if (phone.isEmpty()) {
                    result.success(false)
                } else {
                    try {
                        val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone")).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("OlaMap", "callPhone error", e)
                        result.success(false)
                    }
                }
            }

            "addMarker" -> {
                val lat = call.argument<Double>("lat") ?: 0.0
                val lng = call.argument<Double>("lng") ?: 0.0
                val title = call.argument<String>("title")
                val isPickup = call.argument<Boolean>("isPickup") ?: false
                val isCaptain = call.argument<Boolean>("isCaptain") ?: false

                Log.d("OlaMap", "Native addMarker CALLED: lat=$lat, lng=$lng, isPickup=$isPickup, isCaptain=$isCaptain, mapReady=${olaMap != null}")

                try {
                    val pos = OlaLatLng(lat, lng, 0.0)
                    if (isCaptain) {
                        if (olaMap != null) {
                            drawCaptainMarker(pos)
                        } else {
                            // ignore if map not ready
                        }
                    } else if (!isPickup) {
                        if (olaMap != null) {
                            drawDestinationFlag(pos)
                        } else {
                            pendingDestPosition = pos
                        }
                    } else {
                        if (olaMap != null) {
                            drawPickupTarget(pos)
                        } else {
                            pendingPickupPosition = pos
                        }
                    }

                    result.success(true)
                } catch (e: Exception) {
                    Log.e("OlaMap", "addMarker error", e)
                    result.success(false)
                }
            }

            "drawPolyline" -> {
                val polylineStr = call.argument<String>("polyline") ?: ""
                val pointsList = call.argument<List<Map<String, Any>>>("points")

                val latLngs = ArrayList<OlaLatLng>()

                if (pointsList != null && pointsList.isNotEmpty()) {
                    for (item in pointsList) {
                        val lat = (item["lat"] as? Number)?.toDouble() ?: 0.0
                        val lng = (item["lng"] as? Number)?.toDouble() ?: 0.0
                        latLngs.add(OlaLatLng(lat, lng, 0.0))
                    }
                } else if (polylineStr.isNotEmpty()) {
                    try {
                        val decoded = PolylineDecoder.decode(polylineStr, 5)
                        if (decoded != null) {
                            for (pt in decoded) {
                                latLngs.add(OlaLatLng(pt.latitude, pt.longitude, 0.0))
                            }
                        }
                    } catch (e: Exception) {
                        try {
                            val decoded6 = PolylineDecoder.decode(polylineStr, 6)
                            if (decoded6 != null) {
                                for (pt in decoded6) {
                                    latLngs.add(OlaLatLng(pt.latitude, pt.longitude, 0.0))
                                }
                            }
                        } catch (e2: Exception) {
                            // ignore
                        }
                    }
                }

                    if (latLngs.isNotEmpty() && olaMap != null) {
                        try {
                            activePolyline?.removePolyline()
                            activePolylineCasing?.removePolyline()
                        } catch (e: Exception) {}

                        val mapLibre = mapLibreMap
                        if (mapLibre != null) {
                            mlActivePolylineCasing?.let { mapLibre.removeAnnotation(it) }
                            mlActivePolyline?.let { mapLibre.removeAnnotation(it) }
                            
                            val pts = latLngs.map { LatLng(it.latitude, it.longitude) }
                            val colorStr = call.argument<String>("color") ?: "#2563EB"
                            
                            val casingOptions = PolylineOptions()
                                .addAll(pts)
                                .color(Color.parseColor("#1D4ED8"))
                                .width(9f)
                                
                            val polyOptions = PolylineOptions()
                                .addAll(pts)
                                .color(Color.parseColor(colorStr))
                                .width(5f)
                                
                            mlActivePolylineCasing = mapLibre.addPolyline(casingOptions)
                            mlActivePolyline = mapLibre.addPolyline(polyOptions)
                        }
                    }
                result.success(null)
            }

            "clearRoute" -> {
                try {
                    pickupMarker?.removeMarker()
                    destMarker?.removeMarker()
                    captainMarker?.removeMarker()
                    destInnerPolylines.forEach { it.removePolyline() }
                    destFlagPolyline?.removePolyline()
                    
                    val mapLibre = mapLibreMap
                    if (mapLibre != null) {
                        mlPickupMarkerPolyline?.let { mapLibre.removeAnnotation(it) }
                        mlPickupMarkerAccent?.let { mapLibre.removeAnnotation(it) }
                        mlActivePolylineCasing?.let { mapLibre.removeAnnotation(it) }
                        mlActivePolyline?.let { mapLibre.removeAnnotation(it) }
                        
                        destNativeCircle?.removeCircle()
                        destInnerCircle?.removeCircle()
                        pickupNativeCircle?.removeCircle()
                        pickupInnerCircle?.removeCircle()
                        captainNativeCircle?.removeCircle()
                        captainInnerCircle?.removeCircle()
                        userLiveNativeCircle?.removeCircle()
                        userLiveInnerCircle?.removeCircle()
                    }
                } catch (e: Exception) {
                    // ignore
                }
                pickupMarker = null
                destMarker = null
                captainMarker = null
                pickupMarkerPolyline = null
                pickupMarkerAccent = null
                destInnerPolylines.clear()
                destFlagPolyline = null
                destNativeCircle = null
                destInnerCircle = null
                pickupNativeCircle = null
                pickupInnerCircle = null
                captainNativeCircle = null
                captainInnerCircle = null
                activePolyline = null
                activePolylineCasing = null
                result.success(null)
            }

            "getMethods" -> {
                try {
                    val mapClass = olaMap!!::class.java
                    val sb = StringBuilder()
                    sb.append("OlaMap Methods:\n")
                    mapClass.methods.forEach { sb.append("${it.name}(${it.parameterTypes.joinToString { p -> p.simpleName }}) -> ${it.returnType.simpleName}\n") }
                    sb.append("OlaMarkerOptions.Builder Methods:\n")
                    val builderClass = OlaMarkerOptions.Builder::class.java
                    builderClass.methods.forEach { sb.append("${it.name}(${it.parameterTypes.joinToString { p -> p.simpleName }}) -> ${it.returnType.simpleName}\n") }
                    result.success(sb.toString())
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            }

            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
