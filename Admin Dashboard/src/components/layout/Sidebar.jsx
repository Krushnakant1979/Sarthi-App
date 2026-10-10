import React, { useState } from 'react';
import { NavLink } from 'react-router-dom';

import {
  SquaresFour,
  Users,
  SteeringWheel,
  Car,
  Tag,
  ChartLineUp,
  Gear,
  CaretLeft,
  CaretRight,
  Megaphone,
  Star,
  CarProfile,
  Headset,
  Bank,
  CurrencyInr
} from '@phosphor-icons/react';

const navItems = [
  { name: 'Dashboard', path: '/', icon: SquaresFour },
  { name: 'Captains', path: '/captains', icon: SteeringWheel },
  { name: 'Users', path: '/users', icon: Users },
  { name: 'Rides', path: '/rides', icon: Car },
  { name: 'Finance', path: '/finance', icon: Bank },
  { name: 'Pricing', path: '/pricing', icon: CurrencyInr },
  { name: 'Offers', path: '/offers', icon: Tag },
  { name: 'Analytics', path: '/analytics', icon: ChartLineUp },
  { name: 'Marketing', path: '/marketing', icon: Megaphone },
  { name: 'Reviews', path: '/reviews', icon: Star },
  { name: 'Vehicles', path: '/vehicles', icon: CarProfile },
  { name: 'Support', path: '/support', icon: Headset },
  { name: 'Settings', path: '/settings', icon: Gear },
];

export const Sidebar = ({ isMobileMenuOpen, setIsMobileMenuOpen }) => {
  const [isExpanded, setIsExpanded] = useState(true);

  const handleNavClick = () => {
    if (setIsMobileMenuOpen) {
      setIsMobileMenuOpen(false);
    }
  };

  return (
    <aside className={`sidebar ${isExpanded ? 'expanded' : 'collapsed'} ${isMobileMenuOpen ? 'mobile-open' : ''}`}>
      {/* Brand */}
      <div className="sidebar-brand">
        <div className="sidebar-logo animate-float">S</div>
        <div className="sidebar-brand-text">
          <span className="brand-name">Sarthi</span>
          <span className="brand-tag">Admin Console</span>
        </div>
      </div>

      {/* Navigation */}
      <nav className="sidebar-nav">
        <div className="sidebar-section-label">Main Menu</div>
        <div className="nav-items-container">
          {navItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              end={item.path === '/'}
              className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}
              title={!isExpanded ? item.name : undefined}
              onClick={handleNavClick}
            >
              {({ isActive }) => (
                <>
                  <div className="nav-item-bg"></div>
                  <item.icon 
                    size={20} 
                    weight={isActive ? "fill" : "regular"} 
                    className="nav-item-icon" 
                  />
                  <span className="nav-item-text">{item.name}</span>
                  {isActive && <div className="nav-item-indicator"></div>}
                </>
              )}
            </NavLink>
          ))}
        </div>
      </nav>

      {/* Footer */}
      <div className="sidebar-footer">
        <button 
          className="sidebar-toggle-btn"
          onClick={() => setIsExpanded(!isExpanded)}
          title={isExpanded ? 'Collapse sidebar' : 'Expand sidebar'}
        >
          {isExpanded ? <CaretLeft size={16} weight="bold" /> : <CaretRight size={16} weight="bold" />}
        </button>
      </div>
    </aside>
  );
};
