import React, { useState, useEffect } from 'react';
import { Headset, Users, SteeringWheel, CheckCircle, WarningCircle, Funnel } from '@phosphor-icons/react';
import { collection, query, orderBy, onSnapshot, doc, updateDoc } from 'firebase/firestore';
import { db } from '../../config/firebase';
import { useToast } from '../../context/ToastContext';

const Tabs = [
  { id: 'all', label: 'All Complaints', icon: Headset },
  { id: 'user', label: 'User Complaints', icon: Users },
  { id: 'captain', label: 'Captain Complaints', icon: SteeringWheel },
  { id: 'resolved', label: 'Resolved', icon: CheckCircle },
];

export default function Support() {
  const [activeTab, setActiveTab] = useState('all');
  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const { showToast } = useToast();

  useEffect(() => {
    const q = query(collection(db, 'support_tickets'), orderBy('createdAt', 'desc'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const ticketsData = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setTickets(ticketsData);
      setLoading(false);
    }, (error) => {
      console.error("Error fetching support tickets:", error);
      showToast('Failed to load complaints', 'error');
      setLoading(false);
    });

    return () => unsubscribe();
  }, [showToast]);

  const handleResolve = async (ticketId) => {
    try {
      const ticketRef = doc(db, 'support_tickets', ticketId);
      await updateDoc(ticketRef, {
        status: 'resolved',
        resolutionMessage: 'This issue has been reviewed and resolved by the support team.'
      });
      showToast('Complaint resolved successfully', 'success');
    } catch (error) {
      console.error("Error resolving ticket:", error);
      showToast('Failed to resolve complaint', 'error');
    }
  };

  const filteredTickets = tickets.filter(ticket => {
    if (activeTab === 'resolved') {
      return ticket.status === 'resolved';
    }
    
    if (ticket.status === 'resolved') return false; // Hide resolved from other tabs

    if (activeTab === 'user') return ticket.reporterRole === 'user';
    if (activeTab === 'captain') return ticket.reporterRole === 'captain';
    
    return true; // 'all' tab
  });

  const formatDate = (timestamp) => {
    if (!timestamp) return 'N/A';
    const date = timestamp.toDate();
    return new Intl.DateTimeFormat('en-US', {
      month: 'short', day: 'numeric', year: 'numeric',
      hour: 'numeric', minute: '2-digit'
    }).format(date);
  };

  return (
    <div className="animate-fade-in">
      <div className="page-header">
        <div>
          <h1>Support & Complaints</h1>
          <p>Review and resolve user and captain complaints</p>
        </div>
        
        <div style={{ display: 'flex', gap: '1rem' }}>
          <div className="stat-card-modern" style={{ padding: '0.75rem 1.25rem', minWidth: '140px', background: 'var(--surface-2)', boxShadow: 'none', border: '1px solid var(--border)' }}>
            <div style={{ fontSize: '0.7rem', fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Open Tickets</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--error)', display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
              {tickets.filter(t => t.status !== 'resolved').length}
            </div>
          </div>
          <div className="stat-card-modern" style={{ padding: '0.75rem 1.25rem', minWidth: '140px', background: 'var(--surface-2)', boxShadow: 'none', border: '1px solid var(--border)' }}>
            <div style={{ fontSize: '0.7rem', fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Resolved</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--success)' }}>
              {tickets.filter(t => t.status === 'resolved').length}
            </div>
          </div>
        </div>
      </div>

      <div className="settings-layout">
        {/* Sidebar Tabs */}
        <div className="card" style={{ padding: '1rem 0' }}>
          <div style={{ padding: '0 1.25rem 0.5rem', fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Filter Complaints
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
            {Tabs.map(tab => {
              const isActive = activeTab === tab.id;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  style={{
                    display: 'flex', alignItems: 'center', gap: '0.75rem',
                    padding: '0.75rem 1rem', border: 'none', margin: '0 0.75rem',
                    borderRadius: 'var(--r-md)',
                    background: isActive ? 'rgba(21,101,192,0.1)' : 'transparent',
                    color: isActive ? 'var(--brand-blue)' : 'var(--text-secondary)',
                    fontWeight: isActive ? 600 : 500,
                    textAlign: 'left', cursor: 'pointer', transition: 'all var(--t-fast)',
                  }}
                >
                  <tab.icon size={18} weight={isActive ? "fill" : "regular"} />
                  {tab.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* Content Area */}
        <div className="card">
          <div style={{ padding: '1.5rem', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h2 style={{ fontSize: '1.1rem', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Funnel size={20} color="var(--brand-blue)" /> 
              {Tabs.find(t => t.id === activeTab)?.label}
            </h2>
          </div>
          
          {loading ? (
            <div style={{ padding: '3rem', textAlign: 'center', color: 'var(--text-muted)' }}>Loading tickets...</div>
          ) : filteredTickets.length === 0 ? (
            <div style={{ padding: '3rem', textAlign: 'center', color: 'var(--text-muted)' }}>
              <CheckCircle size={48} color="var(--success)" style={{ opacity: 0.5, marginBottom: '1rem' }} />
              <p>No complaints found in this category.</p>
            </div>
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Role</th>
                  <th>User ID</th>
                  <th>Subject</th>
                  <th>Message</th>
                  <th>Status</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {filteredTickets.map(ticket => (
                  <tr key={ticket.id}>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem' }}>{formatDate(ticket.createdAt)}</td>
                    <td style={{ padding: '1rem 1.25rem' }}>
                      <span style={{ 
                        padding: '0.25rem 0.75rem', 
                        borderRadius: 'var(--r-full)', 
                        fontSize: '0.75rem', 
                        fontWeight: 600,
                        background: ticket.reporterRole === 'captain' ? 'rgba(255, 179, 0, 0.15)' : 'rgba(37, 99, 235, 0.1)',
                        color: ticket.reporterRole === 'captain' ? 'var(--brand-yellow-dark)' : 'var(--brand-blue)',
                        textTransform: 'capitalize'
                      }}>
                        {ticket.reporterRole || 'user'}
                      </span>
                    </td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', color: 'var(--text-secondary)' }}>
                      {ticket.userId ? ticket.userId.substring(0, 8) + '...' : 'Unknown'}
                    </td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', fontWeight: 600 }}>{ticket.subject}</td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', color: 'var(--text-secondary)', maxWidth: '250px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }} title={ticket.message}>
                      {ticket.message}
                    </td>
                    <td style={{ padding: '1rem 1.25rem' }}>
                      <span style={{ 
                        padding: '0.25rem 0.75rem', 
                        borderRadius: 'var(--r-full)', 
                        fontSize: '0.75rem', 
                        fontWeight: 600,
                        background: ticket.status === 'resolved' ? 'var(--success-bg)' : 'var(--error-bg)',
                        color: ticket.status === 'resolved' ? 'var(--success)' : 'var(--error)'
                      }}>
                        {ticket.status === 'resolved' ? 'Resolved' : 'Open'}
                      </span>
                    </td>
                    <td style={{ padding: '1rem 1.25rem' }}>
                      {ticket.status !== 'resolved' && (
                        <button 
                          onClick={() => handleResolve(ticket.id)}
                          className="btn btn-secondary btn-sm" 
                          style={{ padding: '0.375rem 0.75rem' }}
                        >
                          Resolve
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}
