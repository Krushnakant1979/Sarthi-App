import React, { useState, useEffect, useMemo } from 'react';
import { createPortal } from 'react-dom';
import { db } from '../../../config/firebase';
import {
  doc,
  updateDoc,
  collection,
  query,
  where,
  onSnapshot,
  serverTimestamp,
} from 'firebase/firestore';
import { useToast } from '../../../context/ToastContext';
import {
  User,
  Phone,
  Envelope,
  Star,
  Car,
  ShieldCheck,
  X,
  Check,
  Copy,
  MapPin,
  Circle,
  CurrencyInr,
  Calendar,
  Clock,
  NavigationArrow,
  CheckCircle,
  XCircle,
  WarningCircle,
} from '@phosphor-icons/react';
import { publicIdService } from '../../../services/publicIdService';
import { logAdminAction } from '../../../services/auditService';
import { ConfirmModal } from '../../../components/common/ConfirmModal';

/* Robustly format timestamp/date */
const formatDate = (val) => {
  if (!val) return '—';
  try {
    let d;
    if (typeof val?.toDate === 'function') d = val.toDate();
    else if (val?.seconds) d = new Date(val.seconds * 1000);
    else if (val instanceof Date) d = val;
    else d = new Date(val);
    if (isNaN(d.getTime())) return String(val);
    return d.toLocaleString('en-IN', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    });
  } catch (e) {
    return '—';
  }
};

const statusConfig = {
  searching:   { class: 'badge-neutral', label: 'Searching' },
  pending:     { class: 'badge-neutral', label: 'Searching' },
  accepted:    { class: 'badge-warning', label: 'Accepted' },
  arriving:    { class: 'badge-warning', label: 'Arriving' },
  arrived:     { class: 'badge-warning', label: 'Arrived' },
  in_progress: { class: 'badge-warning', label: 'In Progress' },
  ongoing:     { class: 'badge-warning', label: 'In Progress' },
  completed:   { class: 'badge-success', label: 'Completed' },
  cancelled:   { class: 'badge-error',   label: 'Cancelled' },
};

