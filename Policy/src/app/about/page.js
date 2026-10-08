import styles from "./about.module.css";
import { Zap, Shield, Navigation, Users, Rocket } from "lucide-react";

export const metadata = {
  title: "About Us | Sarthi",
  description: "Moving People. Connecting Cities.",
};

export default function AboutPage() {
  return (
    <main className={styles.page}>
      {/* ── HERO ─────────────────────────────────────────────── */}
      <section className={styles.hero}>
        <div className={styles.heroBackground}>
          <div className={styles.glowOrb1}></div>
          <div className={styles.glowOrb2}></div>
        </div>
        <div className={styles.heroContent}>
          <span className={styles.heroTag}>About Sarthi</span>
          <h1 className={styles.heroTitle}>
            We build technology<br />
            <span className={styles.gradientText}>that moves cities.</span>
          </h1>
          <p className={styles.heroDesc}>
            Sarthi is an advanced mobility platform engineered to eliminate friction from everyday travel, connecting riders and captains through a beautifully simple interface.
          </p>
        </div>
      </section>


      {/* ── MISSION ──────────────────────────────────────────── */}
      <section className={styles.missionSection}>
        <div className={styles.missionInner}>
          <div className={styles.missionContent}>
            <h2 className={styles.missionMainTitle}>
              <span className={styles.missionTitleLight}>Our Mission</span><br/>
              <span className={styles.missionTitleBold}>& Vision</span>
            </h2>
            
            <div className={styles.missionTextBlock}>
              <h3 className={styles.missionSubtitle}>A Singular Goal</h3>
              <p className={styles.missionText}>
                Our singular goal is to make reliable transportation accessible to everyone. We believe getting from one place to another should be simple, convenient, and dependable, regardless of where you are or where you're going. Sarthi is being built to remove the complexity from everyday travel and create an experience that puts people first.
              </p>
            </div>

            <div className={styles.missionTextBlock}>
              <h3 className={styles.missionSubtitle}>Opportunity on the Road</h3>
              <p className={styles.missionText}>
                Sarthi is built for captains as much as it is built for riders. We want to create an environment where local captains can connect with riders, manage their availability, complete rides, and track their earnings through a simple digital experience. By giving captains better tools and greater flexibility, we aim to create more opportunities on the road.
              </p>
            </div>

            <div className={styles.missionTextBlock}>
              <h3 className={styles.missionSubtitle}>Our Promise</h3>
              <p className={styles.missionText}>
                We are committed to building transportation that is simple, transparent, accessible, and connected. As Sarthi grows, our focus will remain on improving the experience for both riders and captains, listening to the people who use our platform, and continuously building technology that makes everyday mobility better—one journey at a time.
              </p>
            </div>
          </div>
          
          <div className={styles.missionImageWrapper}>
            <img src="/vehicles.jpg" alt="Sarthi Fleet" className={styles.missionImage} />
          </div>
        </div>
      </section>

      {/* ── ECOSYSTEM ────────────────────────────────────────── */}
      <section className={styles.ecoSection}>
        <div className={styles.ecoHeader}>
          <h2 className={styles.ecoTitle}>The Sarthi Ecosystem</h2>
          <p className={styles.ecoSubtitle}>A unified platform designed for scale, speed, and safety.</p>
        </div>

        <div className={styles.ecoGrid}>
          <div className={styles.ecoCard}>
            <div className={styles.ecoCardIconWrapper}>
              <Navigation className={styles.ecoCardIcon} size={20} />
            </div>
            <h3 className={styles.ecoCardTitle}>Rider App</h3>
            <p className={styles.ecoCardDesc}>
              A lightning-fast interface designed for speed. Riders can seamlessly book a trip, track their captain in real-time, and securely manage their fares—all with zero friction.
            </p>
          </div>

          <div className={styles.ecoCard}>
            <div className={styles.ecoCardIconWrapper}>
              <Users className={styles.ecoCardIcon} size={20} />
            </div>
            <h3 className={styles.ecoCardTitle}>Captain App</h3>
            <p className={styles.ecoCardDesc}>
              Built directly for the people driving the city. Captains get turn-by-turn navigation, instant daily payouts, and an opportunity engine that maximizes their earnings.
            </p>
          </div>

          <div className={styles.ecoCard}>
            <div className={styles.ecoCardIconWrapper}>
              <Zap className={styles.ecoCardIcon} size={20} />
            </div>
            <h3 className={styles.ecoCardTitle}>Platform Core</h3>
            <p className={styles.ecoCardDesc}>
              The invisible brain powering the network. An intelligent, low-latency matchmaking engine that connects riders to the absolute nearest captains within milliseconds.
            </p>
          </div>

          <div className={styles.ecoCard}>
            <div className={styles.ecoCardIconWrapper}>
              <Shield className={styles.ecoCardIcon} size={20} />
            </div>
            <h3 className={styles.ecoCardTitle}>Admin Terminal</h3>
            <p className={styles.ecoCardDesc}>
              Complete oversight. Our operations and safety teams utilize this platform to verify documents, monitor fleet health, and ensure 24/7 security for the entire ecosystem.
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
