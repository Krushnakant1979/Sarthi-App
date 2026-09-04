import React, { useState, useEffect } from 'react';
import { db, auth } from '../../config/firebase';
import { doc, setDoc, Timestamp, onSnapshot, serverTimestamp, increment } from 'firebase/firestore';
import { useToast } from '../../context/ToastContext';
import { Gear, CurrencyInr, CheckCircle, Warning, Moped, Taxi, CarProfile, Package, MapTrifold, Clock, Money, Timer, Hourglass, Lightning, CalendarBlank } from '@phosphor-icons/react';

const defaultVehiclePricing = {
  baseFare: 30,
  includedDistanceKm: 3,
  perKm: 10,
  perMin: 1,
  minimumFare: 30,
  freeWaitingMinutes: 3,
  waitingPerMin: 1.5,
  surgeEnabled: false,
  surgeMultiplier: 1.0,
  surgeReason: '',
  surgeStartAt: '',
  surgeEndAt: '',
  commission: 15,
  pricingVersion: 0,
};

const defaultPricingState = {
  bike: { ...defaultVehiclePricing },
  auto: { ...defaultVehiclePricing },
  cab: { ...defaultVehiclePricing },
  parcel: { ...defaultVehiclePricing },
};

const VehicleTabs = [
  { id: 'bike', label: 'Bike Fare', icon: Moped },
  { id: 'auto', label: 'Auto Rickshaw', icon: Taxi },
  { id: 'cab', label: 'Cab Fare', icon: CarProfile },
  { id: 'parcel', label: 'Parcel Fare', icon: Package },
];

