import React, { useState } from 'react';
import { db } from '../../../config/firebase';
import { doc, updateDoc, serverTimestamp, deleteDoc } from 'firebase/firestore';
import { useToast } from '../../../context/ToastContext';
import {
  SteeringWheel, IdentificationCard,
  CheckCircle, XCircle, Trash
} from '@phosphor-icons/react';
import { createPortal } from 'react-dom';
import { ConfirmModal } from '../../../components/common/ConfirmModal';

/* Robustly parse Firestore Timestamp, ISO string, or Date object → readable date */
const formatDate = (val) => {
  if (!val) return '—';
  let d;
  if (typeof val?.toDate === 'function') d = val.toDate();
  else if (val instanceof Date) d = val;
  else {
    // ISO string like "2026-08-19T13:19:40.670409"
    d = new Date(val);
  }
  if (isNaN(d)) return String(val);
  return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
};

export const CaptainVerifyModal = ({ captain, onClose }) => {
  const toast = useToast();
  const [loading, setLoading] = useState(null); // 'verify' | 'reject' | 'delete'
  const [showConfirmDelete, setShowConfirmDelete] = useState(false);

  const handleVerify = async () => {
    setLoading('verify');
    try {
      await updateDoc(doc(db, 'users', captain.id), {
        verificationStatus: 'verified',
        verificationUpdatedAt: serverTimestamp(),
      });
      toast('Captain verified and added to the app successfully!', 'success');
      onClose();
    } catch (e) {
      toast(`Error: ${e.message}`, 'error');
    } finally {
      setLoading(null);
    }
  };

  const handleReject = async () => {
    setLoading('reject');
    try {
      await updateDoc(doc(db, 'users', captain.id), {
        verificationStatus: 'rejected',
        verificationUpdatedAt: serverTimestamp(),
      });
      toast('Captain documents rejected.', 'info');
      onClose();
    } catch (e) {
      toast(`Error: ${e.message}`, 'error');
    } finally {
      setLoading(null);
    }
  };

  const confirmDelete = async () => {
    setLoading('delete');
    try {
      await deleteDoc(doc(db, 'users', captain.id));
      toast('Captain account deleted.', 'info');
      setShowConfirmDelete(false);
      onClose();
    } catch (e) {
      toast(`Error: ${e.message}`, 'error');
    } finally {
      setLoading(null);
    }
  };

  const status = captain.verificationStatus || 'pending';

  const docItems = [
    { label: 'Aadhaar Card',    url: captain.aadhaarCardUrl      },
    { label: 'Driving Licence', url: captain.drivingLicenceUrl   },
    { label: 'Profile Photo',   url: captain.profilePictureUrl   },
  ];

  return createPortal(
    <div
      className="modal-backdrop"
      onClick={(e) => e.target === e.currentTarget && onClose()}
    >
      {/*
        KEY FIX: modal uses flex-column with a fixed height so that
        header + footer remain sticky and only modal-body scrolls.
      */}
      <div
        className="modal modal-lg"
        style={{
          display: 'flex',
          flexDirection: 'column',
          maxHeight: '90vh',
          overflow: 'hidden',   /* <-- modal itself does NOT scroll */
        }}
      >
        {/* ── Sticky Header ── */}
        <div className="modal-header" style={{ flexShrink: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <div style={{
              width: 40, height: 40, borderRadius: 'var(--r-md)',
              background: 'rgba(0,166,166,0.1)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <SteeringWheel size={20} weight="bold" style={{ color: 'var(--brand-teal)' }} />
            </div>
            <span className="modal-title">Captain Verification</span>
          </div>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>

        {/* ── Scrollable Body (only this scrolls) ── */}
        <div className="modal-body" style={{ overflowY: 'auto', flex: 1 }}>

          {/* Captain Info Banner */}
          <div style={{
            display: 'flex', alignItems: 'center', gap: '1rem',
            marginBottom: '1.25rem', padding: '1rem',
            background: 'var(--surface-2)', borderRadius: 'var(--r-lg)',
            border: '1px solid var(--border)',
          }}>
            <div style={{
              width: 52, height: 52, borderRadius: 'var(--r-full)',
              background: 'linear-gradient(135deg, var(--brand-teal), var(--brand-blue))',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: '1.25rem', fontWeight: 700, color: 'white', flexShrink: 0,
            }}>
              {captain.name ? captain.name.charAt(0).toUpperCase() : 'C'}
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontWeight: 700, fontSize: '1.0625rem', color: 'var(--text-primary)' }}>
                {captain.name || 'Unknown'}
              </div>
              <div style={{ fontSize: '0.875rem', color: 'var(--text-secondary)', marginTop: '0.125rem' }}>
                {captain.email && <span style={{ marginRight: '0.75rem' }}>✉ {captain.email}</span>}
                {captain.phone && <span>📞 {captain.phone}</span>}
              </div>
            </div>
            <span className={`badge ${
              status === 'verified' ? 'badge-success'
              : status === 'rejected' ? 'badge-error'
              : 'badge-warning badge-pulse'
            }`}>
              {status}
            </span>
          </div>

          {/* Info Grid */}
          <div className="info-grid">
            <div className="info-item">
              <div className="info-item-label">Vehicle Type</div>
              <div className="info-item-value">{captain.vehicleType || '—'}</div>
            </div>
            <div className="info-item">
              <div className="info-item-label">Registration No.</div>
              <div className="info-item-value">
                {captain.vehicleDetails?.registrationNumber || captain.registrationNumber || '—'}
              </div>
            </div>
            <div className="info-item">
              <div className="info-item-label">Rating</div>
              <div className="info-item-value">
                {captain.ratingScore && captain.ratingCount
                  ? `⭐ ${(captain.ratingScore / Math.max(captain.ratingCount, 1)).toFixed(1)}`
                  : 'No ratings yet'}
              </div>
            </div>
            <div className="info-item">
              <div className="info-item-label">Joined</div>
              <div className="info-item-value" style={{ fontSize: '0.9rem' }}>
                {formatDate(captain.createdAt)}
              </div>
            </div>
          </div>

          {/* Documents */}
          <div style={{ marginBottom: '0.625rem', fontWeight: 600, fontSize: '0.875rem', color: 'var(--text-secondary)' }}>
            Submitted Documents
          </div>
          <div className="doc-preview-grid" style={{ gridTemplateColumns: 'repeat(3, 1fr)' }}>
            {docItems.map(({ label, url }) => (
              <div key={label} className="doc-preview-card">
                <div className="doc-preview-label">{label}</div>
                {url ? (
                  <a href={url} target="_blank" rel="noopener noreferrer" style={{ display: 'block' }}>
                    <img src={url} alt={label} className="doc-preview-img" />
                  </a>
                ) : (
                  <div className="doc-preview-placeholder">
                    <IdentificationCard size={28} style={{ opacity: 0.35 }} />
                    <span>Not submitted</span>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>

        {/* ── Sticky Footer ── */}
        <div className="modal-footer" style={{ justifyContent: 'space-between', flexShrink: 0 }}>
          <button
            className="btn btn-danger btn-sm"
            onClick={() => setShowConfirmDelete(true)}
            disabled={!!loading}
          >
            <Trash size={15} weight="bold" />
            {loading === 'delete' ? 'Deleting…' : 'Delete Account'}
          </button>

          <div style={{ display: 'flex', gap: '0.625rem' }}>
            <button
              className="btn btn-secondary"
              onClick={handleReject}
              disabled={!!loading || status === 'rejected'}
            >
              <XCircle size={16} weight="bold" />
              {loading === 'reject' ? 'Rejecting…' : 'Reject Documents'}
            </button>
            <button
              className="btn btn-success"
              onClick={handleVerify}
              disabled={!!loading || status === 'verified'}
              style={{ fontWeight: 700 }}
            >
              <CheckCircle size={16} weight="bold" />
              {loading === 'verify' ? 'Verifying…' : 'Approve & Verify'}
            </button>
          </div>
        </div>
      </div>

      <ConfirmModal
        isOpen={showConfirmDelete}
        title="Delete Captain?"
        message={`Are you sure you want to permanently delete the account for "${captain.name}"? This cannot be undone.`}
        confirmText="Yes, Delete"
        onConfirm={confirmDelete}
        onCancel={() => setShowConfirmDelete(false)}
      />
    </div>,
    document.body
  );
};
