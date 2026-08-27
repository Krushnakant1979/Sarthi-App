import React, { useEffect, useState } from 'react';
import { db } from '../../config/firebase';
import { collection, onSnapshot } from 'firebase/firestore';
import { 
  Tooltip, ResponsiveContainer, 
  PieChart, Pie, Cell, Legend
} from 'recharts';
import { ChartLineUp, CurrencyInr, CarProfile, Users, CheckCircle, DownloadSimple, ChartPieSlice, TrendUp } from '@phosphor-icons/react';

// Extractor to get "City, State" from standard Geocoding strings
const extractLocation = (address) => {
  if (!address || typeof address !== 'string') return 'Unknown Location';
  
  const parts = address.split(',').map(p => p.trim()).filter(p => p);
  
  if (parts.length >= 3) {
    const isIndia = parts[parts.length - 1].toLowerCase().includes('india');
    let startIndex = isIndia ? parts.length - 2 : parts.length - 1;
    
    for (let i = startIndex; i > 0; i--) {
      const part = parts[i];
      const alphaOnly = part.replace(/[0-9]/g, '').trim();
      
      if (alphaOnly.length > 2) {
         // Found state. City is likely the part right before it.
         const state = alphaOnly;
         const city = parts[i-1].replace(/[0-9]/g, '').trim();
         return `${city}, ${state}`;
      }
    }
  }
  
  if (parts.length === 2) {
    const clean1 = parts[0].replace(/[0-9]/g, '').trim();
    const clean2 = parts[1].replace(/[0-9]/g, '').trim();
    return `${clean1}, ${clean2}`;
  }

  return parts[0] || 'Unknown Location';
};

const STATUS_COLORS = {
  Completed: '#00A6A6', // var(--brand-teal)
  Cancelled: '#EF4444', // var(--error)
};

