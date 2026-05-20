import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import {
  Sliders,
  Check,
  AlertCircle,
  Loader2,
  Percent,
  Lock,
  Layers,
  Edit3,
} from 'lucide-react';

interface InvestmentPlan {
  id: number;
  plan_name: string;
  min_amount: number;
  max_amount: number;
  daily_roi_pct: number;
  lock_days: number;
  roi_withdraw_days: number;
  is_active: boolean;
  updated_at: string;
}

export const PlansManager: React.FC = () => {
  const [plans, setPlans] = useState<InvestmentPlan[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Selected plan for inline updates editing
  const [editingPlan, setEditingPlan] = useState<InvestmentPlan | null>(null);
  const [editForm, setEditForm] = useState<Partial<InvestmentPlan>>({});
  const [actionLoading, setActionLoading] = useState(false);

  const fetchPlans = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await api.get<any>('admin/plans');
      if (response.success && response.data) {
        setPlans(response.data);
      } else {
        throw new Error(response.message || 'Failed to retrieve plans metadata');
      }
    } catch (e: any) {
      setError(e.message || 'Error occurred listing plans');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPlans();
  }, []);

  const handleStartEdit = (plan: InvestmentPlan) => {
    setEditingPlan(plan);
    setEditForm({ ...plan });
  };

  const handleCancelEdit = () => {
    setEditingPlan(null);
    setEditForm({});
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    const isNum = ['min_amount', 'max_amount', 'daily_roi_pct', 'lock_days', 'roi_withdraw_days'].includes(name);
    
    setEditForm({
      ...editForm,
      [name]: isNum ? parseFloat(value) || 0 : value,
    });
  };

  const savePlanChanges = async (id: number) => {
    if (!window.confirm('Are you sure you want to save limit and ROI changes to this plan? This updates constraints for all future client agreements immediately.')) {
      return;
    }
    
    setActionLoading(true);
    try {
      // Build clean DTO matching backend class-validator constraints
      const dto = {
        planName: editForm.plan_name,
        minAmount: editForm.min_amount,
        maxAmount: editForm.max_amount,
        dailyRoiPct: editForm.daily_roi_pct,
        lockDays: editForm.lock_days,
        roiWithdrawDays: editForm.roi_withdraw_days,
      };
      
      const response = await api.put<any>(`admin/plans/${id}`, dto);
      if (response.success) {
        alert('Plan parameters updated successfully');
        setEditingPlan(null);
        setEditForm({});
        fetchPlans();
      } else {
        alert(response.message || 'Plan parameter update failed');
      }
    } catch (e: any) {
      alert(e.message || 'Error occurred saving plan parameters');
    } finally {
      setActionLoading(false);
    }
  };

  const togglePlanState = async (id: number, currentActive: boolean) => {
    const actionWord = currentActive ? 'DEACTIVATE' : 'ACTIVATE';
    if (!window.confirm(`Are you sure you want to ${actionWord} this investment plan?`)) {
      return;
    }
    
    setActionLoading(true);
    try {
      const response = await api.patch<any>(`admin/plans/${id}/toggle`);
      if (response.success) {
        alert(`Plan toggled successfully`);
        fetchPlans();
      } else {
        alert(response.message || 'Toggling plan state failed');
      }
    } catch (e: any) {
      alert(e.message || 'Error occurred toggling plan state');
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div className="space-y-6 animate-fadeIn relative">
      <div>
        <h2 className="text-3xl font-extrabold text-white tracking-tight">Investment Plans Manager</h2>
        <p className="text-slate-400 text-sm mt-1">Adjust daily interest yield margins, lockup maturities, limits, and active toggle structures.</p>
      </div>

      {error && (
        <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 flex items-center space-x-3 text-sm">
          <AlertCircle className="w-5 h-5 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center py-24">
          <Loader2 className="w-10 h-10 animate-spin text-indigo-500" />
        </div>
      ) : (
        <div className="grid grid-cols-1 xl:grid-cols-3 gap-6 items-start">
          {/* Main cards grid */}
          <div className="xl:col-span-2 space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {plans.map((plan) => (
                <div
                  key={plan.id}
                  className={`glass-panel p-6 rounded-2xl border transition-all duration-300 relative overflow-hidden flex flex-col justify-between ${
                    editingPlan?.id === plan.id
                      ? 'border-indigo-500 shadow-[0_0_25px_rgba(99,102,241,0.15)] bg-slate-900/80'
                      : plan.is_active
                      ? 'border-slate-800 hover:border-slate-700/80'
                      : 'border-slate-800 opacity-60'
                  }`}
                >
                  {/* Decorative background circle */}
                  <div className="absolute -right-6 -top-6 w-24 h-24 rounded-full bg-indigo-500/5 blur-xl pointer-events-none"></div>

                  <div className="space-y-4">
                    {/* Header */}
                    <div className="flex justify-between items-start border-b border-slate-800 pb-3">
                      <div>
                        <h4 className="text-lg font-bold text-white leading-snug">{plan.plan_name}</h4>
                        <span className="text-[10px] text-slate-500">Plan Code: PLAN-{plan.id}</span>
                      </div>
                      <span className={`text-[10px] font-bold tracking-wider px-2 py-0.5 rounded ${
                        plan.is_active ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-slate-800 text-slate-500'
                      }`}>
                        {plan.is_active ? 'ACTIVE' : 'INACTIVE'}
                      </span>
                    </div>

                    {/* Stats details */}
                    <div className="grid grid-cols-2 gap-4 text-xs">
                      <div className="bg-slate-950/40 p-2.5 rounded-xl border border-slate-800/40">
                        <span className="text-slate-500 block mb-1">Yield Daily:</span>
                        <div className="flex items-center text-slate-200 font-bold">
                          <Percent className="w-3.5 h-3.5 mr-0.5 text-indigo-400" />
                          <span>{plan.daily_roi_pct}%</span>
                        </div>
                      </div>

                      <div className="bg-slate-950/40 p-2.5 rounded-xl border border-slate-800/40">
                        <span className="text-slate-500 block mb-1">Maturity Days:</span>
                        <div className="flex items-center text-slate-200 font-bold">
                          <Lock className="w-3.5 h-3.5 mr-0.5 text-slate-400" />
                          <span>{plan.lock_days} Days</span>
                        </div>
                      </div>

                      <div className="col-span-2 bg-slate-950/40 p-3 rounded-xl border border-slate-800/40 flex justify-between items-center">
                        <div>
                          <span className="text-slate-500 block mb-0.5">Capital Bounds:</span>
                          <span className="text-slate-200 font-semibold">
                            ₹{plan.min_amount.toLocaleString()} - ₹{plan.max_amount.toLocaleString()}
                          </span>
                        </div>
                        <Layers className="w-4 h-4 text-slate-600" />
                      </div>
                    </div>
                  </div>

                  {/* Actions footer */}
                  <div className="mt-6 flex space-x-3 pt-4 border-t border-slate-800/50">
                    <button
                      onClick={() => handleStartEdit(plan)}
                      className="flex-1 flex items-center justify-center space-x-1.5 py-2.5 rounded-xl border border-slate-800 hover:bg-slate-800 text-slate-300 text-xs font-semibold transition-all duration-300 cursor-pointer"
                    >
                      <Edit3 className="w-3.5 h-3.5 text-indigo-400" />
                      <span>Adjust Parameters</span>
                    </button>
                    
                    <button
                      onClick={() => togglePlanState(plan.id, plan.is_active)}
                      disabled={actionLoading}
                      className={`px-3 py-2 rounded-xl text-xs font-semibold cursor-pointer border transition-all duration-300 ${
                        plan.is_active
                          ? 'border-rose-500/20 hover:bg-rose-500/10 text-rose-400'
                          : 'border-emerald-500/20 hover:bg-emerald-500/10 text-emerald-400'
                      }`}
                    >
                      {plan.is_active ? 'Deactivate' : 'Activate'}
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Configuration panel edit drawer */}
          <div className="xl:col-span-1 glass-panel rounded-2xl p-6 shadow-2xl h-full space-y-6">
            <div className="flex items-center space-x-2 border-b border-slate-800 pb-4">
              <Sliders className="w-5 h-5 text-indigo-400" />
              <h4 className="text-lg font-bold text-slate-100">Adjustment Desk</h4>
            </div>

            {!editingPlan ? (
              <div className="text-center py-16 text-slate-500 text-sm">
                Select "Adjust Parameters" on an investment tier card to open limit modifications, ROI yielding scales, and maturity adjustments.
              </div>
            ) : (
              <div className="space-y-4 animate-fadeIn">
                <div className="bg-slate-950/40 rounded-xl p-4 border border-slate-800 space-y-1">
                  <span className="font-mono text-[9px] text-indigo-400 font-bold">ADJUSTMENT DRAFT</span>
                  <h5 className="text-sm font-bold text-slate-200">Adjusting: {editingPlan.plan_name}</h5>
                </div>

                {/* Form fields */}
                <div className="space-y-4 text-xs">
                  <div className="space-y-1">
                    <label className="text-slate-500 font-semibold uppercase tracking-wider block">Plan Display Name</label>
                    <input
                      type="text"
                      name="plan_name"
                      value={editForm.plan_name || ''}
                      onChange={handleInputChange}
                      className="w-full bg-slate-900 border border-slate-800 rounded-lg p-2.5 text-slate-100 focus:outline-none focus:border-indigo-500/40"
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div className="space-y-1">
                      <label className="text-slate-500 font-semibold uppercase tracking-wider block">Min Capital (₹)</label>
                      <input
                        type="number"
                        name="min_amount"
                        value={editForm.min_amount || 0}
                        onChange={handleInputChange}
                        className="w-full bg-slate-900 border border-slate-800 rounded-lg p-2.5 text-slate-100 focus:outline-none focus:border-indigo-500/40"
                      />
                    </div>
                    <div className="space-y-1">
                      <label className="text-slate-500 font-semibold uppercase tracking-wider block">Max Capital (₹)</label>
                      <input
                        type="number"
                        name="max_amount"
                        value={editForm.max_amount || 0}
                        onChange={handleInputChange}
                        className="w-full bg-slate-900 border border-slate-800 rounded-lg p-2.5 text-slate-100 focus:outline-none focus:border-indigo-500/40"
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div className="space-y-1">
                      <label className="text-slate-500 font-semibold uppercase tracking-wider block">Daily ROI %</label>
                      <input
                        type="number"
                        step="0.01"
                        name="daily_roi_pct"
                        value={editForm.daily_roi_pct || 0}
                        onChange={handleInputChange}
                        className="w-full bg-slate-900 border border-slate-800 rounded-lg p-2.5 text-slate-100 focus:outline-none focus:border-indigo-500/40"
                      />
                    </div>
                    <div className="space-y-1">
                      <label className="text-slate-500 font-semibold uppercase tracking-wider block">Lock Maturity (Days)</label>
                      <input
                        type="number"
                        name="lock_days"
                        value={editForm.lock_days || 0}
                        onChange={handleInputChange}
                        className="w-full bg-slate-900 border border-slate-800 rounded-lg p-2.5 text-slate-100 focus:outline-none focus:border-indigo-500/40"
                      />
                    </div>
                  </div>

                  <div className="space-y-1">
                    <label className="text-slate-500 font-semibold uppercase tracking-wider block">Interest Yield Withdrawal Cycle (Days)</label>
                    <input
                      type="number"
                      name="roi_withdraw_days"
                      value={editForm.roi_withdraw_days || 0}
                      onChange={handleInputChange}
                      className="w-full bg-slate-900 border border-slate-800 rounded-lg p-2.5 text-slate-100 focus:outline-none focus:border-indigo-500/40"
                    />
                  </div>
                </div>

                {/* Form Actions */}
                <div className="flex space-x-3 pt-4 border-t border-slate-800/60">
                  <button
                    onClick={() => savePlanChanges(editingPlan.id)}
                    disabled={actionLoading}
                    className="flex-1 flex items-center justify-center space-x-1 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold cursor-pointer shadow-lg shadow-indigo-600/10"
                  >
                    <Check className="w-4 h-4" />
                    <span>Save Blueprint</span>
                  </button>
                  <button
                    onClick={handleCancelEdit}
                    className="px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold cursor-pointer"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
