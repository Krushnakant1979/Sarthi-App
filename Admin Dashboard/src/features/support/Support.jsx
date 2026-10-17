import React, { useState, useEffect } from 'react';
import { Headset, Users, SteeringWheel, CheckCircle, Funnel, Eye, Check, X } from '@phosphor-icons/react';
import { collection, query, orderBy, onSnapshot, doc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../../config/firebase';
import { useToast } from '../../context/ToastContext';
import TicketDetailsModal from './components/TicketDetailsModal';
import { logAdminAction } from '../../services/auditService';

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
  const [selectedTicket, setSelectedTicket] = useState(null);
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

  const [resolvingTicket, setResolvingTicket] = useState(null);
  const [resolutionText, setResolutionText] = useState('This issue has been reviewed and resolved by the support team.');
  const [isSubmittingResolve, setIsSubmittingResolve] = useState(false);

  const handleResolve = async (ticketId, customMessage) => {
    try {
      const msg = (customMessage !== undefined && customMessage.trim()) 
        ? customMessage.trim() 
        : 'This issue has been reviewed and resolved by the support team.';

      const ticketRef = doc(db, 'support_tickets', ticketId);
      await updateDoc(ticketRef, {
        status: 'resolved',
        resolutionMessage: msg,
        resolvedAt: serverTimestamp(),
      });
      await logAdminAction('ticket_resolved', ticketId, {
        resolutionMessage: msg,
      });
      setSelectedTicket(prev => (prev && prev.id === ticketId ? { 
        ...prev, 
        status: 'resolved', 
        resolutionMessage: msg 
      } : prev));
      setResolvingTicket(null);
      showToast('Complaint resolved successfully', 'success');
    } catch (error) {
      console.error("Error resolving ticket:", error);
      showToast('Failed to resolve complaint', 'error');
    } finally {
      setIsSubmittingResolve(false);
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

  const formatDateParts = (timestamp) => {
    if (!timestamp) return { dateStr: '—', timeStr: '' };
    const date = timestamp.toDate ? timestamp.toDate() : (timestamp instanceof Date ? timestamp : new Date(timestamp));
    if (isNaN(date.getTime())) return { dateStr: '—', timeStr: '' };

    const dateStr = new Intl.DateTimeFormat('en-US', {
      month: 'short', day: 'numeric', year: 'numeric'
    }).format(date);

    const timeStr = new Intl.DateTimeFormat('en-US', {
      hour: 'numeric', minute: '2-digit', hour12: true
    }).format(date);

    return { dateStr, timeStr };
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
            <div style={{ overflowX: 'auto', width: '100%', padding: '0.5rem' }}>
              <table className="data-table" style={{ width: '100%' }}>
                <thead>
                  <tr>
                    <th style={{ width: '135px', whiteSpace: 'nowrap', padding: '0.875rem 0.75rem 0.875rem 1.25rem' }}>Date</th>
                    <th style={{ width: '85px', whiteSpace: 'nowrap', padding: '0.875rem 0.75rem' }}>Role</th>
                    <th style={{ width: '135px', whiteSpace: 'nowrap', padding: '0.875rem 0.75rem' }}>Details</th>
                    <th style={{ width: '140px', whiteSpace: 'nowrap', padding: '0.875rem 0.75rem' }}>Subject</th>
                    <th style={{ minWidth: '150px', padding: '0.875rem 0.75rem' }}>Message</th>
                    <th style={{ width: '90px', whiteSpace: 'nowrap', padding: '0.875rem 0.75rem' }}>Status</th>
                    <th style={{ width: '95px', textAlign: 'right', whiteSpace: 'nowrap', padding: '0.875rem 1.25rem 0.875rem 0.75rem' }}>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredTickets.map(ticket => {
                    const { dateStr, timeStr } = formatDateParts(ticket.createdAt);
                    return (
                      <tr key={ticket.id}>
                        <td style={{ padding: '0.875rem 0.75rem 0.875rem 1.25rem', whiteSpace: 'nowrap', verticalAlign: 'middle' }}>
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.15rem' }}>
                            <span style={{ fontSize: '0.8125rem', fontWeight: 700, color: 'var(--text-primary)', letterSpacing: '-0.01em', whiteSpace: 'nowrap' }}>
                              {dateStr}
                            </span>
                            {timeStr && (
                              <span style={{ fontSize: '0.72rem', color: 'var(--text-muted)', fontWeight: 500, whiteSpace: 'nowrap' }}>
                                {timeStr}
                              </span>
                            )}
                          </div>
                        </td>
                        <td style={{ padding: '0.875rem 0.75rem', verticalAlign: 'middle', whiteSpace: 'nowrap' }}>
                          <span style={{ 
                            display: 'inline-flex',
                            alignItems: 'center',
                            padding: '0.2rem 0.6rem', 
                            borderRadius: 'var(--r-full)', 
                            fontSize: '0.72rem', 
                            fontWeight: 700,
                            background: ticket.reporterRole === 'captain' ? 'rgba(245, 158, 11, 0.15)' : 'rgba(37, 99, 235, 0.1)',
                            color: ticket.reporterRole === 'captain' ? '#D97706' : 'var(--brand-blue)',
                            textTransform: 'capitalize'
                          }}>
                            {ticket.reporterRole || 'user'}
                          </span>
                        </td>
                        <td style={{ padding: '0.875rem 0.75rem', verticalAlign: 'middle', whiteSpace: 'nowrap' }}>
                          <button
                            type="button"
                            onClick={() => setSelectedTicket(ticket)}
                            className="btn btn-secondary btn-sm"
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: '0.35rem',
                              padding: '0.3rem 0.6rem',
                              fontSize: '0.72rem',
                              fontWeight: 600,
                              borderRadius: 'var(--r-md)',
                              cursor: 'pointer'
                            }}
                          >
                            <Eye size={13} weight="bold" />
                            View in Details
                          </button>
                        </td>
                        <td style={{ padding: '0.875rem 0.75rem', fontSize: '0.8125rem', fontWeight: 700, color: 'var(--text-primary)', verticalAlign: 'middle', maxWidth: '140px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={ticket.subject}>
                          {ticket.subject || 'No Subject'}
                        </td>
                        <td style={{ padding: '0.875rem 0.75rem', fontSize: '0.8125rem', color: 'var(--text-secondary)', maxWidth: '200px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', verticalAlign: 'middle' }} title={ticket.message}>
                          {ticket.message || '—'}
                        </td>
                        <td style={{ padding: '0.875rem 0.75rem', verticalAlign: 'middle', whiteSpace: 'nowrap' }}>
                          <span style={{ 
                            display: 'inline-flex',
                            alignItems: 'center',
                            padding: '0.2rem 0.6rem', 
                            borderRadius: 'var(--r-full)', 
                            fontSize: '0.72rem', 
                            fontWeight: 700,
                            background: ticket.status === 'resolved' ? 'rgba(16, 185, 129, 0.12)' : 'rgba(239, 68, 68, 0.12)',
                            color: ticket.status === 'resolved' ? '#10B981' : '#EF4444'
                          }}>
                            {ticket.status === 'resolved' ? 'Resolved' : 'Open'}
                          </span>
                        </td>
                        <td style={{ padding: '0.875rem 1.25rem 0.875rem 0.75rem', textAlign: 'right', verticalAlign: 'middle', whiteSpace: 'nowrap' }}>
                          {ticket.status !== 'resolved' ? (
                            <button 
                              onClick={() => {
                                setResolvingTicket(ticket);
                                setResolutionText('This issue has been reviewed and resolved by the support team.');
                              }}
                              className="btn btn-secondary btn-sm" 
                              style={{ padding: '0.3rem 0.65rem', fontSize: '0.75rem', fontWeight: 600, borderRadius: 'var(--r-md)' }}
                            >
                              Resolve
                            </button>
                          ) : (
                            <span style={{ fontSize: '0.72rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                              Completed
                            </span>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {/* Quick Resolve Modal (replaces browser prompt) */}
      {resolvingTicket && (
        <div className="modal-backdrop" onClick={() => setResolvingTicket(null)}>
          <div 
            className="modal modal-md animate-fade-in" 
            onClick={(e) => e.stopPropagation()}
            style={{ maxWidth: '480px', padding: '1.75rem', borderRadius: 'var(--r-xl)' }}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1.25rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.625rem' }}>
                <div style={{ width: 36, height: 36, borderRadius: 'var(--r-md)', background: 'rgba(16, 185, 129, 0.12)', color: '#10B981', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Check size={20} weight="bold" />
                </div>
                <div>
                  <h3 style={{ margin: 0, fontSize: '1.125rem', fontWeight: 800 }}>Resolve Complaint</h3>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Ticket ID: {resolvingTicket.id}</div>
                </div>
              </div>
              <button 
                onClick={() => setResolvingTicket(null)}
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}
              >
                <X size={20} />
              </button>
            </div>

            <div style={{ marginBottom: '1.25rem' }}>
              <div style={{ fontSize: '0.8125rem', fontWeight: 700, marginBottom: '0.35rem', color: 'var(--text-primary)' }}>
                Subject: {resolvingTicket.subject || 'Complaint'}
              </div>
              <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', background: 'var(--surface-2)', padding: '0.75rem', borderRadius: 'var(--r-md)', border: '1px solid var(--border)' }}>
                {resolvingTicket.message || 'No description provided.'}
              </div>
            </div>

            <div style={{ marginBottom: '1.5rem' }}>
              <label style={{ display: 'block', fontSize: '0.8125rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--text-primary)' }}>
                Resolution Note for Complainant
              </label>
              <textarea
                rows={3}
                className="form-input"
                style={{ width: '100%', resize: 'vertical' }}
                value={resolutionText}
                onChange={(e) => setResolutionText(e.target.value)}
                placeholder="Explain how this issue was resolved..."
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem' }}>
              <button 
                className="btn btn-secondary"
                onClick={() => setResolvingTicket(null)}
                disabled={isSubmittingResolve}
              >
                Cancel
              </button>
              <button 
                className="btn btn-primary"
                disabled={isSubmittingResolve || !resolutionText.trim()}
                onClick={() => {
                  setIsSubmittingResolve(true);
                  handleResolve(resolvingTicket.id, resolutionText);
                }}
                style={{ background: '#10B981', borderColor: '#10B981' }}
              >
                {isSubmittingResolve ? 'Resolving...' : 'Confirm & Mark Resolved'}
              </button>
            </div>
          </div>
        </div>
      )}

      {selectedTicket && (
        <TicketDetailsModal
          ticket={selectedTicket}
          onClose={() => setSelectedTicket(null)}
          onResolve={handleResolve}
        />
      )}
    </div>
  );
}
