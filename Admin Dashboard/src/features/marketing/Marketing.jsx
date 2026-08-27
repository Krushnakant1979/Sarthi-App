import React, { useState } from 'react';
import { Megaphone, PaperPlaneTilt, Funnel, PenNib, ListBullets } from '@phosphor-icons/react';

const mockCampaigns = [
  { id: 'CMP-001', name: 'Welcome Back 10%', type: 'Push', audience: 'Inactive 30+ Days', status: 'Active', sent: 1240 },
  { id: 'CMP-002', name: 'Weekend Surge Alert', type: 'SMS', audience: 'All Captains', status: 'Completed', sent: 350 },
  { id: 'CMP-003', name: 'Diwali Special 25%', type: 'Email', audience: 'All Users', status: 'Draft', sent: 0 },
];

const Tabs = [
  { id: 'compose', label: 'Compose Message', icon: PenNib },
  { id: 'campaigns', label: 'Campaign History', icon: ListBullets },
];

export default function Marketing() {
  const [activeTab, setActiveTab] = useState('compose');

  return (
    <div className="animate-fade-in">
      <div className="page-header">
        <div>
          <h1>Marketing Hub</h1>
          <p>Engage users and captains with targeted campaigns</p>
        </div>
        <button className="btn btn-primary">
          <Megaphone size={18} weight="bold" />
          Quick Announcement
        </button>
      </div>

      <div className="settings-layout">
        {/* Sidebar Tabs */}
        <div className="card" style={{ padding: '1rem 0' }}>
          <div style={{ padding: '0 1.25rem 0.5rem', fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Marketing Tools
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
        {activeTab === 'compose' ? (
          <div className="card" style={{ padding: '2rem' }}>
            <h2 style={{ fontSize: '1.25rem', fontWeight: 700, marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <PenNib size={22} style={{ color: 'var(--brand-blue)' }} />
              New Campaign
            </h2>
            
            <div className="settings-grid">
              <div>
                <div className="form-group" style={{ marginBottom: '1.5rem' }}>
                  <label className="form-label">Target Audience</label>
                  <select className="form-input">
                    <option>All Users</option>
                    <option>Inactive Users (30+ Days)</option>
                    <option>All Captains</option>
                    <option>Top Rated Captains</option>
                  </select>
                </div>

                <div className="form-group" style={{ marginBottom: '1.5rem' }}>
                  <label className="form-label">Message Type</label>
                  <div style={{ display: 'flex', gap: '1.5rem', marginTop: '0.5rem' }}>
                    {['Push Notification', 'SMS', 'Email'].map((type, i) => (
                      <label key={type} style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', cursor: 'pointer', color: 'var(--text-secondary)', fontSize: '0.875rem' }}>
                        <input type="radio" name="msgType" defaultChecked={i === 0} style={{ accentColor: 'var(--brand-blue)' }} />
                        {type}
                      </label>
                    ))}
                  </div>
                </div>
              </div>

              <div>
                <div className="form-group" style={{ marginBottom: '1.5rem' }}>
                  <label className="form-label">Message Title</label>
                  <input type="text" className="form-input" placeholder="e.g., 10% Off Your Next Ride!" />
                </div>
                
                <div className="form-group" style={{ marginBottom: '1.5rem' }}>
                  <label className="form-label">Message Body</label>
                  <textarea rows={4} className="form-input" placeholder="Type your message here..." style={{ resize: 'vertical' }} />
                </div>

                <button className="btn btn-primary" style={{ width: '100%', justifyContent: 'center' }}>
                  <PaperPlaneTilt size={18} weight="bold" /> Send Campaign Now
                </button>
              </div>
            </div>
          </div>
        ) : (
          <div className="card">
            <div style={{ padding: '1.5rem', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h2 style={{ fontSize: '1.1rem', fontWeight: 700 }}>Recent Campaigns</h2>
              <button className="btn btn-secondary btn-sm" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <Funnel size={16} /> Filter
              </button>
            </div>
            <table className="data-table">
              <thead>
                <tr>
                  <th>Campaign ID</th>
                  <th>Name</th>
                  <th>Type</th>
                  <th>Audience</th>
                  <th>Status</th>
                  <th>Sent</th>
                </tr>
              </thead>
              <tbody>
                {mockCampaigns.map(camp => (
                  <tr key={camp.id}>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-primary)' }}>{camp.id}</td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem' }}>{camp.name}</td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem' }}>{camp.type}</td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', color: 'var(--text-secondary)' }}>{camp.audience}</td>
                    <td style={{ padding: '1rem 1.25rem' }}>
                      <span style={{ 
                        padding: '0.25rem 0.75rem', 
                        borderRadius: 'var(--r-full)', 
                        fontSize: '0.75rem', 
                        fontWeight: 600,
                        background: camp.status === 'Active' ? 'var(--success-bg)' : camp.status === 'Draft' ? 'var(--warning-bg)' : 'var(--info-bg)',
                        color: camp.status === 'Active' ? 'var(--success)' : camp.status === 'Draft' ? 'var(--warning)' : 'var(--info)'
                      }}>
                        {camp.status}
                      </span>
                    </td>
                    <td style={{ padding: '1rem 1.25rem', fontSize: '0.875rem', fontWeight: 500 }}>{camp.sent}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
