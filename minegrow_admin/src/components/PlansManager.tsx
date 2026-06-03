import React, { useState, useEffect, useCallback } from 'react';
import { createPortal } from 'react-dom';
import { api } from '../services/api';
import { useToast } from '../context/ToastContext';
import { useConfirm } from '../context/ConfirmContext';
import {
  Sliders,
  Check,
  AlertCircle,
  Percent,
  Lock,
  Layers,
  Edit3,
  Plus,
  Trash2,
  Upload,
  X
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
  image_url?: string;
  updated_at: string;
}

export const PlansManager: React.FC = () => {
  const [plans, setPlans] = useState<InvestmentPlan[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const toast = useToast();
  const confirm = useConfirm();

  // Modal editing plan state (id === 0 means creating new plan, null means modal is closed)
  const [editingPlan, setEditingPlan] = useState<InvestmentPlan | null>(null);
  const [editForm, setEditForm] = useState<Partial<InvestmentPlan>>({});
  const [actionLoading, setActionLoading] = useState(false);
  const [isDragging, setIsDragging] = useState(false);

  const fetchPlans = useCallback(async () => {
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
  }, []);

  useEffect(() => {
    Promise.resolve().then(() => {
      fetchPlans();
    });
  }, [fetchPlans]);

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

  const processImageFile = (file: File) => {
    if (!file.type.startsWith('image/')) {
      toast.error('File must be a valid image format');
      return;
    }

    if (file.size > 1024 * 1024) {
      toast.error('Image size must be less than 1MB');
      return;
    }

    const reader = new FileReader();
    reader.onloadend = () => {
      setEditForm((prev) => ({
        ...prev,
        image_url: reader.result as string,
      }));
      toast.success('Plan image attached successfully');
    };
    reader.readAsDataURL(file);
  };

  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) processImageFile(file);
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = () => {
    setIsDragging(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    const file = e.dataTransfer.files?.[0];
    if (file) processImageFile(file);
  };

  const savePlanChanges = async (id: number) => {
    const isNew = id === 0;

    if (!editForm.plan_name?.trim()) {
      toast.error('Please enter a display name for this plan');
      return;
    }
    if ((editForm.min_amount || 0) <= 0 || (editForm.max_amount || 0) <= 0) {
      toast.error('Capital bounds must be positive numbers');
      return;
    }
    if ((editForm.min_amount || 0) >= (editForm.max_amount || 0)) {
      toast.error('Minimum capital bound must be less than maximum capital');
      return;
    }
    if ((editForm.daily_roi_pct || 0) <= 0) {
      toast.error('Daily yield percentage must be positive');
      return;
    }
    if ((editForm.lock_days || 0) <= 0) {
      toast.error('Lockup duration must be at least 1 day');
      return;
    }

    confirm({
      title: isNew ? 'Create New Plan' : 'Save Plan Changes',
      message: isNew
        ? 'Are you sure you want to launch this new investment plan? Clients will be able to subscribe immediately once active.'
        : 'Are you sure you want to save limit and ROI changes to this plan? This updates constraints for all future client agreements immediately.',
      confirmText: isNew ? 'Create Plan' : 'Save Changes',
      type: 'warning',
      onConfirm: async () => {
        setActionLoading(true);
        try {
          const dto = {
            planName: editForm.plan_name,
            minAmount: editForm.min_amount,
            maxAmount: editForm.max_amount,
            dailyRoiPct: editForm.daily_roi_pct,
            lockDays: editForm.lock_days,
            roiWithdrawDays: editForm.roi_withdraw_days,
            imageUrl: editForm.image_url || null,
          };

          let response;
          if (isNew) {
            response = await api.post<any>('admin/plans', dto);
          } else {
            response = await api.put<any>(`admin/plans/${id}`, dto);
          }

          if (response.success) {
            toast.success(isNew ? 'Investment plan created successfully' : 'Plan parameters updated successfully');
            setEditingPlan(null);
            setEditForm({});
            fetchPlans();
          } else {
            toast.error(response.message || 'Action failed');
          }
        } catch (e: any) {
          toast.error(e.message || 'Error occurred saving plan');
        } finally {
          setActionLoading(false);
        }
      },
    });
  };

  const deletePlan = async (id: number, name: string) => {
    confirm({
      title: 'Delete Investment Plan',
      message: `Are you sure you want to delete the plan "${name}"? This action is permanent and cannot be undone. Active investments under this plan will have their plan reference set to null.`,
      confirmText: 'Delete Plan',
      type: 'danger',
      onConfirm: async () => {
        setActionLoading(true);
        try {
          const response = await api.delete<any>(`admin/plans/${id}`);
          if (response.success) {
            toast.success('Investment plan deleted successfully');
            if (editingPlan?.id === id) {
              setEditingPlan(null);
              setEditForm({});
            }
            fetchPlans();
          } else {
            toast.error(response.message || 'Failed to delete investment plan');
          }
        } catch (e: any) {
          toast.error(e.message || 'Error occurred deleting plan');
        } finally {
          setActionLoading(false);
        }
      },
    });
  };

  const togglePlanState = async (id: number, currentActive: boolean) => {
    const actionWord = currentActive ? 'DEACTIVATE' : 'ACTIVATE';
    confirm({
      title: `${actionWord} Plan`,
      message: `Are you sure you want to ${actionWord.toLowerCase()} this investment plan?`,
      confirmText: actionWord,
      type: 'warning',
      onConfirm: async () => {
        setActionLoading(true);
        try {
          const response = await api.patch<any>(`admin/plans/${id}/toggle`);
          if (response.success) {
            toast.success(`Plan ${currentActive ? 'deactivated' : 'activated'} successfully`);
            fetchPlans();
          } else {
            toast.error(response.message || 'Toggling plan state failed');
          }
        } catch (e: any) {
          toast.error(e.message || 'Error occurred toggling plan state');
        } finally {
          setActionLoading(false);
        }
      },
    });
  };

  return (
    <div className="space-y-6 animate-fadeIn relative">
      
      {/* Top Banner and Navigation */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div className="space-y-1">
          <h2 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">Investment Plans Manager</h2>
          <p className="text-slate-400 text-xs sm:text-sm">Adjust daily interest yield margins, lockup maturities, limits, and active toggle structures.</p>
        </div>
        <button
          onClick={() => {
            const blankPlan: InvestmentPlan = {
              id: 0,
              plan_name: '',
              min_amount: 1000,
              max_amount: 100000,
              daily_roi_pct: 1.5,
              lock_days: 30,
              roi_withdraw_days: 7,
              is_active: true,
              image_url: '',
              updated_at: '',
            };
            setEditingPlan(blankPlan);
            setEditForm({ ...blankPlan });
          }}
          className="flex items-center justify-center space-x-2 w-full sm:w-auto px-4 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold cursor-pointer shadow-lg shadow-indigo-600/20 transition-all duration-300 border border-indigo-500 hover:scale-[1.01] active:scale-[0.99]"
        >
          <Plus className="w-4 h-4" />
          <span>Create New Plan</span>
        </button>
      </div>

      {error && (
        <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 flex items-center space-x-3 text-sm">
          <AlertCircle className="w-5 h-5 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {loading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-6 animate-pulse">
          {Array.from({ length: 3 }).map((_, idx) => (
            <div key={idx} className="glass-panel p-6 rounded-2xl border border-slate-800/60 flex flex-col justify-between h-[340px] relative overflow-hidden">
              <div className="space-y-5">
                {/* Header skeleton */}
                <div className="flex justify-between items-start border-b border-slate-800 pb-3">
                  <div className="flex items-center space-x-3">
                    {/* Icon placeholder */}
                    <div className="w-10 h-10 rounded-xl bg-slate-800/60 flex-shrink-0"></div>
                    <div className="space-y-2">
                      {/* Plan title placeholder */}
                      <div className="h-4 bg-slate-800/80 rounded w-24"></div>
                      {/* Plan code placeholder */}
                      <div className="h-2.5 bg-slate-800/40 rounded w-16"></div>
                    </div>
                  </div>
                  {/* Status tag placeholder */}
                  <div className="h-5 bg-slate-800/50 rounded-md w-14"></div>
                </div>

                {/* Statistics details skeleton */}
                <div className="grid grid-cols-2 gap-4">
                  <div className="bg-slate-950/20 p-2.5 rounded-xl border border-slate-800/20 space-y-2">
                    <div className="h-2 bg-slate-800/40 rounded w-12"></div>
                    <div className="h-3.5 bg-slate-800/70 rounded w-16"></div>
                  </div>

                  <div className="bg-slate-950/20 p-2.5 rounded-xl border border-slate-800/20 space-y-2">
                    <div className="h-2 bg-slate-800/40 rounded w-16"></div>
                    <div className="h-3.5 bg-slate-800/70 rounded w-12"></div>
                  </div>

                  <div className="col-span-2 bg-slate-950/20 p-3 rounded-xl border border-slate-800/20 flex justify-between items-center">
                    <div className="space-y-2 w-full">
                      <div className="h-2 bg-slate-800/40 rounded w-20"></div>
                      <div className="h-3.5 bg-slate-800/70 rounded w-2/3"></div>
                    </div>
                    <div className="w-4 h-4 bg-slate-800/40 rounded-full flex-shrink-0"></div>
                  </div>
                </div>
              </div>

              {/* Actions footer skeleton */}
              <div className="flex space-x-2 pt-4 border-t border-slate-800/50">
                <div className="flex-1 h-9 bg-slate-800/50 rounded-xl"></div>
                <div className="w-20 h-9 bg-slate-800/30 rounded-xl"></div>
                <div className="w-10 h-9 bg-slate-800/30 rounded-xl"></div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        /* Nice and Clean original Grid list */
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-6">
          {plans.map((plan) => (
            <div
              key={plan.id}
              className={`glass-panel p-6 rounded-2xl border transition-all duration-300 relative overflow-hidden flex flex-col justify-between ${
                plan.is_active
                  ? 'border-slate-800 hover:border-slate-700/80'
                  : 'border-slate-800 opacity-60 hover:opacity-85'
              }`}
            >
              {/* Soft visual background circle */}
              <div className="absolute -right-6 -top-6 w-24 h-24 rounded-full bg-indigo-500/5 blur-xl pointer-events-none"></div>

              <div className="space-y-4">
                {/* Header */}
                <div className="flex justify-between items-start border-b border-slate-800 pb-3">
                  <div className="flex items-center space-x-3">
                    {plan.image_url ? (
                      <img
                        src={plan.image_url}
                        alt=""
                        className="w-10 h-10 object-contain rounded-xl bg-slate-950/60 p-1 border border-slate-800/80 flex-shrink-0"
                      />
                    ) : (
                      <div className="w-10 h-10 rounded-xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center flex-shrink-0">
                        <Layers className="w-5 h-5 text-indigo-400" />
                      </div>
                    )}
                    <div>
                      <h4 className="text-lg font-bold text-white leading-snug">{plan.plan_name}</h4>
                      <span className="text-[10px] text-slate-500">Plan Code: PLAN-{plan.id}</span>
                    </div>
                  </div>
                  <span className={`text-[10px] font-bold tracking-wider px-2 py-0.5 rounded ${
                    plan.is_active ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-slate-800 text-slate-500'
                  }`}>
                    {plan.is_active ? 'ACTIVE' : 'INACTIVE'}
                  </span>
                </div>

                {/* Statistics details */}
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
              <div className="mt-6 flex flex-wrap sm:flex-nowrap gap-2 pt-4 border-t border-slate-800/50">
                <button
                  onClick={() => handleStartEdit(plan)}
                  className="flex-1 min-w-[140px] flex items-center justify-center space-x-1.5 py-2.5 rounded-xl border border-slate-800 hover:bg-slate-800 text-slate-300 text-xs font-semibold transition-all duration-300 cursor-pointer"
                >
                  <Edit3 className="w-3.5 h-3.5 text-indigo-400" />
                  <span>Adjust Parameters</span>
                </button>
                
                <button
                  onClick={() => togglePlanState(plan.id, plan.is_active)}
                  disabled={actionLoading}
                  className={`flex-1 sm:flex-initial min-w-[85px] px-3 py-2.5 rounded-xl text-xs font-semibold cursor-pointer border transition-all duration-300 ${
                    plan.is_active
                      ? 'border-rose-500/20 hover:bg-rose-500/10 text-rose-400'
                      : 'border-emerald-500/20 hover:bg-emerald-500/10 text-emerald-400'
                  }`}
                >
                  {plan.is_active ? 'Deactivate' : 'Activate'}
                </button>

                <button
                  onClick={() => deletePlan(plan.id, plan.plan_name)}
                  disabled={actionLoading}
                  className="px-3.5 py-2.5 rounded-xl text-xs font-semibold cursor-pointer border border-rose-500/20 hover:bg-rose-500/10 hover:border-rose-500/30 text-rose-400 transition-all duration-300"
                  title="Delete Plan"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Elegant, clean Modal overlay for creation & parameter adjustments */}
      {editingPlan && createPortal(
        <div className="fixed inset-0 z-[999] flex items-center justify-center p-4 md:p-6 overflow-y-auto">
          {/* Backdrop (light opacity overlay without heavy blur) */}
          <div 
            className="fixed inset-0 bg-slate-950/45 transition-opacity duration-300 animate-fadeIn"
            onClick={handleCancelEdit}
          />
          
          {/* Modal Content with deep shadow and hidden scrollbars */}
          <div 
            id="plans-modal-content"
            className="relative bg-slate-900/98 border border-slate-800 rounded-3xl p-5 sm:p-8 shadow-[0_25px_60px_-15px_rgba(0,0,0,0.9)] max-w-lg w-full z-10 transform transition-all duration-300 animate-scaleUp max-h-[90vh] overflow-y-auto"
            style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
          >
            <style dangerouslySetInnerHTML={{__html: `
              #plans-modal-content::-webkit-scrollbar {
                display: none !important;
              }
            `}} />
            
            {/* Modal Header */}
            <div className="flex items-center justify-between border-b border-slate-800/80 pb-4 mb-5">
              <div className="flex items-center space-x-2.5">
                <Sliders className="w-5 h-5 text-indigo-400" />
                <h4 className="text-lg font-bold text-slate-100">
                  {editingPlan.id === 0 ? 'Create New Plan' : 'Adjust Plan Parameters'}
                </h4>
              </div>
              <button 
                onClick={handleCancelEdit}
                className="text-slate-500 hover:text-white p-1.5 rounded-lg hover:bg-slate-800 transition-colors cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Modal Body / Form */}
            <div className="space-y-4 text-sm">
              
              {/* Plan Display Name */}
              <div className="space-y-1">
                <label className="text-[10px] text-slate-400 font-bold uppercase tracking-wider block mb-1.5">Plan Display Name</label>
                <input
                  type="text"
                  name="plan_name"
                  value={editForm.plan_name || ''}
                  onChange={handleInputChange}
                  className="w-full bg-slate-950 border border-slate-800 focus:border-indigo-500/40 rounded-xl py-3 px-4 text-sm text-slate-100 focus:outline-none placeholder-slate-700 transition-colors duration-300"
                  placeholder="e.g. Diamond Plan"
                />
              </div>

              {/* Cover Image Upload drag zone */}
              <div className="space-y-1">
                <label className="text-[10px] text-slate-400 font-bold uppercase tracking-wider block mb-1.5">Plan Icon / Image</label>
                <div 
                  onDragOver={handleDragOver}
                  onDragLeave={handleDragLeave}
                  onDrop={handleDrop}
                  className={`flex flex-col items-center justify-center p-4 rounded-xl border-2 border-dashed transition-all duration-300 bg-slate-950/40 ${
                    isDragging 
                      ? 'border-indigo-500 bg-indigo-500/5' 
                      : editForm.image_url 
                      ? 'border-slate-800' 
                      : 'border-slate-800 hover:border-indigo-500/30'
                  }`}
                >
                  {editForm.image_url ? (
                    <div className="flex items-center space-x-4 w-full">
                      <div className="relative">
                        <img
                          src={editForm.image_url}
                          alt="Uploaded plan"
                          className="w-14 h-14 object-contain rounded-xl bg-slate-950 p-1.5 border border-slate-800/80"
                        />
                        <button
                          type="button"
                          onClick={() => setEditForm((prev) => ({ ...prev, image_url: '' }))}
                          className="absolute -top-1.5 -right-1.5 bg-rose-600 text-white rounded-full p-0.5 hover:bg-rose-500 transition-all shadow cursor-pointer"
                        >
                          <X className="w-3.5 h-3.5" />
                        </button>
                      </div>
                      <div className="flex-1 text-left">
                        <span className="text-[11px] font-bold text-slate-350 block">Base64 String Attached</span>
                        <span className="text-[9px] text-slate-500 block mt-0.5">Ready to store in database</span>
                        
                        <label className="inline-block text-[10px] font-semibold text-indigo-400 hover:text-indigo-300 mt-1 cursor-pointer">
                          Change Graphic
                          <input
                            type="file"
                            accept="image/*"
                            onChange={handleImageUpload}
                            className="hidden"
                          />
                        </label>
                      </div>
                    </div>
                  ) : (
                    <div className="text-center space-y-1.5 py-1">
                      <Upload className="w-6 h-6 text-slate-500 mx-auto" />
                      <p className="text-[11px] font-semibold text-slate-350">
                        Drag cover image here or{' '}
                        <label className="text-indigo-400 hover:text-indigo-300 cursor-pointer select-none">
                          browse
                          <input
                            type="file"
                            accept="image/*"
                            onChange={handleImageUpload}
                            className="hidden"
                          />
                        </label>
                      </p>
                      <p className="text-[9px] text-slate-500">Supports SVG/PNG/JPG (Max 1MB)</p>
                    </div>
                  )}
                </div>
              </div>

              {/* Capital boundaries */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[10px] text-slate-400 font-bold uppercase tracking-wider block mb-1.5">Min Capital (₹)</label>
                  <input
                    type="number"
                    name="min_amount"
                    value={editForm.min_amount || ''}
                    onChange={handleInputChange}
                    className="w-full bg-slate-950 border border-slate-800 focus:border-indigo-500/40 rounded-xl py-3 px-4 text-sm text-slate-100 focus:outline-none placeholder-slate-700 transition-colors duration-300"
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-[10px] text-slate-400 font-bold uppercase tracking-wider block mb-1.5">Max Capital (₹)</label>
                  <input
                    type="number"
                    name="max_amount"
                    value={editForm.max_amount || ''}
                    onChange={handleInputChange}
                    className="w-full bg-slate-950 border border-slate-800 focus:border-indigo-500/40 rounded-xl py-3 px-4 text-sm text-slate-100 focus:outline-none placeholder-slate-700 transition-colors duration-300"
                  />
                </div>
              </div>

              {/* Yield margins */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[10px] text-slate-400 font-bold uppercase tracking-wider block mb-1.5">Daily ROI %</label>
                  <input
                    type="number"
                    step="0.01"
                    name="daily_roi_pct"
                    value={editForm.daily_roi_pct || ''}
                    onChange={handleInputChange}
                    className="w-full bg-slate-950 border border-slate-800 focus:border-indigo-500/40 rounded-xl py-3 px-4 text-sm text-slate-100 focus:outline-none placeholder-slate-700 transition-colors duration-300"
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-[10px] text-slate-400 font-bold uppercase tracking-wider block mb-1.5">Lock Duration (Days)</label>
                  <input
                    type="number"
                    name="lock_days"
                    value={editForm.lock_days || ''}
                    onChange={handleInputChange}
                    className="w-full bg-slate-950 border border-slate-800 focus:border-indigo-500/40 rounded-xl py-3 px-4 text-sm text-slate-100 focus:outline-none placeholder-slate-700 transition-colors duration-300"
                  />
                </div>
              </div>

              {/* ROI withdrawal cycle */}
              <div className="space-y-1">
                <label className="text-[10px] text-slate-400 font-bold uppercase tracking-wider block mb-1.5">Interest Yield Withdrawal Cycle (Days)</label>
                <input
                  type="number"
                  name="roi_withdraw_days"
                  value={editForm.roi_withdraw_days || ''}
                  onChange={handleInputChange}
                  className="w-full bg-slate-950 border border-slate-800 focus:border-indigo-500/40 rounded-xl py-3 px-4 text-sm text-slate-100 focus:outline-none placeholder-slate-700 transition-colors duration-300"
                />
              </div>
            </div>

            {/* Modal Actions */}
            <div className="flex space-x-3 pt-5 mt-6 border-t border-slate-800">
              <button
                onClick={() => savePlanChanges(editingPlan.id)}
                disabled={actionLoading}
                className="flex-1 flex items-center justify-center space-x-2 py-3 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-bold cursor-pointer shadow-lg shadow-indigo-600/20 active:scale-[0.98] transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {actionLoading ? (
                  <span className="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
                ) : (
                  <Check className="w-4 h-4" />
                )}
                <span>{editingPlan.id === 0 ? 'Create Plan' : 'Save Changes'}</span>
              </button>
              <button
                onClick={handleCancelEdit}
                disabled={actionLoading}
                className="px-6 py-3 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-sm font-bold cursor-pointer transition-colors active:scale-[0.98]"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>,
        document.body
      )}
    </div>
  );
};
