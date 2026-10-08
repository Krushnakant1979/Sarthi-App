"use client";

import { useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { useRouter } from "next/navigation";
import Link from "next/link";
import styles from "./login.module.css";

export default function LoginPage() {
  const [isLogin, setIsLogin] = useState(true);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  
  const { login, signup } = useAuth();
  const router = useRouter();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      if (isLogin) {
        await login(email, password);
      } else {
        await signup(email, password, name);
      }
      router.push("/"); // Or /booking in Phase 2
    } catch (err) {
      console.error(err);
      setError(err.message || "Failed to authenticate");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className={styles.container}>
      <div className={styles.authCard}>
        <div className={styles.header}>
          <h2>{isLogin ? "Welcome Back" : "Create Account"}</h2>
          <p>
            {isLogin 
              ? "Login with your Sarthi credentials" 
              : "Sign up to ride with Sarthi"}
          </p>
        </div>

        {error && <div className={styles.errorBanner}>{error}</div>}

        <form onSubmit={handleSubmit} className={styles.form}>
          {!isLogin && (
            <div className={styles.inputGroup}>
              <label htmlFor="name">Full Name</label>
              <input
                id="name"
                type="text"
                placeholder="John Doe"
                value={name}
                onChange={(e) => setName(e.target.value)}
                required={!isLogin}
              />
            </div>
          )}

          <div className={styles.inputGroup}>
            <label htmlFor="email">Email Address</label>
            <input
              id="email"
              type="email"
              placeholder="you@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>

          <div className={styles.inputGroup}>
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>

          <button 
            type="submit" 
            className={styles.submitBtn} 
            disabled={loading}
          >
            {loading ? "Please wait..." : (isLogin ? "Sign In" : "Sign Up")}
          </button>
        </form>

        <div className={styles.toggleText}>
          {isLogin ? "Don't have an account?" : "Already have an account?"}{" "}
          <button 
            type="button" 
            className={styles.toggleBtn}
            onClick={() => {
              setIsLogin(!isLogin);
              setError("");
            }}
          >
            {isLogin ? "Sign Up" : "Log In"}
          </button>
        </div>
      </div>
    </div>
  );
}
