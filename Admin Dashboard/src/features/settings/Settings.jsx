import React, { useState, useEffect } from 'react';
import { db } from '../../config/firebase';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { useToast } from '../../context/ToastContext';
import { Gear, CurrencyInr, CheckCircle, Warning, Moped, Taxi, CarProfile, Package } from '@phosphor-icons/react';

const defaultPricing = {
  bike: { baseFare: 30, perKm: 10, commission: 15 },
  auto: { baseFare: 40, perKm: 12, commission: 15 },
  cab: { baseFare: 60, perKm: 16, commission: 20 },
  parcel: { baseFare: 45, perKm: 11, commission: 15 },
};

const VehicleTabs = [
  { id: 'bike', label: 'Bike Fare', icon: Moped },
  { id: 'auto', label: 'Auto Rickshaw', icon: Taxi },
  { id: 'cab', label: 'Cab Fare', icon: CarProfile },
  { id: 'parcel', label: 'Parcel Fare', icon: Package },
];

const Settings = () => {
  const [activeTab, setActiveTab] = useState('bike');
  const [pricing, setPricing] = useState(defaultPricing);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const { addToast } = useToast();

  useEffect(() => {
    const fetchSettings = async () => {
      try {
        const docRef = doc(db, 'settings', 'pricing');
        const snap = await getDoc(docRef);
        if (snap.exists()) {
          setPricing({ ...defaultPricing, ...snap.data() });
        }
      } catch (error) {
        console.error("Error fetching pricing", error);
        addToast("Failed to load settings", "error");
      } finally {
        setLoading(false);
      }
    };
    fetchSettings();
  }, [addToast]);

  const handleSave = async () => {
    setSaving(true);
    try {
      await setDoc(doc(db, 'settings', 'pricing'), pricing);
      addToast("Pricing settings saved successfully!", "success");
    } catch (error) {
      console.error(error);
      addToast("Error saving settings", "error");
    } finally {
      setSaving(false);
    }
  };

  const updateField = (field, value) => {
    setPricing(prev => ({
      ...prev,
      [activeTab]: {
        ...prev[activeTab],
        [field]: Number(value) || 0
      }
    }));
  };

  if (loading) {
    return <div style={{ padding: '4rem', textAlign: 'center', color: 'var(--text-muted)' }}>Loading settings...</div>;
  }

  const currentSettings = pricing[activeTab];

  return (
    <div className="animate-fade-in">
      <div className="page-header" style={{ marginBottom: '2rem' }}>
        <div>
          <h1>Global Settings</h1>
          <p>Configure pricing models, commissions, and platform rules</p>
        </div>
        <button 
          onClick={handleSave} 
          disabled={saving}
          className="btn btn-primary"
        >
          {saving ? <div className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }}></div> : <CheckCircle size={18} />}
          Save Changes
        </button>
      </div>

      <div className="settings-layout">
        
        {/* Sidebar Tabs */}
        <div className="card" style={{ padding: '1rem 0' }}>
          <div style={{ padding: '0 1.25rem 0.5rem', fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Pricing Configuration
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
            {VehicleTabs.map(tab => {
              const isActive = activeTab === tab.id;
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
                  }}
                >
                  <tab.icon size={18} weight={isActive ? "fill" : "regular"} />
                  {tab.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* Content Area */}
        <div className="card" style={{ padding: '2rem' }}>
          <h2 style={{ fontSize: '1.25rem', fontWeight: 700, marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Gear size={22} style={{ color: 'var(--brand-teal)' }} />
            {VehicleTabs.find(t => t.id === activeTab)?.label} Configuration
          </h2>

          <div className="settings-grid">
            
            <div className="form-group">
              <label className="form-label" style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                Base Fare <span style={{ color: 'var(--text-muted)', fontSize: '0.75rem', fontWeight: 400 }}>(Minimum amount)</span>
              </label>
              <div style={{ position: 'relative' }}>
                <CurrencyInr size={18} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                <input 
                  type="number" 
                  className="form-input" 
                  style={{ paddingLeft: '2.5rem' }}
                  value={currentSettings?.baseFare || ''} 
                  onChange={e => updateField('baseFare', e.target.value)} 
                />
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Per-KM Rate</label>
              <div style={{ position: 'relative' }}>
                <CurrencyInr size={18} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                <input 
                  type="number" 
                  className="form-input" 
                  style={{ paddingLeft: '2.5rem' }}
                  value={currentSettings?.perKm || ''} 
                  onChange={e => updateField('perKm', e.target.value)} 
                />
              </div>
            </div>

            <div className="form-group">
              <label className="form-label" style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                Platform Commission <span style={{ color: 'var(--text-muted)', fontSize: '0.75rem', fontWeight: 400 }}>(Percentage)</span>
              </label>
              <div style={{ position: 'relative' }}>
                <input 
                  type="number" 
                  className="form-input" 
                  value={currentSettings?.commission || ''} 
                  onChange={e => updateField('commission', e.target.value)} 
                />
                <span style={{ position: 'absolute', right: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontWeight: 600 }}>%</span>
              </div>
            </div>

          </div>

          <div className="alert-warning">
            <Warning size={20} weight="fill" style={{ color: 'var(--warning)', flexShrink: 0, marginTop: '2px' }} />
            <div>
              <div style={{ fontSize: '0.875rem', fontWeight: 700, color: '#92400E', marginBottom: '0.25rem' }}>Important Note</div>
              <div style={{ fontSize: '0.8125rem', color: '#B45309', lineHeight: 1.5 }}>
                Changing these values will immediately affect all new rides created on the platform. Active rides will retain their originally calculated estimates. Ensure your mobile app reads from the <code>settings/pricing</code> Firestore document.
              </div>
            </div>
          </div>
          
        </div>
      </div>
    </div>
  );
};

export default Settings;
