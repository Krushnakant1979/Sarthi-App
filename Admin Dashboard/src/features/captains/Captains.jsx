import React, { useState, useMemo } from 'react';
import { useCaptains } from './hooks/useCaptains';
import { captainService } from './services/captainService';
import { 
  MagnifyingGlass, Circle, XCircle, 
  Eye, SteeringWheel, WarningCircle, 
  Star, Moped, Taxi, CarProfile, Package, Check, Copy
} from '@phosphor-icons/react';
import { CaptainVerifyModal } from './components/CaptainVerifyModal';
import { useToast } from '../../context/ToastContext';

const TABS = [
  { id: 'all',      label: 'All Captains' },
  { id: 'pending',  label: 'Pending' },
  { id: 'verified', label: 'Verified' },
  { id: 'rejected', label: 'Rejected' },
];

const getVehicleIcon = (type) => {
  const t = type?.toLowerCase() || '';
  if (t.includes('bike') || t.includes('motor')) return <Moped weight="fill" size={16} />;
  if (t.includes('auto') || t.includes('rickshaw')) return <Taxi weight="fill" size={16} />;
  if (t.includes('parcel')) return <Package weight="fill" size={16} />;
  return <CarProfile weight="fill" size={16} />;
};

const Captains = () => {
  const { captains, loading } = useCaptains();
  const [tab, setTab] = useState('all');
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState(null);
  const [copiedId, setCopiedId] = useState(null);
  const toast = useToast();

  const handleVerify = async (captain, e) => {
    e?.stopPropagation();
    try {
      await captainService.verifyCaptain(captain.id);
      toast(`${captain.name || 'Captain'} has been verified!`, 'success');
    } catch (err) {
      toast(err.message, 'error');
    }
  };

  const handleReject = async (captain, e) => {
    e?.stopPropagation();
    try {
      await captainService.rejectCaptain(captain.id);
      toast(`${captain.name || 'Captain'} documents rejected.`, 'info');
    } catch (err) {
      toast(err.message, 'error');
    }
  };



  const counts = {
    all:      captains.length,
    pending:  captains.filter(c => c.verificationStatus === 'pending').length,
    verified: captains.filter(c => c.verificationStatus === 'verified').length,
    rejected: captains.filter(c => c.verificationStatus === 'rejected').length,
  };

  const avgRating = useMemo(() => {
    const rated = captains.filter(c => c.ratingScore && c.ratingCount);
    if (rated.length === 0) return 0;
    const totalScore = rated.reduce((acc, c) => acc + (c.ratingScore / c.ratingCount), 0);
    return (totalScore / rated.length).toFixed(1);
  }, [captains]);

  const filtered = captains.filter(c => {
    const statusMatch = tab === 'all' || c.verificationStatus === tab;
    const searchMatch = !search ||
      c.name?.toLowerCase().includes(search.toLowerCase()) ||
      c.phone?.includes(search) ||
      c.email?.toLowerCase().includes(search.toLowerCase()) ||
      c.vehicleDetails?.registrationNumber?.toLowerCase().includes(search.toLowerCase()) ||
      c.publicId?.toLowerCase().includes(search.toLowerCase());
    return statusMatch && searchMatch;
  });

  const handleCopy = (e, id) => {
    e.stopPropagation();
    navigator.clipboard.writeText(id);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  return (
    <div className="animate-fade-in" style={{ paddingBottom: '2rem' }}>
      
      {/* 1. Premium Header Banner */}
      <div style={{ 
        background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 100%)',
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
            <SteeringWheel size={32} weight="duotone" style={{ color: 'var(--brand-teal)' }} /> 
            Fleet Management
          </h1>
          <p style={{ color: 'rgba(255,255,255,0.6)', fontSize: '1rem', marginTop: '0.5rem', marginLeft: '3.125rem' }}>
            Monitor and manage your network of Sarthi captains.
          </p>
        </div>
      </div>

      {/* 2. Fleet KPI Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1.25rem', marginBottom: '1.5rem' }}>
        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(21,101,192,0.1)', color: '#1565C0', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <SteeringWheel size={18} weight="fill" />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Total Fleet Size</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : counts.all}
            </div>
          </div>
        </div>

        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem', border: counts.pending > 0 ? '1px solid rgba(217,119,6,0.3)' : 'none', background: counts.pending > 0 ? 'var(--warning-bg)' : 'var(--surface-1)' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(217,119,6,0.1)', color: 'var(--warning)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <WarningCircle size={18} weight={counts.pending > 0 ? "fill" : "regular"} />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: counts.pending > 0 ? '#92400E' : 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Pending Approvals</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: counts.pending > 0 ? '#92400E' : 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : counts.pending}
            </div>
          </div>
        </div>

        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(22,163,74,0.1)', color: 'var(--success)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Star size={18} weight="fill" />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Avg Fleet Rating</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : avgRating}
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
                onClick={() => setTab(t.id)}
                style={{
                  padding: '0.5rem 1rem',
                  borderRadius: 'var(--r-full)',
                  border: 'none',
                  background: tab === t.id ? 'var(--surface-1)' : 'transparent',
                  color: tab === t.id ? 'var(--brand-blue)' : 'var(--text-secondary)',
                  fontWeight: 500,
                  fontSize: '0.875rem',
                  cursor: 'pointer',
                  transition: 'all var(--t-fast)',
                  boxShadow: tab === t.id ? 'var(--shadow-sm)' : 'none',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.5rem'
                }}
              >
                {t.label}
                <span style={{ 
                  background: tab === t.id ? 'rgba(21,101,192,0.1)' : 'var(--surface-3)', 
                  color: tab === t.id ? 'var(--brand-blue)' : 'var(--text-muted)',
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
              placeholder="Search fleet..."
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
                <th style={{ paddingLeft: '1.5rem' }}>Captain</th>
                <th>Contact</th>
                <th>Vehicle</th>
                <th>Status</th>
                <th>Rating</th>
                <th style={{ textAlign: 'right', paddingRight: '1.5rem' }}>Manage</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr key="empty-loading"><td colSpan="6" className="table-empty">Syncing fleet data...</td></tr>
              ) : filtered.length === 0 ? (
                <tr key="empty-nodata"><td colSpan="6" className="table-empty">No captains found</td></tr>
              ) : filtered.map(cap => (
                <tr
                  key={cap.id}
                  style={{ cursor: 'pointer' }}
                  onClick={() => setSelected(cap)}
                >
                  <td style={{ paddingLeft: '1.5rem' }}>
                    <div className="user-row-info">
                      <div className="user-row-avatar" style={{ background: 'var(--brand-blue)', color: 'white' }}>
                        {cap.name ? cap.name.charAt(0).toUpperCase() : 'C'}
                      </div>
                      <div>
                        <div style={{ fontWeight: 600, fontSize: '0.9375rem', color: 'var(--text-primary)' }}>{cap.name || 'Unknown'}</div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginTop: '0.125rem' }}>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontFamily: 'monospace' }}>
                            {cap.publicId || 'Generating...'}
                          </div>
                          {cap.publicId && (
                            <button 
                              onClick={(e) => handleCopy(e, cap.publicId)}
                              style={{ background: 'none', border: 'none', cursor: 'pointer', color: copiedId === cap.publicId ? 'var(--success)' : 'var(--text-muted)', padding: 0, display: 'flex' }}
                              title="Copy ID"
                            >
                              {copiedId === cap.publicId ? <Check size={14} weight="bold" /> : <Copy size={14} />}
                            </button>
                          )}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <div style={{ fontWeight: 500, color: 'var(--text-primary)', fontSize: '0.875rem' }}>{cap.phone || '—'}</div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{cap.email || 'No email'}</div>
                  </td>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                      <div style={{ width: 28, height: 28, borderRadius: 'var(--r-sm)', background: 'var(--surface-2)', border: '1px solid var(--border)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-secondary)' }}>
                        {getVehicleIcon(cap.vehicleType)}
                      </div>
                      <div>
                        <div style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-primary)', textTransform: 'capitalize' }}>
                          {cap.vehicleType || 'Unknown'}
                        </div>
                        {cap.vehicleDetails?.registrationNumber && (
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                            {cap.vehicleDetails.registrationNumber}
                          </div>
                        )}
                      </div>
                    </div>
                  </td>
                  <td>
                    <span className={`badge ${
                      cap.verificationStatus === 'verified' ? 'badge-success' :
                      cap.verificationStatus === 'rejected' ? 'badge-error' :
                      'badge-warning'
                    } ${cap.verificationStatus === 'pending' ? 'badge-pulse' : ''}`}>
                      <Circle size={6} weight="fill" />
                      {cap.verificationStatus || 'pending'}
                    </span>
                  </td>
                  <td>
                    {cap.ratingScore && cap.ratingCount ? (
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                        <Star size={14} weight="fill" style={{ color: 'var(--warning)' }} />
                        <span style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.875rem' }}>
                          {(cap.ratingScore / cap.ratingCount).toFixed(1)}
                        </span>
                        <span style={{ color: 'var(--text-muted)', fontSize: '0.75rem' }}>
                          ({cap.ratingCount})
                        </span>
                      </div>
                    ) : (
                      <span style={{ color: 'var(--text-muted)', fontSize: '0.875rem' }}>No trips</span>
                    )}
                  </td>
                  <td style={{ paddingRight: '1.5rem' }}>
                    <div className="action-row" style={{ justifyContent: 'flex-end' }} onClick={e => e.stopPropagation()}>
                      {cap.verificationStatus !== 'verified' && (
                        <button 
                          className="btn btn-sm" 
                          style={{ background: 'rgba(22, 163, 74, 0.1)', color: 'var(--success)', border: 'none' }}
                          onClick={e => handleVerify(cap, e)} 
                          title="Verify Captain"
                        >
                          <Check size={16} weight="bold" />
                        </button>
                      )}
                      {cap.verificationStatus !== 'rejected' && (
                        <button 
                          className="btn btn-sm" 
                          style={{ background: 'rgba(220, 38, 38, 0.1)', color: 'var(--error)', border: 'none' }}
                          onClick={e => handleReject(cap, e)} 
                          title="Reject"
                        >
                          <XCircle size={16} weight="bold" />
                        </button>
                      )}
                      <button 
                        className="btn btn-sm" 
                        style={{ background: 'var(--surface-2)', color: 'var(--text-secondary)', border: '1px solid var(--border)' }}
                        onClick={() => setSelected(cap)} 
                        title="View Full Profile"
                      >
                        <Eye size={16} weight="bold" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Detail / Verify Modal */}
      {selected && (
        <CaptainVerifyModal
          captain={selected}
          onClose={() => setSelected(null)}
        />
      )}
    </div>
  );
};

export default Captains;
