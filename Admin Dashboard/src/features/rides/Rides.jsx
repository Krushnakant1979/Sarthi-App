import React, { useEffect, useState } from 'react';
import { db } from '../../config/firebase';
import { collection, getDocs, query, orderBy, limit } from 'firebase/firestore';
import { MagnifyingGlass, Circle, Eye, MapTrifold, NavigationArrow, CheckCircle, XCircle } from '@phosphor-icons/react';
import { RideDetailsModal } from './components/RideDetailsModal';

const statusConfig = {
  completed: { class: 'badge-success', label: 'Completed' },
  cancelled:  { class: 'badge-error',   label: 'Cancelled'  },
  ongoing:    { class: 'badge-warning',  label: 'Ongoing'    },
  pending:    { class: 'badge-neutral',  label: 'Pending'    },
};

const TABS = [
  { id: 'all',       label: 'All Trips' },
  { id: 'ongoing',   label: 'Ongoing' },
  { id: 'completed', label: 'Completed' },
  { id: 'cancelled', label: 'Cancelled' },
  { id: 'pending',   label: 'Pending' },
];

const Rides = () => {
  const [rides, setRides] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selectedRide, setSelectedRide] = useState(null);

  useEffect(() => {
    const fetchRides = async () => {
      try {
        const q = query(collection(db, 'ride_requests'), orderBy('createdAt', 'desc'), limit(200));
        const snap = await getDocs(q);
        setRides(snap.docs.map(doc => ({ id: doc.id, ...doc.data() })));
      } catch (error) {
        console.error(error);
      } finally {
        setLoading(false);
      }
    };
    fetchRides();
  }, []);

  const counts = rides.reduce((acc, r) => {
    acc[r.status] = (acc[r.status] || 0) + 1;
    acc['all'] = (acc['all'] || 0) + 1;
    return acc;
  }, { all: 0, ongoing: 0, completed: 0, cancelled: 0, pending: 0 });

  const filtered = rides.filter(r => {
    if (statusFilter !== 'all' && r.status !== statusFilter) return false;
    if (search) {
      const q = search.toLowerCase();
      return r.id.toLowerCase().includes(q) ||
        r.pickup?.address?.toLowerCase().includes(q) ||
        r.destination?.address?.toLowerCase().includes(q);
    }
    return true;
  });

  return (
    <div className="animate-fade-in" style={{ paddingBottom: '2rem' }}>
      
      {/* 1. Premium Header Banner */}
      <div style={{ 
        background: 'linear-gradient(135deg, #064E3B 0%, #0F766E 100%)',
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
        <div style={{ position: 'absolute', right: '-5%', top: '-50%', width: '300px', height: '300px', background: 'radial-gradient(circle, rgba(255,255,255,0.05) 0%, rgba(255,255,255,0) 70%)', borderRadius: '50%' }}></div>
        
        <div style={{ position: 'relative', zIndex: 1 }}>
          <h1 style={{ fontSize: '2rem', fontWeight: 800, margin: 0, letterSpacing: '-0.03em', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <MapTrifold size={32} weight="duotone" style={{ color: '#5EEAD4' }} /> 
            Trip Operations
          </h1>
          <p style={{ color: 'rgba(255,255,255,0.6)', fontSize: '1rem', marginTop: '0.5rem', marginLeft: '3.125rem' }}>
            Monitor and manage live rides across the network.
          </p>
        </div>
      </div>

      {/* 2. Operations KPI Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1.25rem', marginBottom: '1.5rem' }}>
        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem', border: counts.ongoing > 0 ? '1px solid rgba(217,119,6,0.3)' : 'none', background: counts.ongoing > 0 ? 'var(--warning-bg)' : 'var(--surface-1)' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(217,119,6,0.1)', color: 'var(--warning)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <NavigationArrow size={18} weight="fill" />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: counts.ongoing > 0 ? '#92400E' : 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Ongoing Rides</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: counts.ongoing > 0 ? '#92400E' : 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : counts.ongoing}
            </div>
          </div>
        </div>

        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(22,163,74,0.1)', color: 'var(--success)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <CheckCircle size={18} weight="fill" />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Completed (Last 200)</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : counts.completed}
            </div>
          </div>
        </div>

        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(220,38,38,0.1)', color: 'var(--error)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <XCircle size={18} weight="fill" />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Cancelled (Last 200)</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : counts.cancelled}
            </div>
          </div>
        </div>
      </div>

      <div className="card">
        {/* 3. Redesigned Filters & Search */}
        <div style={{ padding: '1rem 1.5rem', borderBottom: '1px solid var(--border)', display: 'flex', gap: '1.5rem', alignItems: 'center', flexWrap: 'wrap', justifyContent: 'space-between', background: 'rgba(255,255,255,0.5)', backdropFilter: 'blur(10px)', borderTopLeftRadius: 'var(--r-xl)', borderTopRightRadius: 'var(--r-xl)' }}>
          
          {/* Segmented Control */}
          <div style={{ display: 'flex', background: 'var(--surface-2)', padding: '0.25rem', borderRadius: 'var(--r-full)', border: '1px solid var(--border)' }}>
            {TABS.map(t => (
              <button
                key={t.id}
                onClick={() => setStatusFilter(t.id)}
                style={{
                  padding: '0.5rem 1rem',
                  borderRadius: 'var(--r-full)',
                  border: 'none',
                  background: statusFilter === t.id ? 'var(--surface-1)' : 'transparent',
                  color: statusFilter === t.id ? 'var(--brand-teal)' : 'var(--text-secondary)',
                  fontWeight: 500,
                  fontSize: '0.875rem',
                  cursor: 'pointer',
                  transition: 'all var(--t-fast)',
                  boxShadow: statusFilter === t.id ? 'var(--shadow-sm)' : 'none',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.5rem'
                }}
              >
                {t.label}
                <span style={{ 
                  background: statusFilter === t.id ? 'rgba(0,166,166,0.1)' : 'var(--surface-3)', 
                  color: statusFilter === t.id ? 'var(--brand-teal)' : 'var(--text-muted)',
                  padding: '0.125rem 0.5rem', 
                  borderRadius: 'var(--r-full)', 
                  fontSize: '0.75rem' 
                }}>
                  {counts[t.id]}
                </span>
              </button>
            ))}
          </div>

          {/* Frosted Search */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', background: 'rgba(255,255,255,0.7)', border: '1px solid var(--border-strong)', borderRadius: 'var(--r-full)', padding: '0.5rem 1rem', minWidth: 260, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.02)' }}>
            <MagnifyingGlass size={16} style={{ color: 'var(--text-muted)', flexShrink: 0 }} />
            <input
              type="text"
              placeholder="Search by ID or address..."
              value={search}
              onChange={e => setSearch(e.target.value)}
              style={{ border: 'none', background: 'transparent', outline: 'none', fontSize: '0.875rem', width: '100%', color: 'var(--text-primary)' }}
            />
          </div>
        </div>

        {/* 4. Upgraded Table */}
        <div style={{ overflowX: 'auto', padding: '0.5rem' }}>
          <table className="data-table">
            <thead>
              <tr>
                <th style={{ paddingLeft: '1.5rem' }}>Ride ID</th>
                <th>Status</th>
                <th>Pickup Route</th>
                <th>Dropoff Route</th>
                <th>Fare</th>
                <th style={{ textAlign: 'right', paddingRight: '1.5rem' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan="6" className="table-empty">Syncing trips...</td></tr>
              ) : filtered.length === 0 ? (
                <tr><td colSpan="6" className="table-empty">No rides match your filters</td></tr>
              ) : filtered.map(ride => {
                const sc = statusConfig[ride.status] || { class: 'badge-neutral', label: ride.status || 'Unknown' };
                return (
                  <tr 
                    key={ride.id} 
                    style={{ cursor: 'pointer' }}
                    onClick={() => setSelectedRide(ride)}
                  >
                    <td style={{ paddingLeft: '1.5rem' }}>
                      <div style={{ fontFamily: 'monospace', fontSize: '0.875rem', color: 'var(--text-primary)', fontWeight: 600 }}>
                        #{ride.id.slice(0, 8)}
                      </div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                        {ride.id.slice(8, 16)}
                      </div>
                    </td>
                    <td>
                      <span className={`badge ${sc.class}`}>
                        <Circle size={6} weight="fill" />
                        {sc.label}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <div style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--success)' }}></div>
                        <div style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', color: 'var(--text-primary)', fontSize: '0.875rem' }}>
                          {ride.pickup?.address || '—'}
                        </div>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <div style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--error)' }}></div>
                        <div style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', color: 'var(--text-primary)', fontSize: '0.875rem' }}>
                          {ride.destination?.address || '—'}
                        </div>
                      </div>
                    </td>
                    <td style={{ fontWeight: 700, color: ride.fareEstimate ? 'var(--text-primary)' : 'var(--text-muted)' }}>
                      {ride.fareEstimate ? `₹${ride.fareEstimate}` : '—'}
                    </td>
                    <td style={{ paddingRight: '1.5rem' }}>
                      <div className="action-row" style={{ justifyContent: 'flex-end' }}>
                        <button 
                          className="btn btn-sm" 
                          style={{ background: 'var(--surface-2)', color: 'var(--text-secondary)', border: '1px solid var(--border)' }}
                          title="View Full Ride Details"
                        >
                          <Eye size={16} weight="bold" />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      <RideDetailsModal 
        ride={selectedRide} 
        onClose={() => setSelectedRide(null)} 
      />
    </div>
  );
};

export default Rides;
