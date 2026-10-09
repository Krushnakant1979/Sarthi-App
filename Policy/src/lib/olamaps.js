export async function geocode(query) {
  const apiKey = process.env.NEXT_PUBLIC_OLA_MAPS_API_KEY;
  
  // 1. Autocomplete
  const acRes = await fetch(`/api/ola/places/v1/autocomplete?input=${encodeURIComponent(query)}&api_key=${apiKey}`);
  const acData = await acRes.json();
  
  if (!acData.predictions || acData.predictions.length === 0) return null;
  const placeId = acData.predictions[0].place_id;
  const address = acData.predictions[0].description;
  
  // 2. Details
  const detailsRes = await fetch(`/api/ola/places/v1/details?place_id=${placeId}&api_key=${apiKey}`);
  const detailsData = await detailsRes.json();
  
  if (detailsData.result && detailsData.result.geometry) {
    const loc = detailsData.result.geometry.location;
    return { lat: loc.lat, lng: loc.lng, address };
  }
  return null;
}

export async function autocomplete(query) {
  if (!query) return [];
  const apiKey = process.env.NEXT_PUBLIC_OLA_MAPS_API_KEY;
  try {
    const res = await fetch(`/api/ola/places/v1/autocomplete?input=${encodeURIComponent(query)}&api_key=${apiKey}`);
    const data = await res.json();
    return data.predictions || [];
  } catch (error) {
    console.error("Autocomplete failed:", error);
    return [];
  }
}

export async function getPlaceDetails(placeId) {
  const apiKey = process.env.NEXT_PUBLIC_OLA_MAPS_API_KEY;
  try {
    const res = await fetch(`/api/ola/places/v1/details?place_id=${placeId}&api_key=${apiKey}`);
    const data = await res.json();
    if (data.result && data.result.geometry) {
      const loc = data.result.geometry.location;
      return { lat: loc.lat, lng: loc.lng, address: data.result.name || data.result.formatted_address };
    }
    return null;
  } catch (error) {
    console.error("Place details failed:", error);
    return null;
  }
}

export async function getDirections(startLat, startLng, endLat, endLng) {
  const apiKey = process.env.NEXT_PUBLIC_OLA_MAPS_API_KEY;
  
  try {
    const res = await fetch(`/api/ola/routing/v1/directions?origin=${startLat},${startLng}&destination=${endLat},${endLng}&api_key=${apiKey}`);
    const data = await res.json();
    
    let routes = [];
    if (data.routes && data.routes.length > 0) routes = data.routes;
    else if (data.result && data.result.routes) routes = data.result.routes;
    
    if (routes.length > 0) {
      const route = routes[0];
      const legs = route.legs[0];
      
      let distanceMeters = 0;
      if (typeof legs.distance === 'number') distanceMeters = legs.distance;
      else if (legs.distance && typeof legs.distance.value === 'number') distanceMeters = legs.distance.value;
      
      let durationSeconds = 0;
      if (typeof legs.duration === 'number') durationSeconds = legs.duration;
      else if (legs.duration && typeof legs.duration.value === 'number') durationSeconds = legs.duration.value;
      
      return {
        distanceMeters,
        durationSeconds,
        polyline: route.overview_polyline || ''
      };
    }
  } catch (err) {
    console.warn("Ola Maps routing failed, falling back to OSRM:", err);
  }

  // Fallback to OSRM if Ola Maps fails or returns no routes
  try {
    const osrmUrl = `https://router.project-osrm.org/route/v1/driving/${startLng},${startLat};${endLng},${endLat}?overview=full&geometries=polyline`;
    const osrmRes = await fetch(osrmUrl);
    const osrmData = await osrmRes.json();
    
    if (osrmData.routes && osrmData.routes.length > 0) {
      const route = osrmData.routes[0];
      return {
        distanceMeters: route.distance || 0,
        durationSeconds: route.duration || 0,
        polyline: route.geometry || ''
      };
    }
  } catch (osrmErr) {
    console.error("OSRM fallback also failed:", osrmErr);
  }

  return null;
}

export function decodePolyline(encoded) {
  if (!encoded) return [];
  let points = [];
  let index = 0, len = encoded.length;
  let lat = 0, lng = 0;

  while (index < len) {
    let b, shift = 0, result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    let dlat = ((result & 1) !== 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    let dlng = ((result & 1) !== 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    points.push([lng / 1E5, lat / 1E5]); // MapLibre uses [lng, lat] for GeoJSON
  }
  return points;
}
