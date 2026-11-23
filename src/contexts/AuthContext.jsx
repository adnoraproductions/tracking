import React, { createContext, useContext, useState, useEffect } from 'react';
import { authService } from '../services/auth/authService';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Check active session
    const initAuth = async () => {
      try {
        const currentUser = await authService.getCurrentUser();
        setUser(currentUser);
        if (currentUser) {
          const userProfile = await authService.getUserProfile(currentUser.id);
          setProfile(userProfile);
        }
      } catch (error) {
        console.error('Error initializing auth:', error);
      } finally {
        setLoading(false);
      }
    };

    initAuth();

    // Listen for auth changes.
    // The callback must stay synchronous: Supabase runs it while holding its auth lock, so
    // awaiting another Supabase query in here deadlocks (blank screen when an expired login
    // is refreshed on startup). The profile load is deferred until the lock is released.
    const { data: { subscription } } = authService.onAuthStateChange((event, session) => {
      const nextUser = session?.user ?? null;
      setUser(nextUser);
      if (!nextUser) {
        setProfile(null);
        setLoading(false);
        return;
      }
      // A token refresh doesn't change who is signed in — keep the current profile
      if (event === 'TOKEN_REFRESHED') return;
      setTimeout(async () => {
        try {
          const userProfile = await authService.getUserProfile(nextUser.id);
          setProfile(userProfile);
        } catch (e) {
          console.error(e);
          setProfile(null);
        } finally {
          setLoading(false);
        }
      }, 0);
    });

    return () => {
      subscription?.unsubscribe();
    };
  }, []);

  const value = {
    user,
    profile,
    loading,
    role: profile?.role,
    isAdmin: profile?.role === 'admin',
    signIn: authService.signIn,
    signOut: authService.signOut
  };

  return (
    <AuthContext.Provider value={value}>
      {!loading && children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
