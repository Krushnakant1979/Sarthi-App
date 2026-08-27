import React, { useState } from 'react';
import { CarProfile, Plus, Funnel, ListBullets, Taxi, Moped } from '@phosphor-icons/react';
import { useCaptains } from '../captains/hooks/useCaptains';

const Tabs = [
  { id: 'All Vehicle', label: 'All Vehicles', icon: ListBullets },
  { id: 'Auto Rikshaw', label: 'Auto Rikshaw', icon: Taxi },
  { id: 'Cab', label: 'Cab', icon: CarProfile },
  { id: 'Bike', label: 'Bike', icon: Moped },
];

export default function Vehicles() {
  const [filter, setFilter] = useState('All Vehicle');
  const { captains, loading } = useCaptains();

  // Extract vehicles from verified captains
  const vehicles = captains
    .filter(c => c.verificationStatus === 'verified' && c.vehicleType)
    .map(c => ({
      id: c.id,
      plate: c.vehicleDetails?.registrationNumber || c.registrationNumber || 'Pending Update',
      category: c.vehicleType,
      owner: c.name || 'Unknown',
      insuranceExpiry: 'Pending Update',
    }));

  const getFleetSize = (categoryName) => {
    return vehicles.filter(v => v.category.toLowerCase() === categoryName.toLowerCase()).length;
  };

  const filteredVehicles = filter === 'All Vehicle' 
    ? vehicles 
    : vehicles.filter(vh => vh.category.toLowerCase() === filter.toLowerCase());

  return (
    <div className="animate-fade-in">
      <div className="page-header">
        <div>
          <h1>Vehicle & Fleet Management</h1>
          <p>Configure ride categories and track fleet compliance</p>
        </div>
        <button className="btn btn-primary">
          <Plus size={18} weight="bold" />
          Add Vehicle
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
              return (
                <button
                  key={tab.id}
                  onClick={() => setFilter(tab.id)}
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
        <div className="card">
          <div style={{ padding: '1.5rem', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h2 style={{ fontSize: '1.1rem', fontWeight: 700 }}>Fleet Overview: {Tabs.find(t => t.id === filter)?.label}</h2>
            <div style={{ display: 'flex', gap: '0.5rem' }}>
              <button className="btn btn-secondary btn-sm" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <Funnel size={16} /> Advanced Filter
              </button>
            </div>
          </div>
          <table className="data-table">
            <thead>
              <tr>
                <th>Category</th>
                <th>Active Fleet Size</th>
                <th>Owner (Captain)</th>
                <th>Vehicle Plate</th>
                <th>Insurance Expiry</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={5} style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                    Loading fleet data...
                  </td>
                </tr>
              ) : filteredVehicles.length === 0 ? (
                <tr>
                  <td colSpan={5} style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                    No vehicles found in this category.
                  </td>
                </tr>
              ) : (
                filteredVehicles.map(vh => (
                  <tr key={vh.id}>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                      <CarProfile size={18} color="var(--brand-blue)" /> {vh.category}
                    </td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', color: 'var(--text-secondary)' }}>{getFleetSize(vh.category)} vehicles</td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', fontWeight: 500 }}>{vh.owner}</td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', fontWeight: 700, color: 'var(--brand-blue)' }}>{vh.plate}</td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', color: 'var(--text-secondary)' }}>{vh.insuranceExpiry}</td>
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
