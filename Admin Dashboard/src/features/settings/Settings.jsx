import React, { useState, useEffect } from 'react';
import { db } from '../../config/firebase';
import { doc, onSnapshot, setDoc, serverTimestamp } from 'firebase/firestore';
import { useToast } from '../../context/ToastContext';
import { ConfirmModal } from '../../components/common/ConfirmModal';
import { 
  Gear, ShieldWarning, MapPin, Envelope, Phone, 
  CheckCircle, Plus, Trash, Globe, Power, WarningCircle
} from '@phosphor-icons/react';

export default function Settings() {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [newZone, setNewZone] = useState('');
  const [confirmDialog, setConfirmDialog] = useState(null);
  const { showToast } = useToast();

  const [settings, setSettings] = useState({
    isPlatformActive: true,
    supportEmail: 'support@sarthi.com',
    supportPhone: '+91 1800-000-000',
    activeZones: ['Ahmedabad', 'Gandhinagar', 'Surat', 'Vadodara'],
  });

  useEffect(() => {
    const docRef = doc(db, 'config', 'global_settings');
    const unsub = onSnapshot(docRef, (snap) => {
      if (snap.exists()) {
        const data = snap.data();
        setSettings({
          isPlatformActive: data.isPlatformActive !== false,
          supportEmail: data.supportEmail || 'support@sarthi.com',
          supportPhone: data.supportPhone || '+91 1800-000-000',
          activeZones: Array.isArray(data.activeZones) ? data.activeZones : ['Ahmedabad', 'Gandhinagar', 'Surat', 'Vadodara'],
        });
      }
      setLoading(false);
    }, (err) => {
      console.error('Error fetching global settings:', err);
      showToast('Failed to load settings from server', 'error');
      setLoading(false);
    });

    return () => unsub();
  }, [showToast]);

  const handleSave = async (updatedData) => {
    setSaving(true);
    const dataToSave = updatedData || settings;
    try {
      const docRef = doc(db, 'config', 'global_settings');
      await setDoc(docRef, {
        ...dataToSave,
        updatedAt: serverTimestamp(),
      }, { merge: true });
      showToast('Platform settings saved successfully!', 'success');
    } catch (err) {
      console.error('Error saving settings:', err);
      showToast(`Save failed: ${err.message}`, 'error');
    } finally {
      setSaving(false);
    }
  };

  const handleToggleKillSwitch = () => {
    const nextState = !settings.isPlatformActive;
    setConfirmDialog({
      title: nextState ? 'Re-activate Platform' : 'Emergency Platform Kill Switch',
      message: nextState
        ? 'Are you sure you want to RE-ACTIVATE platform ride requests for all users?'
        : '⚠️ DANGER: Are you sure you want to ACTIVATE THE EMERGENCY KILL SWITCH? This will immediately suspend all ride bookings across the platform!',
      confirmText: nextState ? 'Re-activate' : 'Activate Kill Switch',
      isDestructive: !nextState,
      onConfirm: async () => {
        setConfirmDialog(null);
        const updated = { ...settings, isPlatformActive: nextState };
        setSettings(updated);
        await handleSave(updated);
      }
    });
  };

  const handleAddZone = (e) => {
    e.preventDefault();
    const city = newZone.trim();
    if (!city) return;
    if (settings.activeZones.includes(city)) {
      showToast('This operational zone already exists.', 'warning');
      return;
    }
    const updated = { ...settings, activeZones: [...settings.activeZones, city] };
    setSettings(updated);
    setNewZone('');
    handleSave(updated);
  };

  const handleRemoveZone = (city) => {
    setConfirmDialog({
      title: 'Remove Service Zone',
      message: `Are you sure you want to remove "${city}" from active service zones?`,
      confirmText: 'Remove Zone',
      isDestructive: true,
      onConfirm: async () => {
        setConfirmDialog(null);
        const updated = { ...settings, activeZones: settings.activeZones.filter(z => z !== city) };
        setSettings(updated);
        await handleSave(updated);
      }
    });
  };

  if (loading) {
    return (
      <div className="animate-fade-in" style={{ padding: '2rem' }}>
        <div className="spinner"></div>
      </div>
    );
  }

  return (
    <div className="animate-fade-in" style={{ paddingBottom: '3rem' }}>
      {/* Header Banner */}
      <div style={{
        background: 'linear-gradient(135deg, #1E1B4B 0%, #312E81 100%)',
        borderRadius: 'var(--r-xl)',
        padding: '2rem 3rem',
        color: 'white',
        marginBottom: '2rem',
        boxShadow: 'var(--shadow-md)',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        position: 'relative',
        overflow: 'hidden'
      }}>
        <div style={{ position: 'relative', zIndex: 1 }}>
          <h1 style={{ fontSize: '2rem', fontWeight: 800, margin: 0, display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <Gear size={32} weight="duotone" style={{ color: '#A5B4FC' }} />
            Platform Control & Zones
          </h1>
          <p style={{ color: 'rgba(255,255,255,0.7)', fontSize: '1rem', marginTop: '0.5rem', marginLeft: '3.125rem' }}>
            Control master platform status, operational cities, and global contact parameters.
          </p>
        </div>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '1.75rem' }}>
        {/* 1. MASTER EMERGENCY KILL SWITCH */}
        <div className="card" style={{ 
          padding: '2rem',
          border: settings.isPlatformActive ? '1px solid var(--border)' : '2px solid var(--error)',
          background: settings.isPlatformActive ? 'var(--surface-1)' : 'rgba(239, 68, 68, 0.05)',
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '1.25rem' }}>
              <div style={{
                width: 52,
                height: 52,
                borderRadius: 'var(--r-lg)',
                background: settings.isPlatformActive ? 'rgba(22, 163, 74, 0.12)' : 'rgba(239, 68, 68, 0.15)',
                color: settings.isPlatformActive ? 'var(--success)' : 'var(--error)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center'
              }}>
                <Power size={28} weight="bold" />
              </div>
              <div>
                <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0, display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  Master Booking Kill Switch
                  <span className={`badge ${settings.isPlatformActive ? 'badge-success' : 'badge-error'}`} style={{ fontSize: '0.75rem' }}>
                    {settings.isPlatformActive ? 'Platform Live' : 'Platform Suspended'}
                  </span>
                </h3>
                <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', marginTop: '0.25rem', marginBottom: 0 }}>
                  {settings.isPlatformActive 
                    ? 'All ride booking and captain matching services are operational across all zones.'
                    : 'Emergency mode active! Ride bookings and dispatch queues are currently blocked platform-wide.'}
                </p>
              </div>
            </div>

            <button
              onClick={handleToggleKillSwitch}
              disabled={saving}
              style={{
                background: settings.isPlatformActive ? 'var(--error)' : 'var(--success)',
                color: 'white',
                border: 'none',
                padding: '0.75rem 1.5rem',
                borderRadius: 'var(--r-md)',
                fontWeight: 700,
                fontSize: '0.9rem',
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                cursor: 'pointer',
                boxShadow: 'var(--shadow-sm)',
                transition: 'all 0.2s ease',
              }}
            >
              <Power size={18} weight="bold" />
              {settings.isPlatformActive ? 'Activate Kill Switch' : 'Resume Normal Operations'}
            </button>
          </div>
        </div>

        {/* 2. OPERATIONAL ZONES & SERVICE CITIES */}
        <div className="card" style={{ padding: '2rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem', flexWrap: 'wrap', gap: '1rem' }}>
            <div>
              <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0, display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <Globe size={22} color="var(--brand-blue)" />
                Operating Service Zones
              </h3>
              <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', marginTop: '0.25rem', marginBottom: 0 }}>
                Active metropolitan cities and geographic areas where Sarthi rides are supported.
              </p>
            </div>
            <div style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-muted)' }}>
              Total Active Cities: <strong style={{ color: 'var(--text-primary)' }}>{settings.activeZones.length}</strong>
            </div>
          </div>

          {/* Add Zone Form */}
          <form onSubmit={handleAddZone} style={{ display: 'flex', gap: '0.75rem', marginBottom: '1.5rem', maxWidth: '500px' }}>
            <input
              type="text"
              className="form-input"
              placeholder="e.g. Mumbai, Pune, Rajkot..."
              value={newZone}
              onChange={(e) => setNewZone(e.target.value)}
              style={{ flex: 1 }}
            />
            <button type="submit" className="btn btn-primary" style={{ whiteSpace: 'nowrap' }}>
              <Plus size={16} weight="bold" /> Add City
            </button>
          </form>

          {/* Zones Chips List */}
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem' }}>
            {settings.activeZones.map(zone => (
              <div 
                key={zone} 
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.5rem',
                  padding: '0.5rem 1rem',
                  borderRadius: 'var(--r-full)',
                  background: 'var(--surface-2)',
                  border: '1px solid var(--border)',
                  fontSize: '0.875rem',
                  fontWeight: 600,
                  color: 'var(--text-primary)',
                  boxShadow: '0 1px 3px rgba(0,0,0,0.04)'
                }}
              >
                <MapPin size={16} color="var(--brand-blue)" weight="fill" />
                <span>{zone}</span>
                <button
                  type="button"
                  onClick={() => handleRemoveZone(zone)}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: 'var(--text-muted)',
                    cursor: 'pointer',
                    padding: 0,
                    marginLeft: '0.25rem',
                    display: 'flex',
                    alignItems: 'center',
                  }}
                  title={`Remove ${zone}`}
                >
                  <Trash size={14} />
                </button>
              </div>
            ))}
          </div>
        </div>

        {/* 3. SUPPORT CONTACT SETTINGS */}
        <div className="card" style={{ padding: '2rem' }}>
          <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: '0 0 1.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Envelope size={22} color="var(--brand-blue)" />
            Support & Communications Contact
          </h3>
          
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '1.5rem', marginBottom: '1.5rem' }}>
            <div className="form-group">
              <label className="form-label" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <Envelope size={16} /> Official Support Email
              </label>
              <input
                type="email"
                className="form-input"
                value={settings.supportEmail}
                onChange={(e) => setSettings({ ...settings, supportEmail: e.target.value })}
                placeholder="support@sarthi.com"
              />
            </div>

            <div className="form-group">
              <label className="form-label" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <Phone size={16} /> Toll-Free / Support Helpline
              </label>
              <input
                type="text"
                className="form-input"
                value={settings.supportPhone}
                onChange={(e) => setSettings({ ...settings, supportPhone: e.target.value })}
                placeholder="+91 1800-000-000"
              />
            </div>
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <button
              onClick={() => handleSave()}
              disabled={saving}
              className="btn btn-primary"
              style={{ minWidth: '150px' }}
            >
              {saving ? 'Saving...' : 'Save Changes'}
            </button>
          </div>
        </div>
      </div>

      {confirmDialog && (
        <ConfirmModal
          isOpen={true}
          title={confirmDialog.title}
          message={confirmDialog.message}
          confirmText={confirmDialog.confirmText}
          isDestructive={confirmDialog.isDestructive}
          onConfirm={confirmDialog.onConfirm}
          onCancel={() => setConfirmDialog(null)}
        />
      )}
    </div>
  );
}
