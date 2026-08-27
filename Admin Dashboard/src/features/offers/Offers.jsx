import React, { useEffect, useState } from 'react';
import { db } from '../../config/firebase';
import {
  collection, query, orderBy, onSnapshot,
  doc, updateDoc, deleteDoc
} from 'firebase/firestore';
import { Plus, Tag, Percent, Trash, TagChevron, Megaphone, WarningCircle, CheckCircle } from '@phosphor-icons/react';
import { CreateOfferModal } from './components/CreateOfferModal';
import { ConfirmModal } from '../../components/common/ConfirmModal';
import { useToast } from '../../context/ToastContext';

const Offers = () => {
  const [offers, setOffers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [offerToDelete, setOfferToDelete] = useState(null);
  const toast = useToast();

  useEffect(() => {
    const q = query(collection(db, 'offers'), orderBy('createdAt', 'desc'));
    const unsub = onSnapshot(q, snap => {
      setOffers(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    }, err => {
      console.error(err);
      setLoading(false);
    });
    return () => unsub();
  }, []);

  const toggleActive = async (offer) => {
    try {
      await updateDoc(doc(db, 'offers', offer.id), { isActive: !offer.isActive });
      toast(`Offer "${offer.code}" ${offer.isActive ? 'deactivated' : 'activated'}.`, 'success');
    } catch (e) {
      toast(`Error: ${e.message}`, 'error');
    }
  };

  const deleteOffer = async () => {
    if (!offerToDelete) return;
    try {
      await deleteDoc(doc(db, 'offers', offerToDelete.id));
      toast(`Offer "${offerToDelete.code}" deleted.`, 'info');
      setOfferToDelete(null);
    } catch (e) {
      toast(`Error: ${e.message}`, 'error');
    }
  };

  const active   = offers.filter(o => o.isActive);
  const inactive = offers.filter(o => !o.isActive);

  const isExpired = (offer) => {
    if (!offer.expiryDate) return false;
    const exp = offer.expiryDate.toDate ? offer.expiryDate.toDate() : new Date(offer.expiryDate);
    return exp < new Date();
  };

  return (
    <div className="animate-fade-in" style={{ paddingBottom: '2rem' }}>
      
      {/* 1. Premium Header Banner */}
      <div style={{ 
        background: 'linear-gradient(135deg, #9A3412 0%, #C2410C 100%)',
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
            <Megaphone size={32} weight="duotone" style={{ color: '#FDBA74' }} /> 
            Promotions & Campaigns
          </h1>
          <p style={{ color: 'rgba(255,255,255,0.7)', fontSize: '1rem', marginTop: '0.5rem', marginLeft: '3.125rem' }}>
            Create and manage discount codes to drive passenger bookings.
          </p>
        </div>

        <button 
          onClick={() => setShowCreate(true)}
          style={{ 
            position: 'relative', zIndex: 1, 
            background: 'white', color: '#9A3412', 
            border: 'none', padding: '0.75rem 1.5rem', 
            borderRadius: 'var(--r-full)', fontWeight: 700, 
            fontSize: '0.9375rem', display: 'flex', alignItems: 'center', gap: '0.5rem',
            cursor: 'pointer', boxShadow: '0 4px 12px rgba(0,0,0,0.1)'
          }}
        >
          <Plus size={18} weight="bold" />
          Create Offer
        </button>
      </div>

      {/* 2. Marketing KPI Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1.25rem', marginBottom: '2rem' }}>
        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem', border: active.length > 0 ? '1px solid rgba(22,163,74,0.3)' : 'none', background: active.length > 0 ? 'var(--success-bg)' : 'var(--surface-1)' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(22,163,74,0.1)', color: 'var(--success)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <CheckCircle size={18} weight="fill" />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: active.length > 0 ? '#166534' : 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Active Campaigns</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: active.length > 0 ? '#166534' : 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : active.length}
            </div>
          </div>
        </div>

        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(217,119,6,0.1)', color: 'var(--warning)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <WarningCircle size={18} weight="fill" />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Inactive Offers</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : inactive.length}
            </div>
          </div>
        </div>

        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(21,101,192,0.1)', color: '#1565C0', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <TagChevron size={18} weight="fill" />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Total Created</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : offers.length}
            </div>
          </div>
        </div>
      </div>

      {loading ? (
        <div style={{ textAlign: 'center', padding: '4rem', color: 'var(--text-muted)' }}>Syncing promotions...</div>
      ) : offers.length === 0 ? (
        <div className="card" style={{ textAlign: 'center', padding: '5rem 2rem', border: '1px dashed var(--border-strong)', background: 'var(--surface-2)' }}>
          <Tag size={48} weight="duotone" style={{ color: 'var(--text-muted)', marginBottom: '1rem', opacity: 0.5 }} />
          <h3 style={{ color: 'var(--text-primary)', fontWeight: 700, marginBottom: '0.5rem', fontSize: '1.25rem' }}>No campaigns yet</h3>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.9375rem', marginBottom: '1.5rem', maxWidth: 400, margin: '0 auto 1.5rem auto' }}>
            Create your first promotional discount code to incentivize bookings and boost passenger retention.
          </p>
          <button className="btn btn-primary" onClick={() => setShowCreate(true)} style={{ padding: '0.75rem 1.5rem', borderRadius: 'var(--r-full)' }}>
            <Plus size={16} weight="bold" /> Create First Offer
          </button>
        </div>
      ) : (
        <>
          {active.length > 0 && (
            <section style={{ marginBottom: '3rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1.25rem' }}>
                <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--success)' }}></div>
                <h2 style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-primary)', margin: 0 }}>
                  Active Campaigns
                </h2>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '1.5rem' }}>
                {active.map(o => <OfferCard key={o.id} offer={o} expired={isExpired(o)} onToggle={toggleActive} onDelete={() => setOfferToDelete(o)} />)}
              </div>
            </section>
          )}
          {inactive.length > 0 && (
            <section>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1.25rem' }}>
                <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--text-muted)' }}></div>
                <h2 style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-secondary)', margin: 0 }}>
                  Inactive & Past Offers
                </h2>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '1.5rem' }}>
                {inactive.map(o => <OfferCard key={o.id} offer={o} expired={isExpired(o)} onToggle={toggleActive} onDelete={() => setOfferToDelete(o)} />)}
              </div>
            </section>
          )}
        </>
      )}

      {showCreate && (
        <CreateOfferModal onClose={() => setShowCreate(false)} />
      )}

      <ConfirmModal
        isOpen={!!offerToDelete}
        title="Delete Offer?"
        message={`Are you sure you want to delete the offer "${offerToDelete?.code}"? This action cannot be undone.`}
        confirmText="Yes, Delete"
        onConfirm={deleteOffer}
        onCancel={() => setOfferToDelete(null)}
      />
    </div>
  );
};

/* 3. Redesigned Ticket/Coupon Card */
const OfferCard = ({ offer, expired, onToggle, onDelete }) => {
  const expDate = offer.expiryDate?.toDate
    ? offer.expiryDate.toDate().toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
    : offer.expiryDate
    ? new Date(offer.expiryDate).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
    : null;

  return (
    <div style={{ 
      background: 'var(--surface-1)', 
      borderRadius: 'var(--r-xl)', 
      border: '1px solid var(--border)', 
      boxShadow: 'var(--shadow-sm)',
      display: 'flex', 
      flexDirection: 'column',
      position: 'relative',
      opacity: !offer.isActive ? 0.6 : 1,
      transition: 'all 0.2s',
      overflow: 'hidden'
    }}>
      {/* Top Banner / Code Section */}
      <div style={{ 
        padding: '1.5rem', 
        background: offer.isActive && !expired ? 'linear-gradient(135deg, #FFF7ED 0%, #FFEDD5 100%)' : 'var(--surface-2)',
        borderBottom: '2px dashed var(--border-strong)',
        position: 'relative'
      }}>
        {/* Cutouts for ticket effect */}
        <div style={{ position: 'absolute', bottom: -10, left: -10, width: 20, height: 20, borderRadius: '50%', background: 'var(--bg)', borderRight: '1px solid var(--border)' }}></div>
        <div style={{ position: 'absolute', bottom: -10, right: -10, width: 20, height: 20, borderRadius: '50%', background: 'var(--bg)', borderLeft: '1px solid var(--border)' }}></div>
        
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '0.75rem' }}>
          <span style={{ 
            background: expired ? 'var(--error-bg)' : offer.isActive ? '#F97316' : 'var(--surface-3)',
            color: expired ? 'var(--error)' : offer.isActive ? 'white' : 'var(--text-muted)',
            padding: '0.25rem 0.75rem', borderRadius: 'var(--r-full)', fontSize: '0.75rem', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.05em'
          }}>
            {expired ? 'Expired' : offer.isActive ? 'Live' : 'Paused'}
          </span>
          <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 2px 4px rgba(0,0,0,0.05)' }}>
            <Percent size={16} weight="bold" style={{ color: '#F97316' }} />
          </div>
        </div>

        <div style={{ fontSize: '1.75rem', fontWeight: 900, color: 'var(--text-primary)', letterSpacing: '-0.02em', lineHeight: 1.1 }}>
          {offer.code || 'NO CODE'}
        </div>
        <div style={{ fontSize: '1rem', fontWeight: 700, color: '#EA580C', marginTop: '0.25rem' }}>
          {offer.type === 'flat' ? `₹${offer.value} OFF` : `${offer.value}% OFF`}
        </div>
      </div>

      {/* Details Section */}
      <div style={{ padding: '1.5rem', flex: 1, display: 'flex', flexDirection: 'column' }}>
        <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', lineHeight: 1.5, marginBottom: '1rem', flex: 1 }}>
          {offer.description || 'No description provided for this campaign.'}
        </p>

        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', marginBottom: '1.5rem' }}>
          {offer.minAmount > 0 && (
            <div style={{ background: 'var(--surface-2)', padding: '0.25rem 0.625rem', borderRadius: '4px', fontSize: '0.75rem', color: 'var(--text-secondary)', fontWeight: 600 }}>
              Min Order: ₹{offer.minAmount}
            </div>
          )}
          {expDate && (
            <div style={{ background: expired ? 'var(--error-bg)' : 'var(--surface-2)', padding: '0.25rem 0.625rem', borderRadius: '4px', fontSize: '0.75rem', color: expired ? 'var(--error)' : 'var(--text-secondary)', fontWeight: 600 }}>
              Ends {expDate}
            </div>
          )}
        </div>

        {/* Action Row */}
        <div style={{ display: 'flex', gap: '0.5rem', marginTop: 'auto' }}>
          <button
            onClick={() => onToggle(offer)}
            style={{ 
              flex: 1, padding: '0.625rem', borderRadius: 'var(--r-md)', border: 'none', 
              background: offer.isActive ? 'var(--surface-2)' : '#16A34A', 
              color: offer.isActive ? 'var(--text-primary)' : 'white',
              fontWeight: 600, fontSize: '0.875rem', cursor: 'pointer', transition: 'all 0.2s'
            }}
          >
            {offer.isActive ? 'Pause Campaign' : 'Activate Campaign'}
          </button>
          <button
            onClick={() => onDelete(offer)}
            style={{ 
              width: '40px', display: 'flex', alignItems: 'center', justifyContent: 'center', 
              borderRadius: 'var(--r-md)', border: '1px solid var(--border)', background: 'white',
              color: 'var(--error)', cursor: 'pointer', transition: 'all 0.2s'
            }}
            title="Delete Offer"
          >
            <Trash size={18} />
          </button>
        </div>
      </div>
    </div>
  );
};

export default Offers;
