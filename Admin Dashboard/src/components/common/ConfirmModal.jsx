import React, { useState } from 'react';
import { createPortal } from 'react-dom';
import { WarningCircle } from '@phosphor-icons/react';

export const ConfirmModal = ({ 
  isOpen, 
  title, 
  message, 
  confirmText = 'Delete', 
  cancelText = 'Cancel', 
  onConfirm, 
  onCancel,
  isDestructive = true
}) => {
  const [loading, setLoading] = useState(false);

  if (!isOpen) return null;

  const handleConfirm = async () => {
    setLoading(true);
    try {
      await onConfirm();
    } finally {
      // We don't necessarily set loading to false because the modal usually closes or unmounts.
      // But just in case it doesn't:
      setLoading(false);
    }
  };

  return createPortal(
    <div className="modal-backdrop" style={{ zIndex: 2000 }} onClick={onCancel}>
      <div 
        className="modal" 
        style={{ maxWidth: 420, overflow: 'visible', animation: 'modalIn 0.2s cubic-bezier(0.34, 1.56, 0.64, 1)' }}
        onClick={e => e.stopPropagation()}
      >
        <div style={{ padding: '2rem 1.75rem 1.5rem', display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
          <div style={{ 
            width: 56, height: 56, borderRadius: '50%', 
            background: isDestructive ? 'var(--error-bg)' : 'var(--warning-bg)', 
            color: isDestructive ? 'var(--error)' : 'var(--warning)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            marginBottom: '1.25rem'
          }}>
            <WarningCircle size={32} weight="fill" />
          </div>
          <h2 style={{ fontSize: '1.125rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '0.5rem' }}>
            {title}
          </h2>
          <p style={{ fontSize: '0.9375rem', color: 'var(--text-secondary)', lineHeight: 1.5 }}>
            {message}
          </p>
        </div>
        
        <div style={{ 
          padding: '1.25rem 1.75rem', 
          background: 'var(--surface-2)', 
          borderTop: '1px solid var(--border)',
          display: 'flex', gap: '0.75rem', justifyContent: 'center',
          borderBottomLeftRadius: 'var(--r-xl)', borderBottomRightRadius: 'var(--r-xl)'
        }}>
          <button 
            className="btn btn-secondary" 
            style={{ flex: 1 }} 
            onClick={onCancel}
            disabled={loading}
          >
            {cancelText}
          </button>
          <button 
            className={`btn ${isDestructive ? 'btn-danger' : 'btn-primary'}`} 
            style={{ flex: 1 }} 
            onClick={handleConfirm}
            disabled={loading}
          >
            {loading ? 'Processing...' : confirmText}
          </button>
        </div>
      </div>
    </div>,
    document.body
  );
};