const Settings = () => {
  const [activeTab, setActiveTab] = useState('bike');
  
  // remotePricing is what comes directly from Firestore
  const [remotePricing, setRemotePricing] = useState(defaultPricingState);
  
  // localPricing is what the user edits in the form
  const [localPricing, setLocalPricing] = useState(defaultPricingState);
  
  // Track conflicts per tab
  const [conflicts, setConflicts] = useState({ bike: false, auto: false, cab: false, parcel: false });
  
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const { addToast } = useToast();

  useEffect(() => {
    const unsubscribes = [];
    
    VehicleTabs.forEach(tab => {
      const docRef = doc(db, 'fare_rules', `${tab.id}_default`);
      
      const unsub = onSnapshot(docRef, (snap) => {
        if (snap.exists()) {
          const data = snap.data();
          
          // Parse Timestamps to datetime-local strings
          let sStart = '';
          if (data.surgeStartAt?.toDate) {
             const d = data.surgeStartAt.toDate();
             d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
             sStart = d.toISOString().slice(0, 16);
          } else if (data.surgeStartTime?.toDate) {
             const d = data.surgeStartTime.toDate();
             d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
             sStart = d.toISOString().slice(0, 16);
          }
          
          let sEnd = '';
          if (data.surgeEndAt?.toDate) {
             const d = data.surgeEndAt.toDate();
             d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
             sEnd = d.toISOString().slice(0, 16);
          } else if (data.surgeEndTime?.toDate) {
             const d = data.surgeEndTime.toDate();
             d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
             sEnd = d.toISOString().slice(0, 16);
          }

          const newRemote = {
            baseFare: data.baseFare ?? 30,
            includedDistanceKm: data.includedDistanceKm ?? data.includedDistance ?? 3,
            perKm: data.perKm ?? data.perKmFare ?? 10,
            perMin: data.perMin ?? data.perMinuteFare ?? 1,
            minimumFare: data.minimumFare ?? 30,
            freeWaitingMinutes: data.freeWaitingMinutes ?? data.freeWaitingTime ?? 3,
            waitingPerMin: data.waitingPerMin ?? data.waitingChargePerMin ?? 1.5,
            surgeEnabled: data.surgeEnabled ?? data.dynamicPricingEnabled ?? false,
            surgeMultiplier: data.surgeMultiplier ?? 1.0,
            surgeReason: data.surgeReason ?? '',
            surgeStartAt: sStart,
            surgeEndAt: sEnd,
            commission: data.commission ?? 15,
            pricingVersion: data.pricingVersion ?? 0,
          };
          
          setRemotePricing(prev => {
            const previousRemote = prev[tab.id];
            
            setLocalPricing(prevLocal => {
               const currentLocal = prevLocal[tab.id];
               
               // Check if user has unsaved changes for this tab
               const hasChanges = Object.keys(currentLocal).some(
                 key => currentLocal[key] !== previousRemote[key]
               );
               
               // If there's a newer version from another admin, and we have local changes, flag conflict
               if (newRemote.pricingVersion > previousRemote.pricingVersion) {
                  if (hasChanges) {
                     setConflicts(c => ({ ...c, [tab.id]: true }));
                     return prevLocal; // Do not overwrite local edits!
                  } else {
                     // No local changes, safe to overwrite silently
                     return { ...prevLocal, [tab.id]: newRemote };
                  }
               }
               
               // If it's the first load, populate local too
               if (previousRemote.pricingVersion === 0) {
                  return { ...prevLocal, [tab.id]: newRemote };
               }
               
               return prevLocal;
            });
            
            return { ...prev, [tab.id]: newRemote };
          });
        }
      }, (error) => {
        console.error(`Error listening to ${tab.id}_default`, error);
      });
      
      unsubscribes.push(unsub);
    });

    setLoading(false);
    
    return () => unsubscribes.forEach(unsub => unsub());
  }, []);

  const handleSave = async () => {
    setSaving(true);
    try {
      const data = { ...localPricing[activeTab] };
      
      // Convert ISO strings back to Firestore Timestamps
      if (data.surgeStartAt) {
        data.surgeStartAt = Timestamp.fromDate(new Date(data.surgeStartAt));
      } else {
        data.surgeStartAt = null;
      }
      
      if (data.surgeEndAt) {
        data.surgeEndAt = Timestamp.fromDate(new Date(data.surgeEndAt));
      } else {
        data.surgeEndAt = null;
      }
      
      data.updatedAt = serverTimestamp();
      data.updatedBy = auth?.currentUser?.uid || 'admin-web';
      data.pricingVersion = increment(1);
      
      await setDoc(doc(db, 'fare_rules', `${activeTab}_default`), data, { merge: true });
      
      addToast(`${VehicleTabs.find(t=>t.id===activeTab).label} saved successfully!`, "success");
      setConflicts(c => ({ ...c, [activeTab]: false }));
    } catch (error) {
      console.error(error);
      addToast("Error saving fare rules", "error");
    } finally {
      setSaving(false);
    }
  };
  
  const handleReload = () => {
    setLocalPricing(prev => ({
      ...prev,
      [activeTab]: remotePricing[activeTab]
    }));
    setConflicts(c => ({ ...c, [activeTab]: false }));
  };

  const updateField = (field, value, isNumber = true) => {
    setLocalPricing(prev => ({
      ...prev,
      [activeTab]: {
        ...prev[activeTab],
        [field]: isNumber ? (Number(value) || 0) : value
      }
    }));
  };
  
  const hasUnsavedChanges = () => {
    const currentLocal = localPricing[activeTab];
    const currentRemote = remotePricing[activeTab];
    return Object.keys(currentLocal).some(key => currentLocal[key] !== currentRemote[key]);
  };

  if (loading) {
    return <div style={{ padding: '4rem', textAlign: 'center', color: 'var(--text-muted)' }}>Loading settings...</div>;
  }

  const currentSettings = localPricing[activeTab];
  const hasChanges = hasUnsavedChanges();
  const hasConflict = conflicts[activeTab];

  return (
    <div className="animate-fade-in">
      <div className="page-header" style={{ marginBottom: '2rem' }}>
        <div>
          <h1>Global Settings</h1>
          <p>Configure advanced pricing models, waiting charges, and dynamic surge pricing.</p>
        </div>
        <div style={{ display: 'flex', gap: '1rem' }}>
          {hasChanges && !hasConflict && (
            <button 
              onClick={handleReload}
              className="btn btn-outline"
              disabled={saving}
            >
              Discard Changes
            </button>
          )}
          <button 
            onClick={handleSave} 
            disabled={saving || !hasChanges || hasConflict}
            className="btn btn-primary"
          >
            {saving ? <div className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }}></div> : <CheckCircle size={18} />}
            {hasChanges ? 'Save Changes' : 'Up to date'}
          </button>
        </div>
      </div>
      
      {hasConflict && (
        <div className="alert-error" style={{ marginBottom: '2rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '1rem 1.5rem', borderRadius: 'var(--r-lg)', backgroundColor: 'var(--error-light)', border: '1px solid rgba(220, 38, 38, 0.3)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
            <Warning size={24} weight="fill" color="var(--error)" />
            <div>
              <div style={{ fontWeight: 700, color: '#991B1B', marginBottom: '0.25rem' }}>Fare rules were updated from another admin platform.</div>
              <div style={{ fontSize: '0.875rem', color: '#B91C1C' }}>Reload the latest values before saving to prevent overwriting.</div>
            </div>
          </div>
          <button onClick={handleReload} className="btn" style={{ backgroundColor: 'var(--error)', color: 'white', border: 'none', padding: '0.5rem 1.5rem', fontWeight: 600 }}>
            Reload Latest
          </button>
        </div>
      )}

      <div className="settings-layout" style={{ display: 'grid', gridTemplateColumns: '250px 1fr', gap: '2rem', alignItems: 'start' }}>
        
        {/* Sidebar Tabs */}
        <div className="card" style={{ padding: '1rem 0' }}>
          <div style={{ padding: '0 1.25rem 0.5rem', fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Vehicle Configurations
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
            {VehicleTabs.map(tab => {
              const isActive = activeTab === tab.id;
              const tabHasConflict = conflicts[tab.id];
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  style={{
                    display: 'flex', alignItems: 'center', gap: '0.75rem',
                    padding: '0.75rem 1rem', border: 'none', margin: '0 0.75rem',
                    borderRadius: 'var(--r-md)',
                    background: isActive ? 'rgba(21,101,192,0.1)' : 'transparent',
                    color: isActive ? 'var(--brand-blue)' : 'var(--text-secondary)',
                    fontWeight: isActive ? 600 : 500,
                    textAlign: 'left', cursor: 'pointer', transition: 'all var(--t-fast)',
                    position: 'relative'
                  }}
                >
                  <tab.icon size={18} weight={isActive ? "fill" : "regular"} />
                  {tab.label}
                  {tabHasConflict && (
                     <div style={{ position: 'absolute', right: '1rem', width: 8, height: 8, borderRadius: '50%', backgroundColor: 'var(--error)' }} />
                  )}
                </button>
              );
            })}
          </div>
        </div>

        {/* Content Area */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem', opacity: hasConflict ? 0.5 : 1, pointerEvents: hasConflict ? 'none' : 'auto' }}>
          
          {/* Fare Components Card */}
          <div className="card" style={{ padding: '2rem' }}>
            <h2 style={{ fontSize: '1.25rem', fontWeight: 700, marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Gear size={22} style={{ color: 'var(--brand-teal)' }} />
              {VehicleTabs.find(t => t.id === activeTab)?.label} Components
            </h2>

            <div className="settings-grid">
              <div className="form-group">
                <label className="form-label">Base Fare (₹)</label>
                <div style={{ position: 'relative' }}>
                  <CurrencyInr size={18} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input type="number" className="form-input" style={{ paddingLeft: '2.5rem' }} value={currentSettings?.baseFare ?? ''} onChange={e => updateField('baseFare', e.target.value)} />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Included Distance (km)</label>
                <div style={{ position: 'relative' }}>
                  <MapTrifold size={18} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input type="number" className="form-input" style={{ paddingLeft: '2.5rem' }} value={currentSettings?.includedDistanceKm ?? ''} onChange={e => updateField('includedDistanceKm', e.target.value)} />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Rate per Extra Km (₹/km)</label>
                <div style={{ position: 'relative' }}>
                  <CurrencyInr size={18} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input type="number" className="form-input" style={{ paddingLeft: '2.5rem' }} value={currentSettings?.perKm ?? ''} onChange={e => updateField('perKm', e.target.value)} />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Rate per Minute (₹/min)</label>
                <div style={{ position: 'relative' }}>
                  <Clock size={18} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input type="number" className="form-input" style={{ paddingLeft: '2.5rem' }} value={currentSettings?.perMin ?? ''} onChange={e => updateField('perMin', e.target.value)} />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Minimum Fare (₹)</label>
                <div style={{ position: 'relative' }}>
                  <Money size={18} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input type="number" className="form-input" style={{ paddingLeft: '2.5rem' }} value={currentSettings?.minimumFare ?? ''} onChange={e => updateField('minimumFare', e.target.value)} />
                </div>
              </div>
              
              <div className="form-group">
                <label className="form-label">Platform Commission (%)</label>
                <div style={{ position: 'relative' }}>
                  <input type="number" className="form-input" value={currentSettings?.commission ?? ''} onChange={e => updateField('commission', e.target.value)} />
                  <span style={{ position: 'absolute', right: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontWeight: 600 }}>%</span>
                </div>
              </div>
            </div>
          </div>

          {/* Waiting Charges Card */}
          <div className="card" style={{ padding: '2rem' }}>
            <h2 style={{ fontSize: '1.25rem', fontWeight: 700, marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Timer size={22} style={{ color: 'var(--brand-teal)' }} />
              Waiting Charges
            </h2>
            <div className="settings-grid">
              <div className="form-group">
                <label className="form-label">Free Waiting Time (min)</label>
                <div style={{ position: 'relative' }}>
                  <Timer size={18} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input type="number" className="form-input" style={{ paddingLeft: '2.5rem' }} value={currentSettings?.freeWaitingMinutes ?? ''} onChange={e => updateField('freeWaitingMinutes', e.target.value)} />
                </div>
              </div>
              <div className="form-group">
                <label className="form-label">Charge After Free Time (₹/min)</label>
                <div style={{ position: 'relative' }}>
                  <Hourglass size={18} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input type="number" className="form-input" style={{ paddingLeft: '2.5rem' }} value={currentSettings?.waitingPerMin ?? ''} onChange={e => updateField('waitingPerMin', e.target.value)} />
                </div>
              </div>
            </div>
          </div>

          {/* Dynamic Pricing Card */}
          <div className="card" style={{ padding: '2rem', border: currentSettings.surgeEnabled ? '1px solid var(--brand-teal)' : 'none' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
              <h2 style={{ fontSize: '1.25rem', fontWeight: 700, margin: 0, display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <Lightning size={22} style={{ color: currentSettings.surgeEnabled ? 'var(--brand-teal)' : 'var(--text-muted)' }} />
                Dynamic Pricing
              </h2>
              <label style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', cursor: 'pointer' }}>
                <span style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-secondary)' }}>
                  {currentSettings.surgeEnabled ? 'Enabled' : 'Disabled'}
                </span>
                <div style={{ position: 'relative', width: '44px', height: '24px' }}>
                  <input 
                    type="checkbox" 
                    style={{ opacity: 0, width: 0, height: 0 }} 
                    checked={currentSettings.surgeEnabled} 
                    onChange={e => updateField('surgeEnabled', e.target.checked, false)}
                  />
                  <div style={{ 
                    position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, 
                    backgroundColor: currentSettings.surgeEnabled ? 'var(--brand-teal)' : '#e5e7eb',
                    borderRadius: '24px', transition: '0.3s',
                    cursor: 'pointer'
                  }}>
                    <div style={{
                      position: 'absolute', top: '2px', left: currentSettings.surgeEnabled ? '22px' : '2px',
                      width: '20px', height: '20px', backgroundColor: 'white', borderRadius: '50%', transition: '0.3s',
                      boxShadow: '0 1px 3px rgba(0,0,0,0.2)'
                    }} />
                  </div>
                </div>
              </label>
            </div>

            {currentSettings.surgeEnabled && (
              <div className="settings-grid animate-fade-in">
                <div className="form-group" style={{ gridColumn: '1 / -1' }}>
                  <label className="form-label">Surge Multiplier (x)</label>
                  <div style={{ position: 'relative', maxWidth: '300px' }}>
                    <Lightning size={18} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                    <input type="number" step="0.1" min="1.0" max="5.0" className="form-input" style={{ paddingLeft: '2.5rem' }} value={currentSettings?.surgeMultiplier ?? ''} onChange={e => updateField('surgeMultiplier', e.target.value)} />
                  </div>
                  <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.5rem' }}>E.g. 1.5x increases a ₹100 fare to ₹150.</p>
                </div>

                <div className="form-group" style={{ gridColumn: '1 / -1' }}>
                  <label className="form-label">Surge Reason</label>
                  <input type="text" className="form-input" placeholder="e.g. Heavy Rain, Rush Hour" value={currentSettings?.surgeReason ?? ''} onChange={e => updateField('surgeReason', e.target.value, false)} />
                </div>

                <div className="form-group">
                  <label className="form-label">Start Time</label>
                  <div style={{ position: 'relative' }}>
                    <CalendarBlank size={18} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                    <input type="datetime-local" className="form-input" style={{ paddingLeft: '2.5rem' }} value={currentSettings?.surgeStartAt || ''} onChange={e => updateField('surgeStartAt', e.target.value, false)} />
                  </div>
                </div>

                <div className="form-group">
                  <label className="form-label">End Time</label>
                  <div style={{ position: 'relative' }}>
                    <CalendarBlank size={18} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                    <input type="datetime-local" className="form-input" style={{ paddingLeft: '2.5rem' }} value={currentSettings?.surgeEndAt || ''} onChange={e => updateField('surgeEndAt', e.target.value, false)} />
                  </div>
                </div>
              </div>
            )}
          </div>
          
        </div>
      </div>
    </div>
  );
};

export default Settings;
