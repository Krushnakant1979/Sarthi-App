package com.example.rapido_app

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import com.ola.mapsdk.interfaces.OlaMapCallback
import com.ola.mapsdk.model.OlaCircleOptions
import com.ola.mapsdk.model.OlaLatLng
import com.ola.mapsdk.utils.PolylineDecoder
import com.ola.mapsdk.view.Circle
import com.ola.mapsdk.view.Marker
import com.ola.mapsdk.view.OlaMap
import com.ola.mapsdk.view.OlaMapView
import com.ola.mapsdk.view.Polyline
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import org.maplibre.android.annotations.PolylineOptions
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView

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

    private var destNativeCircle: Circle? = null    // OlaMap Circle — outer ring
    private var destInnerCircle: Circle? = null     // OlaMap Circle — white inner dot
    private var pickupNativeCircle: Circle? = null  // OlaMap Circle — outer ring
    private var pickupInnerCircle: Circle? = null   // OlaMap Circle — white inner dot
    private var captainNativeCircle: Circle? = null // OlaMap Circle — captain outer ring
    private var captainInnerCircle: Circle? = null  // OlaMap Circle — captain white inner dot
    private var userLiveNativeCircle: Circle? = null // OlaMap Circle — live user outer ring
    private var userLiveInnerCircle: Circle? = null  // OlaMap Circle — live user inner dot

    private var mapLibreMap: MapLibreMap? = null
    private var mlActivePolylineCasing: org.maplibre.android.annotations.Polyline? = null
    private var mlActivePolyline: org.maplibre.android.annotations.Polyline? = null

    private val methodChannel = MethodChannel(messenger, "sarthi/ola_map_$id")
    private val eventChannel = EventChannel(messenger, "sarthi/ola_map_events_$id")
    private var eventSink: EventChannel.EventSink? = null

    // Queued operations if map is not ready
    private var pendingLat: Double? = null
    private var pendingLng: Double? = null
    private var pendingZoom: Double = 16.0
    private var pendingBearing: Double? = null
    private var pendingTilt: Double? = null

    private var pendingPickupPosition: OlaLatLng? = null
    private var pendingDestPosition: OlaLatLng? = null
    private var pendingCaptainPosition: OlaLatLng? = null
    private var pendingPolylinePoints: List<OlaLatLng>? = null
    private var pendingPolylineColor: String? = null
    private var pendingPadding: IntArray? = null

    private var padLeft: Int = 0
    private var padTop: Int = 0
    private var padRight: Int = 0
    private var padBottom: Int = 0
    private var isMapReadyNotified: Boolean = false

    private fun getFocalPointLatLng(): LatLng? {
        val mapLibre = mapLibreMap ?: return null
        val view = olaMapView ?: container
        val dm = context.resources.displayMetrics
        val w = if (view.width > 0) view.width else dm.widthPixels
        val h = if (view.height > 0) view.height else dm.heightPixels

        if (w > 0 && h > 0) {
            val focalX = padLeft + (w - padLeft - padRight) / 2f
            val focalY = padTop + (h - padTop - padBottom) / 2f
            try {
                val pt = mapLibre.projection.fromScreenLocation(android.graphics.PointF(focalX, focalY))
                if (pt != null) {
                    return pt
                }
            } catch (e: Exception) {
                Log.e("OlaMap", "fromScreenLocation error", e)
            }
        }
        return mapLibre.cameraPosition.target
    }

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

        // Ensure MapLibre OpenGL lifecycle events trigger when attached to window (essential for physical devices)
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

        fun notifyReady() {
            if (!isMapReadyNotified) {
                isMapReadyNotified = true
                eventSink?.success(mapOf("event" to "mapReady"))
            }
        }

        olaMapView?.getMap(apiKey, object : OlaMapCallback {
            override fun onMapReady(map: OlaMap) {
                olaMap = map

                try {
                    olaMapView?.let { mapView ->
                        val field = mapView.javaClass.getDeclaredField("mapLibreMapView")
                        field.isAccessible = true
                        val mlMapView = field.get(mapView) as? MapView
                        if (mlMapView != null) {
                            mlMapView.getMapAsync { mapLibre ->
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

                                // Apply pending padding if set
                                pendingPadding?.let { p ->
                                    padLeft = p[0]
                                    padTop = p[1]
                                    padRight = p[2]
                                    padBottom = p[3]
                                    mapLibre.setPadding(p[0], p[1], p[2], p[3])
                                    pendingPadding = null
                                }

                                // Apply pending camera move
                                val lat = pendingLat
                                val lng = pendingLng
                                if (lat != null && lng != null) {
                                    moveCameraTo(lat, lng, pendingZoom, pendingBearing, pendingTilt)
                                    pendingLat = null
                                    pendingLng = null
                                    pendingBearing = null
                                    pendingTilt = null
                                }

                                // Apply pending polyline if queued
                                pendingPolylinePoints?.let { pts ->
                                    drawPolylineOnMap(pts, pendingPolylineColor ?: "#2563EB")
                                    pendingPolylinePoints = null
                                    pendingPolylineColor = null
                                }

                                mapLibre.addOnCameraMoveListener {
                                    val target = getFocalPointLatLng()
                                    if (target != null) {
                                        eventSink?.success(mapOf("event" to "cameraMove", "lat" to target.latitude, "lng" to target.longitude))
                                    }
                                }
                                mapLibre.addOnCameraIdleListener {
                                    val target = getFocalPointLatLng()
                                    if (target != null) {
                                        eventSink?.success(mapOf("event" to "cameraIdle", "lat" to target.latitude, "lng" to target.longitude))
                                    }
                                }
                                Log.d("OlaMap", "MapLibreMap acquired successfully!")
                                notifyReady()
                            }
                        } else {
                            notifyReady()
                        }
                    }
                } catch (e: Exception) {
                    Log.e("OlaMap", "Reflection error getting MapLibreMap", e)
                    notifyReady()
                }

                // Show native GPS dot if requested
                if (showUserDot) {
                    try {
                        map.showCurrentLocation()
                    } catch (e: Exception) {
                        Log.e("OlaMap", "showCurrentLocation error", e)
                    }
                }

                // Apply queued camera move if not already applied
                val lat = pendingLat
                val lng = pendingLng
                if (lat != null && lng != null) {
                    moveCameraTo(lat, lng, pendingZoom, pendingBearing, pendingTilt)
                    pendingLat = null
                    pendingLng = null
                    pendingBearing = null
                    pendingTilt = null
                }

                // Apply queued markers
                pendingPickupPosition?.let {
                    drawPickupTarget(it)
                    pendingPickupPosition = null
                }
                pendingDestPosition?.let {
                    drawDestinationFlag(it)
                    pendingDestPosition = null
                }
                pendingCaptainPosition?.let {
                    drawCaptainMarker(it)
                    pendingCaptainPosition = null
                }

                // Ensure notifyReady is triggered if getMapAsync was delayed
                container.postDelayed({ notifyReady() }, 600)
            }

            override fun onMapError(error: String) {
                Log.e("OlaMap", "onMapError: $error")
                eventSink?.error("MAP_ERROR", error, null)
            }
        })

        // Initial resume in case container is already attached
        try {
            olaMapView?.onStart()
            olaMapView?.onResume()
        } catch (e: Exception) {
            Log.e("OlaMap", "lifecycle error", e)
        }
    }

    // ── Visual Drawing Helpers ───────────────────────────────────────────────

    private fun safeRemoveCircle(circle: Circle?) {
        if (circle == null) return
        try {
            circle.removeCircle()
        } catch (_: Exception) {
            try {
                circle::class.java.methods.firstOrNull { it.name == "removeCircle" }?.invoke(circle)
            } catch (_: Exception) {}
        }
    }

    private fun drawDestinationFlag(position: OlaLatLng) {
        val map = olaMap ?: return

        try { destMarker?.removeMarker() } catch (_: Exception) {}
        destMarker = null
        safeRemoveCircle(destNativeCircle)
        safeRemoveCircle(destInnerCircle)
        destNativeCircle = null
        destInnerCircle = null

        try {
            val outerOptions = OlaCircleOptions.Builder()
                .setOlaLatLng(position)
                .setRadius(10.0f)
                .setColorHexCode("#EA4335")
                .setCircleOpacity(1.0f)
                .build()
            destNativeCircle = map.addCircle(outerOptions)

            val innerOptions = OlaCircleOptions.Builder()
                .setOlaLatLng(position)
                .setRadius(5.0f)
                .setColorHexCode("#FFFFFF")
                .setCircleOpacity(1.0f)
                .build()
            destInnerCircle = map.addCircle(innerOptions)
        } catch (e: Exception) {
            Log.e("OlaMap", "drawDestinationFlag error", e)
        }
    }

    private fun drawPickupTarget(position: OlaLatLng) {
        val map = olaMap ?: return

        try { pickupMarker?.removeMarker() } catch (_: Exception) {}
        pickupMarker = null
        safeRemoveCircle(pickupNativeCircle)
        safeRemoveCircle(pickupInnerCircle)
        pickupNativeCircle = null
        pickupInnerCircle = null

        try {
            val outerOptions = OlaCircleOptions.Builder()
                .setOlaLatLng(position)
                .setRadius(10.0f)
                .setColorHexCode("#0B2545")
                .setCircleOpacity(1.0f)
                .build()
            pickupNativeCircle = map.addCircle(outerOptions)

            val innerOptions = OlaCircleOptions.Builder()
                .setOlaLatLng(position)
                .setRadius(5.0f)
                .setColorHexCode("#FFFFFF")
                .setCircleOpacity(1.0f)
                .build()
            pickupInnerCircle = map.addCircle(innerOptions)
        } catch (e: Exception) {
            Log.e("OlaMap", "drawPickupTarget error", e)
        }
    }

    private fun drawCaptainMarker(position: OlaLatLng) {
        val map = olaMap ?: return

        try { captainMarker?.removeMarker() } catch (_: Exception) {}
        captainMarker = null
        safeRemoveCircle(captainNativeCircle)
        safeRemoveCircle(captainInnerCircle)
        captainNativeCircle = null
        captainInnerCircle = null

        try {
            val outerOptions = OlaCircleOptions.Builder()
                .setOlaLatLng(position)
                .setRadius(10.0f)
                .setColorHexCode("#22C55E")
                .setCircleOpacity(1.0f)
                .build()
            captainNativeCircle = map.addCircle(outerOptions)

            val innerOptions = OlaCircleOptions.Builder()
                .setOlaLatLng(position)
                .setRadius(5.0f)
                .setColorHexCode("#FFFFFF")
                .setCircleOpacity(1.0f)
                .build()
            captainInnerCircle = map.addCircle(innerOptions)
        } catch (e: Exception) {
            Log.e("OlaMap", "drawCaptainMarker error", e)
        }
    }

    private fun drawUserLiveMarker(position: OlaLatLng) {
        val map = olaMap ?: return

        safeRemoveCircle(userLiveNativeCircle)
        safeRemoveCircle(userLiveInnerCircle)
        userLiveNativeCircle = null
        userLiveInnerCircle = null

        if (!showUserDot) {
            try {
                val outerOptions = OlaCircleOptions.Builder()
                    .setOlaLatLng(position)
                    .setRadius(10.0f)
                    .setColorHexCode("#22C55E")
                    .setCircleOpacity(1.0f)
                    .build()
                userLiveNativeCircle = map.addCircle(outerOptions)

                val innerOptions = OlaCircleOptions.Builder()
                    .setOlaLatLng(position)
                    .setRadius(5.0f)
                    .setColorHexCode("#FFFFFF")
                    .setCircleOpacity(1.0f)
                    .build()
                userLiveInnerCircle = map.addCircle(innerOptions)
            } catch (e: Exception) {
                Log.e("OlaMap", "drawUserLiveMarker error", e)
            }
        }
    }

    private fun drawPolylineOnMap(latLngs: List<OlaLatLng>, colorStr: String) {
        val mapLibre = mapLibreMap ?: return

        try {
            mlActivePolylineCasing?.let { mapLibre.removeAnnotation(it) }
            mlActivePolyline?.let { mapLibre.removeAnnotation(it) }
        } catch (_: Exception) {}

        try {
            val pts = latLngs.map { LatLng(it.latitude, it.longitude) }
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
        } catch (e: Exception) {
            Log.e("OlaMap", "drawPolylineOnMap error", e)
        }
    }

    // ── Camera helpers ───────────────────────────────────────────────────────

    private fun moveCameraTo(lat: Double, lng: Double, zoom: Double, bearing: Double? = null, tilt: Double? = null) {
        try {
            val mapLibre = mapLibreMap
            if (mapLibre != null) {
                if (bearing != null || tilt != null) {
                    val pos = org.maplibre.android.camera.CameraPosition.Builder()
                        .target(LatLng(lat, lng))
                        .zoom(zoom)
                        .bearing(bearing ?: 0.0)
                        .tilt(tilt ?: 0.0)
                        .build()
                    val update = org.maplibre.android.camera.CameraUpdateFactory.newCameraPosition(pos)
                    mapLibre.animateCamera(update, 500)
                } else {
                    val update = org.maplibre.android.camera.CameraUpdateFactory.newLatLngZoom(LatLng(lat, lng), zoom)
                    mapLibre.animateCamera(update, 500)
                }
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
                val density = context.resources.displayMetrics.density

                padLeft = (left * density).toInt()
                padTop = (top * density).toInt()
                padRight = (right * density).toInt()
                padBottom = (bottom * density).toInt()

                val map = mapLibreMap
                if (map != null) {
                    map.setPadding(padLeft, padTop, padRight, padBottom)
                } else {
                    pendingPadding = intArrayOf(padLeft, padTop, padRight, padBottom)
                }
                result.success(null)
            }

            "getCenterCoordinates" -> {
                val pt = getFocalPointLatLng()
                if (pt != null) {
                    result.success(mapOf("lat" to pt.latitude, "lng" to pt.longitude))
                } else {
                    val target = mapLibreMap?.cameraPosition?.target
                    if (target != null) {
                        result.success(mapOf("lat" to target.latitude, "lng" to target.longitude))
                    } else {
                        result.error("UNAVAILABLE", "Coordinates unavailable", null)
                    }
                }
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

                        val zoom = when {
                            distanceMeters < 1000 -> 15.0
                            distanceMeters < 3000 -> 14.0
                            distanceMeters < 7000 -> 13.0
                            distanceMeters < 15000 -> 12.0
                            distanceMeters < 3000 -> 11.0
                            distanceMeters < 60000 -> 10.0
                            else -> 9.0
                        }

                        val latOffset = (lat1 - lat2).let { kotlin.math.abs(it) } * 0.2
                        moveCameraTo(midLat - latOffset, midLng, zoom)
                    }
                } else {
                    pendingLat = (lat1 + lat2) / 2.0
                    pendingLng = (lng1 + lng2) / 2.0
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
                        safeRemoveCircle(userLiveNativeCircle)
                        safeRemoveCircle(userLiveInnerCircle)
                        userLiveNativeCircle = null
                        userLiveInnerCircle = null

                        safeRemoveCircle(pickupNativeCircle)
                        safeRemoveCircle(pickupInnerCircle)
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
                if (lat != null && lng != null) {
                    val pos = OlaLatLng(lat, lng, 0.0)
                    drawUserLiveMarker(pos)
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
                val isPickup = call.argument<Boolean>("isPickup") ?: false
                val isCaptain = call.argument<Boolean>("isCaptain") ?: false

                try {
                    val pos = OlaLatLng(lat, lng, 0.0)
                    if (isCaptain) {
                        if (olaMap != null) {
                            drawCaptainMarker(pos)
                        } else {
                            pendingCaptainPosition = pos
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
                val colorStr = call.argument<String>("color") ?: "#2563EB"

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
                    } catch (_: Exception) {
                        try {
                            val decoded6 = PolylineDecoder.decode(polylineStr, 6)
                            if (decoded6 != null) {
                                for (pt in decoded6) {
                                    latLngs.add(OlaLatLng(pt.latitude, pt.longitude, 0.0))
                                }
                            }
                        } catch (_: Exception) {}
                    }
                }

                if (latLngs.isNotEmpty()) {
                    if (mapLibreMap != null) {
                        drawPolylineOnMap(latLngs, colorStr)
                    } else {
                        pendingPolylinePoints = latLngs
                        pendingPolylineColor = colorStr
                    }
                }
                result.success(null)
            }

            "clearRoute" -> {
                try {
                    pickupMarker?.removeMarker()
                    destMarker?.removeMarker()
                    captainMarker?.removeMarker()

                    val mapLibre = mapLibreMap
                    if (mapLibre != null) {
                        mlActivePolylineCasing?.let { mapLibre.removeAnnotation(it) }
                        mlActivePolyline?.let { mapLibre.removeAnnotation(it) }
                    }

                    safeRemoveCircle(destNativeCircle)
                    safeRemoveCircle(destInnerCircle)
                    safeRemoveCircle(pickupNativeCircle)
                    safeRemoveCircle(pickupInnerCircle)
                    safeRemoveCircle(captainNativeCircle)
                    safeRemoveCircle(captainInnerCircle)
                } catch (_: Exception) {}

                pickupMarker = null
                destMarker = null
                captainMarker = null
                destNativeCircle = null
                destInnerCircle = null
                pickupNativeCircle = null
                pickupInnerCircle = null
                captainNativeCircle = null
                captainInnerCircle = null
                mlActivePolylineCasing = null
                mlActivePolyline = null

                pendingPickupPosition = null
                pendingDestPosition = null
                pendingCaptainPosition = null
                pendingPolylinePoints = null
                pendingPolylineColor = null

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
