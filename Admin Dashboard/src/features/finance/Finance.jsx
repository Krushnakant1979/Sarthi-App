import React, { useEffect, useState } from 'react';
import { db } from '../../config/firebase';
import { collection, onSnapshot, query, where, orderBy, doc, writeBatch, serverTimestamp } from 'firebase/firestore';
import { Bank } from '@phosphor-icons/react';
import { useToast } from '../../context/ToastContext';
import { logAdminAction } from '../../services/auditService';

export const Finance = () => {
  const [activeTab, setActiveTab] = useState('pending');
  const [rides, setRides] = useState([]);
  const [payouts, setPayouts] = useState([]);
  const [captainNames, setCaptainNames] = useState({});
  const [loading, setLoading] = useState(true);
  const [processingId, setProcessingId] = useState(null);
  const toast = useToast();

  useEffect(() => {
    let unsubInnerPayouts = null;

    const qRides = query(collection(db, 'ride_requests'), where('status', '==', 'completed'));
    const unsubRides = onSnapshot(qRides, (snap) => {
      setRides(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });

    const unsubCaptains = onSnapshot(query(collection(db, 'users'), where('role', '==', 'captain')), (snap) => {
      const map = {};
      snap.forEach(doc => {
        const d = doc.data();
        map[doc.id] = d.name || d.fullName || d.displayName || d.phone || 'Captain';
      });
      setCaptainNames(map);
    }, (err) => console.warn('Failed to load captain names:', err));

    const qPayouts = query(collection(db, 'payout_history'), orderBy('settledAt', 'desc'));
    const unsubPayouts = onSnapshot(qPayouts, (snap) => {
      if (!snap.empty) {
        setPayouts(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      } else {
        // Fallback to legacy payouts collection
        if (unsubInnerPayouts) unsubInnerPayouts();
        const qLegacy = query(collection(db, 'payouts'), orderBy('createdAt', 'desc'));
        unsubInnerPayouts = onSnapshot(qLegacy, (legSnap) => {
          setPayouts(legSnap.docs.map(d => ({ id: d.id, ...d.data() })));
        });
      }
    }, (err) => {
      // If index missing on settledAt, fallback gracefully
      if (unsubInnerPayouts) unsubInnerPayouts();
      const qLegacy = query(collection(db, 'payout_history'));
      unsubInnerPayouts = onSnapshot(qLegacy, (s) => {
        const sorted = s.docs.map(d => ({ id: d.id, ...d.data() })).sort((a,b) => {
          const tA = (a.settledAt || a.createdAt)?.toDate?.() || 0;
          const tB = (b.settledAt || b.createdAt)?.toDate?.() || 0;
          return tB - tA;
        });
        setPayouts(sorted);
      });
    });

    return () => {
      unsubRides();
      unsubCaptains();
      unsubPayouts();
      if (unsubInnerPayouts) unsubInnerPayouts();
    };
  }, []);

  const pendingByCaptain = {};
  let totalRevenue = 0;
  let platformEarnings = 0;
  let totalPendingPayouts = 0;

  rides.forEach(ride => {
    const fare = Number(ride.actualFare || ride.finalFare || ride.fareEstimate) || 0;
    totalRevenue += fare;
    const comm = fare * 0.15; // 15% commission
    platformEarnings += comm;

    const capId = ride.assignedCaptainId || ride.captainId;
    if (!ride.isSettled && capId) {
      if (!pendingByCaptain[capId]) {
        pendingByCaptain[capId] = { 
          captainId: capId, 
          captainName: ride.captainName || null,
          rides: [], 
          totalAmount: 0 
        };
      } else if (!pendingByCaptain[capId].captainName && ride.captainName) {
        pendingByCaptain[capId].captainName = ride.captainName;
      }
      pendingByCaptain[capId].rides.push(ride.id);
      pendingByCaptain[capId].totalAmount += (fare - comm);
      totalPendingPayouts += (fare - comm);
    }
  });

  const pendingList = Object.values(pendingByCaptain);

  const handleSettle = async (captainId, totalAmount, rideIds) => {
    setProcessingId(captainId);
    try {
      // Chunk ride updates into safe batches of 400 to prevent Firestore 500-operation limit crash
      const CHUNK_SIZE = 400;
      for (let i = 0; i < rideIds.length; i += CHUNK_SIZE) {
        const chunk = rideIds.slice(i, i + CHUNK_SIZE);
        const rideBatch = writeBatch(db);
        chunk.forEach(id => {
          const rideRef = doc(db, 'ride_requests', id);
          rideBatch.update(rideRef, { isSettled: true });
        });
        await rideBatch.commit();
      }

      // Record unified payout history
      const payoutBatch = writeBatch(db);
      const payoutHistoryRef = doc(collection(db, 'payout_history'));
      const capName = pendingByCaptain[captainId]?.captainName || captainNames[captainId] || 'Captain';
      const payoutPayload = {
        captainId,
        captainName: capName,
        amount: totalAmount,
        status: 'completed',
        settledAt: serverTimestamp(),
        createdAt: serverTimestamp(),
        rideIds: rideIds,
        rideCount: rideIds.length
      };
      payoutBatch.set(payoutHistoryRef, payoutPayload);

      // Dual-write to legacy payouts collection
      const legacyPayoutRef = doc(collection(db, 'payouts'));
      payoutBatch.set(legacyPayoutRef, payoutPayload);
      await payoutBatch.commit();

      // Record administrative audit trail
      await logAdminAction('payout_settled', captainId, {
        captainName: capName,
        amount: totalAmount,
        rideCount: rideIds.length
      });

      toast(`Successfully settled ₹${totalAmount.toFixed(2)} for captain.`, 'success');
    } catch (err) {
      console.error(err);
      toast('Failed to process settlement.', 'error');
    } finally {
      setProcessingId(null);
    }
  };

  return (
    <div className="animate-fade-in" style={{ paddingBottom: '2rem' }}>
      <div style={{ 
        background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 100%)',
        borderRadius: 'var(--r-xl)', padding: '2rem 3rem', color: 'white',
        marginBottom: '2rem', boxShadow: 'var(--shadow-md)', position: 'relative', overflow: 'hidden'
      }}>
        <div style={{ position: 'relative', zIndex: 1 }}>
          <h1 style={{ fontSize: '2rem', fontWeight: 800, margin: 0, display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <Bank size={32} weight="duotone" style={{ color: 'var(--success)' }} /> 
            Finance & Settlements
          </h1>
          <p style={{ color: 'rgba(255,255,255,0.6)', fontSize: '1rem', marginTop: '0.5rem', marginLeft: '3.125rem' }}>
            Track platform revenue and manage captain payouts.
          </p>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1.25rem', marginBottom: '2rem' }}>
        <div className="card" style={{ padding: '1.5rem' }}>
          <div style={{ fontSize: '0.875rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase' }}>Total Gross Revenue</div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: 'var(--text-primary)', marginTop: '0.5rem' }}>
            ₹{totalRevenue.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 0 })}
          </div>
        </div>
        <div className="card" style={{ padding: '1.5rem' }}>
          <div style={{ fontSize: '0.875rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase' }}>Platform Earnings (15%)</div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: 'var(--success)', marginTop: '0.5rem' }}>
            ₹{platformEarnings.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 0 })}
          </div>
        </div>
        <div className="card" style={{ padding: '1.5rem', border: '1px solid var(--warning)' }}>
          <div style={{ fontSize: '0.875rem', color: 'var(--warning)', fontWeight: 600, textTransform: 'uppercase' }}>Pending Payouts</div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: 'var(--warning)', marginTop: '0.5rem' }}>
            ₹{totalPendingPayouts.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 0 })}
          </div>
        </div>
      </div>

      <div className="card">
        <div style={{ display: 'flex', borderBottom: '1px solid var(--border)' }}>
          <button 
            onClick={() => setActiveTab('pending')}
            style={{ padding: '1rem 2rem', background: 'transparent', border: 'none', borderBottom: activeTab === 'pending' ? '3px solid var(--brand-blue)' : '3px solid transparent', color: activeTab === 'pending' ? 'var(--brand-blue)' : 'var(--text-muted)', fontWeight: 600, cursor: 'pointer' }}>
            Pending Settlements
          </button>
          <button 
            onClick={() => setActiveTab('history')}
            style={{ padding: '1rem 2rem', background: 'transparent', border: 'none', borderBottom: activeTab === 'history' ? '3px solid var(--brand-blue)' : '3px solid transparent', color: activeTab === 'history' ? 'var(--brand-blue)' : 'var(--text-muted)', fontWeight: 600, cursor: 'pointer' }}>
            Payout History
          </button>
        </div>

        <div style={{ padding: '1.5rem' }}>
          {activeTab === 'pending' && (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Captain ID</th>
                  <th>Unsettled Rides</th>
                  <th>Total Owed</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr><td colSpan="4" className="table-empty">Loading...</td></tr>
                ) : pendingList.length === 0 ? (
                  <tr><td colSpan="4" className="table-empty">No pending settlements.</td></tr>
                ) : (
                  pendingList.map(p => (
                    <tr key={p.captainId}>
                      <td style={{ fontWeight: 600, color: 'var(--brand-blue)' }}>
                        {p.captainName ? `${p.captainName} (${p.captainId})` : p.captainId}
                      </td>
                      <td>{p.rides.length} rides</td>
                      <td style={{ fontWeight: 700, color: 'var(--warning)' }}>₹{p.totalAmount.toFixed(2)}</td>
                      <td>
                        <button 
                          className="btn btn-primary btn-sm"
                          disabled={processingId === p.captainId}
                          onClick={() => handleSettle(p.captainId, p.totalAmount, p.rides)}
                        >
                          {processingId === p.captainId ? 'Processing...' : 'Settle Now'}
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          )}

          {activeTab === 'history' && (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Captain ID</th>
                  <th>Amount</th>
                  <th>Rides Settled</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {payouts.length === 0 ? (
                  <tr><td colSpan="5" className="table-empty">No payout history found.</td></tr>
                ) : (
                  payouts.map(p => {
                    const ts = p.settledAt || p.createdAt;
                    const dt = ts?.toDate ? ts.toDate() : (ts ? new Date(ts) : null);
                    const dateStr = dt && !isNaN(dt.getTime())
                      ? new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(dt)
                      : '—';
                    const timeStr = dt && !isNaN(dt.getTime())
                      ? new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit', hour12: true }).format(dt)
                      : '';
                    return (
                      <tr key={p.id}>
                        <td style={{ whiteSpace: 'nowrap', verticalAlign: 'middle' }}>
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.15rem' }}>
                            <span style={{ fontSize: '0.8125rem', fontWeight: 600, color: 'var(--text-primary)' }}>{dateStr}</span>
                            {timeStr && <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{timeStr}</span>}
                          </div>
                        </td>
                        <td style={{ verticalAlign: 'middle' }}>
                          <div style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{p.captainName || captainNames[p.captainId] || 'Captain'}</div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontFamily: 'monospace' }}>{p.captainId}</div>
                        </td>
                        <td style={{ fontWeight: 700 }}>₹{p.amount?.toFixed(2)}</td>
                        <td>{p.rideCount || 0}</td>
                        <td><span style={{ color: 'var(--success)', fontWeight: 600, background: 'var(--success-bg)', padding: '4px 8px', borderRadius: '4px' }}>{p.status}</span></td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
};
