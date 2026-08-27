import React, { useState } from 'react';
import { Star, WarningCircle, Funnel, ListBullets } from '@phosphor-icons/react';

const mockReviews = [
  { id: 'REV-1042', tripId: 'TRP-8921', date: '2026-08-25', reviewer: 'John D. (User)', reviewee: 'Ramesh K. (Captain)', rating: 1, comment: 'Driver was very rude and drove rashly.', status: 'Flagged' },
  { id: 'REV-1043', tripId: 'TRP-8933', date: '2026-08-25', reviewer: 'Priya S. (User)', reviewee: 'Suresh M. (Captain)', rating: 2, comment: 'Car was not clean, AC wasn\'t working.', status: 'Pending' },
  { id: 'REV-1044', tripId: 'TRP-8901', date: '2026-08-24', reviewer: 'Amit P. (Captain)', reviewee: 'Neha G. (User)', rating: 1, comment: 'User refused to pay toll tax and argued.', status: 'Pending' },
];

const Tabs = [
  { id: 'attention', label: 'Needs Attention', icon: WarningCircle },
  { id: 'all', label: 'All Reviews', icon: ListBullets },
];

export default function Reviews() {
  const [activeTab, setActiveTab] = useState('attention');

  return (
    <div className="animate-fade-in">
      <div className="page-header">
        <div>
          <h1>Reviews & Moderation</h1>
          <p>Monitor platform quality and handle low-rated trips</p>
        </div>
        
        <div style={{ display: 'flex', gap: '1rem' }}>
          <div className="stat-card-modern" style={{ padding: '0.75rem 1.25rem', minWidth: '140px', background: 'var(--surface-2)', boxShadow: 'none', border: '1px solid var(--border)' }}>
            <div style={{ fontSize: '0.7rem', fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Avg Captain Rating</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
              4.7 <Star weight="fill" color="var(--brand-yellow)" size={16} />
            </div>
          </div>
          <div className="stat-card-modern" style={{ padding: '0.75rem 1.25rem', minWidth: '140px', background: 'var(--surface-2)', boxShadow: 'none', border: '1px solid var(--border)' }}>
            <div style={{ fontSize: '0.7rem', fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Flagged Reviews</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--error)' }}>
              12
            </div>
          </div>
        </div>
      </div>

      <div className="settings-layout">
        {/* Sidebar Tabs */}
        <div className="card" style={{ padding: '1rem 0' }}>
          <div style={{ padding: '0 1.25rem 0.5rem', fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Moderation Views
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
              {activeTab === 'attention' ? (
                <><WarningCircle size={20} color="var(--error)" /> Needs Attention</>
              ) : (
                <><ListBullets size={20} color="var(--brand-blue)" /> All Reviews</>
              )}
            </h2>
            <button className="btn btn-secondary btn-sm" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Funnel size={16} /> Filter
            </button>
          </div>
          
          <table className="data-table">
            <thead>
              <tr>
                <th>Trip ID</th>
                <th>Reviewer</th>
                <th>Reviewee</th>
                <th>Rating</th>
                <th>Comment</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {mockReviews.map(review => (
                <tr key={review.id}>
                  <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', fontWeight: 600, color: 'var(--brand-blue)' }}>{review.tripId}</td>
                  <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', fontWeight: 500 }}>{review.reviewer}</td>
                  <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', fontWeight: 500 }}>{review.reviewee}</td>
                  <td style={{ padding: '1rem 1.25rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                      {[...Array(5)].map((_, i) => (
                        <Star key={i} size={14} weight={i < review.rating ? "fill" : "regular"} color={i < review.rating ? "var(--error)" : "var(--text-muted)"} />
                      ))}
                    </div>
                  </td>
                  <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', color: 'var(--text-secondary)', maxWidth: '200px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }} title={review.comment}>
                    "{review.comment}"
                  </td>
                  <td style={{ padding: '1rem 1.25rem' }}>
                    <span style={{ 
                      padding: '0.25rem 0.75rem', 
                      borderRadius: 'var(--r-full)', 
                      fontSize: '0.75rem', 
                      fontWeight: 600,
                      background: review.status === 'Flagged' ? 'var(--error-bg)' : 'var(--warning-bg)',
                      color: review.status === 'Flagged' ? 'var(--error)' : 'var(--warning)'
                    }}>
                      {review.status}
                    </span>
                  </td>
                  <td style={{ padding: '1rem 1.25rem' }}>
                    <button className="btn btn-secondary btn-sm" style={{ padding: '0.375rem 0.75rem' }}>
                      Review
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
