import React from 'react';
import { TrendUp, TrendDown } from '@phosphor-icons/react';
import { AreaChart, Area, ResponsiveContainer } from 'recharts';

export const DashboardStatCard = ({ 
  label, 
  icon: Icon, 
  accent, 
  format, 
  trendData,
  value,
  trendPercentage,
  loading
}) => {
  return (
    <div className="stat-card-modern">
      {/* Sparkline Background */}
      <div className="stat-card-sparkline">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={trendData}>
            <Area type="monotone" dataKey="val" stroke={accent} fill={accent} strokeWidth={2} />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      <div style={{ position: 'relative', zIndex: 1 }}>
        <div className="stat-card-header">
          <span className="stat-card-label">{label}</span>
          <div className="stat-card-icon-wrapper" style={{ background: `rgba(${accent === '#1565C0' ? '21,101,192' : accent === '#00A6A6' ? '0,166,166' : accent === '#7C3AED' ? '124,58,237' : '217,119,6'}, 0.1)`, color: accent }}>
            <Icon size={18} weight="bold" />
          </div>
        </div>
        <div className="stat-card-value">
          {loading ? <span className="skeleton stat-skeleton">&nbsp;</span> : format(value)}
        </div>
        <div className="stat-card-trend">
          {!loading && trendPercentage >= 0 ? (
            <TrendUp size={14} style={{ color: 'var(--success)' }} />
          ) : (
            <TrendDown size={14} style={{ color: 'var(--error)' }} />
          )}
          <span className="stat-card-trend-text">
            {loading ? (
              <span className="skeleton stat-trend-skeleton">&nbsp;</span>
            ) : (
              <>
                <span style={{ color: trendPercentage >= 0 ? 'var(--success)' : 'var(--error)' }}>
                  {trendPercentage > 0 ? '+' : ''}{trendPercentage}%
                </span> this week
              </>
            )}
          </span>
        </div>
      </div>
    </div>
  );
};
