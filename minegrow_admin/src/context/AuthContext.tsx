import React, { createContext, useContext, useState, useEffect } from 'react';
import { api } from '../services/api';

export interface AdminUser {
  id: number;
  fullName: string;
  email: string;
  isSuper: boolean;
}

interface AuthContextType {
  admin: AdminUser | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  sessionError: string | null;
  clearSessionError: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [admin, setAdmin] = useState<AdminUser | null>(() => {
    const token = localStorage.getItem('admin_access_token');
    const storedUser = localStorage.getItem('admin_user');
    if (token && storedUser) {
      try {
        return JSON.parse(storedUser);
      } catch {
        // Clear corrupt storage
        localStorage.removeItem('admin_access_token');
        localStorage.removeItem('admin_user');
      }
    }
    return null;
  });
  const [loading, setLoading] = useState(false);
  const [sessionError, setSessionError] = useState<string | null>(null);

  useEffect(() => {
    api.registerOnUnauthorized(() => {
      setAdmin(null);
      setSessionError('Session expired. Please log in again.');
    });
  }, []);

  const clearSessionError = () => {
    setSessionError(null);
  };

  const login = async (email: string, password: string) => {
    setLoading(true);
    setSessionError(null);
    try {
      const response = await api.post<any>('auth/admin/login', { email, password });
      if (response.success && response.data) {
        const { accessToken, admin: adminData } = response.data;
        localStorage.setItem('admin_access_token', accessToken);
        localStorage.setItem('admin_user', JSON.stringify(adminData));
        setAdmin(adminData);
      } else {
        throw new Error(response.message || 'Login failed');
      }
    } finally {
      setLoading(false);
    }
  };

  const logout = async () => {
    setLoading(true);
    try {
      await api.post('auth/logout');
    } catch (e) {
      console.warn('Server logout failed or token already invalid:', e);
    } finally {
      localStorage.removeItem('admin_access_token');
      localStorage.removeItem('admin_user');
      setAdmin(null);
      setSessionError(null);
      setLoading(false);
    }
  };

  return (
    <AuthContext.Provider value={{ admin, loading, login, logout, sessionError, clearSessionError }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
