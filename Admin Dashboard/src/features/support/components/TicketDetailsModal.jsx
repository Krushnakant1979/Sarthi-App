import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { 
  Headset, 
  X, 
  Check, 
  Copy, 
  CheckCircle, 
  User, 
  SteeringWheel, 
  Clock, 
  IdentificationCard,
  Phone,
  Envelope
} from '@phosphor-icons/react';
import { doc, getDoc } from 'firebase/firestore';
import { db } from '../../../config/firebase';

export default function TicketDetailsModal({ ticket, onClose, onResolve }) {
  const [copiedId, setCopiedId] = useState(false);
  const [copiedUserId, setCopiedUserId] = useState(false);
  const [userData, setUserData] = useState(null);
  const [loadingUser, setLoadingUser] = useState(false);
  const [resolving, setResolving] = useState(false);
  const [resolutionMsg, setResolutionMsg] = useState('This issue has been reviewed and resolved by the support team.');

  useEffect(() => {
    if (!ticket?.userId) return;
    let isMounted = true;
    const fetchUserData = async () => {
      setLoadingUser(true);
      try {
        const userSnap = await getDoc(doc(db, 'users', ticket.userId));
        if (userSnap.exists() && isMounted) {
          setUserData(userSnap.data());
        }
      } catch (err) {
        console.error('Error fetching complainant user details:', err);
      } finally {
        if (isMounted) setLoadingUser(false);
      }
    };
    fetchUserData();
    return () => { isMounted = false; };
  }, [ticket?.userId]);

  // Close on Escape key
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  if (!ticket) return null;

  const handleCopyTicketId = () => {
    navigator.clipboard.writeText(ticket.id);
    setCopiedId(true);
    setTimeout(() => setCopiedId(false), 2000);
  };

  const handleCopyUserId = () => {
    if (ticket.userId) {
      navigator.clipboard.writeText(ticket.userId);
      setCopiedUserId(true);
      setTimeout(() => setCopiedUserId(false), 2000);
    }
  };

  const handleResolveClick = async () => {
    if (resolving) return;
    setResolving(true);
    try {
      await onResolve(ticket.id, resolutionMsg);
    } finally {
      setResolving(false);
    }
  };

  const formatFullDate = (timestamp) => {
    if (!timestamp) return '—';
    const date = timestamp.toDate ? timestamp.toDate() : (timestamp instanceof Date ? timestamp : new Date(timestamp));
    if (isNaN(date.getTime())) return '—';
    return new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true
    }).format(date);
  };

  const isResolved = ticket.status === 'resolved';

  return createPortal(
    <div className="modal-backdrop" onClick={onClose}>
      <div 
        className="modal" 
        onClick={(e) => e.stopPropagation()} 
        style={{ maxWidth: '620px', width: '100%', padding: 0, overflow: 'hidden' }}
      >
        {/* Modal Header */}
        <div style={{
          background: 'linear-gradient(135deg, #0F172A 0%, #1E3A8A 100%)',
          padding: '1.5rem 1.75rem',
          color: 'white',
          position: 'relative',
          display: 'flex',
          alignItems: 'center',
          gap: '1rem'
        }}>
          <button 
            type="button"
            onClick={onClose}
            aria-label="Close details"
            style={{
              position: 'absolute',
              top: '1rem',
              right: '1rem',
              background: 'rgba(255,255,255,0.12)',
              border: 'none',
              borderRadius: 'var(--r-full)',
              color: 'white',
              width: 32,
              height: 32,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer',
              transition: 'background 0.2s ease'
            }}
          >
            <X size={18} />
          </button>

          <div style={{
            width: 48,
            height: 48,
            borderRadius: 'var(--r-lg)',
            background: 'rgba(255,255,255,0.12)',
            backdropFilter: 'blur(8px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0
          }}>
            <Headset size={26} color="#93C5FD" weight="duotone" />
          </div>

          <div style={{ flex: 1, minWidth: 0 }}>
            <h2 style={{ margin: 0, fontSize: '1.2rem', fontWeight: 800, letterSpacing: '-0.02em', color: '#FFFFFF' }}>
              Complaint Details
            </h2>
            <div style={{ 
              fontSize: '0.78rem', 
              color: '#93C5FD', 
              fontFamily: 'monospace', 
              marginTop: '0.2rem',
              display: 'flex',
              alignItems: 'center',
              gap: '0.4rem'
            }}>
              Ticket ID: {ticket.id}
              <button 
                type="button"
                onClick={handleCopyTicketId}
                style={{ 
                  background: 'none', 
                  border: 'none', 
                  color: copiedId ? '#4ADE80' : '#BFDBFE', 
                  cursor: 'pointer', 
                  padding: 0,
                  display: 'inline-flex',
                  alignItems: 'center'
                }}
                title="Copy Ticket ID"
              >
                {copiedId ? <Check size={14} weight="bold" /> : <Copy size={14} />}
              </button>
            </div>
          </div>
        </div>

        {/* Modal Body */}
        <div className="modal-body" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
          
          {/* Metadata Badges Bar */}
          <div style={{ 
            display: 'flex', 
            flexWrap: 'wrap', 
            gap: '0.75rem', 
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0.75rem 1rem',
            background: 'var(--surface-2)',
            borderRadius: 'var(--r-md)',
            border: '1px solid var(--border)'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              {/* Role Badge */}
              <span style={{ 
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.35rem',
                padding: '0.3rem 0.75rem', 
                borderRadius: 'var(--r-full)', 
                fontSize: '0.75rem', 
                fontWeight: 700,
                background: ticket.reporterRole === 'captain' ? 'rgba(245, 158, 11, 0.15)' : 'rgba(37, 99, 235, 0.12)',
                color: ticket.reporterRole === 'captain' ? '#D97706' : 'var(--brand-blue)',
                textTransform: 'capitalize'
              }}>
                {ticket.reporterRole === 'captain' ? <SteeringWheel size={14} weight="bold" /> : <User size={14} weight="bold" />}
                {ticket.reporterRole ? `${ticket.reporterRole}` : 'User'}
              </span>

              {/* Status Badge */}
              <span style={{ 
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.35rem',
                padding: '0.3rem 0.75rem', 
                borderRadius: 'var(--r-full)', 
                fontSize: '0.75rem', 
                fontWeight: 700,
                background: isResolved ? 'rgba(16, 185, 129, 0.12)' : 'rgba(239, 68, 68, 0.12)',
                color: isResolved ? '#10B981' : '#EF4444'
              }}>
                {isResolved ? <CheckCircle size={14} weight="fill" /> : null}
                {isResolved ? 'Resolved' : 'Open Ticket'}
              </span>
            </div>

            {/* Submitted Date & Time */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 500 }}>
              <Clock size={15} />
              <span>{formatFullDate(ticket.createdAt)}</span>
            </div>
          </div>

          {/* Complainant User Information */}
          <div style={{
            padding: '1rem',
            background: 'var(--surface-1)',
            borderRadius: 'var(--r-md)',
            border: '1px solid var(--border)',
            display: 'flex',
            flexDirection: 'column',
            gap: '0.5rem'
          }}>
            <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.04em', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
              <IdentificationCard size={16} />
              Complainant Information
            </div>

            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '1rem', alignItems: 'center', marginTop: '0.25rem' }}>
              <div style={{ flex: 1, minWidth: '180px' }}>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>User ID</div>
                <div style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  gap: '0.5rem',
                  fontFamily: 'monospace', 
                  fontSize: '0.8125rem', 
                  fontWeight: 600,
                  color: 'var(--text-primary)',
                  wordBreak: 'break-all'
                }}>
                  <span>{ticket.userId || 'Not specified'}</span>
                  {ticket.userId && (
                    <button 
                      type="button"
                      onClick={handleCopyUserId}
                      style={{ 
                        background: 'none', 
                        border: 'none', 
                        color: copiedUserId ? '#10B981' : 'var(--text-muted)', 
                        cursor: 'pointer', 
                        padding: 0,
                        display: 'inline-flex',
                        alignItems: 'center'
                      }}
                      title="Copy User ID"
                    >
                      {copiedUserId ? <Check size={14} weight="bold" /> : <Copy size={14} />}
                    </button>
                  )}
                </div>
              </div>

              {userData?.name && (
                <div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Name</div>
                  <div style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-primary)' }}>
                    {userData.name}
                  </div>
                </div>
              )}

              {userData?.phone && (
                <div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Phone</div>
                  <div style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                    <Phone size={13} color="var(--text-muted)" />
                    {userData.phone}
                  </div>
                </div>
              )}

              {userData?.email && (
                <div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Email</div>
                  <div style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                    <Envelope size={13} color="var(--text-muted)" />
                    {userData.email}
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Subject Box */}
          <div>
            <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: '0.35rem' }}>
              Subject
            </div>
            <div style={{
              padding: '0.75rem 1rem',
              background: 'var(--surface-2)',
              borderRadius: 'var(--r-md)',
              border: '1px solid var(--border)',
              fontSize: '0.95rem',
              fontWeight: 700,
              color: 'var(--text-primary)'
            }}>
              {ticket.subject || 'No Subject'}
            </div>
          </div>

          {/* Full Message Box */}
          <div>
            <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: '0.35rem' }}>
              Full Complaint Message
            </div>
            <div style={{
              padding: '1rem 1.25rem',
              background: 'var(--surface-2)',
              borderRadius: 'var(--r-md)',
              border: '1px solid var(--border)',
              fontSize: '0.875rem',
              color: 'var(--text-primary)',
              lineHeight: 1.6,
              whiteSpace: 'pre-wrap',
              wordBreak: 'break-word',
              maxHeight: '220px',
              overflowY: 'auto'
            }}>
              {ticket.message || 'No detailed message provided.'}
            </div>
          </div>

          {/* Resolution Info (if resolved) */}
          {isResolved && (
            <div style={{
              padding: '0.875rem 1rem',
              background: 'rgba(16, 185, 129, 0.08)',
              border: '1px solid rgba(16, 185, 129, 0.25)',
              borderRadius: 'var(--r-md)',
              display: 'flex',
              alignItems: 'flex-start',
              gap: '0.75rem'
            }}>
              <CheckCircle size={20} color="#10B981" weight="fill" style={{ flexShrink: 0, marginTop: '0.1rem' }} />
              <div style={{ fontSize: '0.8125rem' }}>
                <strong style={{ color: '#059669', display: 'block', marginBottom: '0.2rem' }}>
                  Issue Resolved
                </strong>
                <p style={{ margin: 0, color: 'var(--text-secondary)' }}>
                  {ticket.resolutionMessage || 'This complaint has been reviewed and marked as completed.'}
                </p>
              </div>
            </div>
          )}

          {!isResolved && (
            <div style={{ marginTop: '1.25rem', paddingTop: '1.25rem', borderTop: '1px solid var(--border)' }}>
              <label style={{ display: 'block', fontSize: '0.8125rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: '0.5rem' }}>
                Resolution Message / Notes for Complainant
              </label>
              <textarea
                value={resolutionMsg}
                onChange={(e) => setResolutionMsg(e.target.value)}
                placeholder="Enter resolution notes..."
                rows={3}
                style={{
                  width: '100%',
                  padding: '0.625rem 0.75rem',
                  borderRadius: 'var(--r-md)',
                  border: '1px solid var(--border)',
                  background: 'var(--surface-2)',
                  color: 'var(--text-primary)',
                  fontSize: '0.85rem',
                  resize: 'vertical',
                  boxSizing: 'border-box'
                }}
              />
            </div>
          )}
        </div>

        {/* Modal Footer */}
        <div className="modal-footer" style={{ padding: '1rem 1.5rem', background: 'var(--surface-1)' }}>
          <button 
            type="button" 
            onClick={onClose} 
            className="btn btn-secondary" 
            style={{ padding: '0.5rem 1rem', fontSize: '0.85rem' }}
          >
            Close
          </button>
          
          {!isResolved && (
            <button 
              type="button" 
              onClick={handleResolveClick} 
              disabled={resolving}
              className="btn btn-primary"
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.4rem',
                padding: '0.5rem 1.25rem',
                fontSize: '0.85rem',
                fontWeight: 600
              }}
            >
              <CheckCircle size={16} weight="bold" />
              {resolving ? 'Resolving...' : 'Resolve Complaint'}
            </button>
          )}
        </div>
      </div>
    </div>,
    document.body
  );
}
