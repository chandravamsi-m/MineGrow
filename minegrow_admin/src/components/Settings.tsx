import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import { useToast } from '../context/ToastContext';
import { useConfirm } from '../context/ConfirmContext';
import { Settings as SettingsIcon, CreditCard, Clock, Save, RefreshCw, AlertCircle } from 'lucide-react';

export const Settings: React.FC = () => {
  const [paymentUpi, setPaymentUpi] = useState('');
  const [otpDelay, setOtpDelay] = useState(30);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  const toast = useToast();
  const confirm = useConfirm();

  const fetchConfigs = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await api.get<any>('admin/app-config');
      if (Array.isArray(response)) {
        // Direct array response
        const upiItem = response.find(c => c.key === 'payment_upi_id');
        const delayItem = response.find(c => c.key === 'otp_resend_delay');
        if (upiItem) setPaymentUpi(upiItem.value);
        if (delayItem) setOtpDelay(parseInt(delayItem.value, 10) || 30);
      } else if (response.success && Array.isArray(response.data)) {
        // Wrapped response
        const upiItem = response.data.find((c: any) => c.key === 'payment_upi_id');
        const delayItem = response.data.find((c: any) => c.key === 'otp_resend_delay');
        if (upiItem) setPaymentUpi(upiItem.value);
        if (delayItem) setOtpDelay(parseInt(delayItem.value, 10) || 30);
      } else {
        throw new Error('Failed to load system configs');
      }
    } catch (err: any) {
      setError(err.message || 'Error occurred listing app configs');
      toast.error(err.message || 'Failed to fetch system configurations');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchConfigs();
  }, []);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!paymentUpi.trim()) {
      toast.error('Payment UPI ID cannot be empty');
      return;
    }
    if (otpDelay < 10 || otpDelay > 300) {
      toast.error('OTP delay must be between 10 and 300 seconds');
      return;
    }

    confirm({
      title: 'Update App Parameters',
      message: 'Are you sure you want to update the payment UPI ID and OTP resend delay? This changes global parameters for all clients immediately.',
      confirmText: 'Save Parameters',
      type: 'warning',
      onConfirm: async () => {
        setSaving(true);
        try {
          // Update Payment UPI ID
          await api.patch(`admin/app-config/payment_upi_id`, { value: paymentUpi });
          // Update OTP Delay
          await api.patch(`admin/app-config/otp_resend_delay`, { value: otpDelay.toString() });
          
          toast.success('App configurations updated successfully');
          fetchConfigs();
        } catch (err: any) {
          toast.error(err.message || 'Failed to save configuration settings');
        } finally {
          setSaving(false);
        }
      }
    });
  };

  if (loading) {
    return (
      <div className="space-y-8 animate-pulse">
        <div className="space-y-2">
          <div className="h-8 bg-slate-900 rounded-xl w-48"></div>
          <div className="h-4 bg-slate-900/60 rounded-xl w-72"></div>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="h-48 bg-slate-900/60 border border-slate-900/80 rounded-2xl p-6"></div>
          <div className="h-48 bg-slate-900/60 border border-slate-900/80 rounded-2xl p-6"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Header Banner */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center space-y-4 md:space-y-0">
        <div>
          <h2 className="text-3xl font-extrabold text-white tracking-tight flex items-center space-x-3">
            <SettingsIcon className="w-8 h-8 text-indigo-400 animate-spin-slow" />
            <span>App Parameters</span>
          </h2>
          <p className="text-slate-400 text-sm mt-1">Configure security delays, gateway credentials, and other global features.</p>
        </div>
        <button
          onClick={fetchConfigs}
          className="flex items-center space-x-2 px-4 py-2 text-xs font-semibold bg-slate-900/60 border border-slate-800/80 hover:bg-slate-800/60 rounded-xl text-slate-300 transition-all cursor-pointer"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          <span>Synchronize Cache</span>
        </button>
      </div>

      {error && (
        <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 flex items-center space-x-3 text-sm">
          <AlertCircle className="w-5 h-5 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}

      <form onSubmit={handleSave} className="space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Card 1: Payment UPI Gateway */}
          <div className="glass-panel p-6 rounded-2xl space-y-6">
            <div className="flex items-center space-x-3 border-b border-slate-800 pb-4">
              <div className="p-2 bg-emerald-500/10 border border-emerald-500/20 rounded-xl text-emerald-400">
                <CreditCard className="w-5 h-5" />
              </div>
              <div>
                <h4 className="text-base font-bold text-slate-100">Payment Gateway UPI ID</h4>
                <p className="text-[10px] text-slate-500 mt-0.5">UPI ID displayed to users inside mobile deposit sheets.</p>
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-[10px] text-slate-500 uppercase tracking-wider font-bold">UPI ID / VPA</label>
              <input
                type="text"
                placeholder="pay@gateway"
                value={paymentUpi}
                onChange={(e) => setPaymentUpi(e.target.value)}
                className="w-full bg-slate-900/60 border border-slate-800 focus:border-indigo-500/40 rounded-xl py-3 px-4 text-sm text-slate-200 focus:outline-none placeholder-slate-700 transition-colors animate-fadeIn"
                required
              />
            </div>

            <div className="bg-slate-950/40 rounded-xl p-4 border border-slate-900/60 text-xs text-slate-400 leading-relaxed">
              Ensure this UPI is linked to the primary settlement account. Double check spelling to prevent client transfer reconciliation delays.
            </div>
          </div>

          {/* Card 2: OTP Resend Delay */}
          <div className="glass-panel p-6 rounded-2xl space-y-6">
            <div className="flex items-center space-x-3 border-b border-slate-800 pb-4">
              <div className="p-2 bg-indigo-500/10 border border-indigo-500/20 rounded-xl text-indigo-400">
                <Clock className="w-5 h-5" />
              </div>
              <div>
                <h4 className="text-base font-bold text-slate-100">OTP Resend Delay</h4>
                <p className="text-[10px] text-slate-500 mt-0.5">Abuse protection rate limit timer in seconds.</p>
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-[10px] text-slate-500 uppercase tracking-wider font-bold">Timer Delay (Seconds)</label>
              <input
                type="number"
                min={10}
                max={300}
                value={otpDelay}
                onChange={(e) => setOtpDelay(parseInt(e.target.value, 10) || 30)}
                className="w-full bg-slate-900/60 border border-slate-800 focus:border-indigo-500/40 rounded-xl py-3 px-4 text-sm text-slate-200 focus:outline-none placeholder-slate-700 transition-colors animate-fadeIn"
                required
              />
            </div>

            <div className="bg-slate-950/40 rounded-xl p-4 border border-slate-900/60 text-xs text-slate-400 leading-relaxed">
              Standard setting is 30 seconds. Higher numbers reduce OTP SMS consumption costs but may trigger user drop-off during onboarding.
            </div>
          </div>
        </div>

        <div className="flex justify-end pt-4">
          <button
            type="submit"
            disabled={saving}
            className={`flex items-center justify-center space-x-2 px-8 py-3.5 bg-gradient-to-r from-indigo-600 to-indigo-500 hover:from-indigo-500 hover:to-indigo-400 text-white rounded-xl font-bold text-xs tracking-wider transition-all shadow-lg shadow-indigo-600/20 active:scale-98 ${
              saving ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'
            }`}
          >
            <Save className="w-4 h-4" />
            <span>{saving ? 'Saving System Changes...' : 'Save Parameters'}</span>
          </button>
        </div>
      </form>
    </div>
  );
};
