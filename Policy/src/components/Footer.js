import Link from "next/link";
import { Apple, Play } from "lucide-react";
import styles from "./components.module.css";

export default function Footer() {
  return (
    <footer className={styles.footer}>
      <div className={styles.footerGrid}>
        {/* Brand */}
        <div className={styles.footerBrand}>
          <div className={styles.footerLogo} style={{ display: "flex", alignItems: "center", gap: "8px" }}>
            <img src="/Sarthi app user logo.png" alt="Sarthi Logo" width="32" height="32" style={{ borderRadius: "8px", objectFit: "contain" }} />
            Sarthi<span className={styles.footerLogoAccent}>.</span>
          </div>
          <p className={styles.footerTagline}>
            Your Ride. Your Way. Connecting people with convenient, reliable and real-time transportation.
          </p>
          <div className={styles.footerSocials}>
            {/* Real links to be added when available */}
            <a href="#" className={styles.socialIcon}>𝕏</a>
            <a href="#" className={styles.socialIcon}>in</a>
            <a href="#" className={styles.socialIcon}>f</a>
          </div>
          
          <div className={styles.storeButtons}>
            <button className={styles.storeBtn}>
              <span className={styles.storeBtnIcon}>
                <svg viewBox="0 0 384 512" width="32" height="32" fill="currentColor">
                  <path d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z"/>
                </svg>
              </span>
              <span className={styles.storeBtnText}>
                <span className={styles.storeBtnSub}>Download on the</span>
                <span className={styles.storeBtnMain}>App Store</span>
              </span>
            </button>
            <button className={styles.storeBtn}>
              <span className={styles.storeBtnIcon}>
                <svg viewBox="0 0 512 512" width="32" height="32" fill="currentColor">
                  <path d="M325.3 234.3L104.6 13l280.8 161.2-60.1 60.1zM47 0C34 6.8 25.3 19.2 25.3 35.3v441.3c0 16.1 8.7 28.5 21.7 35.3l256.6-256L47 0zm425.2 225.6l-58.9-34.1-65.7 64.5 65.7 64.5 60.1-34.1c18-14.3 18-46.5-1.2-60.8zM104.6 499l280.8-161.2-60.1-60.1L104.6 499z"/>
                </svg>
              </span>
              <span className={styles.storeBtnText}>
                <span className={styles.storeBtnSub}>Get it on</span>
                <span className={styles.storeBtnMain}>Google Play</span>
              </span>
            </button>
          </div>
        </div>

        {/* Product */}
        <div className={styles.footerCol}>
          <h4 className={styles.footerColTitle}>Product</h4>
          <ul className={styles.footerColLinks}>
            <li><Link href="/" className={styles.footerColLink}>Home</Link></li>
            <li><Link href="/features" className={styles.footerColLink}>Features</Link></li>
            <li><Link href="/riders" className={styles.footerColLink}>Riders</Link></li>
            <li><Link href="/captains" className={styles.footerColLink}>Captains</Link></li>
          </ul>
        </div>

        {/* Company & Support */}
        <div className={styles.footerCol}>
          <h4 className={styles.footerColTitle}>Company & Support</h4>
          <ul className={styles.footerColLinks}>
            <li><Link href="/about" className={styles.footerColLink}>About</Link></li>
            <li><Link href="/contact" className={styles.footerColLink}>Contact</Link></li>
            <li><Link href="/contact" className={styles.footerColLink}>Rider Support</Link></li>
            <li><Link href="/contact" className={styles.footerColLink}>Captain Support</Link></li>
            <li><Link href="/contact" className={styles.footerColLink}>Help Center</Link></li>
          </ul>
        </div>

        {/* Legal */}
        <div className={styles.footerCol}>
          <h4 className={styles.footerColTitle}>Legal</h4>
          <ul className={styles.footerColLinks}>
            <li><Link href="/privacy" className={styles.footerColLink}>Privacy Policy</Link></li>
            <li><Link href="/terms" className={styles.footerColLink}>Terms & Conditions</Link></li>
          </ul>
        </div>
      </div>

      <div className={styles.footerBottom}>
        <span className={styles.footerCopy}>
          © 2026 Sarthi. All rights reserved.
        </span>
        <div className={styles.footerBottomLinks}>
          <Link href="/privacy" className={styles.footerBottomLink}>Privacy</Link>
          <Link href="/terms" className={styles.footerBottomLink}>Terms</Link>
        </div>
      </div>
    </footer>
  );
}
