import React from 'react';
import { ShieldCheck } from '@phosphor-icons/react';

export const PlatformHealthCard = ({ dbStatus, activeCaptains }) => {
  return (
    <div className="card" style={{ padding: '1.5rem' }}>
      <h2 style={{ fontSize: '1.125rem', fontWeight: 700, margin: 0, marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
        <ShieldCheck size={22} style={{ color: 'var(--success)' }} />
        Platform Health
      </h2>
      
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '1rem', borderBottom: '1px solid var(--border)' }}>
          <span style={{ fontSize: '0.875rem', color: 'var(--text-secondary)' }}>Database Connection</span>
          <span style={{ fontSize: '0.875rem', fontWeight: 600, color: dbStatus === 'connected' ? 'var(--success)' : dbStatus === 'error' ? 'var(--error)' : 'var(--warning)' }}>
            {dbStatus === 'connected' ? 'Stable' : dbStatus === 'error' ? 'Error' : 'Checking'}
          </span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '1rem', borderBottom: '1px solid var(--border)' }}>
          <span style={{ fontSize: '0.875rem', color: 'var(--text-secondary)' }}>API Latency</span>
          <span style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-primary)' }}>42ms</span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '1rem', borderBottom: '1px solid var(--border)' }}>
          <span style={{ fontSize: '0.875rem', color: 'var(--text-secondary)' }}>Active Captains</span>
          <span style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--brand-blue)' }}>{activeCaptains} Online</span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <span style={{ fontSize: '0.875rem', color: 'var(--text-secondary)' }}>Server Status</span>
          <span style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--success)' }}>99.9% Uptime</span>
        </div>
      </div>
    </div>
  );
};
