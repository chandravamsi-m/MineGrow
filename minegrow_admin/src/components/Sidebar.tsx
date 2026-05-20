import React from 'react';
import { useAuth } from '../context/AuthContext';
import {
  LayoutDashboard,
  Users as UsersIcon,
  ArrowDownCircle,
  ArrowUpCircle,
  Sliders,
  BookOpen,
  LogOut,
  Sparkles,
} from 'lucide-react';

interface SidebarProps {
  activeTab: string;
  setActiveTab: (tab: string) => void;
}

export const Sidebar: React.FC<SidebarProps> = ({ activeTab, setActiveTab }) => {
  const { admin, logout } = useAuth();

  const navigationItems = [
    { id: 'dashboard', name: 'Dashboard', icon: LayoutDashboard },
    { id: 'users', name: 'Users & KYC', icon: UsersIcon },
    { id: 'deposits', name: 'Deposit Approvals', icon: ArrowDownCircle },
    { id: 'withdrawals', name: 'Withdrawal Flow', icon: ArrowUpCircle },
    { id: 'plans', name: 'Investment Plans', icon: Sliders },
    { id: 'ledger', name: 'System Ledger', icon: BookOpen },
  ];

  return (
    <aside className="w-64 glass-panel border-r border-slate-800 flex flex-col h-screen fixed left-0 top-0 z-20">
      {/* Brand Header */}
      <div className="p-6 border-b border-slate-800 flex items-center space-x-3">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-500 to-purple-600 flex items-center justify-center shadow-lg shadow-indigo-500/20">
          <Sparkles className="w-5 h-5 text-white animate-pulse" />
        </div>
        <div>
          <h1 className="text-xl font-bold bg-gradient-to-r from-white via-slate-100 to-indigo-400 bg-clip-text text-transparent leading-none">
            MineGrow
          </h1>
          <span className="text-[10px] tracking-wider text-indigo-400 font-bold uppercase mt-1 block">
            Control Center
          </span>
        </div>
      </div>

      {/* Nav List */}
      <nav className="flex-1 px-4 py-6 space-y-2 overflow-y-auto custom-scrollbar">
        {navigationItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              className={`w-full flex items-center space-x-3 px-4 py-3 rounded-xl transition-all duration-300 group ${
                isActive
                  ? 'bg-gradient-to-r from-indigo-600/20 to-purple-600/20 text-indigo-300 border-l-4 border-indigo-500 shadow-md font-medium'
                  : 'text-slate-400 hover:text-slate-100 hover:bg-slate-800/40 border-l-4 border-transparent'
              }`}
            >
              <Icon
                className={`w-5 h-5 transition-transform duration-300 group-hover:scale-110 ${
                  isActive ? 'text-indigo-400' : 'text-slate-400 group-hover:text-slate-300'
                }`}
              />
              <span className="text-sm">{item.name}</span>
            </button>
          );
        })}
      </nav>

      {/* Admin Profile Details */}
      <div className="p-4 border-t border-slate-800 bg-slate-900/40">
        <div className="flex items-center space-x-3 mb-4">
          <div className="w-9 h-9 rounded-full bg-slate-800 border border-slate-700 flex items-center justify-center text-sm font-semibold text-indigo-400">
            {admin?.fullName?.charAt(0) || 'A'}
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-xs font-semibold text-slate-200 truncate">
              {admin?.fullName}
            </p>
            <p className="text-[10px] text-slate-500 truncate">
              {admin?.email}
            </p>
          </div>
        </div>
        
        <button
          onClick={logout}
          className="w-full flex items-center justify-center space-x-2 px-4 py-2.5 rounded-lg border border-rose-500/20 bg-rose-500/5 hover:bg-rose-500/10 text-rose-400 text-xs font-semibold transition-all duration-300 cursor-pointer"
        >
          <LogOut className="w-3.5 h-3.5" />
          <span>Terminate Session</span>
        </button>
      </div>
    </aside>
  );
};
