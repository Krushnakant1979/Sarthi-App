"use client";
import { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAuth } from "@/context/AuthContext";
import { db } from "@/config/firebase";
import { doc, getDoc } from "firebase/firestore";
import styles from "./components.module.css";

function ProfileDropdown({ user, logout }) {
  const [isOpen, setIsOpen] = useState(false);
  const [userData, setUserData] = useState(null);

  useEffect(() => {
    async function fetchUserData() {
      if (!user?.uid) return;
      try {
        const docRef = doc(db, "users", user.uid);
        const docSnap = await getDoc(docRef);
        if (docSnap.exists()) {
          setUserData(docSnap.data());
        }
      } catch (e) {
        console.error("Failed to fetch user data", e);
      }
    }
    fetchUserData();
  }, [user]);

  const initials = userData?.firstName 
    ? `${userData.firstName[0]}${userData.lastName?.[0] || ''}`.toUpperCase() 
    : (user.displayName?.[0] || user.email?.[0] || 'U').toUpperCase();

  const name = userData?.firstName 
    ? `${userData.firstName} ${userData.lastName || ''}` 
    : (user.displayName || 'Sarthi User');

  return (
    <div className={styles.profileContainer}>
      <button 
        className={styles.profileBtn} 
        onClick={() => setIsOpen(!isOpen)}
        onBlur={() => setTimeout(() => setIsOpen(false), 200)}
      >
        <div className={styles.profileAvatar}>{initials}</div>
      </button>

      {isOpen && (
        <div className={styles.profileDropdown}>
          <div className={styles.profileHeader}>
            <div className={styles.profileAvatarLg}>{initials}</div>
            <div className={styles.profileInfo}>
              <h4>{name}</h4>
              <p>{userData?.email || user.email}</p>
              {userData?.phone && <p>{userData.phone}</p>}
            </div>
          </div>
          <div className={styles.profileBody}>
            {userData?.role && (
              <div className={styles.profileItem}>
                <span>Role</span>
                <strong>{userData.role.charAt(0).toUpperCase() + userData.role.slice(1)}</strong>
              </div>
            )}
            <Link href="/rides" className={styles.profileItem} onClick={() => setIsOpen(false)} style={{ textDecoration: 'none', display: 'flex' }}>
              <span>My Rides</span>
              <strong>→</strong>
            </Link>
            <button onClick={logout} className={styles.profileLogoutBtn}>Logout</button>
          </div>
        </div>
      )}
    </div>
  );
}

export default function Navbar() {
  const [menuOpen, setMenuOpen] = useState(false);
  const { user, logout } = useAuth();
  const pathname = usePathname();

  const isActive = (path) => pathname === path ? styles.active : "";

  return (
    <nav className={styles.navbar}>
      <div className={styles.navInner}>
        <Link href="/" className={styles.navLogo}>
          <img src="/Sarthi app user logo.png" alt="Sarthi Logo" width="32" height="32" style={{ borderRadius: "8px", objectFit: "contain" }} />
          Sarthi<span className={styles.navLogoAccent}>.</span>
        </Link>

        <ul className={styles.navLinks}>
          <li><Link href="/" className={`${styles.navLink} ${isActive("/")}`}>Home</Link></li>
          <li><Link href="/about" className={`${styles.navLink} ${isActive("/about")}`}>About</Link></li>
          <li><Link href="/features" className={`${styles.navLink} ${isActive("/features")}`}>Features</Link></li>
          <li><Link href="/riders" className={`${styles.navLink} ${isActive("/riders")}`}>Riders</Link></li>
          <li><Link href="/captains" className={`${styles.navLink} ${isActive("/captains")}`}>Captains</Link></li>
          <li><Link href="/contact" className={`${styles.navLink} ${isActive("/contact")}`}>Contact</Link></li>
        </ul>

        <div className={styles.navActions}>
          {user ? (
            <ProfileDropdown user={user} logout={logout} />
          ) : (
            <>
              <Link href="/login" className={styles.btnNavOutline}>Login</Link>
              <Link href="/riders" className={styles.btnNavPrimary}>Download App</Link>
            </>
          )}
        </div>

        <button
          className={styles.menuToggle}
          onClick={() => setMenuOpen(!menuOpen)}
          aria-label="Menu"
        >
          <span></span>
          <span></span>
          <span></span>
        </button>
      </div>

      <div className={`${styles.mobileMenu} ${menuOpen ? styles.open : ""}`}>
        <Link href="/" className={`${styles.navLink} ${isActive("/")}`} onClick={() => setMenuOpen(false)}>Home</Link>
        <Link href="/about" className={`${styles.navLink} ${isActive("/about")}`} onClick={() => setMenuOpen(false)}>About</Link>
        <Link href="/features" className={`${styles.navLink} ${isActive("/features")}`} onClick={() => setMenuOpen(false)}>Features</Link>
        <Link href="/riders" className={`${styles.navLink} ${isActive("/riders")}`} onClick={() => setMenuOpen(false)}>Riders</Link>
        <Link href="/captains" className={`${styles.navLink} ${isActive("/captains")}`} onClick={() => setMenuOpen(false)}>Captains</Link>
        <Link href="/contact" className={`${styles.navLink} ${isActive("/contact")}`} onClick={() => setMenuOpen(false)}>Contact</Link>
      </div>
    </nav>
  );
}
