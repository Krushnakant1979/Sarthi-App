import React, { useState, useEffect } from 'react';
import { db } from '../../../config/firebase';
import { doc, updateDoc, collection, query, where, getDocs, serverTimestamp } from 'firebase/firestore';
import { useToast } from '../../../context/ToastContext';
import { User, Phone, Envelope, Star, Car, ShieldCheck, X, Check, Copy } from '@phosphor-icons/react';
import { createPortal } from 'react-dom';
import { logAdminAction } from '../../../services/auditService';
import { ConfirmModal } from '../../../components/common/ConfirmModal';

export const UserDetailsModal = ({ user, onClose }) => {
  const [ridesCount, setRidesCount] = useState(null);
  const [updating, setUpdating] = useState(false);
  const [copiedId, setCopiedId] = useState(false);
  const { showToast } = useToast();

  useEffect(() => {
    if (!user?.id) return;
    const fetchUserStats = async () => {
      try {
        const q = query(collection(db, 'ride_requests'), where('userId', '==', user.id));
        const snap = await getDocs(q);
        setRidesCount(snap.docs.length);
      } catch (err) {
        console.error('Error fetching user rides count:', err);
        setRidesCount(0);
      }
    };
    fetchUserStats();
  }, [user]);

  const handleCopyId = () => {
    navigator.clipboard.writeText(user.publicId || user.id);
    setCopiedId(true);
    setTimeout(() => setCopiedId(false), 2000);
  };

  const [pendingRole, setPendingRole] = useState(null);

  const handleRoleChange = (newRole) => {
    setPendingRole(newRole);
  };

  const confirmRoleChange = async () => {
    if (!pendingRole) return;
    const newRole = pendingRole;
    setUpdating(true);
    try {
      await updateDoc(doc(db, 'users', user.id), {
        role: newRole,
        updatedAt: serverTimestamp(),
      });
      await logAdminAction('user_role_changed', user.id, {
        oldRole: user.role,
        newRole,
      });
      showToast(`User role updated to ${newRole}`, 'success');
      setPendingRole(null);
      onClose();
    } catch (err) {
      console.error(err);
      showToast(`Failed to update role: ${err.message}`, 'error');
    } finally {
      setUpdating(false);
    }
  };

  if (!user) return null;

  return createPortal(
    <div className="modal-backdrop" onClick={onClose}>
      <div 
        className="modal" 
        onClick={e => e.stopPropagation()}
        style={{ maxWidth: '520px', width: '100%', padding: 0, overflow: 'hidden' }}
      >
        {/* Header */}
        <div style={{
          background: 'linear-gradient(135deg, #1E1B4B 0%, #312E81 100%)',
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
            width: 64,
            height: 64,
            borderRadius: 'var(--r-full)',
            background: 'linear-gradient(135deg, #7C3AED, #5B21B6)',
            color: 'white',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '1.75rem',
            fontWeight: 800,
            boxShadow: '0 4px 14px rgba(0,0,0,0.25)',
            marginBottom: '0.75rem'
          }}>
            {user.name ? user.name.charAt(0).toUpperCase() : 'U'}
          </div>

          <h2 style={{ margin: 0, fontSize: '1.3rem', fontWeight: 800 }}>
            {user.name || 'Passenger Profile'}
          </h2>
          <div style={{ 
            fontSize: '0.75rem', 
            color: '#A5B4FC', 
            fontFamily: 'monospace', 
            marginTop: '0.25rem',
            display: 'flex',
            alignItems: 'center',
            gap: '0.5rem'
          }}>
            ID: {user.publicId || user.id}
            <button 
              onClick={handleCopyId}
              style={{ background: 'none', border: 'none', color: copiedId ? '#4ADE80' : 'white', cursor: 'pointer', padding: 0 }}
              title="Copy ID"
            >
              {copiedId ? <Check size={14} weight="bold" /> : <Copy size={14} />}
            </button>
          </div>
        </div>

        {/* Content Details */}
        <div style={{ padding: '1.75rem', display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
          {/* Quick Stats Grid */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '1rem' }}>
            <div style={{
              padding: '1rem',
              background: 'var(--surface-2)',
              borderRadius: 'var(--r-md)',
              border: '1px solid var(--border)',
              display: 'flex',
              alignItems: 'center',
              gap: '0.75rem'
            }}>
              <Car size={24} color="var(--brand-blue)" />
              <div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Total Trips</div>
                <div style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--text-primary)' }}>
                  {ridesCount !== null ? ridesCount : '...'}
                </div>
              </div>
            </div>

            <div style={{
              padding: '1rem',
              background: 'var(--surface-2)',
              borderRadius: 'var(--r-md)',
              border: '1px solid var(--border)',
              display: 'flex',
              alignItems: 'center',
              gap: '0.75rem'
            }}>
              <Star size={24} color="var(--warning)" weight="fill" />
              <div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Passenger Rating</div>
                <div style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--text-primary)' }}>
                  {user.rating || '5.0'}
                </div>
              </div>
            </div>
          </div>

          {/* Contact Details */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.75rem',
              padding: '0.75rem 1rem',
              background: 'var(--surface-1)',
              borderRadius: 'var(--r-md)',
              border: '1px solid var(--border)'
            }}>
              <Phone size={18} color="var(--text-muted)" />
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Phone Number</div>
                <div style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-primary)' }}>
                  {user.phone || 'Not provided'}
                </div>
              </div>
            </div>

            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.75rem',
              padding: '0.75rem 1rem',
              background: 'var(--surface-1)',
              borderRadius: 'var(--r-md)',
              border: '1px solid var(--border)'
            }}>
              <Envelope size={18} color="var(--text-muted)" />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Email Address</div>
                <div style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {user.email || 'Not provided'}
                </div>
              </div>
            </div>
          </div>

          {/* Role Management */}
          <div style={{
            padding: '1rem',
            background: 'var(--surface-2)',
            borderRadius: 'var(--r-md)',
            border: '1px solid var(--border)'
          }}>
            <div style={{ fontSize: '0.8rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '0.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <ShieldCheck size={16} color="var(--brand-blue)" /> Change Account Role
            </div>
            <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
              {['user', 'captain', 'admin'].map(r => (
                <button
                  key={r}
                  disabled={updating || user.role === r}
                  onClick={() => handleRoleChange(r)}
                  style={{
                    flex: 1,
                    padding: '0.5rem',
                    borderRadius: 'var(--r-sm)',
                    border: user.role === r ? '2px solid var(--brand-blue)' : '1px solid var(--border)',
                    background: user.role === r ? 'rgba(37, 99, 235, 0.1)' : 'var(--surface-1)',
                    color: user.role === r ? 'var(--brand-blue)' : 'var(--text-primary)',
                    fontWeight: 700,
                    fontSize: '0.8125rem',
                    textTransform: 'capitalize',
                    cursor: user.role === r ? 'default' : 'pointer'
                  }}
                >
                  {r === 'user' ? 'Passenger' : r}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>

      <ConfirmModal
        isOpen={!!pendingRole}
        title="Change User Role?"
        message={`Are you sure you want to change this user's role to "${pendingRole}"?`}
        confirmText="Confirm Role Change"
        onConfirm={confirmRoleChange}
        onCancel={() => setPendingRole(null)}
      />
    </div>
  );
};
