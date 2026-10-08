"use client";
import React, { useEffect, useRef } from "react";
import * as maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";

// Fix for Next.js Turbopack Worker Error
if (typeof window !== "undefined") {
  if (maplibregl.setWorkerUrl) {
    // Load the worker from the local public directory. This guarantees no CORS errors!
    maplibregl.setWorkerUrl("/maplibre-gl-worker.mjs");
  }
}

const OlaMap = ({ routeCoordinates, captainLocation }) => {
  const mapContainer = useRef(null);
  const mapRef = useRef(null);
  const captainMarkerRef = useRef(null);

  useEffect(() => {
    if (mapRef.current) return;
    const apiKey = process.env.NEXT_PUBLIC_OLA_MAPS_API_KEY;

    if (!apiKey) {
      console.error("Ola Maps API Key is missing!");
      return;
    }

    const initMap = async () => {
      try {
        // 1. Fetch the style directly to fix the "3d_model" error
        const styleRes = await fetch(`https://api.olamaps.io/tiles/vector/v1/styles/default-light-standard/style.json?api_key=${apiKey}`);
        const styleData = await styleRes.json();

        // Remove the buggy 3d_model layer that Ola Maps includes but doesn't provide data for
        if (styleData.layers) {
          styleData.layers = styleData.layers.filter(layer => layer.id !== "3d_model_data");
        }

        // 2. Initialize the map with the cleaned style
        mapRef.current = new maplibregl.Map({
          container: mapContainer.current,
          style: styleData, 
          center: [77.61648, 12.93142], // Default center
          zoom: 12,
          transformRequest: (url, resourceType) => {
            if (url.includes("api.olamaps.io")) {
              const hasQuery = url.indexOf("?") !== -1;
              const separator = hasQuery ? "&" : "?";
              return { url: `${url}${separator}api_key=${apiKey}` };
            }
            return { url };
          }
        });

        mapRef.current.addControl(new maplibregl.NavigationControl(), 'top-right');
        mapRef.current.addControl(
          new maplibregl.GeolocateControl({
              positionOptions: { enableHighAccuracy: true },
              trackUserLocation: true
          })
        );

        // Wait for map load to draw initial polyline if exists
        mapRef.current.on('load', () => {
          if (routeCoordinates && routeCoordinates.length > 0) {
            drawRoute(routeCoordinates);
          }
        });

      } catch (err) {
        console.error("Failed to load map style:", err);
      }
    };

    initMap();
  }, []);

  // Function to draw route
  const drawRoute = (coords) => {
    const map = mapRef.current;
    if (!map || !map.isStyleLoaded()) return;

    if (map.getSource('route')) {
      map.getSource('route').setData({
        type: 'Feature',
        properties: {},
        geometry: {
          type: 'LineString',
          coordinates: coords
        }
      });
    } else {
      map.addSource('route', {
        type: 'geojson',
        data: {
          type: 'Feature',
          properties: {},
          geometry: {
            type: 'LineString',
            coordinates: coords
          }
        }
      });
      map.addLayer({
        id: 'route',
        type: 'line',
        source: 'route',
        layout: {
          'line-join': 'round',
          'line-cap': 'round'
        },
        paint: {
          'line-color': '#2563EB',
          'line-width': 4
        }
      });
    }

    // Fit map to bounds
    const bounds = coords.reduce((bounds, coord) => {
      return bounds.extend(coord);
    }, new maplibregl.LngLatBounds(coords[0], coords[0]));
    
    map.fitBounds(bounds, { padding: 50 });
  };

  // React to prop changes
  useEffect(() => {
    if (routeCoordinates && routeCoordinates.length > 0) {
      drawRoute(routeCoordinates);
    } else if (mapRef.current && mapRef.current.getSource('route')) {
      // Clear route
      mapRef.current.getSource('route').setData({
        type: 'Feature',
        properties: {},
        geometry: { type: 'LineString', coordinates: [] }
      });
    }
  }, [routeCoordinates]);

  useEffect(() => {
    if (!mapRef.current) return;
    
    if (captainLocation) {
      if (!captainMarkerRef.current) {
        // Create an HTML element for the marker
        const el = document.createElement('div');
        el.className = 'captain-marker';
        el.style.width = '24px';
        el.style.height = '24px';
        el.style.backgroundColor = '#000';
        el.style.borderRadius = '50%';
        el.style.border = '3px solid white';
        el.style.boxShadow = '0 0 10px rgba(0,0,0,0.3)';

        captainMarkerRef.current = new maplibregl.Marker({ element: el })
          .setLngLat(captainLocation)
          .addTo(mapRef.current);
      } else {
        captainMarkerRef.current.setLngLat(captainLocation);
      }
    } else if (captainMarkerRef.current) {
      captainMarkerRef.current.remove();
      captainMarkerRef.current = null;
    }
  }, [captainLocation]);

  return (
    <div 
      ref={mapContainer} 
      style={{ width: "100%", height: "100%", position: "absolute", top: 0, left: 0 }} 
    />
  );
};

export default OlaMap;
