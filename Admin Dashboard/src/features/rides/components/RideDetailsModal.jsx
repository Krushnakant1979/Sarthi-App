import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { X, MapPin, NavigationArrow, CurrencyInr, Car, User, Circle, Copy, Check, WarningCircle } from '@phosphor-icons/react';
import { db } from '../../../config/firebase';
import { doc, getDoc, updateDoc, serverTimestamp, deleteField } from 'firebase/firestore';
import { publicIdService } from '../../../services/publicIdService';
import { logAdminAction } from '../../../services/auditService';
import { useToast } from '../../../context/ToastContext';

const formatDate = (val) => {
  if (!val) return '—';
  try {
    let d;
    if (val.seconds) d = new Date(val.seconds * 1000);
    else if (val.toDate) d = val.toDate();
    else d = new Date(val);
    if (isNaN(d.getTime())) return '—';
    return d.toLocaleString('en-IN', {
      day: 'numeric', month: 'short', year: 'numeric',
      hour: 'numeric', minute: '2-digit', hour12: true
    });
  } catch (e) {
    console.error(e);
    return '—';
  }
};

export const RideDetailsModal = ({ ride, onClose }) => {
  const [passenger, setPassenger] = useState(null);
  const [captain, setCaptain] = useState(null);
  const [loadingUsers, setLoadingUsers] = useState(true);
  const [copiedId, setCopiedId] = useState(null);
  const [showCancelPrompt, setShowCancelPrompt] = useState(false);
  const [cancelReason, setCancelReason] = useState('Cancelled by admin dispatcher due to driver inactivity');
  const [cancelling, setCancelling] = useState(false);
  const toast = useToast();

  useEffect(() => {
    if (!ride) return;
    let isMounted = true;
    
    const fetchUsers = async () => {
      setLoadingUsers(true);
      try {
        if (ride.userId) {
          const pDoc = await getDoc(doc(db, 'users', ride.userId));
          if (pDoc.exists()) {
            let pData = pDoc.data();
            pData.publicId = publicIdService.formatId(pDoc.id);
            if (isMounted) setPassenger(pData);
          }
        }
        
        const actualCaptainId = ride.captainId || ride.assignedCaptainId;
        if (actualCaptainId) {
          const cDoc = await getDoc(doc(db, 'users', actualCaptainId));
          if (cDoc.exists()) {
            let cData = cDoc.data();
            cData.publicId = publicIdService.formatId(cDoc.id);
            if (isMounted) setCaptain(cData);
          }
        }
      } catch (err) {
        console.error("Error fetching ride users", err);
      } finally {
        if (isMounted) setLoadingUsers(false);
      }
    };
    
    fetchUsers();
    return () => { isMounted = false; };
  }, [ride]);

  const handleCopy = (e, id) => {
    e.stopPropagation();
    navigator.clipboard.writeText(id);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const canCancel = ['searching', 'pending', 'accepted', 'arriving', 'arrived', 'in_progress', 'ongoing'].includes(ride?.status);

  const handleForceCancel = async () => {
    if (!cancelReason.trim()) {
      toast('Please provide a reason for cancelling this trip', 'warning');
      return;
    }
    setCancelling(true);
    try {
      const rideRef = doc(db, 'ride_requests', ride.id);
      await updateDoc(rideRef, {
        status: 'cancelled',
        cancelReason: cancelReason.trim(),
        cancelledBy: 'admin',
        updatedAt: serverTimestamp(),
      });
      const actualCaptainId = ride.assignedCaptainId || ride.captainId;
      if (actualCaptainId) {
        try {
          await updateDoc(doc(db, 'users', actualCaptainId), {
            onTrip: false,
            isAvailable: true,
            currentRideId: deleteField(),
            updatedAt: serverTimestamp(),
          });
        } catch (e) {
          console.warn('Could not reset captain availability:', e);
        }
      }

      await logAdminAction('ride_force_cancelled', ride.id, {
        reason: cancelReason.trim(),
        previousStatus: ride.status,
        userId: ride.userId,
        captainId: actualCaptainId,
      });
      toast('Ride force-cancelled and captain/passenger released!', 'success');
      onClose();
    } catch (err) {
      console.error('Error force-cancelling ride:', err);
      toast(`Failed to cancel ride: ${err.message}`, 'error');
    } finally {
      setCancelling(false);
    }
  };

  if (!ride) return null;

  return createPortal(
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        
        {/* Header */}
        <div className="modal-header">
          <div>
            <h2 className="modal-title">Ride Details</h2>
            <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', marginTop: '0.25rem', fontFamily: 'monospace' }}>
              #{publicIdService.formatId(ride.id)}
            </div>
          </div>
          <button className="modal-close" onClick={onClose}><X /></button>
        </div>

        {/* Body */}
        <div className="modal-body">
          
          {/* Status & Timing */}
          <div className="info-grid">
            <div className="info-item">
              <div className="info-item-label">Status</div>
              <div className="info-item-value" style={{ textTransform: 'capitalize' }}>
                {ride.status || 'Unknown'}
              </div>
            </div>
            <div className="info-item">
              <div className="info-item-label">Requested At</div>
              <div className="info-item-value">
                {formatDate(ride.createdAt)}
              </div>
            </div>
          </div>

          <h3 style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.05em', margin: '1.5rem 0 0.75rem' }}>
            Trip Information
          </h3>

          <div style={{ background: 'var(--surface-2)', borderRadius: 'var(--r-md)', border: '1px solid var(--border)', padding: '1rem' }}>
            {/* Pickup */}
            <div style={{ display: 'flex', gap: '0.75rem', marginBottom: '1rem' }}>
              <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'rgba(22, 163, 74, 0.1)', color: 'var(--success)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <Circle weight="fill" size={12} />
              </div>
              <div>
                <div style={{ fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Pickup</div>
                <div style={{ fontSize: '0.9375rem', color: 'var(--text-primary)', marginTop: '0.125rem', lineHeight: 1.4 }}>
                  {ride.pickup?.address || '—'}
                </div>
              </div>
            </div>

            {/* Dropoff */}
            <div style={{ display: 'flex', gap: '0.75rem' }}>
              <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'rgba(220, 38, 38, 0.1)', color: 'var(--error)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <MapPin weight="fill" size={16} />
              </div>
              <div>
                <div style={{ fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Dropoff</div>
                <div style={{ fontSize: '0.9375rem', color: 'var(--text-primary)', marginTop: '0.125rem', lineHeight: 1.4 }}>
                  {ride.destination?.address || '—'}
                </div>
              </div>
            </div>
          </div>

          {/* Ride Stats */}
          <div style={{ display: 'flex', gap: '1rem', marginTop: '1rem' }}>
            <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: '0.5rem', background: 'var(--surface-2)', padding: '0.75rem 1rem', borderRadius: 'var(--r-md)', border: '1px solid var(--border)' }}>
              <NavigationArrow size={16} style={{ color: 'var(--brand-blue)' }} />
              <div>
                <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>Distance</div>
                <div style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-primary)' }}>
                  {ride.distanceMeters ? `${(ride.distanceMeters / 1000).toFixed(1)} km` : '—'}
                </div>
              </div>
            </div>
            <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: '0.5rem', background: 'var(--surface-2)', padding: '0.75rem 1rem', borderRadius: 'var(--r-md)', border: '1px solid var(--border)' }}>
              <CurrencyInr size={16} style={{ color: 'var(--warning)' }} />
              <div>
                <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>Fare</div>
                <div style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-primary)' }}>{ride.fareEstimate ? `₹${ride.fareEstimate}` : '—'}</div>
              </div>
            </div>
          </div>

          <div className="info-grid" style={{ marginTop: '1.5rem' }}>
            {/* Passenger Info */}
            <div className="info-item" style={{ minWidth: 0 }}>
              <div className="info-item-label" style={{ display: 'flex', alignItems: 'center', gap: '0.375rem' }}>
                <User size={14} /> Passenger
              </div>
              <div className="info-item-value" style={{ fontSize: '0.875rem', marginTop: '0.5rem', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {loadingUsers ? 'Loading...' : passenger ? (
                  <div>
                    <div style={{ fontWeight: 600, color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {passenger.name || 'Unknown User'}
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginTop: '0.25rem' }}>
                      <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontFamily: 'monospace' }}>
                        User ID: {passenger.publicId || 'Generating...'}
                      </span>
                      {passenger.publicId && (
                        <button 
                          onClick={(e) => handleCopy(e, passenger.publicId)}
                          style={{ background: 'none', border: 'none', cursor: 'pointer', color: copiedId === passenger.publicId ? 'var(--success)' : 'var(--text-muted)', padding: 0, display: 'flex' }}
                          title="Copy ID"
                        >
                          {copiedId === passenger.publicId ? <Check size={14} weight="bold" /> : <Copy size={14} />}
                        </button>
                      )}
                    </div>
                    {passenger.phone && (
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
                        {passenger.phone}
                      </div>
                    )}
                  </div>
                ) : 'Passenger details unavailable'}
              </div>
            </div>

            {/* Captain Info */}
            <div className="info-item" style={{ minWidth: 0 }}>
              <div className="info-item-label" style={{ display: 'flex', alignItems: 'center', gap: '0.375rem' }}>
                <Car size={14} /> Captain
              </div>
              <div className="info-item-value" style={{ fontSize: '0.875rem', marginTop: '0.5rem', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {loadingUsers ? 'Loading...' : captain ? (
                  <div>
                    <div style={{ fontWeight: 600, color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {captain.name || 'Unknown Captain'}
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginTop: '0.25rem' }}>
                      <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontFamily: 'monospace' }}>
                        Capt ID: {captain.publicId || 'Generating...'}
                      </span>
                      {captain.publicId && (
                        <button 
                          onClick={(e) => handleCopy(e, captain.publicId)}
                          style={{ background: 'none', border: 'none', cursor: 'pointer', color: copiedId === captain.publicId ? 'var(--success)' : 'var(--text-muted)', padding: 0, display: 'flex' }}
                          title="Copy ID"
                        >
                          {copiedId === captain.publicId ? <Check size={14} weight="bold" /> : <Copy size={14} />}
                        </button>
                      )}
                    </div>
                    {captain.phone && (
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
                        {captain.phone}
                      </div>
                    )}
                  </div>
                ) : (ride.captainId || ride.assignedCaptainId) ? 'Captain details unavailable' : 'Unassigned'}
              </div>
            </div>
          </div>

          {/* Dispatcher Override: Force Cancel */}
          {canCancel && (
            <div style={{ marginTop: '1.5rem', paddingTop: '1.25rem', borderTop: '1px solid var(--border)' }}>
              {!showCancelPrompt ? (
                <button
                  type="button"
                  onClick={() => setShowCancelPrompt(true)}
                  style={{
                    width: '100%',
                    padding: '0.75rem 1rem',
                    borderRadius: 'var(--r-md)',
                    border: '1px solid var(--error-border, #fca5a5)',
                    background: 'rgba(239, 68, 68, 0.08)',
                    color: 'var(--error, #ef4444)',
                    fontWeight: 600,
                    fontSize: '0.875rem',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '0.5rem',
                    cursor: 'pointer',
                    transition: 'all 0.2s ease',
                  }}
                >
                  <WarningCircle size={18} weight="bold" />
                  Force Cancel Ride (Dispatcher Override)
                </button>
              ) : (
                <div style={{ background: 'rgba(239, 68, 68, 0.05)', border: '1px solid var(--error-border, #fca5a5)', borderRadius: 'var(--r-md)', padding: '1rem' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: 'var(--error, #ef4444)', fontWeight: 600, fontSize: '0.875rem', marginBottom: '0.5rem' }}>
                    <WarningCircle size={18} weight="bold" />
                    Confirm Ride Force-Cancellation
                  </div>
                  <p style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', marginBottom: '0.75rem', lineHeight: 1.4 }}>
                    Cancelling this active trip will release the user lock and notify both passenger and captain. Please specify the administrative reason:
                  </p>
                  <input
                    type="text"
                    value={cancelReason}
                    onChange={(e) => setCancelReason(e.target.value)}
                    placeholder="Enter cancellation reason..."
                    style={{
                      width: '100%',
                      padding: '0.625rem 0.75rem',
                      borderRadius: 'var(--r-sm)',
                      border: '1px solid var(--border)',
                      background: 'var(--surface)',
                      color: 'var(--text-primary)',
                      fontSize: '0.875rem',
                      marginBottom: '0.75rem',
                      boxSizing: 'border-box'
                    }}
                  />
                  <div style={{ display: 'flex', gap: '0.5rem', justifyContent: 'flex-end' }}>
                    <button
                      type="button"
                      onClick={() => setShowCancelPrompt(false)}
                      disabled={cancelling}
                      style={{
                        padding: '0.5rem 0.875rem',
                        borderRadius: 'var(--r-sm)',
                        border: '1px solid var(--border)',
                        background: 'transparent',
                        color: 'var(--text-secondary)',
                        fontSize: '0.8125rem',
                        cursor: 'pointer'
                      }}
                    >
                      Dismiss
                    </button>
                    <button
                      type="button"
                      onClick={handleForceCancel}
                      disabled={cancelling}
                      style={{
                        padding: '0.5rem 1rem',
                        borderRadius: 'var(--r-sm)',
                        border: 'none',
                        background: 'var(--error, #ef4444)',
                        color: 'white',
                        fontWeight: 600,
                        fontSize: '0.8125rem',
                        cursor: cancelling ? 'not-allowed' : 'pointer',
                        opacity: cancelling ? 0.7 : 1
                      }}
                    >
                      {cancelling ? 'Cancelling...' : 'Confirm Force Cancel'}
                    </button>
                  </div>
                </div>
              )}
            </div>
          )}

        </div>
        
      </div>
    </div>,
    document.body
  );
};
