import React, { useState } from 'react';
import { auth } from '../../config/firebase';
import { sendPasswordResetEmail, signOut } from 'firebase/auth';
import { useToast } from '../../context/ToastContext';
import { ShieldCheck, Envelope, Key, SignOut, X, CheckCircle } from '@phosphor-icons/react';
import { createPortal } from 'react-dom';

export const AdminProfileModal = ({ onClose }) => {
  const user = auth.currentUser;
  const { showToast } = useToast();
  const [resetting, setResetting] = useState(false);
  const [resetSent, setResetSent] = useState(false);

  const handlePasswordReset = async () => {
    if (!user?.email) return;
    setResetting(true);
    try {
      await sendPasswordResetEmail(auth, user.email);
      setResetSent(true);
      showToast(`Password reset link sent to ${user.email}`, 'success');
    } catch (err) {
      console.error('Password reset error:', err);
      showToast(`Failed to send reset email: ${err.message}`, 'error');
    } finally {
      setResetting(false);
    }
  };

  const handleLogout = async () => {
    try {
      await signOut(auth);
    } catch (err) {
      console.error('Sign out error:', err);
    }
  };

  const initials = user?.email ? user.email.charAt(0).toUpperCase() : 'A';

  return createPortal(
    <div className="modal-backdrop" onClick={onClose}>
      <div 
        className="modal" 
        onClick={e => e.stopPropagation()} 
        style={{ maxWidth: '480px', width: '100%', padding: '0', overflow: 'hidden' }}
      >
        <div style={{
          background: 'linear-gradient(135deg, #0B2545 0%, #134074 100%)',
          padding: '2rem 1.5rem',
          color: 'white',
          position: 'relative',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          textAlign: 'center'
        }}>
          <button 
            onClick={onClose}
            style={{
              position: 'absolute',
              top: '1rem',
              right: '1rem',
              background: 'rgba(255,255,255,0.1)',
              border: 'none',
              borderRadius: 'var(--r-full)',
              color: 'white',
              width: 32,
              height: 32,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer'
            }}
          >
            <X size={18} />
          </button>

          <div style={{
            width: 72,
            height: 72,
            borderRadius: 'var(--r-full)',
            background: 'linear-gradient(135deg, #FFD633, #FFB300)',
            color: '#0B2545',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '2rem',
            fontWeight: 900,
            boxShadow: '0 4px 16px rgba(0,0,0,0.25)',
            marginBottom: '0.75rem'
          }}>
            {initials}
          </div>

          <h2 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 800 }}>
            {user?.email?.split('@')[0] || 'Administrator'}
          </h2>
          <span style={{ 
            fontSize: '0.75rem', 
            fontWeight: 700, 
            letterSpacing: '0.05em', 
            textTransform: 'uppercase',
            color: '#FFD633',
            marginTop: '0.25rem',
            display: 'flex',
            alignItems: 'center',
            gap: '0.25rem'
          }}>
            <ShieldCheck size={14} weight="bold" /> Super Admin
          </span>
        </div>

        <div style={{ padding: '1.75rem', display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
          {/* Email Info */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '0.75rem',
            padding: '0.75rem 1rem',
            background: 'var(--surface-2)',
            borderRadius: 'var(--r-md)',
            border: '1px solid var(--border)'
          }}>
            <Envelope size={20} color="var(--brand-blue)" />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Registered Email</div>
              <div style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {user?.email || 'admin@sarthi.com'}
              </div>
            </div>
          </div>

          {/* Password Reset Action */}
          <div style={{
            padding: '1rem',
            background: 'var(--surface-1)',
            borderRadius: 'var(--r-md)',
            border: '1px solid var(--border)'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.5rem' }}>
              <Key size={18} color="var(--warning)" />
              <span style={{ fontWeight: 700, fontSize: '0.9rem', color: 'var(--text-primary)' }}>Account Security</span>
            </div>
            <p style={{ fontSize: '0.8125rem', color: 'var(--text-secondary)', margin: '0 0 1rem' }}>
              Reset your administrator login password securely by receiving an official reset link in your email inbox.
            </p>
            <button
              onClick={handlePasswordReset}
              disabled={resetting || resetSent}
              className="btn btn-secondary"
              style={{ width: '100%', justifyContent: 'center', gap: '0.5rem' }}
            >
              {resetSent ? (
                <><CheckCircle size={16} color="var(--success)" weight="bold" /> Reset Link Dispatched!</>
              ) : resetting ? (
                'Sending Link...'
              ) : (
                <><Key size={16} /> Send Password Reset Email</>
              )}
            </button>
          </div>

          {/* Sign Out Button */}
          <button
            onClick={handleLogout}
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '0.5rem',
              padding: '0.75rem',
              background: 'rgba(239, 68, 68, 0.1)',
              color: 'var(--error)',
              border: '1px solid rgba(239, 68, 68, 0.2)',
              borderRadius: 'var(--r-md)',
              fontWeight: 700,
              fontSize: '0.9rem',
              cursor: 'pointer',
              transition: 'all 0.2s ease'
            }}
          >
            <SignOut size={18} weight="bold" /> Sign Out
          </button>
        </div>
      </div>
    </div>,
    document.body
  );
};
