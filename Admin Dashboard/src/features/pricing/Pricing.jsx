import React, { useState, useEffect } from 'react';
import { db } from '../../config/firebase';
import { doc, onSnapshot, setDoc, serverTimestamp } from 'firebase/firestore';
import { CurrencyInr, WarningCircle, Lightning, MapPinLine, Clock } from '@phosphor-icons/react';
import { useToast } from '../../context/ToastContext';

export const Pricing = () => {
  const [vehicle, setVehicle] = useState('cab');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const toast = useToast();

  const [formData, setFormData] = useState({
    baseFare: 15,
    includedDistanceKm: 3,
    perKmFare: 5,
    perMinuteFare: 1,
    minimumFare: 15,
    freeWaitingMinutes: 3,
    waitingChargePerMin: 1,
    dynamicPricingEnabled: false,
    surgeMultiplier: 1.0,
    surgeReason: '',
    pricingVersion: 0
  });

  useEffect(() => {
    setLoading(true);
    const docRef = doc(db, 'pricing', vehicle);
    const unsub = onSnapshot(docRef, (snap) => {
      if (snap.exists()) {
        const data = snap.data();
        setFormData({
          baseFare: data.baseFare ?? data.base ?? 15,
          includedDistanceKm: data.includedDistanceKm ?? data.includedDistance ?? 3,
          perKmFare: data.perKmFare ?? data.perKm ?? 5,
          perMinuteFare: data.perMinuteFare ?? data.perMin ?? 1,
          minimumFare: data.minimumFare ?? 15,
          freeWaitingMinutes: data.freeWaitingMinutes ?? data.freeWaitingTime ?? 3,
          waitingChargePerMin: data.waitingChargePerMin ?? data.waitingPerMin ?? 1,
          dynamicPricingEnabled: data.dynamicPricingEnabled ?? data.surgeEnabled ?? false,
          surgeMultiplier: data.surgeMultiplier ?? 1.0,
          surgeReason: data.surgeReason ?? '',
          pricingVersion: data.pricingVersion ?? 0
        });
      } else {
        // Defaults if doesn't exist
        setFormData({
          baseFare: 15, includedDistanceKm: 3, perKmFare: 5, perMinuteFare: 1,
          minimumFare: 15, freeWaitingMinutes: 3, waitingChargePerMin: 1,
          dynamicPricingEnabled: false, surgeMultiplier: 1.0, surgeReason: '', pricingVersion: 0
        });
      }
      setLoading(false);
    }, (err) => {
      console.error(err);
      toast('Failed to load pricing.', 'error');
      setLoading(false);
    });

    return () => unsub();
  }, [vehicle]);

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : (type === 'number' ? Number(value) : value)
    }));
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      const docRef = doc(db, 'pricing', vehicle);
      await setDoc(docRef, {
        baseFare: formData.baseFare,
        includedDistanceKm: formData.includedDistanceKm,
        perKmFare: formData.perKmFare,
        perMinuteFare: formData.perMinuteFare,
        minimumFare: formData.minimumFare,
        freeWaitingMinutes: formData.freeWaitingMinutes,
        waitingChargePerMin: formData.waitingChargePerMin,
        dynamicPricingEnabled: formData.dynamicPricingEnabled,
        surgeMultiplier: formData.surgeMultiplier,
        surgeReason: formData.surgeReason,
        pricingVersion: formData.pricingVersion + 1,
        updatedAt: serverTimestamp()
      }, { merge: true });
      toast('Pricing updated successfully.', 'success');
    } catch (error) {
      console.error(error);
      toast('Failed to update pricing.', 'error');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="animate-fade-in" style={{ paddingBottom: '2rem' }}>
      <div style={{ 
        background: 'linear-gradient(135deg, #1e3a8a 0%, #1e40af 100%)',
        borderRadius: 'var(--r-xl)', padding: '2rem 3rem', color: 'white',
        marginBottom: '2rem', boxShadow: 'var(--shadow-md)', position: 'relative', overflow: 'hidden'
      }}>
        <div style={{ position: 'relative', zIndex: 1 }}>
          <h1 style={{ fontSize: '2rem', fontWeight: 800, margin: 0, display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <CurrencyInr size={32} weight="duotone" style={{ color: '#60A5FA' }} /> 
            Pricing & Surge Configuration
          </h1>
          <p style={{ color: 'rgba(255,255,255,0.6)', fontSize: '1rem', marginTop: '0.5rem', marginLeft: '3.125rem' }}>
            Manage base fares, wait times, and dynamic pricing across your fleet.
          </p>
        </div>
      </div>

      <div className="card" style={{ padding: '2rem' }}>
        <div style={{ marginBottom: '2rem', display: 'flex', gap: '1rem', alignItems: 'center' }}>
          <span style={{ fontWeight: 600 }}>Select Vehicle Class:</span>
          <select 
            value={vehicle} 
            onChange={(e) => setVehicle(e.target.value)} 
            className="form-input" 
            style={{ width: '200px', display: 'inline-block' }}
          >
            <option value="cab">Cab / Car</option>
            <option value="auto">Auto Rickshaw</option>
            <option value="bike">Bike</option>
            <option value="parcel">Parcel / Delivery</option>
          </select>
        </div>

        {loading ? (
          <div>Loading pricing details...</div>
        ) : (
          <form onSubmit={handleSave}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem' }}>
              {/* Base Fare Configuration */}
              <div>
                <h3 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem', color: 'var(--brand-blue)' }}>
                  <MapPinLine size={20} /> Distance & Base Fare
                </h3>
                
                <div className="form-group" style={{ marginBottom: '1rem' }}>
                  <label className="form-label">Base Fare (₹)</label>
                  <input type="number" name="baseFare" value={formData.baseFare} onChange={handleChange} className="form-input" required min="0" step="0.5" />
                </div>

                <div className="form-group" style={{ marginBottom: '1rem' }}>
                  <label className="form-label">Included Distance in Base Fare (Km)</label>
                  <input type="number" name="includedDistanceKm" value={formData.includedDistanceKm} onChange={handleChange} className="form-input" required min="0" step="0.1" />
                </div>

                <div className="form-group" style={{ marginBottom: '1rem' }}>
                  <label className="form-label">Rate per Additional Km (₹)</label>
                  <input type="number" name="perKmFare" value={formData.perKmFare} onChange={handleChange} className="form-input" required min="0" step="0.5" />
                </div>

                <div className="form-group" style={{ marginBottom: '1rem' }}>
                  <label className="form-label">Minimum Fare Cap (₹)</label>
                  <input type="number" name="minimumFare" value={formData.minimumFare} onChange={handleChange} className="form-input" required min="0" step="1" />
                </div>
              </div>

              {/* Waiting & Time Configuration */}
              <div>
                <h3 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem', color: 'var(--warning)' }}>
                  <Clock size={20} /> Waiting & Duration Charges
                </h3>
                
                <div className="form-group" style={{ marginBottom: '1rem' }}>
                  <label className="form-label">Rate per Minute of Ride (₹)</label>
                  <input type="number" name="perMinuteFare" value={formData.perMinuteFare} onChange={handleChange} className="form-input" required min="0" step="0.1" />
                </div>

                <div className="form-group" style={{ marginBottom: '1rem' }}>
                  <label className="form-label">Free Waiting Time (Minutes)</label>
                  <input type="number" name="freeWaitingMinutes" value={formData.freeWaitingMinutes} onChange={handleChange} className="form-input" required min="0" step="1" />
                </div>

                <div className="form-group" style={{ marginBottom: '1rem' }}>
                  <label className="form-label">Waiting Charge per Minute (₹)</label>
                  <input type="number" name="waitingChargePerMin" value={formData.waitingChargePerMin} onChange={handleChange} className="form-input" required min="0" step="0.5" />
                </div>
              </div>
            </div>

            <hr style={{ margin: '2rem 0', borderColor: 'var(--border)' }} />

            {/* Dynamic Pricing (Surge) */}
            <div>
              <h3 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem', color: 'var(--error)' }}>
                <Lightning size={20} /> Dynamic Pricing (Surge)
              </h3>
              
              <div className="form-group" style={{ marginBottom: '1.5rem' }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', cursor: 'pointer', fontWeight: 600 }}>
                  <input type="checkbox" name="dynamicPricingEnabled" checked={formData.dynamicPricingEnabled} onChange={handleChange} style={{ width: 18, height: 18 }} />
                  Enable Surge Pricing
                </label>
              </div>

              {formData.dynamicPricingEnabled && (
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: '1.5rem', background: 'var(--surface-2)', padding: '1.5rem', borderRadius: 'var(--r-md)' }}>
                  <div className="form-group">
                    <label className="form-label">Surge Multiplier (e.g. 1.5x)</label>
                    <input type="number" name="surgeMultiplier" value={formData.surgeMultiplier} onChange={handleChange} className="form-input" required min="1" step="0.1" max="5" />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Reason for Surge (visible to passengers)</label>
                    <input type="text" name="surgeReason" value={formData.surgeReason} onChange={handleChange} className="form-input" placeholder="e.g. High demand in your area" required />
                  </div>
                </div>
              )}
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '2rem' }}>
              <button type="submit" className="btn btn-primary" disabled={saving} style={{ padding: '0.75rem 2rem' }}>
                {saving ? 'Saving...' : 'Save Configuration'}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};
