import React, { useEffect, useState, useMemo } from 'react';
import { db } from '../../config/firebase';
import { collection, onSnapshot, query, where, orderBy, limit, Timestamp } from 'firebase/firestore';
import { 
  ResponsiveContainer, 
  AreaChart, Area, XAxis, YAxis, Tooltip, 
  PieChart, Pie, Cell, Legend, BarChart, Bar 
} from 'recharts';
import { 
  ChartLineUp, CurrencyInr, CarProfile, Users, CheckCircle, 
  DownloadSimple, ChartPieSlice, TrendUp, TrendDown, Calendar, 
  CaretLeft, CaretRight, MapPin, Fire, Scooter, Taxi, Package
} from '@phosphor-icons/react';

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

const parseDate = (val) => {
  if (!val) return null;
  if (val.toDate && typeof val.toDate === 'function') return val.toDate();
  if (val instanceof Date) return val;
  if (typeof val === 'string' || typeof val === 'number') {
    const d = new Date(val);
    return isNaN(d.getTime()) ? null : d;
  }
  return null;
};

const STATUS_COLORS = {
  Completed: '#00A6A6',
  Cancelled: '#EF4444',
  Other: '#64748B'
};

const SERVICE_META = {
  bike: { label: 'Bike Ride', icon: Scooter, color: '#38BDF8' },
  auto: { label: 'Auto Rickshaw', icon: Taxi, color: '#F59E0B' },
  cab: { label: 'Cab / Sedan', icon: CarProfile, color: '#10B981' },
  parcel: { label: 'Parcel Delivery', icon: Package, color: '#8B5CF6' }
};

