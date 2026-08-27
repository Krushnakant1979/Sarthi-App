import React, { useState } from 'react';
import { db, auth } from '../../../config/firebase';
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { useToast } from '../../../context/ToastContext';
import { Tag } from '@phosphor-icons/react';
import { createPortal } from 'react-dom';

const today = () => {
  const d = new Date();
  d.setDate(d.getDate() + 30);
  return d.toISOString().split('T')[0];
};

export const CreateOfferModal = ({ onClose, onCreated }) => {
  const toast = useToast();
  const [form, setForm] = useState({
    code: '',
    description: '',
    type: 'flat',
    value: '',
    minAmount: '',
    expiryDate: today(),
  });
  const [saving, setSaving] = useState(false);
  const [errors, setErrors] = useState({});

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  const validate = () => {
    const e = {};
    if (!form.code.trim())        e.code        = 'Coupon code is required';
    if (!form.description.trim()) e.description = 'Description is required';
    if (!form.value || isNaN(Number(form.value)) || Number(form.value) <= 0)
                                   e.value       = 'Enter a valid discount value';
    if (!form.minAmount || isNaN(Number(form.minAmount)) || Number(form.minAmount) < 0)
                                   e.minAmount   = 'Enter a valid minimum amount';
    if (!form.expiryDate)          e.expiryDate  = 'Expiry date is required';
    setErrors(e);
    return Object.keys(e).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;
    setSaving(true);
    try {
      await addDoc(collection(db, 'offers'), {
        code: form.code.trim().toUpperCase(),
        description: form.description.trim(),
        type: form.type,
        value: Number(form.value),
        minAmount: Number(form.minAmount),
        expiryDate: new Date(form.expiryDate),
        isActive: true,
        createdAt: serverTimestamp(),
        createdBy: auth.currentUser?.uid,
      });
      toast(`Offer "${form.code.toUpperCase()}" published successfully!`, 'success');
      onCreated?.();
      onClose();
    } catch (err) {
      toast(`Failed to create offer: ${err.message}`, 'error');
    } finally {
      setSaving(false);
    }
  };

  return createPortal(
    <div className="modal-backdrop" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal" style={{ display: 'flex', flexDirection: 'column', maxHeight: '90vh', overflow: 'hidden' }}>
        <div className="modal-header" style={{ flexShrink: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <div style={{ width: 38, height: 38, borderRadius: 'var(--r-md)', background: 'rgba(79,70,229,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Tag size={19} weight="bold" style={{ color: 'var(--info)' }} />
            </div>
            <span className="modal-title">Create New Offer</span>
          </div>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden', flex: 1 }}>
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem', overflowY: 'auto', flex: 1 }}>
            {/* Code */}
            <div className="form-group">
              <label className="form-label">Coupon Code <span style={{ color: 'var(--error)' }}>*</span></label>
              <input
                className="form-input"
                placeholder="e.g. FLAT50"
                value={form.code}
                onChange={e => set('code', e.target.value.toUpperCase())}
                style={{ textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}
              />
              {errors.code && <span style={{ color: 'var(--error)', fontSize: '0.8125rem' }}>{errors.code}</span>}
            </div>

            {/* Description */}
            <div className="form-group">
              <label className="form-label">Description <span style={{ color: 'var(--error)' }}>*</span></label>
              <input
                className="form-input"
                placeholder="e.g. ₹50 off on your first 3 rides"
                value={form.description}
                onChange={e => set('description', e.target.value)}
              />
              {errors.description && <span style={{ color: 'var(--error)', fontSize: '0.8125rem' }}>{errors.description}</span>}
            </div>

            {/* Type + Value */}
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">Discount Type</label>
                <select className="form-select" value={form.type} onChange={e => set('type', e.target.value)}>
                  <option value="flat">Flat Amount (₹)</option>
                  <option value="percent">Percentage (%)</option>
                </select>
              </div>
              <div className="form-group">
                <label className="form-label">Discount Value <span style={{ color: 'var(--error)' }}>*</span></label>
                <input
                  className="form-input"
                  type="number"
                  min="1"
                  placeholder={form.type === 'flat' ? 'Amount in ₹' : 'Percentage'}
                  value={form.value}
                  onChange={e => set('value', e.target.value)}
                />
                {errors.value && <span style={{ color: 'var(--error)', fontSize: '0.8125rem' }}>{errors.value}</span>}
              </div>
            </div>

            {/* Min Amount + Expiry */}
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">Minimum Ride Amount (₹) <span style={{ color: 'var(--error)' }}>*</span></label>
                <input
                  className="form-input"
                  type="number"
                  min="0"
                  placeholder="e.g. 100"
                  value={form.minAmount}
                  onChange={e => set('minAmount', e.target.value)}
                />
                {errors.minAmount && <span style={{ color: 'var(--error)', fontSize: '0.8125rem' }}>{errors.minAmount}</span>}
              </div>
              <div className="form-group">
                <label className="form-label">Expiry Date <span style={{ color: 'var(--error)' }}>*</span></label>
                <input
                  className="form-input"
                  type="date"
                  min={new Date().toISOString().split('T')[0]}
                  value={form.expiryDate}
                  onChange={e => set('expiryDate', e.target.value)}
                />
                {errors.expiryDate && <span style={{ color: 'var(--error)', fontSize: '0.8125rem' }}>{errors.expiryDate}</span>}
              </div>
            </div>

            {/* Preview */}
            {form.code && form.value && (
              <div style={{ background: 'linear-gradient(135deg, rgba(21,101,192,0.06), rgba(0,166,166,0.06))', border: '1px dashed var(--border-strong)', borderRadius: 'var(--r-lg)', padding: '1rem 1.25rem', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '0.125rem' }}>Preview</div>
                  <div style={{ fontWeight: 800, fontSize: '1.125rem', color: 'var(--text-primary)', letterSpacing: '0.04em' }}>{form.code}</div>
                  {form.description && <div style={{ fontSize: '0.8125rem', color: 'var(--text-secondary)', marginTop: '0.125rem' }}>{form.description}</div>}
                </div>
                <div style={{ fontSize: '1.625rem', fontWeight: 800, color: 'var(--brand-blue)' }}>
                  {form.type === 'flat' ? `₹${form.value}` : `${form.value}%`} OFF
                </div>
              </div>
            )}
          </div>

          <div className="modal-footer" style={{ flexShrink: 0 }}>
            <button type="button" className="btn btn-secondary" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn btn-primary" disabled={saving}>
              {saving ? 'Publishing...' : 'Publish Offer'}
            </button>
          </div>
        </form>
      </div>
    </div>,
    document.body
  );
};
