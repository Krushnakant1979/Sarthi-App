package com.example.rapido_app

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.util.Log
import android.net.Uri
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import com.ola.mapsdk.view.OlaMapView
import com.ola.mapsdk.view.OlaMap
import com.ola.mapsdk.view.Marker
import com.ola.mapsdk.view.Polyline
import com.ola.mapsdk.interfaces.OlaMapCallback
import com.ola.mapsdk.model.OlaLatLng
import com.ola.mapsdk.model.OlaMarkerOptions
import com.ola.mapsdk.model.OlaPolylineOptions
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

    private val container: FrameLayout = FrameLayout(context)
    private var olaMapView: OlaMapView? = null
    private var olaMap: OlaMap? = null

    private var pickupMarker: Marker? = null
    private var destMarker: Marker? = null
    private var captainMarker: Marker? = null
    
    private var pickupMarkerPolyline: Polyline? = null
    private var pickupMarkerAccent: Polyline? = null
    private var destMarkerPolyline: Polyline? = null
    private var destFlagPolyline: Polyline? = null
    private var activePolyline: Polyline? = null
    private var activePolylineCasing: Polyline? = null
    private var headingPolyline: Polyline? = null
    private var headingPolylineCasing: Polyline? = null

    private val methodChannel = MethodChannel(messenger, "sarthi/ola_map_$id")
    private val eventChannel = EventChannel(messenger, "sarthi/ola_map_events_$id")
    private var eventSink: EventChannel.EventSink? = null

    // Queue a camera move to apply as soon as the map is ready
    private var pendingLat: Double? = null
    private var pendingLng: Double? = null
    private var pendingZoom: Double = 16.0

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

                // Safely attempt to enable user current location blue dot
                try {
                    map.showCurrentLocation()
                } catch (e: Exception) {
                    Log.e("OlaMap", "showCurrentLocation error", e)
                }

                // Apply any camera move that was requested before the map was ready
                val lat = pendingLat
                val lng = pendingLng
                if (lat != null && lng != null) {
                    moveCameraTo(lat, lng, pendingZoom)
                    pendingLat = null
                    pendingLng = null
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

                // Notify Flutter that the map is ready
                eventSink?.success(mapOf("event" to "mapReady"))
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
            val width = 72
            val height = 90
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)

            val redColor = Color.parseColor("#EA4335")
            val poleColor = Color.parseColor("#374151")

            // Pole
            paint.color = poleColor
            paint.style = Paint.Style.FILL
            canvas.drawRect(width / 2f - 3f, 10f, width / 2f + 3f, height.toFloat() - 5f, paint)

            // Flag
            val path = Path()
            path.moveTo(width / 2f + 3f, 10f)
            path.lineTo(width.toFloat() - 5f, 28f)
            path.lineTo(width / 2f + 3f, 46f)
            path.close()
            paint.color = redColor
            canvas.drawPath(path, paint)

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

    // ── Helper to build OlaMarkerOptions ─────────────────────────────────────

    private fun buildMarkerOptions(position: OlaLatLng, isPickup: Boolean, snippetText: String?): OlaMarkerOptions {
        val builder = OlaMarkerOptions.Builder()
            .setMarkerId(if (isPickup) "pickup_marker" else "destination_marker")
            .setPosition(position)

        if (isPickup) {
            val resId = getResId("ic_pickup_pin")
            if (resId != 0) {
                try {
                    val bitmap = android.graphics.BitmapFactory.decodeResource(context.resources, resId)
                    builder.setIconBitmap(bitmap)
                } catch (e: Exception) {
                    try { builder.setIconBitmap(createMarkerBitmap(true)) } catch (e: Exception) {}
                }
            } else {
                try { builder.setIconBitmap(createMarkerBitmap(true)) } catch (e: Exception) {}
            }
        } else {
            val resId = getResId("ic_dest_pin")
            if (resId != 0) {
                try {
                    val bitmap = android.graphics.BitmapFactory.decodeResource(context.resources, resId)
                    builder.setIconBitmap(bitmap)
                } catch (e: Exception) {
                    try { builder.setIconBitmap(createMarkerBitmap(false)) } catch (e: Exception) {}
                }
            } else {
                try { builder.setIconBitmap(createMarkerBitmap(false)) } catch (e: Exception) {}
            }
        }
        
        if (!snippetText.isNullOrEmpty()) {
            builder.setSnippet(snippetText)
        }

        return builder.build()
    }

    /**
     * Draws the destination as map geometry instead of an SDK marker. Ola/MapLibre
     * polylines are not suppressed by symbol collision detection, so the flag stays
     * visible even when the destination overlaps a base-map POI label.
     */
    private fun drawDestinationFlag(position: OlaLatLng) {
        val map = olaMap ?: return

        try { destMarker?.removeMarker() } catch (_: Exception) {}
        try { destMarkerPolyline?.removePolyline() } catch (_: Exception) {}
        try { destFlagPolyline?.removePolyline() } catch (_: Exception) {}
        destMarker = null

        // Rough metre-to-coordinate conversion, sufficient for this small map icon.
        val metresPerDegreeLatitude = 111_320.0
        val metresPerDegreeLongitude =
            metresPerDegreeLatitude * cos(Math.toRadians(position.latitude)).coerceAtLeast(0.01)
        // Keep the whole silhouette red and intentionally oversized so it reads
        // like the 🚩 emoji against roads and POI labels at the route overview zoom.
        val poleHeight = 34.0
        val flagWidth = 22.0
        val flagDrop = 13.0

        val poleTop = OlaLatLng(
            position.latitude + poleHeight / metresPerDegreeLatitude,
            position.longitude,
            0.0
        )
        val flagTip = OlaLatLng(
            poleTop.latitude - flagDrop / (2.0 * metresPerDegreeLatitude),
            poleTop.longitude + flagWidth / metresPerDegreeLongitude,
            0.0
        )
        val flagBottom = OlaLatLng(
            poleTop.latitude - flagDrop / metresPerDegreeLatitude,
            poleTop.longitude,
            0.0
        )

        try {
            val poleOptions = OlaPolylineOptions.Builder().build().apply {
                points = arrayListOf(position, poleTop)
                color = "#EA4335"
                width = 10f
            }
            destMarkerPolyline = map.addPolyline(poleOptions)

            val flagOptions = OlaPolylineOptions.Builder().build().apply {
                points = arrayListOf(poleTop, flagTip, flagBottom, poleTop)
                color = "#EA4335"
                width = 14f
            }
            destFlagPolyline = map.addPolyline(flagOptions)
            
            // Also add the actual SDK marker pin for better visibility
            val markerOptions = buildMarkerOptions(position, false, "Destination")
            destMarker = map.addMarker(markerOptions)
        } catch (e: Exception) {
            Log.e("OlaMap", "drawDestinationFlag error", e)
        }
    }

    private fun drawPickupTarget(position: OlaLatLng) {
        val map = olaMap ?: return
        try { pickupMarker?.removeMarker() } catch (_: Exception) {}
        try { pickupMarkerPolyline?.removePolyline() } catch (_: Exception) {}
        try { pickupMarkerAccent?.removePolyline() } catch (_: Exception) {}
        pickupMarker = null

        val metresPerDegreeLatitude = 111_320.0
        val metresPerDegreeLongitude =
            metresPerDegreeLatitude * cos(Math.toRadians(position.latitude)).coerceAtLeast(0.01)
        
        val poleHeight = 34.0
        val flagWidth = -22.0 // Make flag point left to differentiate from red destination flag
        val flagDrop = 13.0

        val poleTop = OlaLatLng(
            position.latitude + poleHeight / metresPerDegreeLatitude,
            position.longitude,
            0.0
        )
        val flagTip = OlaLatLng(
            poleTop.latitude - flagDrop / (2.0 * metresPerDegreeLatitude),
            poleTop.longitude + flagWidth / metresPerDegreeLongitude,
            0.0
        )
        val flagBottom = OlaLatLng(
            poleTop.latitude - flagDrop / metresPerDegreeLatitude,
            poleTop.longitude,
            0.0
        )

        val poleOptions = OlaPolylineOptions.Builder().build().apply {
            points = arrayListOf(position, poleTop)
            color = "#374151" // Dark pole
            width = 10f
        }

        val flagOptions = OlaPolylineOptions.Builder().build().apply {
            points = arrayListOf(poleTop, flagTip, flagBottom, poleTop)
            color = "#10B981" // Emerald Green flag
            width = 14f
        }

        try {
            pickupMarkerPolyline = map.addPolyline(poleOptions)
            pickupMarkerAccent = map.addPolyline(flagOptions)
            
            // Also add the actual SDK marker pin in case it's not occluded
            val markerOptions = buildMarkerOptions(position, true, "User Pickup")
            pickupMarker = map.addMarker(markerOptions)
        } catch (e: Exception) {
            Log.e("OlaMap", "drawPickupTarget marker error", e)
        }
    }

    private fun drawCaptainMarker(position: OlaLatLng) {
        val map = olaMap ?: return
        try { captainMarker?.removeMarker() } catch (_: Exception) {}
        
        try {
            val markerOptions = OlaMarkerOptions.Builder()
                .setMarkerId("captain_marker")
                .setPosition(position)
                .setIconBitmap(createMarkerBitmap(true)) // Use existing logic for bitmap
                .build()
            captainMarker = map.addMarker(markerOptions)
        } catch (e: Exception) {
            Log.e("OlaMap", "drawCaptainMarker error", e)
        }
    }

    private fun drawHeadingIndicator(position: OlaLatLng, heading: Double) {
        val map = olaMap ?: return
        try { headingPolyline?.removePolyline() } catch (_: Exception) {}
        try { headingPolylineCasing?.removePolyline() } catch (_: Exception) {}

        val metresPerDegreeLatitude = 111_320.0
        val metresPerDegreeLongitude =
            metresPerDegreeLatitude * cos(Math.toRadians(position.latitude)).coerceAtLeast(0.01)
        fun offset(distance: Double, bearing: Double): OlaLatLng {
            val radians = Math.toRadians(bearing)
            return OlaLatLng(
                position.latitude + cos(radians) * distance / metresPerDegreeLatitude,
                position.longitude + sin(radians) * distance / metresPerDegreeLongitude,
                0.0
            )
        }

        val tip = offset(18.0, heading)
        val left = offset(11.0, heading + 145.0)
        val right = offset(11.0, heading - 145.0)
        val chevron = arrayListOf(left, tip, right)
        try {
            val casing = OlaPolylineOptions.Builder().build().apply {
                points = chevron
                color = "#FFFFFF"
                width = 14f
            }
            headingPolylineCasing = map.addPolyline(casing)
            val arrow = OlaPolylineOptions.Builder().build().apply {
                points = chevron
                color = "#2563EB"
                width = 8f
            }
            headingPolyline = map.addPolyline(arrow)
        } catch (e: Exception) {
            Log.e("OlaMap", "drawHeadingIndicator error", e)
        }
    }

    // ── Camera helpers ───────────────────────────────────────────────────────

    private fun moveCameraTo(lat: Double, lng: Double, zoom: Double) {
        try {
            olaMap?.moveCameraToLatLong(OlaLatLng(lat, lng, 0.0), zoom, 500)
        } catch (e: Exception) {
            Log.e("OlaMap", "moveCameraTo error", e)
        }
    }

    // ── PlatformView ─────────────────────────────────────────────────────────

    override fun getView(): View = container

    override fun dispose() {
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

                if (olaMap != null) {
                    moveCameraTo(lat, lng, zoom)
                } else {
                    pendingLat  = lat
                    pendingLng  = lng
                    pendingZoom = zoom
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
                        moveCameraTo(midLat, midLng, 14.0)
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

            "updateUserLocation" -> {
                val lat = call.argument<Double>("lat")
                val lng = call.argument<Double>("lng")
                val heading = call.argument<Double>("heading")
                if (lat != null && lng != null && heading != null) {
                    drawHeadingIndicator(OlaLatLng(lat, lng, 0.0), heading)
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

                        try {
                            val polyOptions = OlaPolylineOptions.Builder().build()
                            polyOptions.points = latLngs
                            val colorStr = call.argument<String>("color") ?: "#2563EB"
                            polyOptions.color = colorStr
                            polyOptions.width = 7f
                            
                            val casingOptions = OlaPolylineOptions.Builder().build()
                            casingOptions.points = latLngs
                            casingOptions.color = "#1D4ED8"
                            casingOptions.width = 13f
                            activePolylineCasing = olaMap?.addPolyline(casingOptions)
                            activePolyline = olaMap?.addPolyline(polyOptions)
                        } catch (e: Exception) {
                            Log.e("OlaMap", "drawPolyline error", e)
                        }
                    }
                result.success(null)
            }

            "clearRoute" -> {
                try {
                    pickupMarker?.removeMarker()
                    destMarker?.removeMarker()
                    captainMarker?.removeMarker()
                    pickupMarkerPolyline?.removePolyline()
                    pickupMarkerAccent?.removePolyline()
                    destMarkerPolyline?.removePolyline()
                    destFlagPolyline?.removePolyline()
                    activePolyline?.removePolyline()
                    activePolylineCasing?.removePolyline()
                } catch (e: Exception) {
                    // ignore
                }
                pickupMarker = null
                destMarker = null
                captainMarker = null
                pickupMarkerPolyline = null
                pickupMarkerAccent = null
                destMarkerPolyline = null
                destFlagPolyline = null
                activePolyline = null
                activePolylineCasing = null
                result.success(null)
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