const Analytics = () => {
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('analytics'); // 'analytics' | 'heatmap'
  const [period, setPeriod] = useState('month'); // 'day' | 'month' | 'year'
  const [selectedDate, setSelectedDate] = useState(new Date());

  const [rawRides, setRawRides] = useState([]);
  const [activeCaptains, setActiveCaptains] = useState(0);

  // Shift period back/forward
  const shiftDate = (direction) => {
    const d = new Date(selectedDate);
    if (period === 'day') {
      d.setDate(d.getDate() + direction);
    } else if (period === 'month') {
      d.setMonth(d.getMonth() + direction);
    } else if (period === 'year') {
      d.setFullYear(d.getFullYear() + direction);
    }
    setSelectedDate(d);
  };

  const isCurrentPeriod = useMemo(() => {
    const now = new Date();
    if (period === 'day') {
      return now.toDateString() === selectedDate.toDateString();
    } else if (period === 'month') {
      return now.getFullYear() === selectedDate.getFullYear() && now.getMonth() === selectedDate.getMonth();
    } else {
      return now.getFullYear() === selectedDate.getFullYear();
    }
  }, [period, selectedDate]);

  // Compute date ranges for current and previous periods
  const { currentStart, currentEnd, prevStart, prevEnd } = useMemo(() => {
    const d = new Date(selectedDate);
    let curS, curE, prvS, prvE;

    if (period === 'day') {
      curS = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0);
      curE = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59, 999);
      prvS = new Date(d.getFullYear(), d.getMonth(), d.getDate() - 1, 0, 0, 0);
      prvE = new Date(d.getFullYear(), d.getMonth(), d.getDate() - 1, 23, 59, 59, 999);
    } else if (period === 'month') {
      curS = new Date(d.getFullYear(), d.getMonth(), 1, 0, 0, 0);
      curE = new Date(d.getFullYear(), d.getMonth() + 1, 0, 23, 59, 59, 999);
      prvS = new Date(d.getFullYear(), d.getMonth() - 1, 1, 0, 0, 0);
      prvE = new Date(d.getFullYear(), d.getMonth(), 0, 23, 59, 59, 999);
    } else {
      curS = new Date(d.getFullYear(), 0, 1, 0, 0, 0);
      curE = new Date(d.getFullYear(), 11, 31, 23, 59, 59, 999);
      prvS = new Date(d.getFullYear() - 1, 0, 1, 0, 0, 0);
      prvE = new Date(d.getFullYear() - 1, 11, 31, 23, 59, 59, 999);
    }

    return { currentStart: curS, currentEnd: curE, prevStart: prvS, prevEnd: prvE };
  }, [period, selectedDate]);

  useEffect(() => {
    setLoading(true);

    // Bound rides listener to relevant date window or top 500 fallback
    let qRides;
    try {
      qRides = query(
        collection(db, 'ride_requests'),
        where('createdAt', '>=', Timestamp.fromDate(prevStart)),
        where('createdAt', '<=', Timestamp.fromDate(currentEnd)),
        orderBy('createdAt', 'desc')
      );
    } catch {
      qRides = query(collection(db, 'ride_requests'), orderBy('createdAt', 'desc'), limit(500));
    }

    let unsubFallback = null;
    const unsubRides = onSnapshot(qRides, (snap) => {
      const rides = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setRawRides(rides);
      setLoading(false);
    }, (err) => {
      console.warn('Index requirement fallback for analytics date range:', err);
      const fallbackQuery = query(collection(db, 'ride_requests'), orderBy('createdAt', 'desc'), limit(500));
      unsubFallback = onSnapshot(fallbackQuery, (fSnap) => {
        setRawRides(fSnap.docs.map(d => ({ id: d.id, ...d.data() })));
        setLoading(false);
      });
    });

    // Query captains specifically instead of streaming entire users collection
    const qCaptains = query(collection(db, 'users'), where('role', '==', 'captain'));
    const unsubUsers = onSnapshot(qCaptains, (snap) => {
      const caps = snap.docs.filter(d => 
        (d.data().verificationStatus === 'verified' || d.data().status === 'verified')
      ).length;
      setActiveCaptains(caps);
    }, (err) => console.error(err));

    return () => {
      unsubRides();
      if (unsubFallback) unsubFallback();
      unsubUsers();
    };
  }, [prevStart, currentEnd]);

  // Filter rides for both periods
  const { currentRides, prevRides } = useMemo(() => {
    const cur = [];
    const prv = [];

    rawRides.forEach(r => {
      const dt = parseDate(r.createdAt || r.timestamp);
      if (!dt) return;

      if (dt >= currentStart && dt <= currentEnd) {
        cur.push(r);
      } else if (dt >= prevStart && dt <= prevEnd) {
        prv.push(r);
      }
    });

    return { currentRides: cur, prevRides: prv };
  }, [rawRides, currentStart, currentEnd, prevStart, prevEnd]);

  // Analytics Aggregates
  const analyticsData = useMemo(() => {
    let currentRevenue = 0;
    let completedCount = 0;
    let cancelledCount = 0;

    const services = {
      bike: { rides: 0, revenue: 0 },
      auto: { rides: 0, revenue: 0 },
      cab: { rides: 0, revenue: 0 },
      parcel: { rides: 0, revenue: 0 },
    };

    const locationStats = {};

    currentRides.forEach(r => {
      const fare = Number(r.fareEstimate || r.fare || 0);
      const status = (r.status || '').toLowerCase();
      const serviceType = (r.vehicleType || 'bike').toLowerCase();

      if (status === 'completed') {
        completedCount++;
        currentRevenue += fare;
        if (services[serviceType]) {
          services[serviceType].revenue += fare;
          services[serviceType].rides += 1;
        } else {
          services.cab.revenue += fare;
          services.cab.rides += 1;
        }

        const loc = extractLocation(r.pickup?.address);
        if (!locationStats[loc]) {
          locationStats[loc] = { name: loc, revenue: 0, rides: 0 };
        }
        locationStats[loc].revenue += fare;
        locationStats[loc].rides += 1;
      } else if (status === 'cancelled') {
        cancelledCount++;
      }
    });

    let prevRevenue = 0;
    prevRides.forEach(r => {
      if ((r.status || '').toLowerCase() === 'completed') {
        prevRevenue += Number(r.fareEstimate || r.fare || 0);
      }
    });

    const revenueGrowth = prevRevenue > 0
      ? Math.round(((currentRevenue - prevRevenue) / prevRevenue) * 100)
      : (currentRevenue > 0 ? 100 : 0);

    const completionRate = currentRides.length > 0 
      ? Math.round((completedCount / currentRides.length) * 100) 
      : 0;

    const avgFare = completedCount > 0 ? Math.round(currentRevenue / completedCount) : 0;

    // Chart Time-buckets
    let trendChartData = [];
    if (period === 'day') {
      // 24 Hour intervals
      const hours = Array.from({ length: 24 }, (_, i) => ({
        label: `${i}:00`,
        revenue: 0,
        rides: 0,
      }));
      currentRides.forEach(r => {
        const dt = parseDate(r.createdAt || r.timestamp);
        if (dt && (r.status || '').toLowerCase() === 'completed') {
          const h = dt.getHours();
          hours[h].revenue += Number(r.fareEstimate || 0);
          hours[h].rides += 1;
        }
      });
      trendChartData = hours;
    } else if (period === 'month') {
      const daysInMonth = currentEnd.getDate();
      const days = Array.from({ length: daysInMonth }, (_, i) => ({
        label: `${i + 1}`,
        revenue: 0,
        rides: 0,
      }));
      currentRides.forEach(r => {
        const dt = parseDate(r.createdAt || r.timestamp);
        if (dt && (r.status || '').toLowerCase() === 'completed') {
          const dIdx = dt.getDate() - 1;
          if (days[dIdx]) {
            days[dIdx].revenue += Number(r.fareEstimate || 0);
            days[dIdx].rides += 1;
          }
        }
      });
      trendChartData = days;
    } else {
      // 12 Months
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'].map(m => ({
        label: m,
        revenue: 0,
        rides: 0,
      }));
      currentRides.forEach(r => {
        const dt = parseDate(r.createdAt || r.timestamp);
        if (dt && (r.status || '').toLowerCase() === 'completed') {
          const mIdx = dt.getMonth();
          months[mIdx].revenue += Number(r.fareEstimate || 0);
          months[mIdx].rides += 1;
        }
      });
      trendChartData = months;
    }

    const topLocations = Object.values(locationStats).sort((a, b) => b.rides - a.rides);

    const outcomesData = [
      { name: 'Completed', value: completedCount },
      { name: 'Cancelled', value: cancelledCount },
      { name: 'Other', value: Math.max(0, currentRides.length - completedCount - cancelledCount) }
    ].filter(d => d.value > 0);

    return {
      currentRevenue,
      prevRevenue,
      revenueGrowth,
      totalRides: currentRides.length,
      completedCount,
      cancelledCount,
      completionRate,
      avgFare,
      services,
      topLocations,
      outcomesData,
      trendChartData
    };
  }, [currentRides, prevRides, period, currentEnd]);

  // Formatted period title
  const periodLabel = useMemo(() => {
    const optsMonth = { month: 'long', year: 'numeric' };
    const optsDay = { day: 'numeric', month: 'short', year: 'numeric' };
    if (period === 'day') return selectedDate.toLocaleDateString('en-IN', optsDay);
    if (period === 'month') return selectedDate.toLocaleDateString('en-IN', optsMonth);
    return selectedDate.getFullYear().toString();
  }, [period, selectedDate]);

  const exportCSV = () => {
    if (!currentRides.length) return;
    
    const headers = ['Ride ID', 'Status', 'Date', 'Pickup', 'Dropoff', 'Service', 'Distance (km)', 'Fare (INR)', 'User ID', 'Captain ID'];
    const rows = currentRides.map(r => {
      const dt = parseDate(r.createdAt || r.timestamp);
      const dateStr = dt ? dt.toISOString() : '';
      const dist = r.distanceMeters ? (r.distanceMeters / 1000).toFixed(2) : '';
      return [
        r.id, 
        r.status || 'unknown', 
        dateStr, 
        `"${(r.pickup?.address || '').replace(/"/g, '""')}"`,
        `"${(r.destination?.address || '').replace(/"/g, '""')}"`,
        r.vehicleType || 'bike',
        dist, 
        r.fareEstimate || 0, 
        r.userId || '', 
        r.captainId || ''
      ].join(',');
    });

    const csvContent = "data:text/csv;charset=utf-8," + [headers.join(','), ...rows].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `sarthi_analytics_${period}_${periodLabel.replace(/\s+/g, '_')}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="animate-fade-in" style={{ paddingBottom: '2.5rem' }}>
      
      {/* 1. Header Banner */}
      <div style={{ 
        background: 'linear-gradient(135deg, #1e293b 0%, #0f172a 100%)',
        borderRadius: 'var(--r-xl)',
        padding: '1.5rem 2rem',
        color: 'white',
        marginBottom: '1.5rem',
        boxShadow: 'var(--shadow-md)',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        flexWrap: 'wrap',
        gap: '1rem',
        position: 'relative',
        overflow: 'hidden'
      }}>
        <div style={{ position: 'absolute', right: '-5%', top: '-50%', width: '300px', height: '300px', background: 'radial-gradient(circle, rgba(255,255,255,0.05) 0%, rgba(255,255,255,0) 70%)', borderRadius: '50%' }}></div>
        
        <div style={{ position: 'relative', zIndex: 1 }}>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 800, margin: 0, letterSpacing: '-0.03em', display: 'flex', alignItems: 'center', gap: '0.625rem' }}>
            <TrendUp size={26} weight="duotone" style={{ color: '#38BDF8' }} /> 
            Business Intelligence & Heatmaps
          </h1>
          <p style={{ color: 'rgba(255,255,255,0.7)', fontSize: '0.875rem', marginTop: '0.25rem', marginLeft: '2.25rem' }}>
            Live platform metrics, demand hotspots, and trip performance.
          </p>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', position: 'relative', zIndex: 1 }}>
          {/* View Mode Toggle */}
          <div style={{ display: 'flex', background: 'rgba(255,255,255,0.08)', padding: '0.25rem', borderRadius: 'var(--r-full)', border: '1px solid rgba(255,255,255,0.15)' }}>
            <button
              onClick={() => setActiveTab('analytics')}
              style={{
                padding: '0.45rem 1rem',
                borderRadius: 'var(--r-full)',
                border: 'none',
                background: activeTab === 'analytics' ? 'var(--brand-teal)' : 'transparent',
                color: 'white',
                fontWeight: 700,
                fontSize: '0.8125rem',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '0.375rem',
                transition: 'all var(--t-fast)'
              }}
            >
              <ChartLineUp size={16} weight="bold" />
              Analytics
            </button>
            <button
              onClick={() => setActiveTab('heatmap')}
              style={{
                padding: '0.45rem 1rem',
                borderRadius: 'var(--r-full)',
                border: 'none',
                background: activeTab === 'heatmap' ? '#EF4444' : 'transparent',
                color: 'white',
                fontWeight: 700,
                fontSize: '0.8125rem',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '0.375rem',
                transition: 'all var(--t-fast)'
              }}
            >
              <Fire size={16} weight="fill" />
              Demand Heatmap
            </button>
          </div>

          <button 
            onClick={exportCSV}
            style={{ 
              background: 'rgba(255,255,255,0.1)', color: 'white', 
              border: '1px solid rgba(255,255,255,0.2)', padding: '0.5rem 1.125rem', 
              borderRadius: 'var(--r-full)', fontWeight: 600, 
              fontSize: '0.8125rem', display: 'flex', alignItems: 'center', gap: '0.5rem',
              cursor: 'pointer', transition: 'all var(--t-fast)'
            }}
            onMouseOver={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.2)'}
            onMouseOut={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.1)'}
          >
            <DownloadSimple size={16} weight="bold" />
            Export CSV
          </button>
        </div>
      </div>

      {/* 2. Interactive Period Selector Toolbar */}
      <div className="card" style={{ padding: '0.875rem 1.25rem', marginBottom: '1.5rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <span style={{ fontSize: '0.8125rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Period:
          </span>
          <div style={{ display: 'flex', background: 'var(--surface-2)', padding: '0.25rem', borderRadius: 'var(--r-md)', border: '1px solid var(--border)' }}>
            {['day', 'month', 'year'].map(p => (
              <button
                key={p}
                onClick={() => setPeriod(p)}
                style={{
                  padding: '0.35rem 0.875rem',
                  borderRadius: 'var(--r-sm)',
                  border: 'none',
                  background: period === p ? 'var(--brand-blue)' : 'transparent',
                  color: period === p ? 'white' : 'var(--text-secondary)',
                  fontWeight: 700,
                  fontSize: '0.8125rem',
                  textTransform: 'capitalize',
                  cursor: 'pointer',
                  transition: 'all var(--t-fast)'
                }}
              >
                {p}
              </button>
            ))}
          </div>
        </div>

        {/* Date Navigator */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <button 
            onClick={() => shiftDate(-1)}
            style={{ 
              width: 32, height: 32, borderRadius: 'var(--r-full)', 
              border: '1px solid var(--border)', background: 'var(--surface-1)', 
              color: 'var(--text-primary)', display: 'flex', alignItems: 'center', 
              justifyContent: 'center', cursor: 'pointer' 
            }}
          >
            <CaretLeft size={16} weight="bold" />
          </button>

          <div style={{ 
            display: 'flex', alignItems: 'center', gap: '0.5rem', 
            padding: '0.4rem 1rem', background: 'var(--surface-2)', 
            borderRadius: 'var(--r-md)', border: '1px solid var(--border)',
            fontWeight: 700, fontSize: '0.875rem', color: 'var(--text-primary)'
          }}>
            <Calendar size={16} weight="bold" style={{ color: 'var(--brand-teal)' }} />
            {periodLabel}
          </div>

          <button 
            onClick={() => shiftDate(1)}
            disabled={isCurrentPeriod}
            style={{ 
              width: 32, height: 32, borderRadius: 'var(--r-full)', 
              border: '1px solid var(--border)', 
              background: isCurrentPeriod ? 'var(--surface-2)' : 'var(--surface-1)', 
              color: isCurrentPeriod ? 'var(--text-muted)' : 'var(--text-primary)', 
              display: 'flex', alignItems: 'center', justifyContent: 'center', 
              cursor: isCurrentPeriod ? 'not-allowed' : 'pointer',
              opacity: isCurrentPeriod ? 0.4 : 1
            }}
          >
            <CaretRight size={16} weight="bold" />
          </button>

          {!isCurrentPeriod && (
            <button
              onClick={() => setSelectedDate(new Date())}
              style={{
                padding: '0.4rem 0.875rem',
                borderRadius: 'var(--r-md)',
                border: '1px solid var(--brand-blue)',
                background: 'rgba(21, 101, 192, 0.08)',
                color: 'var(--brand-blue)',
                fontWeight: 700,
                fontSize: '0.8125rem',
                cursor: 'pointer'
              }}
            >
              Today
            </button>
          )}
        </div>
      </div>

      {/* VIEW 1: STANDARD ANALYTICS */}
      {activeTab === 'analytics' && (
        <>
          {/* 3. KPI Cards */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '1.25rem', marginBottom: '1.5rem' }}>
            {/* Total Revenue with Trend */}
            <div className="card" style={{ padding: '1.25rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '0.5rem' }}>
                <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                  Period Revenue
                </span>
                <div style={{ width: 34, height: 34, borderRadius: 'var(--r-full)', background: 'rgba(0,166,166,0.1)', color: 'var(--brand-teal)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <CurrencyInr size={18} weight="bold" />
                </div>
              </div>
              <div style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2 }}>
                {loading ? '...' : `₹${analyticsData.currentRevenue.toLocaleString('en-IN')}`}
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.375rem', marginTop: '0.5rem', fontSize: '0.75rem', fontWeight: 700, color: analyticsData.revenueGrowth >= 0 ? 'var(--success)' : 'var(--error)' }}>
                {analyticsData.revenueGrowth >= 0 ? <TrendUp size={14} weight="bold" /> : <TrendDown size={14} weight="bold" />}
                <span>{analyticsData.revenueGrowth >= 0 ? `+${analyticsData.revenueGrowth}%` : `${analyticsData.revenueGrowth}%`}</span>
                <span style={{ color: 'var(--text-muted)', fontWeight: 500 }}>vs previous {period}</span>
              </div>
            </div>

            {/* Total Rides */}
            <div className="card" style={{ padding: '1.25rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '0.5rem' }}>
                <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                  Total Requests
                </span>
                <div style={{ width: 34, height: 34, borderRadius: 'var(--r-full)', background: 'rgba(21,101,192,0.1)', color: 'var(--brand-blue)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <CarProfile size={18} weight="fill" />
                </div>
              </div>
              <div style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2 }}>
                {loading ? '...' : analyticsData.totalRides.toLocaleString()}
              </div>
              <div style={{ marginTop: '0.5rem', fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                {analyticsData.completedCount} completed • {analyticsData.cancelledCount} cancelled
              </div>
            </div>

            {/* Average Fare */}
            <div className="card" style={{ padding: '1.25rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '0.5rem' }}>
                <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                  Average Fare
                </span>
                <div style={{ width: 34, height: 34, borderRadius: 'var(--r-full)', background: 'rgba(139,92,246,0.1)', color: '#8B5CF6', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <ChartLineUp size={18} weight="bold" />
                </div>
              </div>
              <div style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2 }}>
                {loading ? '...' : `₹${analyticsData.avgFare.toLocaleString('en-IN')}`}
              </div>
              <div style={{ marginTop: '0.5rem', fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                Across completed rides
              </div>
            </div>

            {/* Completion Rate */}
            <div className="card" style={{ padding: '1.25rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '0.5rem' }}>
                <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                  Completion Rate
                </span>
                <div style={{ width: 34, height: 34, borderRadius: 'var(--r-full)', background: 'rgba(22,163,74,0.1)', color: 'var(--success)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <CheckCircle size={18} weight="fill" />
                </div>
              </div>
              <div style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2 }}>
                {loading ? '...' : `${analyticsData.completionRate}%`}
              </div>
              <div style={{ marginTop: '0.5rem', fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                {activeCaptains} Active Captains Online
              </div>
            </div>
          </div>

          {/* 4. Revenue Trend Chart & Services Breakdown */}
          <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '1.5rem', marginBottom: '1.5rem', alignItems: 'stretch' }}>
            {/* Revenue Trend Area Chart */}
            <div className="card" style={{ padding: '1.5rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
                <div>
                  <h2 style={{ fontSize: '1.125rem', fontWeight: 700, margin: 0, color: 'var(--text-primary)' }}>
                    Revenue & Demand Trend
                  </h2>
                  <p style={{ margin: 0, fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                    Revenue generated over the selected {period}
                  </p>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.375rem', fontSize: '0.75rem', fontWeight: 700, color: 'var(--brand-teal)' }}>
                  <span style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--brand-teal)' }}></span>
                  Revenue (₹)
                </div>
              </div>

              <div style={{ width: '100%', height: 260 }}>
                <ResponsiveContainer>
                  <AreaChart data={analyticsData.trendChartData}>
                    <defs>
                      <linearGradient id="revenueGrad" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#00A6A6" stopOpacity={0.4}/>
                        <stop offset="95%" stopColor="#00A6A6" stopOpacity={0.0}/>
                      </linearGradient>
                    </defs>
                    <XAxis dataKey="label" stroke="var(--text-muted)" fontSize={11} tickLine={false} />
                    <YAxis stroke="var(--text-muted)" fontSize={11} tickLine={false} tickFormatter={(v) => `₹${v}`} />
                    <Tooltip 
                      contentStyle={{ borderRadius: 'var(--r-md)', border: '1px solid var(--border)', background: 'var(--surface-1)', color: 'var(--text-primary)' }}
                      formatter={(val) => [`₹${val}`, 'Revenue']}
                    />
                    <Area type="monotone" dataKey="revenue" stroke="#00A6A6" strokeWidth={2.5} fillOpacity={1} fill="url(#revenueGrad)" />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            </div>

            {/* Service Breakdown */}
            <div className="card" style={{ padding: '1.5rem' }}>
              <h2 style={{ fontSize: '1.125rem', fontWeight: 700, margin: '0 0 1.25rem 0', color: 'var(--text-primary)' }}>
                Revenue by Service
              </h2>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                {Object.entries(SERVICE_META).map(([key, meta]) => {
                  const svcData = analyticsData.services[key] || { rides: 0, revenue: 0 };
                  const pct = analyticsData.currentRevenue > 0 
                    ? Math.round((svcData.revenue / analyticsData.currentRevenue) * 100) 
                    : 0;
                  const Icon = meta.icon;

                  return (
                    <div key={key} style={{ background: 'var(--surface-2)', padding: '0.875rem', borderRadius: 'var(--r-md)', border: '1px solid var(--border)' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.375rem' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                          <div style={{ width: 28, height: 28, borderRadius: 'var(--r-sm)', background: `${meta.color}20`, color: meta.color, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            <Icon size={16} weight="bold" />
                          </div>
                          <div>
                            <div style={{ fontSize: '0.875rem', fontWeight: 700, color: 'var(--text-primary)' }}>{meta.label}</div>
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{svcData.rides} completed rides</div>
                          </div>
                        </div>
                        <div style={{ textAlign: 'right' }}>
                          <div style={{ fontSize: '0.9375rem', fontWeight: 800, color: 'var(--text-primary)' }}>₹{svcData.revenue.toLocaleString('en-IN')}</div>
                          <div style={{ fontSize: '0.75rem', fontWeight: 700, color: meta.color }}>{pct}% share</div>
                        </div>
                      </div>
                      <div style={{ width: '100%', height: 6, background: 'var(--border)', borderRadius: 3, overflow: 'hidden' }}>
                        <div style={{ width: `${pct}%`, height: '100%', background: meta.color, borderRadius: 3, transition: 'width 0.4s ease' }}></div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>

          {/* 5. Locations & Outcomes */}
          <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '1.5rem', alignItems: 'start' }}>
            {/* Top Locations */}
            <div className="card" style={{ padding: '1.5rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '1.25rem', paddingBottom: '0.875rem', borderBottom: '1px solid var(--border)' }}>
                <MapPin size={20} weight="bold" style={{ color: 'var(--brand-teal)' }} /> 
                <h2 style={{ fontSize: '1.125rem', fontWeight: 700, margin: 0, color: 'var(--text-primary)' }}>
                  Top Locations in Period
                </h2>
              </div>
              {analyticsData.topLocations.length > 0 ? (
                <div style={{ overflowX: 'auto', maxHeight: '300px' }}>
                  <table className="data-table" style={{ width: '100%', textAlign: 'left', borderCollapse: 'collapse' }}>
                    <thead style={{ position: 'sticky', top: 0, background: 'var(--surface-1)', zIndex: 1 }}>
                      <tr>
                        <th style={{ padding: '0.75rem 1rem', color: 'var(--text-muted)', fontSize: '0.75rem', textTransform: 'uppercase' }}>Location</th>
                        <th style={{ padding: '0.75rem 1rem', color: 'var(--text-muted)', fontSize: '0.75rem', textTransform: 'uppercase', textAlign: 'right' }}>Completed Trips</th>
                        <th style={{ padding: '0.75rem 1rem', color: 'var(--text-muted)', fontSize: '0.75rem', textTransform: 'uppercase', textAlign: 'right' }}>Total Revenue</th>
                      </tr>
                    </thead>
                    <tbody>
                      {analyticsData.topLocations.map((loc, idx) => (
                        <tr key={idx} style={{ borderBottom: '1px solid var(--border)' }}>
                          <td style={{ padding: '0.875rem 1rem', fontWeight: 600, color: 'var(--text-primary)' }}>{loc.name}</td>
                          <td style={{ padding: '0.875rem 1rem', textAlign: 'right', color: 'var(--text-secondary)' }}>{loc.rides.toLocaleString()}</td>
                          <td style={{ padding: '0.875rem 1rem', textAlign: 'right', fontWeight: 700, color: 'var(--brand-teal)' }}>₹{loc.revenue.toLocaleString('en-IN')}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <div style={{ height: 200, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)', fontSize: '0.875rem' }}>
                  No trip data for this period.
                </div>
              )}
            </div>

            {/* Trip Outcomes Pie Chart */}
            <div className="card" style={{ padding: '1.5rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '1.25rem', paddingBottom: '0.875rem', borderBottom: '1px solid var(--border)' }}>
                <ChartPieSlice size={20} weight="bold" style={{ color: 'var(--brand-blue)' }} /> 
                <h2 style={{ fontSize: '1.125rem', fontWeight: 700, margin: 0, color: 'var(--text-primary)' }}>Trip Outcomes</h2>
              </div>
              {analyticsData.outcomesData.length > 0 ? (
                <div style={{ width: '100%', height: 260 }}>
                  <ResponsiveContainer>
                    <PieChart>
                      <Pie
                        data={analyticsData.outcomesData}
                        cx="50%"
                        cy="45%"
                        innerRadius={55}
                        outerRadius={85}
                        paddingAngle={5}
                        dataKey="value"
                        stroke="none"
                      >
                        {analyticsData.outcomesData.map((entry, index) => (
                          <Cell key={`cell-${index}`} fill={STATUS_COLORS[entry.name] || '#1565C0'} />
                        ))}
                      </Pie>
                      <Tooltip 
                        contentStyle={{ borderRadius: 'var(--r-md)', border: '1px solid var(--border)', background: 'var(--surface-1)', color: 'var(--text-primary)' }}
                        itemStyle={{ fontWeight: 700 }}
                      />
                      <Legend verticalAlign="bottom" height={36} wrapperStyle={{ fontSize: '0.8125rem', fontWeight: 600 }} iconType="circle" />
                    </PieChart>
                  </ResponsiveContainer>
                </div>
              ) : (
                <div style={{ height: 200, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)', fontSize: '0.875rem' }}>
                  No rides available for this period.
                </div>
              )}
            </div>
          </div>
        </>
      )}

      {/* VIEW 2: DEMAND HEATMAP & HOTSPOTS */}
      {activeTab === 'heatmap' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          <div className="card" style={{ padding: '1.5rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem', flexWrap: 'wrap', gap: '1rem' }}>
              <div>
                <h2 style={{ fontSize: '1.25rem', fontWeight: 800, margin: 0, color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <Fire size={24} weight="fill" style={{ color: '#EF4444' }} />
                  Live Operational Demand Hotspots
                </h2>
                <p style={{ margin: '0.25rem 0 0 0', fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                  Pickup density zones ranked by ride volume in {periodLabel}.
                </p>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', background: 'rgba(239,68,68,0.1)', color: '#EF4444', padding: '0.4rem 0.875rem', borderRadius: 'var(--r-full)', fontSize: '0.8125rem', fontWeight: 700 }}>
                <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#EF4444' }}></span>
                {analyticsData.topLocations.length} Active Zones Identified
              </div>
            </div>

            {analyticsData.topLocations.length > 0 ? (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '1rem' }}>
                {analyticsData.topLocations.map((loc, idx) => {
                  const maxRides = analyticsData.topLocations[0]?.rides || 1;
                  const intensityPct = Math.round((loc.rides / maxRides) * 100);
                  const isTop = idx === 0;

                  return (
                    <div 
                      key={idx}
                      style={{
                        padding: '1.125rem',
                        borderRadius: 'var(--r-lg)',
                        background: isTop ? 'rgba(239,68,68,0.04)' : 'var(--surface-2)',
                        border: isTop ? '1.5px solid rgba(239,68,68,0.3)' : '1px solid var(--border)',
                        display: 'flex',
                        flexDirection: 'column',
                        gap: '0.75rem',
                        position: 'relative'
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.625rem' }}>
                          <div style={{ 
                            width: 28, height: 28, borderRadius: 'var(--r-full)', 
                            background: isTop ? '#EF4444' : 'var(--surface-1)', 
                            color: isTop ? 'white' : 'var(--text-primary)', 
                            display: 'flex', alignItems: 'center', justifyContent: 'center', 
                            fontSize: '0.75rem', fontWeight: 800,
                            border: isTop ? 'none' : '1px solid var(--border)'
                          }}>
                            #{idx + 1}
                          </div>
                          <div>
                            <div style={{ fontWeight: 800, fontSize: '0.9375rem', color: 'var(--text-primary)' }}>
                              {loc.name}
                            </div>
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                              Total revenue: ₹{loc.revenue.toLocaleString('en-IN')}
                            </div>
                          </div>
                        </div>

                        <div style={{ 
                          padding: '0.25rem 0.625rem', 
                          borderRadius: 'var(--r-full)', 
                          fontSize: '0.75rem', 
                          fontWeight: 800,
                          background: intensityPct > 70 ? 'rgba(239,68,68,0.15)' : 'rgba(245,158,11,0.15)',
                          color: intensityPct > 70 ? '#EF4444' : '#F59E0B'
                        }}>
                          {loc.rides} Trips
                        </div>
                      </div>

                      {/* Demand Intensity Bar */}
                      <div>
                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.6875rem', color: 'var(--text-muted)', fontWeight: 600, marginBottom: '0.25rem' }}>
                          <span>Relative Intensity</span>
                          <span>{intensityPct}%</span>
                        </div>
                        <div style={{ width: '100%', height: 6, background: 'var(--border)', borderRadius: 3, overflow: 'hidden' }}>
                          <div style={{ 
                            width: `${intensityPct}%`, 
                            height: '100%', 
                            background: isTop ? 'linear-gradient(90deg, #F59E0B, #EF4444)' : 'var(--brand-teal)', 
                            borderRadius: 3 
                          }}></div>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div style={{ padding: '3rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                <MapPin size={40} style={{ opacity: 0.4, marginBottom: '0.5rem' }} />
                <p>No operational demand recorded for {periodLabel}.</p>
              </div>
            )}
          </div>
        </div>
      )}

    </div>
  );
};

export default Analytics;
