import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { CarProfile, Plus, ListBullets, Taxi, Moped, Package, SteeringWheel } from '@phosphor-icons/react';
import { useCaptains } from '../captains/hooks/useCaptains';

const Tabs = [
  { id: 'all', label: 'All Vehicles', icon: ListBullets },
  { id: 'cab', label: 'Cabs / Cars', icon: CarProfile },
  { id: 'auto', label: 'Auto Rickshaws', icon: Taxi },
  { id: 'bike', label: 'Bikes / Moto', icon: Moped },
  { id: 'parcel', label: 'Parcel Fleet', icon: Package },
];

const getCategoryIcon = (category) => {
  const c = (category || '').toLowerCase();
  if (c.includes('bike') || c.includes('moped')) return <Moped size={18} color="#16a34a" weight="fill" />;
  if (c.includes('auto') || c.includes('rickshaw')) return <Taxi size={18} color="#d97706" weight="fill" />;
  if (c.includes('parcel')) return <Package size={18} color="#7c3aed" weight="fill" />;
  return <CarProfile size={18} color="#2563eb" weight="fill" />;
};

export default function Vehicles() {
  const [filter, setFilter] = useState('all');
  const [search, setSearch] = useState('');
  const { captains, loading } = useCaptains();
  const navigate = useNavigate();

  // Extract vehicles from captains
  const vehicles = captains
    .filter(c => c.vehicleType)
    .map(c => ({
      id: c.id,
      plate: c.vehicleDetails?.registrationNumber || c.vehicleNumber || c.registrationNumber || 'Pending Plate',
      category: c.vehicleType,
      owner: c.name || 'Unknown',
      status: c.verificationStatus || 'pending',
      insuranceExpiry: c.vehicleDetails?.insuranceExpiry || c.insuranceExpiry || 'Active',
      model: c.vehicleDetails?.model || c.vehicleModel || 'Standard',
    }));

  const getFleetSize = (catId) => {
    if (catId === 'all') return vehicles.length;
    return vehicles.filter(v => (v.category || '').toLowerCase() === catId.toLowerCase()).length;
  };

  const filteredVehicles = vehicles.filter(vh => {
    const matchesCat = filter === 'all' || (vh.category || '').toLowerCase() === filter.toLowerCase();
    if (!matchesCat) return false;
    if (!search.trim()) return true;
    const q = search.toLowerCase();
    return (
      vh.plate.toLowerCase().includes(q) ||
      vh.owner.toLowerCase().includes(q) ||
      vh.model.toLowerCase().includes(q) ||
      vh.category.toLowerCase().includes(q)
    );
  });

  return (
    <div className="animate-fade-in">
      <div className="page-header">
        <div>
          <h1>Vehicle & Fleet Management</h1>
          <p>Active fleet overview categorized by service type across verified and onboarded captains</p>
        </div>
        <button 
          onClick={() => navigate('/captains')} 
          className="btn btn-primary"
          style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem' }}
        >
          <SteeringWheel size={18} weight="bold" />
          Onboard Captain & Vehicle
        </button>
      </div>

      <div className="settings-layout">
        {/* Sidebar Tabs */}
        <div className="card" style={{ padding: '1rem 0' }}>
          <div style={{ padding: '0 1.25rem 0.5rem', fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Fleet Categories
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
            {Tabs.map(tab => {
              const isActive = filter === tab.id;
              const count = getFleetSize(tab.id);
              return (
                <button
                  key={tab.id}
                  onClick={() => setFilter(tab.id)}
                  style={{
                    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                    padding: '0.75rem 1rem', border: 'none', margin: '0 0.75rem',
                    borderRadius: 'var(--r-md)',
                    background: isActive ? 'rgba(21,101,192,0.1)' : 'transparent',
                    color: isActive ? 'var(--brand-blue)' : 'var(--text-secondary)',
                    fontWeight: isActive ? 600 : 500,
                    textAlign: 'left', cursor: 'pointer', transition: 'all var(--t-fast)',
                  }}
                >
                  <span style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                    <tab.icon size={18} weight={isActive ? "fill" : "regular"} />
                    {tab.label}
                  </span>
                  <span style={{ 
                    fontSize: '0.75rem', 
                    fontWeight: 700, 
                    padding: '0.1rem 0.45rem', 
                    borderRadius: 'var(--r-full)',
                    background: isActive ? 'var(--brand-blue)' : 'var(--surface-3)',
                    color: isActive ? '#fff' : 'var(--text-muted)'
                  }}>
                    {count}
                  </span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Content Area */}
        <div className="card">
          <div style={{ padding: '1.25rem 1.5rem', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
            <h2 style={{ fontSize: '1.1rem', fontWeight: 700, margin: 0 }}>
              {Tabs.find(t => t.id === filter)?.label} ({filteredVehicles.length})
            </h2>
            <div style={{ maxWidth: 300, width: '100%' }}>
              <input
                type="text"
                placeholder="Search plate, captain, model..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                style={{
                  width: '100%',
                  padding: '0.5rem 0.85rem',
                  fontSize: '0.85rem',
                  borderRadius: 'var(--r-md)',
                  border: '1px solid var(--border)',
                  background: 'var(--surface-1)',
                  color: 'var(--text-primary)',
                  outline: 'none',
                }}
              />
            </div>
          </div>
          <table className="data-table">
            <thead>
              <tr>
                <th style={{ paddingLeft: '1.25rem' }}>Category</th>
                <th>Vehicle Model / Type</th>
                <th>Owner (Captain)</th>
                <th>Vehicle Plate</th>
                <th>Insurance Expiry</th>
                <th>Verification Status</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={6} style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                    Loading fleet data...
                  </td>
                </tr>
              ) : filteredVehicles.length === 0 ? (
                <tr>
                  <td colSpan={6} style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                    No vehicles found in this category.
                  </td>
                </tr>
              ) : (
                filteredVehicles.map(vh => (
                  <tr key={vh.id}>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-primary)' }}>
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem', textTransform: 'capitalize' }}>
                        {getCategoryIcon(vh.category)} {vh.category}
                      </span>
                    </td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', color: 'var(--text-secondary)' }}>{vh.model}</td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', fontWeight: 600 }}>{vh.owner}</td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', fontWeight: 700, color: 'var(--brand-blue)', fontFamily: 'monospace' }}>{vh.plate}</td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem' }}>
                      <span className={`badge ${vh.insuranceExpiry.toLowerCase().includes('expired') ? 'badge-error' : 'badge-neutral'}`}>
                        {vh.insuranceExpiry}
                      </span>
                    </td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem' }}>
                      <span className={`badge ${vh.status === 'verified' ? 'badge-success' : (vh.status === 'rejected' ? 'badge-error' : 'badge-warning')}`}>
                        {vh.status}
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
