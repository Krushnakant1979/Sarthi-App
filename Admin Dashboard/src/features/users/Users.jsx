import React, { useEffect, useState, useMemo } from 'react';
import { db } from '../../config/firebase';
import { collection, onSnapshot, query, where } from 'firebase/firestore';
import { MagnifyingGlass, Users as UsersIcon, ShieldCheck, Star, Eye, Copy, Check } from '@phosphor-icons/react';
import { publicIdService } from '../../services/publicIdService';

const Users = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [copiedId, setCopiedId] = useState(null);

  useEffect(() => {
    const q = query(collection(db, 'users'), where('role', '==', 'user'));
    const unsub = onSnapshot(q, (snap) => {
      setUsers(snap.docs.map(doc => ({ id: doc.id, ...doc.data() })));
      
      // Auto-backfill publicIds
      snap.docs.forEach(docSnap => {
        if (!docSnap.data().publicId) {
          publicIdService.assignSequentialId(docSnap.id, 'user').catch(console.error);
        }
      });
      
      setLoading(false);
    }, (error) => {
      console.error(error);
      setLoading(false);
    });
    return () => unsub();
  }, []);

  const avgRating = useMemo(() => {
    const rated = users.filter(u => u.rating);
    if (rated.length === 0) return 0;
    const totalScore = rated.reduce((acc, u) => acc + Number(u.rating), 0);
    return (totalScore / rated.length).toFixed(1);
  }, [users]);

  const filtered = users.filter(u =>
    !search ||
    u.name?.toLowerCase().includes(search.toLowerCase()) ||
    u.email?.toLowerCase().includes(search.toLowerCase()) ||
    u.phone?.includes(search) ||
    u.publicId?.toLowerCase().includes(search.toLowerCase())
  );

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
        background: 'linear-gradient(135deg, #2e1065 0%, #4c1d95 100%)',
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
            <UsersIcon size={32} weight="duotone" style={{ color: '#A78BFA' }} /> 
            Passenger Management
          </h1>
          <p style={{ color: 'rgba(255,255,255,0.6)', fontSize: '1rem', marginTop: '0.5rem', marginLeft: '3.125rem' }}>
            Monitor and assist your network of registered users.
          </p>
        </div>
      </div>

      {/* 2. User KPI Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1.25rem', marginBottom: '1.5rem' }}>
        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(124,58,237,0.1)', color: '#7C3AED', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <UsersIcon size={18} weight="fill" />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Total Registered Users</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : users.length}
            </div>
          </div>
        </div>

        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(22,163,74,0.1)', color: 'var(--success)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <ShieldCheck size={18} weight="fill" />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Verified Accounts</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : (users.filter(u => u.phone).length || users.length)}
            </div>
          </div>
        </div>

        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(217,119,6,0.1)', color: 'var(--warning)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Star size={18} weight="fill" />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Avg Passenger Rating</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : avgRating}
            </div>
          </div>
        </div>
      </div>

      <div className="card">
        {/* 3. Redesigned Filters & Search */}
        <div style={{ padding: '1rem 1.5rem', borderBottom: '1px solid var(--border)', display: 'flex', gap: '1.5rem', alignItems: 'center', flexWrap: 'wrap', justifyContent: 'flex-end', background: 'rgba(255,255,255,0.5)', backdropFilter: 'blur(10px)', borderTopLeftRadius: 'var(--r-xl)', borderTopRightRadius: 'var(--r-xl)' }}>
          {/* Frosted Search */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', background: 'rgba(255,255,255,0.7)', border: '1px solid var(--border-strong)', borderRadius: 'var(--r-full)', padding: '0.5rem 1rem', minWidth: 300, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.02)' }}>
            <MagnifyingGlass size={16} style={{ color: 'var(--text-muted)', flexShrink: 0 }} />
            <input
              type="text"
              placeholder="Search by name, email or phone..."
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
                <th style={{ paddingLeft: '1.5rem' }}>User Profile</th>
                <th>Contact Number</th>
                <th>Avg Rating</th>
                <th style={{ textAlign: 'right', paddingRight: '1.5rem' }}>Manage</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan="4" className="table-empty">Loading users...</td></tr>
              ) : filtered.length === 0 ? (
                <tr><td colSpan="4" className="table-empty">No users found</td></tr>
              ) : filtered.map(user => (
                <tr key={user.id} style={{ cursor: 'pointer' }}>
                  <td style={{ paddingLeft: '1.5rem' }}>
                    <div className="user-row-info">
                      <div className="user-row-avatar" style={{ background: 'linear-gradient(135deg, #7C3AED, #5B21B6)', color: 'white' }}>
                        {user.name ? user.name.charAt(0).toUpperCase() : 'U'}
                      </div>
                      <div>
                        <div style={{ fontWeight: 600, fontSize: '0.9375rem', color: 'var(--text-primary)' }}>{user.name || 'Unknown User'}</div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginTop: '0.125rem' }}>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontFamily: 'monospace' }}>
                            {user.publicId || 'Generating...'}
                          </div>
                          {user.publicId && (
                            <button 
                              onClick={(e) => handleCopy(e, user.publicId)}
                              style={{ background: 'none', border: 'none', cursor: 'pointer', color: copiedId === user.publicId ? 'var(--success)' : 'var(--text-muted)', padding: 0, display: 'flex' }}
                              title="Copy ID"
                            >
                              {copiedId === user.publicId ? <Check size={14} weight="bold" /> : <Copy size={14} />}
                            </button>
                          )}
                        </div>
                        {user.email && <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.125rem' }}>{user.email}</div>}
                      </div>
                    </div>
                  </td>
                  <td>
                    <div style={{ fontWeight: 500, color: 'var(--text-primary)', fontSize: '0.875rem' }}>{user.phone || '—'}</div>
                  </td>
                  <td>
                    {user.rating ? (
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                        <Star size={14} weight="fill" style={{ color: 'var(--warning)' }} />
                        <span style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.875rem' }}>
                          {user.rating}
                        </span>
                      </div>
                    ) : (
                      <span style={{ color: 'var(--text-muted)', fontSize: '0.875rem' }}>No trips</span>
                    )}
                  </td>
                  <td style={{ paddingRight: '1.5rem' }}>
                    <div className="action-row" style={{ justifyContent: 'flex-end' }}>
                      <button 
                        className="btn btn-sm" 
                        style={{ background: 'var(--surface-2)', color: 'var(--text-secondary)', border: '1px solid var(--border)' }}
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
    </div>
  );
};

export default Users;
