import React, { useState, useEffect, useRef } from 'react';
import { db } from '../../config/firebase';
import { doc, onSnapshot, setDoc, serverTimestamp } from 'firebase/firestore';
import { 
  CurrencyInr, Lightning, MapPinLine, Clock,
  CaretDown, Check, CarProfile, Taxi, Moped, Package
} from '@phosphor-icons/react';
import { useToast } from '../../context/ToastContext';
import { logAdminAction } from '../../services/auditService';

const VEHICLE_OPTIONS = [
  {
    id: 'cab',
    label: 'Cab / Car',
    category: '4-Wheelers',
    description: 'Hatchback, Sedan & Prime Cabs',
    icon: CarProfile,
    color: '#2563eb',
    bg: 'rgba(37, 99, 235, 0.1)',
  },
  {
    id: 'auto',
    label: 'Auto Rickshaw',
    category: '3-Wheelers',
    description: 'Standard City & Electric Auto',
    icon: Taxi,
    color: '#d97706',
    bg: 'rgba(217, 119, 6, 0.1)',
  },
  {
    id: 'bike',
    label: 'Bike',
    category: '2-Wheelers',
    description: 'Moto & Two-Wheeler Taxi',
    icon: Moped,
    color: '#16a34a',
    bg: 'rgba(22, 163, 74, 0.1)',
  },
  {
    id: 'parcel',
    label: 'Parcel / Delivery',
    category: 'Logistics',
    description: 'On-demand goods delivery & courier',
    icon: Package,
    color: '#7c3aed',
    bg: 'rgba(124, 58, 237, 0.1)',
  },
];

