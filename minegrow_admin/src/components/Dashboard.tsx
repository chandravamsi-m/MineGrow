import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import { useToast } from '../context/ToastContext';
import { useConfirm } from '../context/ConfirmContext';
import {
  Users,
  TrendingUp,
  CreditCard,
  Briefcase,
  Play,
  Activity,
  AlertCircle,
  CheckCircle2,
  Calendar,
} from 'lucide-react';

interface DashboardStats {
  totalActiveUsers: number;
  totalActiveInvestments: number;
  totalFundsDeposited: number;
  totalFundsWithdrawn: number;
  pendingDepositApprovalsCount: number;
  pendingWithdrawalRequestsCount: number;
  activePrincipalLockSum: number;
  totalDailyRoiDistributed: number;
}

export const Dashboard: React.FC = () => {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [roiTriggering, setRoiTriggering] = useState(false);
  const [roiStatus, setRoiStatus] = useState<{ success: boolean; message: string } | null>(null);
  const toast = useToast();
  const confirm = useConfirm();

  const fetchStats = async () => {
    try {
      setError(null);
      const response = await api.get<any>('admin/reports/dashboard');
      if (response.success && response.data) {
        setStats(response.data);
      } else {
        throw new Error(response.message || 'Failed to fetch dashboard statistics');
      }
    } catch (e: any) {
      setError(e.message || 'Network error fetching stats');
      toast.error(e.message || 'Failed to sync system statistics dashboard');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();
  }, []);

  const triggerDailyRoi = () => {
    confirm({
      title: 'Manual Interest Payout Process',
      message: 'Are you sure you want to trigger the daily ROI interest payout manually? This will process interest generation for all active maturity investments.',
      confirmText: 'Run Payout Script',
      type: 'warning',
      onConfirm: async () => {
        setRoiTriggering(true);
        setRoiStatus(null);
        try {
          const response = await api.post<any>('admin/roi/trigger');
          if (response.success) {
            const msg = response.message || response.data?.message || 'Daily interest payout completed successfully!';
            setRoiStatus({
              success: true,
              message: msg,
            });
            toast.success(msg);
            // Reload statistics to see updated totals
            fetchStats();
          } else {
            throw new Error(response.message || 'ROI processing routine failed');
          }
        } catch (e: any) {
          const errorMsg = e.message || 'Error occurred executing ROI script';
          setRoiStatus({
            success: false,
            message: errorMsg,
          });
          toast.error(errorMsg);
        } finally {
          setRoiTriggering(false);
        }
      }
    });
  };

  if (loading) {
    return (
      <div className="space-y-8 animate-pulse">
        {/* Header skeleton */}
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center space-y-4 md:space-y-0">
          <div className="space-y-2">
            <div className="h-8 bg-slate-900 rounded-xl w-48"></div>
            <div className="h-4 bg-slate-900/60 rounded-xl w-72"></div>
          </div>
          <div className="h-10 bg-slate-900 rounded-lg w-48 hidden md:block"></div>
        </div>

        {/* Stats Grid skeleton */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {Array.from({ length: 8 }).map((_, idx) => (
            <div key={idx} className="h-32 bg-slate-900/60 border border-slate-900/80 rounded-2xl p-6 space-y-4">
              <div className="flex justify-between items-start">
                <div className="h-4 bg-slate-800 rounded w-24"></div>
                <div className="h-8 bg-slate-800 rounded-lg w-8"></div>
              </div>
              <div className="h-8 bg-slate-800 rounded w-16 animate-pulse"></div>
            </div>
          ))}
        </div>

        {/* ROI manual panel skeleton */}
        <div className="h-48 bg-slate-900/40 border border-slate-900/60 rounded-2xl p-6"></div>
      </div>
    );
  }

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Header Banner */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center space-y-4 md:space-y-0">
        <div>
          <h2 className="text-3xl font-extrabold text-white tracking-tight">System Overview</h2>
          <p className="text-slate-400 text-sm mt-1">Real-time health, user analytics, and investment ledger balances.</p>
        </div>
        <div className="flex items-center space-x-2 text-xs bg-slate-900/60 border border-slate-800/80 px-4 py-2 rounded-xl text-slate-400">
          <Calendar className="w-4 h-4 text-indigo-400" />
          <span>Server Time: {new Date().toLocaleDateString(undefined, { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</span>
        </div>
      </div>

      {error && (
        <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 flex items-center space-x-3 text-sm">
          <AlertCircle className="w-5 h-5 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {/* User Card */}
        <div className="glass-card p-6 rounded-2xl flex items-center space-x-4">
          <div className="p-3 bg-blue-500/10 border border-blue-500/20 rounded-xl text-blue-400">
            <Users className="w-6 h-6" />
          </div>
          <div>
            <p className="text-slate-500 text-xs font-semibold uppercase tracking-wider">Active Members</p>
            <h3 className="text-2xl font-bold text-slate-100 mt-1">{stats?.totalActiveUsers || 0}</h3>
            <span className="text-[10px] text-emerald-400 font-semibold">Active accounts</span>
          </div>
        </div>

        {/* Investments Card */}
        <div className="glass-card p-6 rounded-2xl flex items-center space-x-4">
          <div className="p-3 bg-emerald-500/10 border border-emerald-500/20 rounded-xl text-emerald-400">
            <Briefcase className="w-6 h-6" />
          </div>
          <div>
            <p className="text-slate-500 text-xs font-semibold uppercase tracking-wider">Active Deposits</p>
            <h3 className="text-2xl font-bold text-slate-100 mt-1">₹{(stats?.activePrincipalLockSum || 0).toLocaleString()}</h3>
            <span className="text-[10px] text-slate-400 font-medium">{stats?.totalActiveInvestments || 0} active agreements</span>
          </div>
        </div>

        {/* System Ledger Principal */}
        <div className="glass-card p-6 rounded-2xl flex items-center space-x-4">
          <div className="p-3 bg-purple-500/10 border border-purple-500/20 rounded-xl text-purple-400">
            <TrendingUp className="w-6 h-6" />
          </div>
          <div>
            <p className="text-slate-500 text-xs font-semibold uppercase tracking-wider">Total Deposited</p>
            <h3 className="text-2xl font-bold text-slate-100 mt-1">₹{(stats?.totalFundsDeposited || 0).toLocaleString()}</h3>
            <span className="text-[10px] text-slate-400 font-medium">Cumulative capital</span>
          </div>
        </div>

        {/* System Ledger ROI Payouts */}
        <div className="glass-card p-6 rounded-2xl flex items-center space-x-4">
          <div className="p-3 bg-amber-500/10 border border-amber-500/20 rounded-xl text-amber-400">
            <CreditCard className="w-6 h-6" />
          </div>
          <div>
            <p className="text-slate-500 text-xs font-semibold uppercase tracking-wider">ROI Distributed</p>
            <h3 className="text-2xl font-bold text-slate-100 mt-1">₹{(stats?.totalDailyRoiDistributed || 0).toLocaleString()}</h3>
            <span className="text-[10px] text-amber-400 font-semibold">Total interest paid</span>
          </div>
        </div>
      </div>

      {/* Action panel & Cron controllers */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Core Trigger Center */}
        <div className="lg:col-span-2 glass-panel p-6 rounded-2xl space-y-6">
          <div className="flex items-center space-x-3 border-b border-slate-800 pb-4">
            <Activity className="w-5 h-5 text-indigo-400" />
            <h4 className="text-lg font-bold text-slate-100">Manual Interest Engine</h4>
          </div>

          <p className="text-slate-400 text-sm leading-relaxed">
            The MineGrow service generates daily interest payouts to active investments through automatic cron engine tasks. However, in cases of service interruption or testing, admins can manually command an immediate ROI ledger accrual sequence.
          </p>

          <div className="bg-slate-950/60 rounded-xl p-4 border border-slate-800 space-y-2">
            <span className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold">Pre-conditions for Execution</span>
            <ul className="text-xs text-slate-400 space-y-1 list-disc list-inside">
              <li>Users must have an active investment plan (Starter, Silver, Gold).</li>
              <li>Interest is calculated based on daily ROI percentage from plan metadata.</li>
              <li>Ledger records are created under Double Entry book-keeping rules.</li>
            </ul>
          </div>

          <div className="flex flex-col sm:flex-row items-center sm:space-x-4 space-y-4 sm:space-y-0 pt-2">
            <button
              onClick={triggerDailyRoi}
              disabled={roiTriggering}
              className={`w-full sm:w-auto flex items-center justify-center space-x-2 px-6 py-3.5 rounded-xl text-white font-semibold shadow-lg shadow-indigo-600/20 bg-indigo-600 hover:bg-indigo-500 active:scale-95 transition-all duration-300 ${
                roiTriggering ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'
              }`}
            >
              <Play className="w-4 h-4 fill-white animate-pulse" />
              <span>{roiTriggering ? 'Executing Payout Routine...' : 'Trigger Daily ROI Payout'}</span>
            </button>
            
            {roiTriggering && (
              <span className="text-xs text-indigo-400 animate-pulse font-medium">Processing database ledger accounts...</span>
            )}
          </div>

          {/* Success / Error Logs */}
          {roiStatus && (
            <div className={`p-4 rounded-xl flex items-start space-x-3 text-sm border ${
              roiStatus.success 
                ? 'bg-emerald-500/10 border-emerald-500/25 text-emerald-400' 
                : 'bg-rose-500/10 border-rose-500/25 text-rose-400'
            }`}>
              {roiStatus.success ? (
                <CheckCircle2 className="w-5 h-5 flex-shrink-0 mt-0.5" />
              ) : (
                <AlertCircle className="w-5 h-5 flex-shrink-0 mt-0.5" />
              )}
              <div className="flex-1">
                <p className="font-semibold">{roiStatus.success ? 'Engine Run Completed' : 'Engine Execution Error'}</p>
                <p className="text-xs opacity-90 mt-1 leading-relaxed">{roiStatus.message}</p>
              </div>
            </div>
          )}
        </div>

        {/* Action Required Quick List */}
        <div className="glass-panel p-6 rounded-2xl flex flex-col justify-between">
          <div>
            <div className="flex items-center space-x-3 border-b border-slate-800 pb-4 mb-4">
              <Activity className="w-5 h-5 text-amber-400" />
              <h4 className="text-lg font-bold text-slate-100">Tasks Queue</h4>
            </div>

            <div className="space-y-4">
              <div className="flex justify-between items-center p-3 bg-slate-900/40 rounded-xl border border-slate-800/50">
                <span className="text-xs text-slate-400 font-medium">Pending Deposits Review</span>
                <span className={`text-xs px-2.5 py-1 rounded-full font-bold ${
                  (stats?.pendingDepositApprovalsCount || 0) > 0 
                    ? 'bg-amber-500/10 text-amber-400 border border-amber-500/20 animate-pulse' 
                    : 'bg-slate-800 text-slate-500'
                }`}>
                  {stats?.pendingDepositApprovalsCount || 0}
                </span>
              </div>

              <div className="flex justify-between items-center p-3 bg-slate-900/40 rounded-xl border border-slate-800/50">
                <span className="text-xs text-slate-400 font-medium">Pending Withdrawals Queue</span>
                <span className={`text-xs px-2.5 py-1 rounded-full font-bold ${
                  (stats?.pendingWithdrawalRequestsCount || 0) > 0 
                    ? 'bg-rose-500/10 text-rose-400 border border-rose-500/20' 
                    : 'bg-slate-800 text-slate-500'
                }`}>
                  {stats?.pendingWithdrawalRequestsCount || 0}
                </span>
              </div>
            </div>
          </div>

          <div className="mt-8 text-[11px] text-slate-500 leading-normal border-t border-slate-800/50 pt-4">
            <span className="font-semibold text-slate-400">Security Warning:</span> Database schema connections require authorized administrative roles. Do not share session key details.
          </div>
        </div>
      </div>
    </div>
  );
};
