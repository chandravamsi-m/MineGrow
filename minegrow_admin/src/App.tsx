import React, { useState } from 'react';
import { AuthProvider, useAuth } from './context/AuthContext';
import { Sidebar } from './components/Sidebar';
import { Dashboard } from './components/Dashboard';
import { UsersList } from './components/UsersList';
import { DepositsQueue } from './components/DepositsQueue';
import { WithdrawalsQueue } from './components/WithdrawalsQueue';
import { PlansManager } from './components/PlansManager';
import { LedgerViewer } from './components/LedgerViewer';
import { Sparkles, Mail, Lock, ShieldAlert, CheckCircle, ArrowRight, Loader2, Eye, EyeOff, Menu } from 'lucide-react';


const MainAppContent: React.FC = () => {
  const { admin, loading, login } = useAuth();
  const [activeTab, setActiveTab] = useState('dashboard');
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  
  // Login form states
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loginLoading, setLoginLoading] = useState(false);
  const [loginError, setLoginError] = useState<string | null>(null);

  // Seeding states
  const [seedStatus, setSeedStatus] = useState<{ success: boolean; message: string } | null>(null);
  const [seedingLoading, setSeedingLoading] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) return;
    
    setLoginLoading(true);
    setLoginError(null);
    try {
      await login(email, password);
    } catch (err: any) {
      setLoginError(err.message || 'Invalid administrative credentials');
    } finally {
      setLoginLoading(false);
    }
  };

  const handleSeedAdmin = async () => {
    if (!window.confirm('Do you want to seed the default system super admin? This will trigger the auth/admin/seed endpoint using the default bootstrap security key.')) {
      return;
    }

    setSeedingLoading(true);
    setSeedStatus(null);
    try {
      const response = await fetch('http://localhost:3000/api/v1/auth/admin/seed', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-seed-secret': 'admin-bootstrap-secret-999',
        },
        body: JSON.stringify({
          email: 'admin@minegrow.com',
          password: 'adminpassword123',
        }),
      });

      const payload = await response.json();
      if (response.ok && payload.success) {
        setSeedStatus({
          success: true,
          message: 'Super Admin seeded! Login with: admin@minegrow.com / adminpassword123',
        });
        setEmail('admin@minegrow.com');
        setPassword('adminpassword123');
      } else {
        const errorMsg = payload?.error?.message || payload?.message || 'Seeding rejected (Admin may already exist)';
        setSeedStatus({
          success: false,
          message: errorMsg,
        });
      }
    } catch (err: any) {
      setSeedStatus({
        success: false,
        message: err.message || 'Server connection failed',
      });
    } finally {
      setSeedingLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen bg-slate-950 text-slate-100">
        <Loader2 className="w-10 h-10 animate-spin text-indigo-500 mb-4" />
        <span className="text-sm font-semibold uppercase tracking-wider text-slate-400">Loading Session Cache...</span>
      </div>
    );
  }

  // Not logged in: Show premium glassmorphic login card
  if (!admin) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4 relative overflow-hidden bg-slate-950">
        {/* Glow decoration circles */}
        <div className="absolute top-1/4 left-1/4 w-96 h-96 rounded-full bg-indigo-500/10 blur-3xl pointer-events-none animate-pulse"></div>
        <div className="absolute bottom-1/4 right-1/4 w-96 h-96 rounded-full bg-purple-500/10 blur-3xl pointer-events-none animate-pulse"></div>

        <div className="w-full max-w-md glass-panel p-8 rounded-3xl shadow-2xl relative border border-slate-800/80 space-y-8 animate-fadeIn">
          {/* Logo brand */}
          <div className="text-center space-y-3">
            <div className="mx-auto w-12 h-12 rounded-2xl bg-gradient-to-tr from-indigo-500 to-purple-600 flex items-center justify-center shadow-lg shadow-indigo-500/20">
              <Sparkles className="w-6 h-6 text-white animate-pulse" />
            </div>
            <div>
              <h2 className="text-2xl font-bold bg-gradient-to-r from-white via-slate-100 to-indigo-400 bg-clip-text text-transparent">
                MineGrow Control Center
              </h2>
              <p className="text-slate-500 text-xs mt-1">Authorized administrator dashboard credentials required.</p>
            </div>
          </div>

          {/* Form */}
          <form onSubmit={handleLogin} className="space-y-5">
            {loginError && (
              <div className="p-3.5 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 flex items-center space-x-2 text-xs">
                <ShieldAlert className="w-4 h-4 flex-shrink-0" />
                <span>{loginError}</span>
              </div>
            )}

            <div className="space-y-1.5">
              <label className="text-[10px] text-slate-500 uppercase tracking-wider font-semibold">Admin Email Address</label>
              <div className="relative">
                <Mail className="w-4 h-4 text-slate-500 absolute left-3 top-3.5" />
                <input
                  type="email"
                  placeholder="admin@minegrow.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full bg-slate-900 border border-slate-800 rounded-xl py-3 pl-10 pr-4 text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-indigo-500/40"
                  required
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <label className="text-[10px] text-slate-500 uppercase tracking-wider font-semibold">Security Access Key</label>
              <div className="relative">
                <Lock className="w-4 h-4 text-slate-500 absolute left-3 top-3.5" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  placeholder="••••••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full bg-slate-900 border border-slate-800 rounded-xl py-3 pl-10 pr-10 text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-indigo-500/40"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-3 text-slate-500 hover:text-slate-300 transition-colors duration-200 cursor-pointer"
                  tabIndex={-1}
                >
                  {showPassword ? (
                    <EyeOff className="w-4 h-4" />
                  ) : (
                    <Eye className="w-4 h-4" />
                  )}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loginLoading}
              className="w-full flex items-center justify-center space-x-2 py-3.5 bg-gradient-to-r from-indigo-600 to-indigo-500 hover:from-indigo-500 hover:to-indigo-400 text-white rounded-xl font-semibold text-xs tracking-wider transition-all duration-300 shadow-lg shadow-indigo-600/10 hover:scale-[1.02] cursor-pointer"
            >
              <span>{loginLoading ? 'Authenticating access...' : 'Access Dashboard'}</span>
              <ArrowRight className="w-4 h-4 text-white" />
            </button>
          </form>

          {/* Quick-Seed Block */}
          <div className="border-t border-slate-800/80 pt-6 space-y-4">
            <div className="flex flex-col text-center space-y-1 text-[11px] text-slate-500">
              <span className="font-semibold text-slate-400">First Time Setup Seeding</span>
              <span>Need to bootstrap the DB super admin credentials?</span>
            </div>

            <button
              onClick={handleSeedAdmin}
              disabled={seedingLoading}
              className="w-full flex items-center justify-center space-x-1.5 py-2.5 rounded-xl border border-dashed border-indigo-500/30 hover:border-indigo-500/60 bg-indigo-500/5 hover:bg-indigo-500/10 text-indigo-400 text-[10px] font-bold tracking-wider uppercase transition-all duration-300 cursor-pointer"
            >
              <span>{seedingLoading ? 'Generating Admin Account...' : 'Bootstrap First Super Admin'}</span>
            </button>

            {seedStatus && (
              <div className={`p-3 rounded-xl flex items-start space-x-2 border text-[10px] leading-relaxed ${
                seedStatus.success
                  ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400'
                  : 'bg-rose-500/10 border-rose-500/20 text-rose-400'
              }`}>
                {seedStatus.success ? (
                  <CheckCircle className="w-3.5 h-3.5 flex-shrink-0 mt-0.5" />
                ) : (
                  <ShieldAlert className="w-3.5 h-3.5 flex-shrink-0 mt-0.5" />
                )}
                <span>{seedStatus.message}</span>
              </div>
            )}
          </div>
        </div>
      </div>
    );
  }

  // Logged in layout
  const renderTabContent = () => {
    switch (activeTab) {
      case 'dashboard':
        return <Dashboard />;
      case 'users':
        return <UsersList />;
      case 'deposits':
        return <DepositsQueue />;
      case 'withdrawals':
        return <WithdrawalsQueue />;
      case 'plans':
        return <PlansManager />;
      case 'ledger':
        return <LedgerViewer />;
      default:
        return <Dashboard />;
    }
  };

  return (
    <div className="min-h-screen lg:pl-64 bg-slate-950 text-slate-100 flex flex-col">
      {/* Mobile Top Header */}
      <header className="lg:hidden flex items-center justify-between p-4 bg-slate-950/80 border-b border-slate-800/80 sticky top-0 z-30 backdrop-blur-md">
        <div className="flex items-center space-x-3">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-tr from-indigo-500 to-purple-600 flex items-center justify-center">
            <Sparkles className="w-4 h-4 text-white" />
          </div>
          <span className="font-bold text-base text-white tracking-tight">MineGrow</span>
        </div>
        <button
          onClick={() => setIsSidebarOpen(true)}
          className="p-2 text-slate-400 hover:text-white hover:bg-slate-800/40 rounded-lg transition-colors cursor-pointer"
        >
          <Menu className="w-6 h-6" />
        </button>
      </header>

      {/* Sidebar Backdrop for Mobile */}
      {isSidebarOpen && (
        <div 
          className="fixed inset-0 bg-slate-950/60 backdrop-blur-sm z-40 lg:hidden"
          onClick={() => setIsSidebarOpen(false)}
        />
      )}

      <Sidebar 
        activeTab={activeTab} 
        setActiveTab={setActiveTab} 
        isOpen={isSidebarOpen}
        onClose={() => setIsSidebarOpen(false)}
      />
      <main className="flex-1 p-6 md:p-10 max-w-7xl mx-auto w-full space-y-6">
        {renderTabContent()}
      </main>
    </div>
  );
};

export default function App() {
  return (
    <AuthProvider>
      <MainAppContent />
    </AuthProvider>
  );
}