export const UserDetailsModal = ({ user, onClose }) => {
  const [userData, setUserData] = useState(user);
  const [rides, setRides] = useState([]);
  const [loadingRides, setLoadingRides] = useState(true);
  const [activeTab, setActiveTab] = useState('overview'); // 'overview' | 'trips' | 'actions'
  const [copiedField, setCopiedField] = useState(null);
  const [pendingRole, setPendingRole] = useState(null);
  const [showBlockModal, setShowBlockModal] = useState(false);
  const [updating, setUpdating] = useState(false);
  const toast = useToast();

  const showToast = (msg, type = 'info') => {
    if (typeof toast === 'function') toast(msg, type);
    else if (toast?.showToast) toast.showToast(msg, type);
  };

  // Close on Escape key
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  // 1. Real-time User Profile Document Listener
  useEffect(() => {
    if (!user?.id) return;
    const unsub = onSnapshot(
      doc(db, 'users', user.id),
      (docSnap) => {
        if (docSnap.exists()) {
          const data = docSnap.data();
          setUserData({
            id: docSnap.id,
            ...data,
            publicId: user.publicId || publicIdService.formatId(docSnap.id),
          });
        }
      },
      (err) => {
        console.error('Error listening to user real-time updates:', err);
      }
    );
    return () => unsub();
  }, [user?.id, user?.publicId]);

  // 2. Real-time Rides Query Listener for this user
  useEffect(() => {
    if (!user?.id) return;
    setLoadingRides(true);
    const q = query(collection(db, 'ride_requests'), where('userId', '==', user.id));
    const unsub = onSnapshot(
      q,
      (snap) => {
        const list = snap.docs.map((d) => ({
          id: d.id,
          publicId: publicIdService.formatId(d.id),
          ...d.data(),
        }));

        // Sort client-side descending by createdAt
        list.sort((a, b) => {
          const getTime = (val) => {
            if (!val) return 0;
            if (val.seconds) return val.seconds * 1000;
            if (typeof val?.toDate === 'function') return val.toDate().getTime();
            if (val instanceof Date) return val.getTime();
            const parsed = new Date(val).getTime();
            return isNaN(parsed) ? 0 : parsed;
          };
          return getTime(b.createdAt) - getTime(a.createdAt);
        });

        setRides(list);
        setLoadingRides(false);
      },
      (err) => {
        console.error('Error listening to user rides in real time:', err);
        setLoadingRides(false);
      }
    );
    return () => unsub();
  }, [user?.id]);

  // Derived real-time stats
  const stats = useMemo(() => {
    const total = rides.length;
    const completed = rides.filter((r) => r.status === 'completed').length;
    const cancelled = rides.filter((r) => r.status === 'cancelled').length;
    const ongoing = rides.filter((r) =>
      ['searching', 'pending', 'accepted', 'arriving', 'arrived', 'in_progress', 'ongoing'].includes(r.status)
    ).length;

    const totalSpent = rides
      .filter((r) => r.status === 'completed')
      .reduce((sum, r) => sum + Number(r.fare || r.fareEstimate || 0), 0);

    return {
      total,
      completed,
      cancelled,
      ongoing,
      totalSpent: Math.round(totalSpent),
    };
  }, [rides]);

  const handleCopy = (e, text, field) => {
    e.stopPropagation();
    if (!text) return;
    navigator.clipboard.writeText(text);
    setCopiedField(field);
    setTimeout(() => setCopiedField(null), 2000);
  };

  const isBlocked = userData?.isBlocked === true || userData?.status === 'blocked';

  // Role Change Confirmation
  const confirmRoleChange = async () => {
    if (!pendingRole) return;
    const newRole = pendingRole;
    setUpdating(true);
    try {
      await updateDoc(doc(db, 'users', userData.id), {
        role: newRole,
        updatedAt: serverTimestamp(),
      });
      await logAdminAction('user_role_changed', userData.id, {
        userName: userData.name || '',
        oldRole: userData.role || 'user',
        newRole,
      });
      showToast(`User role successfully changed to ${newRole === 'user' ? 'Passenger' : newRole}`, 'success');
      setPendingRole(null);
    } catch (err) {
      console.error('Error changing user role:', err);
      showToast(`Failed to update role: ${err.message}`, 'error');
    } finally {
      setUpdating(false);
    }
  };

  // Block / Unblock Confirmation
  const confirmToggleBlock = async () => {
    setUpdating(true);
    const newBlockedVal = !isBlocked;
    const newStatus = newBlockedVal ? 'blocked' : 'active';
    try {
      await updateDoc(doc(db, 'users', userData.id), {
        isBlocked: newBlockedVal,
        status: newStatus,
        updatedAt: serverTimestamp(),
      });
      await logAdminAction(newBlockedVal ? 'user_blocked' : 'user_unblocked', userData.id, {
        userName: userData.name || '',
        userEmail: userData.email || '',
        newStatus,
      });
      showToast(
        newBlockedVal ? 'Passenger account has been blocked.' : 'Passenger account has been activated.',
        'success'
      );
      setShowBlockModal(false);
    } catch (err) {
      console.error('Error toggling block state:', err);
      showToast(`Action failed: ${err.message}`, 'error');
    } finally {
      setUpdating(false);
    }
  };

  if (!user) return null;

  return createPortal(
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className="modal"
        onClick={(e) => e.stopPropagation()}
        style={{
          maxWidth: '680px',
          width: '100%',
          maxHeight: '92vh',
          display: 'flex',
          flexDirection: 'column',
          padding: 0,
          overflow: 'hidden',
          borderRadius: 'var(--r-xl)',
          boxShadow: '0 25px 50px -12px rgba(15, 23, 42, 0.45)',
        }}
      >
        {/* 1. Header Banner */}
        <div
          style={{
            background: 'linear-gradient(135deg, #1e1b4b 0%, #312e81 60%, #4338ca 100%)',
            padding: '1.25rem 1.75rem',
            color: 'white',
            position: 'relative',
            overflow: 'hidden',
            flexShrink: 0,
          }}
        >
          {/* Decorative radial lighting */}
          <div
            style={{
              position: 'absolute',
              right: '-10%',
              top: '-40%',
              width: '260px',
              height: '260px',
              background: 'radial-gradient(circle, rgba(167, 139, 250, 0.25) 0%, rgba(255,255,255,0) 70%)',
              borderRadius: '50%',
              pointerEvents: 'none',
            }}
          />

          {/* Top Actions Row: Live Synced indicator & Close */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.875rem' }}>
            <div
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.45rem',
                background: 'rgba(34, 197, 94, 0.15)',
                border: '1px solid rgba(34, 197, 94, 0.35)',
                padding: '0.25rem 0.75rem',
                borderRadius: 'var(--r-full)',
                fontSize: '0.75rem',
                color: '#4ADE80',
                fontWeight: 700,
                letterSpacing: '0.02em',
              }}
            >
              <span
                style={{
                  width: 7,
                  height: 7,
                  borderRadius: '50%',
                  background: '#4ADE80',
                  boxShadow: '0 0 8px #4ADE80',
                  display: 'inline-block',
                }}
              />
              Live Real-Time Synced
            </div>

            <button
              onClick={onClose}
              style={{
                background: 'rgba(255,255,255,0.12)',
                border: '1px solid rgba(255,255,255,0.15)',
                borderRadius: 'var(--r-full)',
                color: 'white',
                width: 32,
                height: 32,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer',
                transition: 'all 0.2s ease',
              }}
              title="Close Profile"
            >
              <X size={16} weight="bold" />
            </button>
          </div>

          {/* User Hero Details */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', position: 'relative', zIndex: 1 }}>
            <div
              style={{
                width: 56,
                height: 56,
                borderRadius: 'var(--r-full)',
                background: 'linear-gradient(135deg, #7c3aed, #4c1d95)',
                border: '2.5px solid rgba(255, 255, 255, 0.25)',
                color: 'white',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '1.5rem',
                fontWeight: 800,
                boxShadow: '0 6px 16px rgba(0,0,0,0.3)',
                flexShrink: 0,
              }}
            >
              {userData.profilePictureUrl ? (
                <img
                  src={userData.profilePictureUrl}
                  alt={userData.name}
                  style={{ width: '100%', height: '100%', borderRadius: '50%', objectFit: 'cover' }}
                />
              ) : userData.name ? (
                userData.name.charAt(0).toUpperCase()
              ) : (
                <User size={28} />
              )}
            </div>

            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap' }}>
                <h2 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 800, letterSpacing: '-0.02em', color: '#FFFFFF', lineHeight: 1.2 }}>
                  {userData.name || 'Passenger Profile'}
                </h2>
                <span
                  style={{
                    fontSize: '0.6875rem',
                    fontWeight: 700,
                    textTransform: 'uppercase',
                    padding: '0.15rem 0.5rem',
                    borderRadius: 'var(--r-full)',
                    background: isBlocked ? 'rgba(239, 68, 68, 0.25)' : 'rgba(34, 197, 94, 0.25)',
                    color: isBlocked ? '#FCA5A5' : '#86EFAC',
                    border: isBlocked ? '1px solid rgba(239, 68, 68, 0.4)' : '1px solid rgba(34, 197, 94, 0.4)',
                  }}
                >
                  {isBlocked ? 'Blocked' : 'Active Account'}
                </span>
                <span
                  style={{
                    fontSize: '0.6875rem',
                    fontWeight: 700,
                    textTransform: 'uppercase',
                    padding: '0.15rem 0.5rem',
                    borderRadius: 'var(--r-full)',
                    background: 'rgba(167, 139, 250, 0.2)',
                    color: '#DDD6FE',
                    border: '1px solid rgba(167, 139, 250, 0.3)',
                  }}
                >
                  {userData.role === 'admin' ? 'Admin' : userData.role === 'captain' ? 'Captain' : 'Passenger'}
                </span>
              </div>

              <div
                style={{
                  fontSize: '0.75rem',
                  color: '#C7D2FE',
                  fontFamily: 'monospace',
                  marginTop: '0.25rem',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.5rem',
                }}
              >
                <span>ID: {userData.publicId || publicIdService.formatId(userData.id)}</span>
                <button
                  onClick={(e) => handleCopy(e, userData.publicId || publicIdService.formatId(userData.id), 'id')}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: copiedField === 'id' ? '#4ADE80' : '#A5B4FC',
                    cursor: 'pointer',
                    padding: 0,
                    display: 'flex',
                    alignItems: 'center',
                  }}
                  title="Copy ID"
                >
                  {copiedField === 'id' ? <Check size={14} weight="bold" /> : <Copy size={14} />}
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* 2. Real-Time KPI Stat Cards */}
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(4, 1fr)',
            gap: '0.75rem',
            padding: '0.875rem 1.5rem',
            background: 'var(--surface-2)',
            borderBottom: '1px solid var(--border)',
            flexShrink: 0,
          }}
        >
          {/* Total Rides */}
          <div
            style={{
              padding: '0.75rem',
              background: 'var(--surface-1)',
              borderRadius: 'var(--r-md)',
              border: '1px solid var(--border)',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', color: 'var(--brand-blue)', marginBottom: '0.25rem' }}>
              <Car size={16} weight="bold" />
              <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase' }}>Trips</span>
            </div>
            <div style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--text-primary)' }}>
              {loadingRides ? '...' : stats.total}
            </div>
          </div>

          {/* Completed */}
          <div
            style={{
              padding: '0.75rem',
              background: 'var(--surface-1)',
              borderRadius: 'var(--r-md)',
              border: '1px solid var(--border)',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', color: 'var(--success)', marginBottom: '0.25rem' }}>
              <CheckCircle size={16} weight="fill" />
              <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase' }}>Completed</span>
            </div>
            <div style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--text-primary)' }}>
              {loadingRides ? '...' : stats.completed}
            </div>
          </div>

          {/* Total Spent */}
          <div
            style={{
              padding: '0.75rem',
              background: 'var(--surface-1)',
              borderRadius: 'var(--r-md)',
              border: '1px solid var(--border)',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', color: 'var(--warning)', marginBottom: '0.25rem' }}>
              <CurrencyInr size={16} weight="bold" />
              <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase' }}>Spent</span>
            </div>
            <div style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--text-primary)' }}>
              {loadingRides ? '...' : `₹${stats.totalSpent.toLocaleString('en-IN')}`}
            </div>
          </div>

          {/* Rating */}
          <div
            style={{
              padding: '0.75rem',
              background: 'var(--surface-1)',
              borderRadius: 'var(--r-md)',
              border: '1px solid var(--border)',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', color: 'var(--warning)', marginBottom: '0.25rem' }}>
              <Star size={16} weight="fill" />
              <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase' }}>Rating</span>
            </div>
            <div style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--text-primary)' }}>
              {userData.rating || userData.ratingScore || (stats.completed > 0 ? '5.0' : '—')}
            </div>
          </div>
        </div>

        {/* 3. Navigation Tabs */}
        <div
          style={{
            display: 'flex',
            padding: '0 1.5rem',
            borderBottom: '1px solid var(--border)',
            background: 'var(--surface-1)',
            gap: '1.5rem',
            flexShrink: 0,
          }}
        >
          <button
            onClick={() => setActiveTab('overview')}
            style={{
              background: 'none',
              border: 'none',
              padding: '0.75rem 0.25rem',
              fontSize: '0.875rem',
              fontWeight: 700,
              color: activeTab === 'overview' ? 'var(--brand-blue)' : 'var(--text-secondary)',
              borderBottom: activeTab === 'overview' ? '2px solid var(--brand-blue)' : '2px solid transparent',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '0.375rem',
            }}
          >
            <User size={16} /> Overview & Profile
          </button>

          <button
            onClick={() => setActiveTab('trips')}
            style={{
              background: 'none',
              border: 'none',
              padding: '0.75rem 0.25rem',
              fontSize: '0.875rem',
              fontWeight: 700,
              color: activeTab === 'trips' ? 'var(--brand-blue)' : 'var(--text-secondary)',
              borderBottom: activeTab === 'trips' ? '2px solid var(--brand-blue)' : '2px solid transparent',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '0.375rem',
            }}
          >
            <Car size={16} /> Live Trips ({rides.length})
          </button>

          <button
            onClick={() => setActiveTab('actions')}
            style={{
              background: 'none',
              border: 'none',
              padding: '0.75rem 0.25rem',
              fontSize: '0.875rem',
              fontWeight: 700,
              color: activeTab === 'actions' ? 'var(--brand-blue)' : 'var(--text-secondary)',
              borderBottom: activeTab === 'actions' ? '2px solid var(--brand-blue)' : '2px solid transparent',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '0.375rem',
            }}
          >
            <ShieldCheck size={16} /> Admin Controls
          </button>
        </div>

        {/* 4. Tab Body Content */}
        <div className="modal-body" style={{ padding: '1.25rem 1.5rem', overflowY: 'auto', flex: 1, minHeight: 0 }}>
          {/* TAB 1: OVERVIEW */}
          {activeTab === 'overview' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
              {/* Contact Information */}
              <div
                style={{
                  background: 'var(--surface-2)',
                  border: '1px solid var(--border)',
                  borderRadius: 'var(--r-lg)',
                  padding: '1.25rem',
                }}
              >
                <div style={{ fontSize: '0.8125rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '0.875rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <User size={16} style={{ color: 'var(--brand-blue)' }} /> Contact Details
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                  {/* Phone */}
                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '0.75rem 1rem',
                      background: 'var(--surface-1)',
                      borderRadius: 'var(--r-md)',
                      border: '1px solid var(--border)',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                      <Phone size={18} style={{ color: 'var(--brand-blue)' }} />
                      <div>
                        <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 600 }}>Phone Number</div>
                        <div style={{ fontSize: '0.9375rem', fontWeight: 600, color: 'var(--text-primary)' }}>
                          {userData.phone || 'Not provided'}
                        </div>
                      </div>
                    </div>

                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                      {userData.phone && (
                        <>
                          <a
                            href={`tel:${userData.phone}`}
                            className="btn btn-sm"
                            style={{
                              padding: '0.3rem 0.6rem',
                              fontSize: '0.75rem',
                              background: 'rgba(21, 101, 192, 0.1)',
                              color: 'var(--brand-blue)',
                              border: '1px solid rgba(21, 101, 192, 0.2)',
                            }}
                          >
                            Call
                          </a>
                          <button
                            onClick={(e) => handleCopy(e, userData.phone, 'phone')}
                            style={{
                              background: 'none',
                              border: 'none',
                              cursor: 'pointer',
                              color: copiedField === 'phone' ? 'var(--success)' : 'var(--text-muted)',
                              padding: '0.25rem',
                              display: 'flex',
                            }}
                            title="Copy Phone"
                          >
                            {copiedField === 'phone' ? <Check size={16} weight="bold" /> : <Copy size={16} />}
                          </button>
                        </>
                      )}
                    </div>
                  </div>

                  {/* Email */}
                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '0.75rem 1rem',
                      background: 'var(--surface-1)',
                      borderRadius: 'var(--r-md)',
                      border: '1px solid var(--border)',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', minWidth: 0 }}>
                      <Envelope size={18} style={{ color: 'var(--brand-blue)', flexShrink: 0 }} />
                      <div style={{ minWidth: 0 }}>
                        <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 600 }}>Email Address</div>
                        <div
                          style={{
                            fontSize: '0.9375rem',
                            fontWeight: 600,
                            color: 'var(--text-primary)',
                            whiteSpace: 'nowrap',
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                          }}
                        >
                          {userData.email || 'Not provided'}
                        </div>
                      </div>
                    </div>

                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flexShrink: 0 }}>
                      {userData.email && (
                        <>
                          <a
                            href={`mailto:${userData.email}`}
                            className="btn btn-sm"
                            style={{
                              padding: '0.3rem 0.6rem',
                              fontSize: '0.75rem',
                              background: 'rgba(21, 101, 192, 0.1)',
                              color: 'var(--brand-blue)',
                              border: '1px solid rgba(21, 101, 192, 0.2)',
                            }}
                          >
                            Email
                          </a>
                          <button
                            onClick={(e) => handleCopy(e, userData.email, 'email')}
                            style={{
                              background: 'none',
                              border: 'none',
                              cursor: 'pointer',
                              color: copiedField === 'email' ? 'var(--success)' : 'var(--text-muted)',
                              padding: '0.25rem',
                              display: 'flex',
                            }}
                            title="Copy Email"
                          >
                            {copiedField === 'email' ? <Check size={16} weight="bold" /> : <Copy size={16} />}
                          </button>
                        </>
                      )}
                    </div>
                  </div>
                </div>
              </div>

              {/* Account Meta & Security Details */}
              <div
                style={{
                  background: 'var(--surface-2)',
                  border: '1px solid var(--border)',
                  borderRadius: 'var(--r-lg)',
                  padding: '1.25rem',
                }}
              >
                <div style={{ fontSize: '0.8125rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '0.875rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <ShieldCheck size={16} style={{ color: 'var(--brand-blue)' }} /> Account & Security
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '0.75rem' }}>
                  {/* Account Status */}
                  <div style={{ padding: '0.75rem 1rem', background: 'var(--surface-1)', borderRadius: 'var(--r-md)', border: '1px solid var(--border)' }}>
                    <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 600 }}>Account Status</div>
                    <div style={{ marginTop: '0.25rem', display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                      <span className={`badge ${isBlocked ? 'badge-error' : 'badge-success'}`}>
                        {isBlocked ? 'Blocked / Restricted' : 'Active & Verified'}
                      </span>
                    </div>
                  </div>

                  {/* Registered On */}
                  <div style={{ padding: '0.75rem 1rem', background: 'var(--surface-1)', borderRadius: 'var(--r-md)', border: '1px solid var(--border)' }}>
                    <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 600 }}>Member Since</div>
                    <div style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-primary)', marginTop: '0.25rem' }}>
                      {formatDate(userData.createdAt)}
                    </div>
                  </div>

                  {/* Firebase UID */}
                  <div style={{ gridColumn: 'span 2', padding: '0.75rem 1rem', background: 'var(--surface-1)', borderRadius: 'var(--r-md)', border: '1px solid var(--border)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <div>
                      <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 600 }}>Firebase User UID</div>
                      <div style={{ fontSize: '0.8125rem', fontFamily: 'monospace', color: 'var(--text-secondary)', marginTop: '0.125rem' }}>
                        {userData.id}
                      </div>
                    </div>
                    <button
                      onClick={(e) => handleCopy(e, userData.id, 'uid')}
                      style={{
                        background: 'none',
                        border: 'none',
                        cursor: 'pointer',
                        color: copiedField === 'uid' ? 'var(--success)' : 'var(--text-muted)',
                        padding: '0.25rem',
                        display: 'flex',
                      }}
                      title="Copy UID"
                    >
                      {copiedField === 'uid' ? <Check size={16} weight="bold" /> : <Copy size={16} />}
                    </button>
                  </div>
                </div>
              </div>

              {/* Saved Locations (if present) */}
              {(userData.homeAddress || userData.workAddress) && (
                <div
                  style={{
                    background: 'var(--surface-2)',
                    border: '1px solid var(--border)',
                    borderRadius: 'var(--r-lg)',
                    padding: '1.25rem',
                  }}
                >
                  <div style={{ fontSize: '0.8125rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '0.875rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    <MapPin size={16} style={{ color: 'var(--brand-blue)' }} /> Saved Addresses
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                    {userData.homeAddress && (
                      <div style={{ display: 'flex', gap: '0.75rem', padding: '0.75rem 1rem', background: 'var(--surface-1)', borderRadius: 'var(--r-md)', border: '1px solid var(--border)' }}>
                        <MapPin size={18} style={{ color: 'var(--success)', flexShrink: 0, marginTop: '0.125rem' }} />
                        <div>
                          <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 600 }}>Home</div>
                          <div style={{ fontSize: '0.875rem', color: 'var(--text-primary)', marginTop: '0.125rem' }}>
                            {userData.homeAddress.address || (typeof userData.homeAddress === 'string' ? userData.homeAddress : 'Saved')}
                          </div>
                        </div>
                      </div>
                    )}

                    {userData.workAddress && (
                      <div style={{ display: 'flex', gap: '0.75rem', padding: '0.75rem 1rem', background: 'var(--surface-1)', borderRadius: 'var(--r-md)', border: '1px solid var(--border)' }}>
                        <MapPin size={18} style={{ color: 'var(--brand-blue)', flexShrink: 0, marginTop: '0.125rem' }} />
                        <div>
                          <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 600 }}>Work</div>
                          <div style={{ fontSize: '0.875rem', color: 'var(--text-primary)', marginTop: '0.125rem' }}>
                            {userData.workAddress.address || (typeof userData.workAddress === 'string' ? userData.workAddress : 'Saved')}
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>
          )}

          {/* TAB 2: LIVE TRIPS HISTORY */}
          {activeTab === 'trips' && (
            <div>
              {loadingRides ? (
                <div style={{ textAlign: 'center', padding: '3rem 1rem', color: 'var(--text-muted)' }}>
                  Loading real-time passenger trips...
                </div>
              ) : rides.length === 0 ? (
                <div
                  style={{
                    textAlign: 'center',
                    padding: '3.5rem 1.5rem',
                    background: 'var(--surface-2)',
                    borderRadius: 'var(--r-lg)',
                    border: '1px dashed var(--border)',
                  }}
                >
                  <div
                    style={{
                      width: 52,
                      height: 52,
                      borderRadius: '50%',
                      background: 'rgba(21, 101, 192, 0.1)',
                      color: 'var(--brand-blue)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      margin: '0 auto 1rem',
                    }}
                  >
                    <Car size={26} />
                  </div>
                  <h4 style={{ margin: '0 0 0.35rem', color: 'var(--text-primary)', fontSize: '1rem', fontWeight: 700 }}>
                    No Trips Found
                  </h4>
                  <p style={{ margin: 0, color: 'var(--text-muted)', fontSize: '0.875rem' }}>
                    This passenger has not requested any rides on the platform yet.
                  </p>
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.875rem' }}>
                  {rides.map((ride) => {
                    const sc = statusConfig[ride.status] || { class: 'badge-neutral', label: ride.status || 'Unknown' };
                    return (
                      <div
                        key={ride.id}
                        style={{
                          background: 'var(--surface-1)',
                          borderRadius: 'var(--r-lg)',
                          border: '1px solid var(--border)',
                          padding: '1rem 1.25rem',
                          boxShadow: 'var(--shadow-xs)',
                          transition: 'border-color 0.2s ease',
                        }}
                      >
                        {/* Trip Top Header */}
                        <div
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between',
                            borderBottom: '1px solid var(--border)',
                            paddingBottom: '0.625rem',
                            marginBottom: '0.75rem',
                          }}
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                            <span style={{ fontSize: '0.8125rem', fontWeight: 700, fontFamily: 'monospace', color: 'var(--brand-blue)' }}>
                              #{ride.publicId || publicIdService.formatId(ride.id)}
                            </span>
                            <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                              • {formatDate(ride.createdAt)}
                            </span>
                          </div>

                          <span className={`badge ${sc.class}`} style={{ fontSize: '0.75rem', textTransform: 'capitalize' }}>
                            {sc.label}
                          </span>
                        </div>

                        {/* Route Pick & Drop */}
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem', marginBottom: '0.75rem' }}>
                          <div style={{ display: 'flex', alignItems: 'flex-start', gap: '0.625rem' }}>
                            <Circle size={12} weight="fill" style={{ color: 'var(--success)', marginTop: '0.25rem', flexShrink: 0 }} />
                            <div style={{ fontSize: '0.875rem', color: 'var(--text-primary)', lineHeight: 1.35 }}>
                              {ride.pickup?.address || 'Pickup location unavailable'}
                            </div>
                          </div>

                          <div style={{ display: 'flex', alignItems: 'flex-start', gap: '0.625rem' }}>
                            <MapPin size={14} weight="fill" style={{ color: 'var(--error)', marginTop: '0.2rem', flexShrink: 0 }} />
                            <div style={{ fontSize: '0.875rem', color: 'var(--text-primary)', lineHeight: 1.35 }}>
                              {ride.destination?.address || 'Dropoff location unavailable'}
                            </div>
                          </div>
                        </div>

                        {/* Trip Metrics Footer */}
                        <div
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between',
                            paddingTop: '0.5rem',
                            borderTop: '1px dashed var(--border)',
                            fontSize: '0.8125rem',
                            color: 'var(--text-secondary)',
                          }}
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                            <span style={{ fontWeight: 700, color: 'var(--text-primary)' }}>
                              ₹{ride.fare || ride.fareEstimate || '—'}
                            </span>
                            {ride.distanceMeters && (
                              <span>{(ride.distanceMeters / 1000).toFixed(1)} km</span>
                            )}
                            {ride.vehicleType && (
                              <span style={{ textTransform: 'capitalize' }}>{ride.vehicleType}</span>
                            )}
                          </div>

                          {ride.captainName && (
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                              Captain: <strong style={{ color: 'var(--text-primary)' }}>{ride.captainName}</strong>
                            </div>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* TAB 3: ADMIN ACTIONS */}
          {activeTab === 'actions' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
              {/* Role Change */}
              <div
                style={{
                  padding: '1.25rem',
                  background: 'var(--surface-2)',
                  borderRadius: 'var(--r-lg)',
                  border: '1px solid var(--border)',
                }}
              >
                <div style={{ fontSize: '0.875rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '0.25rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <ShieldCheck size={18} style={{ color: 'var(--brand-blue)' }} /> Modify Account Role
                </div>
                <p style={{ fontSize: '0.8125rem', color: 'var(--text-secondary)', margin: '0 0 1rem', lineHeight: 1.4 }}>
                  Switch this account's platform role. Promoting to Captain will enable driver mode in the app.
                </p>

                <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
                  {[
                    { key: 'user', label: 'Passenger' },
                    { key: 'captain', label: 'Captain' },
                    { key: 'admin', label: 'Administrator' },
                  ].map((r) => {
                    const isCurrent = (userData.role || 'user') === r.key;
                    return (
                      <button
                        key={r.key}
                        disabled={updating || isCurrent}
                        onClick={() => setPendingRole(r.key)}
                        style={{
                          flex: 1,
                          padding: '0.625rem 1rem',
                          borderRadius: 'var(--r-md)',
                          border: isCurrent ? '2px solid var(--brand-blue)' : '1px solid var(--border)',
                          background: isCurrent ? 'rgba(21, 101, 192, 0.1)' : 'var(--surface-1)',
                          color: isCurrent ? 'var(--brand-blue)' : 'var(--text-primary)',
                          fontWeight: 700,
                          fontSize: '0.875rem',
                          cursor: isCurrent ? 'default' : 'pointer',
                          transition: 'all 0.15s ease',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          gap: '0.35rem',
                        }}
                      >
                        {isCurrent && <Check size={16} weight="bold" />}
                        {r.label}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Account Status / Blocking Access */}
              <div
                style={{
                  padding: '1.25rem',
                  background: isBlocked ? 'rgba(239, 68, 68, 0.05)' : 'var(--surface-2)',
                  borderRadius: 'var(--r-lg)',
                  border: isBlocked ? '1px solid rgba(239, 68, 68, 0.25)' : '1px solid var(--border)',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '1rem' }}>
                  <div>
                    <div style={{ fontSize: '0.875rem', fontWeight: 700, color: isBlocked ? 'var(--error)' : 'var(--text-primary)', marginBottom: '0.25rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                      <WarningCircle size={18} /> Account Access Control
                    </div>
                    <p style={{ fontSize: '0.8125rem', color: 'var(--text-secondary)', margin: 0, maxWidth: '420px', lineHeight: 1.4 }}>
                      {isBlocked
                        ? 'This passenger account is currently BLOCKED. The user cannot request rides or log into booking services.'
                        : 'Block this account to immediately revoke booking privileges and prevent fraudulent ride requests.'}
                    </p>
                  </div>

                  <button
                    disabled={updating}
                    onClick={() => setShowBlockModal(true)}
                    className="btn"
                    style={{
                      background: isBlocked ? 'var(--success)' : 'var(--error)',
                      color: 'white',
                      fontWeight: 700,
                      padding: '0.5rem 1.25rem',
                      border: 'none',
                    }}
                  >
                    {isBlocked ? 'Unblock Passenger' : 'Block Passenger'}
                  </button>
                </div>
              </div>

              {/* Direct Communication Quick Links */}
              <div
                style={{
                  padding: '1.25rem',
                  background: 'var(--surface-2)',
                  borderRadius: 'var(--r-lg)',
                  border: '1px solid var(--border)',
                }}
              >
                <div style={{ fontSize: '0.875rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '0.35rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <Phone size={18} style={{ color: 'var(--brand-blue)' }} /> Direct Dispatcher Assistance
                </div>
                <p style={{ fontSize: '0.8125rem', color: 'var(--text-secondary)', margin: '0 0 1rem' }}>
                  Need to contact this user directly for ride disputes or identity verification?
                </p>

                <div style={{ display: 'flex', gap: '0.75rem' }}>
                  {userData.phone ? (
                    <a
                      href={`tel:${userData.phone}`}
                      className="btn"
                      style={{
                        background: 'var(--brand-blue)',
                        color: 'white',
                        fontWeight: 600,
                        fontSize: '0.875rem',
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '0.5rem',
                      }}
                    >
                      <Phone size={16} weight="bold" /> Call Passenger ({userData.phone})
                    </a>
                  ) : (
                    <button disabled className="btn btn-disabled">
                      Phone Number Not Set
                    </button>
                  )}

                  {userData.email && (
                    <a
                      href={`mailto:${userData.email}`}
                      className="btn"
                      style={{
                        background: 'var(--surface-1)',
                        border: '1px solid var(--border)',
                        color: 'var(--text-primary)',
                        fontWeight: 600,
                        fontSize: '0.875rem',
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '0.5rem',
                      }}
                    >
                      <Envelope size={16} weight="bold" /> Send Email
                    </a>
                  )}
                </div>
              </div>
            </div>
          )}
        </div>

        {/* 5. Footer */}
        <div
          style={{
            padding: '0.75rem 1.5rem',
            borderTop: '1px solid var(--border)',
            background: 'var(--surface-2)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            flexShrink: 0,
          }}
        >
          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
            Real-time listener active • Firebase synced
          </div>
          <button
            onClick={onClose}
            className="btn"
            style={{
              background: 'var(--surface-1)',
              border: '1px solid var(--border)',
              color: 'var(--text-primary)',
              fontWeight: 600,
              fontSize: '0.875rem',
              padding: '0.45rem 1.25rem',
            }}
          >
            Close
          </button>
        </div>
      </div>

      {/* Role Change Confirmation Modal */}
      <ConfirmModal
        isOpen={!!pendingRole}
        title="Change User Role?"
        message={`Are you sure you want to change ${userData.name || 'this user'}'s role to "${
          pendingRole === 'user' ? 'Passenger' : pendingRole
        }"?`}
        confirmText="Confirm Role Change"
        isDestructive={false}
        onConfirm={confirmRoleChange}
        onCancel={() => setPendingRole(null)}
      />

      {/* Block/Unblock Confirmation Modal */}
      <ConfirmModal
        isOpen={showBlockModal}
        title={isBlocked ? 'Unblock Passenger Account?' : 'Block Passenger Account?'}
        message={
          isBlocked
            ? `Are you sure you want to unblock ${userData.name || 'this user'}? They will be granted full ride booking and account privileges immediately.`
            : `Are you sure you want to block ${userData.name || 'this user'}? They will be restricted from booking rides on Sarthi.`
        }
        confirmText={isBlocked ? 'Unblock Account' : 'Block Account'}
        isDestructive={!isBlocked}
        onConfirm={confirmToggleBlock}
        onCancel={() => setShowBlockModal(false)}
      />
    </div>,
    document.body
  );
};
