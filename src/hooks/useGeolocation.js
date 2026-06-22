import { useState } from 'react';
import { supabase } from '../lib/supabase/client';

export function useGeolocation() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // Haversine formula to calculate distance in meters
  const calculateDistance = (lat1, lon1, lat2, lon2) => {
    const R = 6371e3; // Earth radius in meters
    const rad = Math.PI / 180;
    const φ1 = lat1 * rad;
    const φ2 = lat2 * rad;
    const Δφ = (lat2 - lat1) * rad;
    const Δλ = (lon2 - lon1) * rad;

    const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ/2) * Math.sin(Δλ/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

    return R * c; // Distance in meters
  };

  const getCurrentLocation = () => {
    return new Promise((resolve, reject) => {
      if (!navigator.geolocation) {
        reject(new Error('Geolocation is not supported by your browser.'));
        return;
      }
      
      navigator.geolocation.getCurrentPosition(
        (position) => {
          resolve({
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
            accuracy: position.coords.accuracy
          });
        },
        (err) => {
          // Provide friendly error messages for common geolocation errors
          let msg = 'Failed to get location.';
          if (err.code === 1) msg = 'Please allow location permissions to clock in.';
          if (err.code === 2) msg = 'Location unavailable. Please check your GPS signal.';
          if (err.code === 3) msg = 'Location request timed out.';
          reject(new Error(msg));
        },
        { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
      );
    });
  };

  const validateOfficeGeofence = async (latitude, longitude) => {
    // Fetch active office
    const { data: office, error: dbError } = await supabase
      .from('office_settings')
      .select('*')
      .eq('is_active', true)
      .single();

    if (dbError || !office) {
      // If no office is configured, we assume a Soft Pass but flag it
      return { isWithin: true, office: null, distance: null, warning: 'No active office configured.' };
    }

    const distance = calculateDistance(latitude, longitude, office.latitude, office.longitude);
    const isWithin = distance <= office.radius;

    return { isWithin, office, distance };
  };

  const getLocationAndValidate = async (sessionType) => {
    setLoading(true);
    setError(null);
    try {
      const location = await getCurrentLocation();
      let validation = { isWithin: true, office: null, distance: null };

      if (sessionType === 'office') {
        validation = await validateOfficeGeofence(location.latitude, location.longitude);
      }

      setLoading(false);
      return { location, validation };
    } catch (err) {
      setError(err.message);
      setLoading(false);
      throw err;
    }
  };

  return { getLocationAndValidate, loading, error };
}
