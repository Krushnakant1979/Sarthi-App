import styles from "./features.module.css";
import { CheckCircle2, MapPin, Navigation, Wallet, Zap, Compass, CreditCard, ShieldCheck, UserCheck, AlertTriangle, ArrowRight, Shield } from "lucide-react";

export const metadata = {
  title: "Features | Sarthi",
  description: "Comprehensive features for riders and captains on the Sarthi platform.",
};

const FeatureList = ({ items }) => (
  <ul className={styles.cardList}>
    {items.map(item => (
      <li key={item} className={styles.cardListItem}>
        <CheckCircle2 color="var(--blue-500)" size={22} />
        {item}
      </li>
    ))}
  </ul>
);

export default function FeaturesPage() {
  return (
    <main>
      {/* ── HERO ─────────────────────────────────────────────── */}
      <section className={styles.hero}>
        <div className={styles.heroBackground}>
          <div className={styles.glowOrb1}></div>
          <div className={styles.glowOrb2}></div>
        </div>
        <div className={styles.heroInner}>
          <span className={styles.heroTag}>Platform Features</span>
          <h1 className={styles.heroTitle}>
            Everything you need<br />
            <span className={styles.gradientText}>to move smarter.</span>
          </h1>
          <p className={styles.heroDesc}>
            Explore the comprehensive suite of features built to make the Sarthi platform efficient, reliable, and incredibly secure for both Riders and Captains.
          </p>
        </div>
      </section>

      {/* ── RIDER FEATURES ───────────────────────────────────── */}
      <section className={styles.sectionDark}>
        <div className={styles.sectionHeader}>
          <h2 className={styles.sectionTitle}>Built for Riders</h2>
          <p className={styles.sectionDesc}>
            A frictionless experience from the moment you open the app to the moment you step out of your ride.
          </p>
        </div>
        
        <div className={styles.grid}>
          {/* Card 1 - Spans 2 columns */}
          <div className={`${styles.card} ${styles.bentoSpan2}`}>
            <div className={`${styles.cardIcon} ${styles.iconBlue}`}>
              <MapPin size={32} />
            </div>
            <h3 className={styles.cardTitle}>Intelligent Booking Experience</h3>
            <p style={{ color: "var(--gray-500)", marginBottom: "24px", fontSize: "1.1rem", lineHeight: "1.6" }}>
              Our booking engine is designed to minimize wait times. By predicting high-demand areas and pre-routing captains, we ensure you get a ride when you need it most.
            </p>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "16px" }}>
              <FeatureList items={[
                "One-Tap Ride Booking",
                "Pinpoint Pickup Accuracy",
              ]} />
              <FeatureList items={[
                "Multiple Vehicle Choices",
                "Advanced Scheduling",
              ]} />
            </div>
          </div>

          {/* Card 2 */}
          <div className={styles.card}>
            <div className={`${styles.cardIcon} ${styles.iconPurple}`}>
              <Wallet size={32} />
            </div>
            <h3 className={styles.cardTitle}>Transparent Fares</h3>
            <FeatureList items={[
              "No Hidden Surcharges",
              "Upfront Fare Estimates",
              "Seamless Digital Payments",
            ]} />
          </div>

          {/* Card 3 */}
          <div className={styles.card}>
            <div className={`${styles.cardIcon} ${styles.iconGreen}`}>
              <Navigation size={32} />
            </div>
            <h3 className={styles.cardTitle}>Live Tracking</h3>
            <FeatureList items={[
              "Sub-second Location Updates",
              "Live Traffic & ETA",
              "Share Trip Status",
            ]} />
          </div>

          {/* Card 4 - Spans 2 columns */}
          <div className={`${styles.card} ${styles.bentoSpan2}`}>
            <div className={`${styles.cardIcon} ${styles.iconOrange}`}>
              <Shield size={32} />
            </div>
            <h3 className={styles.cardTitle}>Uncompromised Security</h3>
            <p style={{ color: "var(--gray-500)", marginBottom: "24px", fontSize: "1.1rem", lineHeight: "1.6" }}>
              Your safety is our top priority. From secure OTP ride starts to continuous trip monitoring, we've built safeguards into every step of your journey.
            </p>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "16px" }}>
              <FeatureList items={[
                "OTP Verification for every ride",
                "Anonymized Phone Numbers",
              ]} />
              <FeatureList items={[
                "24/7 Incident Response Team",
                "Insurance on every trip",
              ]} />
            </div>
          </div>
        </div>
      </section>

      {/* ── CAPTAIN FEATURES ─────────────────────────────────── */}
      <section className={styles.section}>
        <div className={styles.sectionHeader}>
          <h2 className={styles.sectionTitle}>Empowering Captains</h2>
          <p className={styles.sectionDesc}>
            Powerful tools and intelligent routing designed to help you maximize your earnings while keeping you in total control.
          </p>
        </div>

        <div className={styles.grid}>
          {/* Card 1 */}
          <div className={styles.card}>
            <div className={`${styles.cardIcon} ${styles.iconYellow}`}>
              <Zap size={32} />
            </div>
            <h3 className={styles.cardTitle}>Opportunity Engine</h3>
            <FeatureList items={[
              "High-Demand Heatmaps",
              "Smart Ride Matching",
              "Back-to-back Dispatch",
            ]} />
          </div>



          {/* Card 3 - Spans 2 columns */}
          <div className={`${styles.card} ${styles.bentoSpan2}`}>
            <div className={`${styles.cardIcon} ${styles.iconGreen}`}>
              <CreditCard size={32} />
            </div>
            <h3 className={styles.cardTitle}>Earnings & Transparency</h3>
            <p style={{ color: "var(--gray-500)", marginBottom: "24px", fontSize: "1.1rem", lineHeight: "1.6" }}>
              Your hard work deserves fast rewards. We provide complete transparency into your earnings, with detailed breakdowns and instant access to your money.
            </p>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "16px" }}>
              <FeatureList items={[
                "Instant Daily Bank Payouts",
                "Detailed Trip Fare Breakdowns",
              ]} />
              <FeatureList items={[
                "Performance Bonuses & Goals",
                "Zero Hidden Deductions",
              ]} />
            </div>
          </div>

          {/* Card 4 */}
          <div className={styles.card}>
            <div className={`${styles.cardIcon} ${styles.iconRed}`}>
              <UserCheck size={32} />
            </div>
            <h3 className={styles.cardTitle}>Captain Support</h3>
            <FeatureList items={[
              "Priority Phone Support",
              "In-app Issue Resolution",
              "Community Forums",
            ]} />
          </div>
        </div>
      </section>

      {/* ── SAFETY & RELIABILITY ──────────────────────────────── */}
      <section className={styles.safetySection}>
        <div className={styles.heroBackground}>
          {/* Reuse the glow orbs but repositioned slightly via CSS if needed, or just let them float */}
          <div className={styles.glowOrb1} style={{ opacity: 0.15 }}></div>
          <div className={styles.glowOrb2} style={{ opacity: 0.15 }}></div>
        </div>
        <div className={styles.sectionHeader} style={{ position: "relative", zIndex: 1 }}>
          <h2 className={styles.sectionTitle} style={{ color: "var(--white)", fontSize: "3.5rem" }}>Safety is our priority.</h2>
          <p className={styles.sectionDesc} style={{ color: "rgba(255,255,255,0.7)", fontSize: "1.25rem" }}>
            We've built robust safety features directly into the core of the Sarthi platform.
          </p>
        </div>

        <div className={styles.safetyGrid}>
          <div className={styles.safetyCard}>
            <div className={styles.safetyIcon}>
              <UserCheck size={36} />
            </div>
            <h3 className={styles.safetyTitle}>Verified Captains</h3>
            <p className={styles.safetyDesc}>
              Every captain goes through a strict background and document verification process before they can accept a single ride.
            </p>
          </div>

          <div className={styles.safetyCard}>
            <div className={styles.safetyIcon}>
              <ShieldCheck size={36} />
            </div>
            <h3 className={styles.safetyTitle}>Trip Sharing</h3>
            <p className={styles.safetyDesc}>
              Share your live location, captain details, and ETA with friends or family instantly from within the app.
            </p>
          </div>

          <div className={styles.safetyCard}>
            <div className={styles.safetyIcon}>
              <AlertTriangle size={36} />
            </div>
            <h3 className={styles.safetyTitle}>Emergency SOS</h3>
            <p className={styles.safetyDesc}>
              A dedicated 24/7 SOS button is always visible on your screen during a ride to alert our safety team immediately.
            </p>
          </div>
        </div>
      </section>
      
      {/* ── CTA SECTION ──────────────────────────────── */}
      <section className={styles.ctaContainer}>
        <h2 className={styles.ctaTitle}>Experience the Difference</h2>
        <p className={styles.ctaDesc}>Download Sarthi today and see why thousands are making the switch.</p>
        <button className={styles.btnPrimary}>Get the App</button>
      </section>
    </main>
  );
}