const Analytics = () => {
  const [loading, setLoading] = useState(true);
  const [kpis, setKpis] = useState({
    totalRevenue: 0,
    totalRides: 0,
    activeCaptains: 0,
    completionRate: 0,
  });
  
  const [stateData, setStateData] = useState([]);
  const [statusData, setStatusData] = useState([]);
  const [rawRides, setRawRides] = useState([]);

  useEffect(() => {
    let rides = [];
    let captainsCount = 0;

    const updateUI = () => {
      setRawRides(rides);
      
      let revenue = 0;
      let completed = 0;
      const statusCounts = { completed: 0, cancelled: 0 };
      const cityStats = {};

      rides.forEach(r => {
        const status = r.status || 'pending';
        if (status === 'completed' || status === 'cancelled') {
          statusCounts[status] = (statusCounts[status] || 0) + 1;
        }
        
        if (status === 'completed') {
          completed++;
          const fare = Number(r.fareEstimate) || 0;
          revenue += fare;
          
          const loc = extractLocation(r.pickup?.address);
          if (!cityStats[loc]) cityStats[loc] = { name: loc, revenue: 0, rides: 0 };
          cityStats[loc].revenue += fare;
          cityStats[loc].rides += 1;
        }
      });

      const stateArray = Object.values(cityStats).sort((a, b) => b.revenue - a.revenue);
      setStateData(stateArray);

      setStatusData(Object.keys(statusCounts).map(k => ({
        name: k.charAt(0).toUpperCase() + k.slice(1),
        value: statusCounts[k]
      })).filter(d => d.value > 0));

      setKpis({
        totalRevenue: revenue,
        totalRides: rides.length,
        activeCaptains: captainsCount,
        completionRate: rides.length ? Math.round((completed / rides.length) * 100) : 0,
      });
      
      setLoading(false);
    };

    const unsubRides = onSnapshot(collection(db, 'ride_requests'), (snap) => {
      rides = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      updateUI();
    }, (err) => console.error(err));

    const unsubUsers = onSnapshot(collection(db, 'users'), (snap) => {
      captainsCount = snap.docs.filter(d => d.data().role === 'captain' && d.data().verificationStatus === 'verified').length;
      updateUI();
    }, (err) => console.error(err));

    return () => {
      unsubRides();
      unsubUsers();
    };
  }, []);

  const exportCSV = () => {
    if (!rawRides.length) return;
    
    const headers = ['Ride ID', 'Status', 'Date', 'Pickup', 'Dropoff', 'Distance (km)', 'Fare (INR)', 'User ID', 'Captain ID'];
    const rows = rawRides.map(r => {
      const date = r.createdAt?.toDate ? r.createdAt.toDate().toISOString() : '';
      const dist = r.distanceMeters ? (r.distanceMeters / 1000).toFixed(2) : '';
      return [
        r.id, r.status || 'unknown', date, 
        `"${r.pickup?.address?.replace(/"/g, '""') || ''}"`,
        `"${r.destination?.address?.replace(/"/g, '""') || ''}"`,
        dist, r.fareEstimate || 0, r.userId || '', r.captainId || ''
      ].join(',');
    });

    const csvContent = "data:text/csv;charset=utf-8," + [headers.join(','), ...rows].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `sarthi_rides_report_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="animate-fade-in" style={{ paddingBottom: '2rem' }}>
      
      {/* 1. Premium Header Banner */}
      <div style={{ 
        background: 'linear-gradient(135deg, #1e293b 0%, #0f172a 100%)',
        borderRadius: 'var(--r-xl)',
        padding: '1.5rem 2rem',
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
          <h1 style={{ fontSize: '1.5rem', fontWeight: 800, margin: 0, letterSpacing: '-0.03em', display: 'flex', alignItems: 'center', gap: '0.625rem' }}>
            <TrendUp size={26} weight="duotone" style={{ color: '#38BDF8' }} /> 
            Business Intelligence
          </h1>
          <p style={{ color: 'rgba(255,255,255,0.7)', fontSize: '0.875rem', marginTop: '0.25rem', marginLeft: '2.25rem' }}>
            Macro-level insights and revenue metrics for the Sarthi platform.
          </p>
        </div>

        <button 
          onClick={exportCSV}
          style={{ 
            position: 'relative', zIndex: 1, 
            background: 'rgba(255,255,255,0.1)', color: 'white', 
            border: '1px solid rgba(255,255,255,0.2)', padding: '0.75rem 1.5rem', 
            borderRadius: 'var(--r-full)', fontWeight: 600, 
            fontSize: '0.9375rem', display: 'flex', alignItems: 'center', gap: '0.5rem',
            cursor: 'pointer', transition: 'all var(--t-fast)'
          }}
          onMouseOver={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.2)'}
          onMouseOut={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.1)'}
        >
          <DownloadSimple size={18} weight="bold" />
          Export Data (CSV)
        </button>
      </div>

      {/* 2. Compact KPI Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '1.25rem', marginBottom: '1.5rem' }}>
        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(21,101,192,0.1)', color: '#1565C0', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <CurrencyInr size={18} weight="fill" />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Total Revenue</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : `₹${kpis.totalRevenue.toLocaleString('en-IN')}`}
            </div>
          </div>
        </div>

        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(0,166,166,0.1)', color: 'var(--brand-teal)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <CarProfile size={18} weight="fill" />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Total Rides</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : kpis.totalRides.toLocaleString()}
            </div>
          </div>
        </div>

        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(22,163,74,0.1)', color: 'var(--success)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <CheckCircle size={18} weight="fill" />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Completion Rate</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : `${kpis.completionRate}%`}
            </div>
          </div>
        </div>

        <div className="card" style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: 36, height: 36, borderRadius: 'var(--r-full)', background: 'rgba(245,158,11,0.1)', color: 'var(--warning)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Users size={18} weight="fill" />
          </div>
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Verified Captains</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2, marginTop: '0.125rem' }}>
              {loading ? <span className="skeleton" style={{ width: 40, height: 24, display: 'inline-block' }}></span> : kpis.activeCaptains.toLocaleString()}
            </div>
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '1.5rem', alignItems: 'start' }}>
        {/* 3. Top States Table */}
        <div className="card" style={{ padding: '1.5rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '1.5rem', paddingBottom: '1rem', borderBottom: '1px solid var(--border)' }}>
            <ChartLineUp size={20} weight="bold" style={{ color: 'var(--brand-teal)' }} /> 
            <h2 style={{ fontSize: '1.125rem', fontWeight: 700, margin: 0, color: 'var(--text-primary)' }}>Top Locations by Revenue</h2>
          </div>
          {loading ? (
            <div style={{ height: 320, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
               <span className="skeleton" style={{ width: '100%', height: '100%', borderRadius: 'var(--r-md)' }}></span>
            </div>
          ) : stateData.length > 0 ? (
            <div style={{ overflowX: 'auto', maxHeight: '320px' }}>
              <table className="data-table" style={{ width: '100%', textAlign: 'left', borderCollapse: 'collapse' }}>
                <thead style={{ position: 'sticky', top: 0, background: 'var(--surface-1)', zIndex: 1 }}>
                  <tr>
                    <th style={{ padding: '0.75rem 1rem', color: 'var(--text-muted)', fontSize: '0.75rem', textTransform: 'uppercase' }}>Location (City, State)</th>
                    <th style={{ padding: '0.75rem 1rem', color: 'var(--text-muted)', fontSize: '0.75rem', textTransform: 'uppercase', textAlign: 'right' }}>Completed Trips</th>
                    <th style={{ padding: '0.75rem 1rem', color: 'var(--text-muted)', fontSize: '0.75rem', textTransform: 'uppercase', textAlign: 'right' }}>Total Revenue</th>
                  </tr>
                </thead>
                <tbody>
                  {stateData.map((state, idx) => (
                    <tr key={idx} style={{ borderBottom: '1px solid var(--border)' }}>
                      <td style={{ padding: '1rem', fontWeight: 600, color: 'var(--text-primary)' }}>{state.name}</td>
                      <td style={{ padding: '1rem', textAlign: 'right', color: 'var(--text-secondary)' }}>{state.rides.toLocaleString()}</td>
                      <td style={{ padding: '1rem', textAlign: 'right', fontWeight: 700, color: 'var(--brand-teal)' }}>₹{state.revenue.toLocaleString('en-IN')}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div style={{ height: 320, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)', fontSize: '0.875rem' }}>
              Not enough data for state analysis.
            </div>
          )}
        </div>

        {/* 4. Polished Pie Chart */}
        <div className="card" style={{ padding: '1.5rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '1.5rem', paddingBottom: '1rem', borderBottom: '1px solid var(--border)' }}>
            <ChartPieSlice size={20} weight="bold" style={{ color: 'var(--brand-blue)' }} /> 
            <h2 style={{ fontSize: '1.125rem', fontWeight: 700, margin: 0, color: 'var(--text-primary)' }}>Trip Outcomes</h2>
          </div>
          {loading ? (
            <div style={{ height: 320, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
               <span className="skeleton" style={{ width: '100%', height: '100%', borderRadius: 'var(--r-md)' }}></span>
            </div>
          ) : statusData.length > 0 ? (
            <div style={{ width: '100%', height: 320 }}>
              <ResponsiveContainer>
                <PieChart>
                  <Pie
                    data={statusData}
                    cx="50%"
                    cy="45%"
                    innerRadius={65}
                    outerRadius={95}
                    paddingAngle={5}
                    dataKey="value"
                    stroke="none"
                  >
                    {statusData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={STATUS_COLORS[entry.name] || '#1565C0'} />
                    ))}
                  </Pie>
                  <Tooltip 
                    contentStyle={{ borderRadius: 'var(--r-md)', border: '1px solid var(--border)', boxShadow: 'var(--shadow-md)', background: 'rgba(255,255,255,0.95)', backdropFilter: 'blur(10px)' }}
                    itemStyle={{ color: 'var(--text-primary)', fontWeight: 700 }}
                  />
                  <Legend verticalAlign="bottom" height={36} wrapperStyle={{ fontSize: '0.8125rem', fontWeight: 600, color: 'var(--text-secondary)' }} iconType="circle" />
                </PieChart>
              </ResponsiveContainer>
            </div>
          ) : (
            <div style={{ height: 320, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)', fontSize: '0.875rem' }}>
              No rides available.
            </div>
          )}
        </div>
      </div>

    </div>
  );
};

export default Analytics;
