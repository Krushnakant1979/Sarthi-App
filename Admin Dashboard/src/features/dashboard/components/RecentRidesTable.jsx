import React from 'react';
import { Circle } from '@phosphor-icons/react';

export const RecentRidesTable = ({ rides, loading, onNavigateToRides }) => {
  return (
    <div className="card" style={{ padding: '1.5rem' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1.5rem' }}>
        <h2 style={{ fontSize: '1.125rem', fontWeight: 700, margin: 0 }}>Recent Activity</h2>
        <button 
          onClick={onNavigateToRides} 
          style={{ background: 'transparent', border: 'none', color: 'var(--brand-blue)', fontWeight: 600, fontSize: '0.875rem', cursor: 'pointer' }}
        >
          View all
        </button>
      </div>
      
      <table className="data-table">
        <thead>
          <tr>
            <th>Ride ID</th>
            <th>Status</th>
            <th>Pickup</th>
            <th>Dropoff</th>
          </tr>
        </thead>
        <tbody>
          {loading ? (
            <tr><td colSpan="4" className="table-empty">Loading…</td></tr>
          ) : rides.length === 0 ? (
            <tr><td colSpan="4" className="table-empty">No ride data available</td></tr>
          ) : rides.map(ride => (
            <tr key={ride.id}>
              <td style={{ fontFamily: 'monospace', fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                #{ride.id.slice(0, 8)}
              </td>
              <td>
                <span className={`badge ${ride.status === 'completed' ? 'badge-success' : ride.status === 'cancelled' ? 'badge-error' : 'badge-warning'}`}>
                  <Circle size={6} weight="fill" />
                  {ride.status || 'unknown'}
                </span>
              </td>
              <td style={{ maxWidth: 180, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {ride.pickup?.address || '—'}
              </td>
              <td style={{ maxWidth: 180, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {ride.destination?.address || '—'}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};