export const Pricing = () => {
  const [vehicle, setVehicle] = useState('cab');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef(null);
  const toast = useToast();

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    };
    const handleKeyDown = (event) => {
      if (event.key === 'Escape') {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, []);

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
    surgeStartAt: '',
    surgeEndAt: '',
    pricingVersion: 0
  });

  useEffect(() => {
    setLoading(true);
    const fareRulesRef = doc(db, 'fare_rules', `${vehicle}_default`);
    const unsub = onSnapshot(fareRulesRef, (snap) => {
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
          surgeStartAt: data.surgeStartAt ?? '',
          surgeEndAt: data.surgeEndAt ?? '',
          pricingVersion: data.pricingVersion ?? 0
        });
        setLoading(false);
      } else {
        // Fallback to legacy pricing/{vehicle}
        const legacyRef = doc(db, 'pricing', vehicle);
        const unsubLegacy = onSnapshot(legacyRef, (legSnap) => {
          if (legSnap.exists()) {
            const data = legSnap.data();
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
              surgeStartAt: data.surgeStartAt ?? '',
              surgeEndAt: data.surgeEndAt ?? '',
              pricingVersion: data.pricingVersion ?? 0
            });
          } else {
            setFormData({
              baseFare: 15, includedDistanceKm: 3, perKmFare: 5, perMinuteFare: 1,
              minimumFare: 15, freeWaitingMinutes: 3, waitingChargePerMin: 1,
              dynamicPricingEnabled: false, surgeMultiplier: 1.0, surgeReason: '',
              surgeStartAt: '', surgeEndAt: '', pricingVersion: 0
            });
          }
          setLoading(false);
        });
        return () => unsubLegacy();
      }
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

    // Input Validation (ISSUE-06): Prevent 0 or negative rates that break ride calculations
    const baseFare = Number(formData.baseFare);
    const perKmFare = Number(formData.perKmFare);
    const minimumFare = Number(formData.minimumFare);
    const includedDistanceKm = Number(formData.includedDistanceKm);
    const perMinuteFare = Number(formData.perMinuteFare);
    const waitingChargePerMin = Number(formData.waitingChargePerMin);
    const surgeMultiplier = Number(formData.surgeMultiplier);

    if (isNaN(baseFare) || baseFare <= 0) {
      toast('Base Fare must be greater than ₹0.', 'warning');
      return;
    }
    if (isNaN(perKmFare) || perKmFare <= 0) {
      toast('Per Km Rate must be greater than ₹0.', 'warning');
      return;
    }
    if (isNaN(minimumFare) || minimumFare <= 0) {
      toast('Minimum Fare must be greater than ₹0.', 'warning');
      return;
    }
    if (isNaN(includedDistanceKm) || includedDistanceKm < 0) {
      toast('Included distance cannot be negative.', 'warning');
      return;
    }
    if (isNaN(perMinuteFare) || perMinuteFare < 0 || isNaN(waitingChargePerMin) || waitingChargePerMin < 0) {
      toast('Per-minute and waiting charges cannot be negative.', 'warning');
      return;
    }
    if (formData.dynamicPricingEnabled && (isNaN(surgeMultiplier) || surgeMultiplier < 1.0)) {
      toast('Surge multiplier cannot be less than 1.0x.', 'warning');
      return;
    }

    setSaving(true);
    try {
      const newVersion = (formData.pricingVersion || 0) + 1;
      const payload = {
        baseFare: baseFare,
        base: baseFare,
        includedDistanceKm: includedDistanceKm,
        includedDistance: includedDistanceKm,
        perKm: perKmFare,
        perKmFare: perKmFare,
        perMin: Number(formData.perMinuteFare),
        perMinuteFare: Number(formData.perMinuteFare),
        minimumFare: Number(formData.minimumFare),
        freeWaitingMinutes: Number(formData.freeWaitingMinutes),
        freeWaitingTime: Number(formData.freeWaitingMinutes),
        waitingPerMin: Number(formData.waitingChargePerMin),
        waitingChargePerMin: Number(formData.waitingChargePerMin),
        surgeEnabled: Boolean(formData.dynamicPricingEnabled),
        dynamicPricingEnabled: Boolean(formData.dynamicPricingEnabled),
        surgeMultiplier: Number(formData.surgeMultiplier),
        surgeReason: formData.surgeReason || '',
        surgeStartAt: formData.surgeStartAt || null,
        surgeEndAt: formData.surgeEndAt || null,
        pricingVersion: newVersion,
        updatedAt: serverTimestamp(),
      };

      // Write to live fare_rules collection (read by mobile apps)
      const fareRulesRef = doc(db, 'fare_rules', `${vehicle}_default`);
      await setDoc(fareRulesRef, payload, { merge: true });

      // Dual-write to pricing collection for backward compatibility
      const legacyRef = doc(db, 'pricing', vehicle);
      await setDoc(legacyRef, payload, { merge: true });

      // Audit log the price update
      await logAdminAction('fare_rules_changed', `${vehicle}_default`, {
        vehicle,
        baseFare: Number(formData.baseFare),
        perKmFare: Number(formData.perKmFare),
        surgeMultiplier: Number(formData.surgeMultiplier),
        dynamicPricingEnabled: Boolean(formData.dynamicPricingEnabled),
        pricingVersion: newVersion,
      });

      toast(`Pricing for ${vehicle.toUpperCase()} synchronized across Mobile and Web!`, 'success');
    } catch (error) {
      console.error(error);
      toast('Failed to update pricing.', 'error');
    } finally {
      setSaving(false);
    }
  };

  const currentVehicleOption = VEHICLE_OPTIONS.find(v => v.id === vehicle) || VEHICLE_OPTIONS[0];
  const CurrentIcon = currentVehicleOption.icon;

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
        {/* Enhanced Vehicle Class Dropdown Header */}
        <div style={{ 
          marginBottom: '2rem', 
          paddingBottom: '1.5rem', 
          borderBottom: '1px solid var(--border)',
          display: 'flex', 
          justifyContent: 'space-between', 
          alignItems: 'center', 
          flexWrap: 'wrap', 
          gap: '1.25rem' 
        }}>
          <div>
            <label style={{ 
              display: 'block', 
              fontSize: '0.925rem', 
              fontWeight: 700, 
              color: 'var(--text-primary)', 
              marginBottom: '0.25rem' 
            }}>
              Select Vehicle Class
            </label>
            <p style={{ margin: 0, fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
              Configure base fares, distance tiers, and dynamic surge pricing for each vehicle category.
            </p>
          </div>

          {/* Custom Dropdown */}
          <div ref={dropdownRef} style={{ position: 'relative' }}>
            <button
              type="button"
              onClick={() => setIsOpen(prev => !prev)}
              aria-haspopup="listbox"
              aria-expanded={isOpen}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.875rem',
                padding: '0.5rem 1rem 0.5rem 0.625rem',
                background: 'var(--surface-1)',
                border: isOpen ? '1.5px solid var(--brand-blue)' : '1px solid var(--border-strong)',
                borderRadius: '12px',
                cursor: 'pointer',
                minWidth: '275px',
                boxShadow: isOpen ? '0 0 0 3px rgba(21, 101, 192, 0.15)' : 'var(--shadow-xs)',
                transition: 'all var(--t-fast)',
                outline: 'none',
              }}
            >
              <div style={{
                width: 38,
                height: 38,
                borderRadius: '10px',
                background: currentVehicleOption.bg,
                color: currentVehicleOption.color,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                flexShrink: 0,
              }}>
                <CurrentIcon size={22} weight="duotone" />
              </div>
              
              <div style={{ flex: 1, textAlign: 'left' }}>
                <div style={{ fontSize: '0.9375rem', fontWeight: 700, color: 'var(--text-primary)', lineHeight: 1.2 }}>
                  {currentVehicleOption.label}
                </div>
                <div style={{ fontSize: '0.725rem', color: 'var(--text-muted)', marginTop: '2px', fontWeight: 500 }}>
                  {currentVehicleOption.category}
                </div>
              </div>

              <CaretDown 
                size={16} 
                weight="bold" 
                style={{ 
                  color: 'var(--text-muted)', 
                  transition: 'transform 0.25s ease',
                  transform: isOpen ? 'rotate(180deg)' : 'rotate(0deg)'
                }} 
              />
            </button>

            {/* Dropdown Menu Popup */}
            {isOpen && (
              <div 
                role="listbox"
                style={{
                  position: 'absolute',
                  top: 'calc(100% + 8px)',
                  right: 0,
                  minWidth: '320px',
                  background: 'var(--surface-1)',
                  border: '1px solid var(--border)',
                  borderRadius: '14px',
                  boxShadow: 'var(--shadow-xl)',
                  padding: '0.5rem',
                  zIndex: 50,
                  animation: 'fade-in 0.15s ease-out',
                }}
              >
                <div style={{ 
                  padding: '0.375rem 0.625rem 0.5rem', 
                  fontSize: '0.7rem', 
                  fontWeight: 700, 
                  textTransform: 'uppercase', 
                  letterSpacing: '0.06em', 
                  color: 'var(--text-muted)',
                  borderBottom: '1px solid var(--border)',
                  marginBottom: '0.375rem'
                }}>
                  Vehicle Categories
                </div>

                {VEHICLE_OPTIONS.map((opt) => {
                  const isSelected = opt.id === vehicle;
                  const IconComponent = opt.icon;
                  return (
                    <div
                      key={opt.id}
                      role="option"
                      aria-selected={isSelected}
                      onClick={() => {
                        setVehicle(opt.id);
                        setIsOpen(false);
                      }}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: '0.75rem',
                        padding: '0.625rem 0.75rem',
                        borderRadius: '10px',
                        cursor: 'pointer',
                        background: isSelected ? 'rgba(21, 101, 192, 0.08)' : 'transparent',
                        border: isSelected ? '1px solid rgba(21, 101, 192, 0.2)' : '1px solid transparent',
                        transition: 'background var(--t-fast)',
                        marginBottom: '2px',
                      }}
                      onMouseEnter={(e) => {
                        if (!isSelected) e.currentTarget.style.background = 'var(--surface-2)';
                      }}
                      onMouseLeave={(e) => {
                        if (!isSelected) e.currentTarget.style.background = 'transparent';
                      }}
                    >
                      <div style={{
                        width: 34,
                        height: 34,
                        borderRadius: '8px',
                        background: opt.bg,
                        color: opt.color,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        flexShrink: 0,
                      }}>
                        <IconComponent size={18} weight={isSelected ? "fill" : "duotone"} />
                      </div>

                      <div style={{ flex: 1, minWidth: 0, textAlign: 'left' }}>
                        <div style={{ 
                          fontSize: '0.875rem', 
                          fontWeight: isSelected ? 700 : 600, 
                          color: isSelected ? 'var(--brand-blue)' : 'var(--text-primary)',
                          lineHeight: 1.2
                        }}>
                          {opt.label}
                        </div>
                        <div style={{ 
                          fontSize: '0.725rem', 
                          color: 'var(--text-muted)', 
                          marginTop: '2px',
                          whiteSpace: 'nowrap',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis'
                        }}>
                          {opt.description}
                        </div>
                      </div>

                      {isSelected && (
                        <div style={{
                          width: 20,
                          height: 20,
                          borderRadius: '50%',
                          background: 'var(--brand-blue)',
                          color: 'white',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          flexShrink: 0
                        }}>
                          <Check size={12} weight="bold" />
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
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
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '1.5rem', background: 'var(--surface-2)', padding: '1.5rem', borderRadius: 'var(--r-md)' }}>
                  <div className="form-group">
                    <label className="form-label">Surge Multiplier (e.g. 1.5x)</label>
                    <input type="number" name="surgeMultiplier" value={formData.surgeMultiplier} onChange={handleChange} className="form-input" required min="1" step="0.1" max="5" />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Reason for Surge (visible to passengers)</label>
                    <input type="text" name="surgeReason" value={formData.surgeReason} onChange={handleChange} className="form-input" placeholder="e.g. High demand in your area" required />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Surge Start Time (Optional)</label>
                    <input type="datetime-local" name="surgeStartAt" value={formData.surgeStartAt} onChange={handleChange} className="form-input" />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Surge End Time (Optional)</label>
                    <input type="datetime-local" name="surgeEndAt" value={formData.surgeEndAt} onChange={handleChange} className="form-input" />
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
