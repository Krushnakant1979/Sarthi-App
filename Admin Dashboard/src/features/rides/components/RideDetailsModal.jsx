import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { X, MapPin, NavigationArrow, CurrencyInr, Car, User, Circle, Copy, Check } from '@phosphor-icons/react';
import { db } from '../../../config/firebase';
import { doc, getDoc } from 'firebase/firestore';
import { publicIdService } from '../../../services/publicIdService';

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

        </div>
        
      </div>
    </div>,
    document.body
  );
};
