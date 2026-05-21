import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import { useConfirm } from '../context/ConfirmContext';
import { useToast } from '../context/ToastContext';
import {
  FileText,
  CheckCircle,
  XCircle,
  AlertCircle,
  Eye,
  IndianRupee,
  ShieldCheck,
  X,
  Loader2,
} from 'lucide-react';

interface InvestmentDetail {
  id: number;
  user_id: number;
  plan_id: number;
  amount: number;
  utr_number: string;
  payment_proof_url: string;
  status: 'pending' | 'active' | 'rejected';
  rejection_reason?: string | null;
  daily_roi_pct: number;
  lock_days: number;
  maturity_date?: string | null;
  created_at: string;
  users?: {
    full_name: string;
    mobile: string;
  } | null;
  plans?: {
    plan_name: string;
  } | null;
}

export const DepositsQueue: React.FC = () => {
  const [investments, setInvestments] = useState<InvestmentDetail[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const toast = useToast();
  const confirm = useConfirm();
  
  // Selected investment for verification overlay
  const [selectedItem, setSelectedItem] = useState<InvestmentDetail | null>(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [rejectReason, setRejectReason] = useState('');
  const [showRejectForm, setShowRejectForm] = useState(false);
  const [previewUrl, setPreviewUrl] = useState<string>('');
  const [previewLoading, setPreviewLoading] = useState(false);
  
  // Status filter state
  const [statusFilter, setStatusFilter] = useState('pending');

  useEffect(() => {
    if (selectedItem?.payment_proof_url) {
      setPreviewLoading(true);
      setPreviewUrl('');
      api.get<{ signedUrl: string }>(`admin/files/view?path=${encodeURIComponent(selectedItem.payment_proof_url)}&json=true`)
        .then(res => {
          if (res?.signedUrl) {
            setPreviewUrl(res.signedUrl);
          }
        })
        .catch(err => {
          console.error('Error fetching preview signed URL:', err);
        })
        .finally(() => {
          setPreviewLoading(false);
        });
    } else {
      setPreviewUrl('');
    }
  }, [selectedItem]);

  const fetchInvestments = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const query = statusFilter ? `?status=${statusFilter}` : '';
      const response = await api.get<any>(`admin/investments${query}`);
      if (response.success && response.data) {
        setInvestments(response.data);
      } else {
        throw new Error(response.message || 'Failed to fetch investment queue');
      }
    } catch (e: any) {
      setError(e.message || 'Error occurred listing investments');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchInvestments();
    setSelectedItem(null);
    setShowRejectForm(false);
    setRejectReason('');
  }, [statusFilter]);

  const approveInvestment = async (id: number) => {
    confirm({
      title: 'Approve Deposit Transaction',
      message: 'Are you sure you want to approve this deposit transaction? This will create an active maturity contract, generate a wallet ledger record, and notify the user.',
      confirmText: 'Approve Deposit',
      type: 'success',
      onConfirm: async () => {
        setActionLoading(true);
        try {
          const response = await api.post<any>(`admin/investments/${id}/approve`);
          if (response.success) {
            toast.success('Deposit transaction approved and contract activated');
            fetchInvestments();
            if (selectedItem?.id === id) {
              setSelectedItem(null);
            }
          } else {
            toast.error(response.message || 'Approval processing failed');
          }
        } catch (e: any) {
          toast.error(e.message || 'Error occurred approving deposit');
        } finally {
          setActionLoading(false);
        }
      }
    });
  };

  const rejectInvestment = async (id: number) => {
    if (!rejectReason.trim()) {
      toast.warning('Please specify the reason for transaction rejection.');
      return;
    }
    
    setActionLoading(true);
    try {
      const response = await api.post<any>(`admin/investments/${id}/reject`, { adminNote: rejectReason });
      if (response.success) {
        toast.success('Deposit transaction marked as rejected');
        setShowRejectForm(false);
        setRejectReason('');
        fetchInvestments();
        if (selectedItem?.id === id) {
          setSelectedItem(null);
        }
      } else {
        toast.error(response.message || 'Rejection failed');
      }
    } catch (e: any) {
      toast.error(e.message || 'Error occurred rejecting deposit');
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div className="relative">
      <div className="space-y-6 animate-fadeIn">
        <div>
          <h2 className="text-3xl font-extrabold text-white tracking-tight">Deposit Approvals</h2>
          <p className="text-slate-400 text-sm mt-1">Verify payment screenshots, crosscheck transaction UTR codes, and approve capital contracts.</p>
        </div>

      {error && (
        <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 flex items-center space-x-3 text-sm">
          <AlertCircle className="w-5 h-5 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Navigation tabs */}
      <div className="flex border-b border-slate-800 space-x-4 overflow-x-auto whitespace-nowrap scrollbar-none flex-nowrap">
        <button
          onClick={() => setStatusFilter('pending')}
          className={`pb-4 px-2 text-sm font-semibold border-b-2 cursor-pointer transition-all duration-300 flex-shrink-0 ${
            statusFilter === 'pending'
              ? 'border-indigo-500 text-indigo-400 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-300'
          }`}
        >
          Pending Reviews
        </button>
        <button
          onClick={() => setStatusFilter('active')}
          className={`pb-4 px-2 text-sm font-semibold border-b-2 cursor-pointer transition-all duration-300 flex-shrink-0 ${
            statusFilter === 'active'
              ? 'border-emerald-500 text-emerald-400 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-300'
          }`}
        >
          Active Agreements
        </button>
        <button
          onClick={() => setStatusFilter('rejected')}
          className={`pb-4 px-2 text-sm font-semibold border-b-2 cursor-pointer transition-all duration-300 flex-shrink-0 ${
            statusFilter === 'rejected'
              ? 'border-rose-500 text-rose-400 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-300'
          }`}
        >
          Rejected Deposits
        </button>
      </div>

      {/* Layout Grid */}
      <div className="w-full">
        {/* Main list */}
        <div className="glass-panel rounded-2xl overflow-hidden shadow-2xl">
          {/* Mobile View: Cards stack */}
          <div className="block sm:hidden divide-y divide-slate-800/60 text-sm">
            {loading ? (
              Array.from({ length: 5 }).map((_, idx) => (
                <div key={idx} className="p-4 space-y-3 animate-pulse">
                  <div className="flex justify-between">
                    <div className="h-4 bg-slate-800 rounded w-12"></div>
                    <div className="h-5 bg-slate-800 rounded w-16"></div>
                  </div>
                  <div className="space-y-2">
                    <div className="h-4 bg-slate-800 rounded w-32"></div>
                    <div className="h-3 bg-slate-800/60 rounded w-20"></div>
                  </div>
                  <div className="flex justify-between items-center pt-2">
                    <div className="h-4 bg-slate-800 rounded w-16"></div>
                    <div className="h-8 bg-slate-800 rounded-lg w-10"></div>
                  </div>
                </div>
              ))
            ) : investments.length === 0 ? (
              <div className="p-12 text-center text-slate-500">
                No deposit records currently match this filter tab.
              </div>
            ) : (
              investments.map((item) => (
                <div
                  key={item.id}
                  className={`p-4 space-y-3 hover:bg-slate-900/10 transition-colors duration-250 cursor-pointer ${
                    selectedItem?.id === item.id ? 'bg-slate-900/20' : ''
                  }`}
                  onClick={() => {
                    setSelectedItem(item);
                    setShowRejectForm(false);
                    setRejectReason('');
                  }}
                >
                  <div className="flex justify-between items-center">
                    <span className="font-mono text-xs text-indigo-400 font-semibold">#{item.id}</span>
                    <span className={`text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded ${
                      item.status === 'active'
                        ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                        : item.status === 'pending'
                        ? 'bg-amber-500/10 text-amber-400 border border-amber-500/20 animate-pulse'
                        : 'bg-rose-500/10 text-rose-400 border border-rose-500/20'
                    }`}>
                      {item.status}
                    </span>
                  </div>

                  <div>
                    <div className="font-semibold text-slate-200 text-sm">
                      {item.plans?.plan_name || `Plan #${item.plan_id}`}
                    </div>
                    <div className="text-xs text-slate-400 mt-0.5">
                      Client: {item.users?.full_name || 'System Member'}
                    </div>
                    <div className="text-xs text-slate-500 mt-1 font-mono">
                      UTR: {item.utr_number}
                    </div>
                  </div>

                  <div className="flex justify-between items-center pt-2 border-t border-slate-800/40" onClick={(e) => e.stopPropagation()}>
                    <div className="space-y-0.5">
                      <span className="text-[10px] text-slate-500 block uppercase tracking-wider font-semibold">Capital Amount</span>
                      <div className="flex items-center text-slate-200 font-bold">
                        <IndianRupee className="w-3.5 h-3.5 mr-0.5 text-indigo-400" />
                        <span>{item.amount.toLocaleString()}</span>
                      </div>
                    </div>

                    <button
                      onClick={() => {
                        setSelectedItem(item);
                        setShowRejectForm(false);
                        setRejectReason('');
                      }}
                      className="p-1.5 rounded-lg border border-slate-800 hover:bg-slate-800 text-slate-400 hover:text-slate-100 transition-all duration-300"
                    >
                      <Eye className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>

          {/* Desktop/Tablet View: Table layout */}
          <div className="hidden sm:block overflow-x-auto custom-scrollbar">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-slate-800 bg-slate-950/40 text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  <th className="p-4 pl-6">ID</th>
                  <th className="p-4">Plan / Client</th>
                  <th className="p-4">Capital Amount</th>
                  <th className="p-4">UTR Number</th>
                  <th className="p-4 pr-6 text-center">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 text-sm">
                {loading ? (
                  Array.from({ length: 5 }).map((_, idx) => (
                    <tr key={idx} className="animate-pulse border-b border-slate-800/40">
                      <td className="p-4 pl-6"><div className="h-4 bg-slate-800 rounded w-6"></div></td>
                      <td className="p-4">
                        <div className="h-4 bg-slate-800 rounded w-28 mb-1.5"></div>
                        <div className="h-3 bg-slate-800/60 rounded w-20"></div>
                      </td>
                      <td className="p-4"><div className="h-4 bg-slate-800 rounded w-16"></div></td>
                      <td className="p-4"><div className="h-4 bg-slate-800 rounded w-24"></div></td>
                      <td className="p-4 pr-6 text-center"><div className="h-8 bg-slate-800 rounded-lg w-8 mx-auto"></div></td>
                    </tr>
                  ))
                ) : investments.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="p-12 text-center text-slate-500">
                      No deposit records currently match this filter tab.
                    </td>
                  </tr>
                ) : (
                  investments.map((item) => (
                    <tr
                      key={item.id}
                      className={`hover:bg-slate-900/30 transition-colors duration-250 cursor-pointer ${
                        selectedItem?.id === item.id ? 'bg-slate-900/40' : ''
                      }`}
                      onClick={() => {
                        setSelectedItem(item);
                        setShowRejectForm(false);
                        setRejectReason('');
                      }}
                    >
                      <td className="p-4 pl-6 font-mono text-xs text-indigo-400 font-semibold">#{item.id}</td>
                      <td className="p-4">
                        <div className="font-semibold text-slate-200">
                          {item.plans?.plan_name || `Plan #${item.plan_id}`}
                        </div>
                        <div className="text-xs text-slate-500 mt-0.5">
                          {item.users?.full_name || 'System Member'}
                        </div>
                      </td>
                      <td className="p-4">
                        <div className="flex items-center text-slate-200 font-semibold">
                          <IndianRupee className="w-3.5 h-3.5 mr-0.5 text-slate-400" />
                          <span>{item.amount.toLocaleString()}</span>
                        </div>
                        <span className="text-[10px] text-indigo-400 font-medium">ROI: {item.daily_roi_pct}% / day</span>
                      </td>
                      <td className="p-4 font-mono text-xs text-slate-300 font-semibold tracking-wider">
                        {item.utr_number}
                      </td>
                      <td className="p-4 pr-6 text-center" onClick={(e) => e.stopPropagation()}>
                        <button
                          onClick={() => {
                            setSelectedItem(item);
                            setShowRejectForm(false);
                            setRejectReason('');
                          }}
                          className="p-1.5 rounded-lg border border-slate-800 hover:bg-slate-800 text-slate-400 hover:text-slate-100 transition-all duration-300 cursor-pointer"
                        >
                          <Eye className="w-4 h-4" />
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>

    {/* Slide-over Verification drawer */}
    {selectedItem && (
      <>
        {/* Backdrop */}
        <div 
          className="fixed inset-0 bg-slate-950/70 z-40 animate-fadeIn"
          onClick={() => {
            setSelectedItem(null);
            setShowRejectForm(false);
          }}
        />
        {/* Drawer */}
        <div className="fixed inset-y-0 right-0 z-50 w-full max-w-lg h-full bg-slate-950/98 border-l border-slate-800/80 shadow-[-10px_0_30px_-5px_rgba(0,0,0,0.5)] flex flex-col animate-slideIn">
              {/* Header */}
              <div className="p-6 border-b border-slate-800 flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className="p-2 bg-indigo-500/10 rounded-xl text-indigo-400">
                    <FileText className="w-5 h-5" />
                  </div>
                  <div>
                    <h4 className="text-lg font-bold text-slate-100">Verification Desk</h4>
                    <span className="font-mono text-[10px] text-indigo-400 font-bold uppercase">Transaction ID: #{selectedItem.id}</span>
                  </div>
                </div>
                <button
                  onClick={() => {
                    setSelectedItem(null);
                    setShowRejectForm(false);
                  }}
                  className="p-1.5 text-slate-400 hover:text-slate-100 hover:bg-slate-800/40 rounded-lg cursor-pointer transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Body */}
              <div className="flex-grow overflow-y-auto p-6 space-y-6 custom-scrollbar">
                <div className="space-y-6 animate-fadeIn">
                  {/* User Profile Card */}
                  <div className="bg-slate-900/40 rounded-xl p-4 border border-slate-800 space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="font-mono text-[10px] text-indigo-400 font-bold">DEPOSIT DETAILS</span>
                      <span className={`text-[10px] uppercase font-bold tracking-wider px-2.5 py-0.5 rounded ${
                        selectedItem.status === 'active'
                          ? 'bg-emerald-600/10 text-emerald-400'
                          : selectedItem.status === 'pending'
                          ? 'bg-amber-600/10 text-amber-400 animate-pulse'
                          : 'bg-rose-500/10 text-rose-400'
                      }`}>
                        {selectedItem.status}
                      </span>
                    </div>
                    <h5 className="text-sm font-bold text-slate-200">{selectedItem.users?.full_name || 'System Member'}</h5>
                    <p className="text-xs text-slate-400">Mobile: {selectedItem.users?.mobile}</p>
                  </div>

                  {/* Transaction Details */}
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-1">
                      <span className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold block">UTRs Reference</span>
                      <span className="text-xs font-mono font-bold text-slate-300 bg-slate-900/30 p-2.5 border border-slate-800/40 rounded-lg block select-all">
                        {selectedItem.utr_number}
                      </span>
                    </div>
                    <div className="space-y-1">
                      <span className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold block">Capital Value</span>
                      <span className="text-xs font-bold text-emerald-400 bg-emerald-500/5 p-2.5 border border-emerald-500/10 rounded-lg block">
                        ₹{selectedItem.amount.toLocaleString()}
                      </span>
                    </div>
                  </div>

                  {/* Plan Information */}
                  <div className="p-4 bg-slate-900/20 rounded-xl border border-slate-800 text-xs space-y-2">
                    <div className="flex justify-between">
                      <span className="text-slate-500 font-medium">Interest Percentage:</span>
                      <span className="text-indigo-400 font-semibold">{selectedItem.daily_roi_pct}% / day</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500 font-medium">Contract Lockup Time:</span>
                      <span className="text-slate-300 font-semibold">{selectedItem.lock_days} days</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500 font-medium">Created On:</span>
                      <span className="text-slate-400">{new Date(selectedItem.created_at).toLocaleString()}</span>
                    </div>
                    {selectedItem.maturity_date && (
                      <div className="flex justify-between border-t border-slate-800/60 pt-2 mt-2 font-semibold">
                        <span className="text-slate-400">Contract Maturity:</span>
                        <span className="text-emerald-400">{new Date(selectedItem.maturity_date).toLocaleDateString()}</span>
                      </div>
                    )}
                  </div>

                  {/* Payment Proof Snapshot */}
                  <div className="space-y-3">
                    <span className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold block">Payment Screenshot Receipt</span>
                    
                    {selectedItem.payment_proof_url ? (
                      <div className="space-y-4">
                        {previewLoading ? (
                          <div className="flex flex-col items-center justify-center p-6 bg-slate-950/40 border border-slate-800 rounded-xl aspect-video text-slate-500 animate-pulse">
                            <Loader2 className="w-8 h-8 animate-spin text-indigo-500 mb-2" />
                            <span className="text-[10px] font-semibold uppercase tracking-wider">Securing View URL...</span>
                          </div>
                        ) : previewUrl ? (
                          <a
                            href={previewUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="group relative block rounded-xl overflow-hidden border border-slate-800 bg-slate-950 aspect-video flex items-center justify-center hover:border-indigo-500/30 transition-all duration-300 shadow-inner"
                          >
                            <img
                              src={previewUrl}
                              alt="Payment Receipt"
                              className="w-full h-full object-contain opacity-75 group-hover:scale-105 transition-all duration-300 group-hover:opacity-95"
                              onError={(e) => {
                                e.currentTarget.style.display = 'none';
                              }}
                            />
                            <span className="absolute bottom-3 right-3 bg-slate-950/80 px-2.5 py-1 rounded text-[10px] font-semibold text-slate-300 group-hover:bg-indigo-600 transition-colors duration-300">
                              View Receipt Fullscreen
                            </span>
                          </a>
                        ) : (
                          <div className="p-6 rounded-xl border border-dashed border-slate-800/80 text-center text-xs text-slate-500 bg-slate-900/10">
                            Failed to generate view URL.
                          </div>
                        )}

                        {/* Pending Actions */}
                        {selectedItem.status === 'pending' && (
                          <div className="space-y-2 pt-2 border-t border-slate-800/60">
                            {!showRejectForm ? (
                              <div className="grid grid-cols-2 gap-3">
                                <button
                                  onClick={() => approveInvestment(selectedItem.id)}
                                  disabled={actionLoading}
                                  className="flex items-center justify-center space-x-1.5 py-2.5 rounded-xl border border-emerald-500/20 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 text-xs font-semibold transition-all duration-300 cursor-pointer"
                                >
                                  <CheckCircle className="w-3.5 h-3.5" />
                                  <span>Approve Deposit</span>
                                </button>
                                
                                <button
                                  onClick={() => setShowRejectForm(true)}
                                  className="flex items-center justify-center space-x-1.5 py-2.5 rounded-xl border border-rose-500/20 bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 text-xs font-semibold transition-all duration-300 cursor-pointer"
                                >
                                  <XCircle className="w-3.5 h-3.5" />
                                  <span>Reject Deposit</span>
                                </button>
                              </div>
                            ) : (
                              <div className="space-y-3 p-3 bg-rose-500/5 rounded-xl border border-rose-500/15 animate-fadeIn">
                                <label className="text-[10px] font-bold text-rose-400 uppercase">Reason for Transaction Rejection</label>
                                <textarea
                                  rows={3}
                                  placeholder="Specify reason (e.g. UTR matches an already approved transaction, blur payment image proof)..."
                                  value={rejectReason}
                                  onChange={(e) => setRejectReason(e.target.value)}
                                  className="w-full bg-slate-950/80 border border-slate-800 rounded-lg p-2 text-xs text-slate-100 placeholder-slate-500 focus:outline-none focus:border-rose-500/40"
                                />
                                <div className="flex space-x-2">
                                  <button
                                    onClick={() => rejectInvestment(selectedItem.id)}
                                    disabled={actionLoading}
                                    className="flex-1 py-1.5 bg-rose-600 hover:bg-rose-500 text-white rounded-lg text-xs font-semibold transition-colors duration-300 cursor-pointer"
                                  >
                                    Submit Rejection
                                  </button>
                                  <button
                                    onClick={() => setShowRejectForm(false)}
                                    className="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-lg text-xs font-semibold transition-colors duration-300 cursor-pointer"
                                  >
                                    Cancel
                                  </button>
                                </div>
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                    ) : (
                      <div className="p-6 rounded-xl border border-dashed border-slate-800/80 text-center text-xs text-slate-500 bg-slate-900/10">
                        No receipt screens loaded. Profile upload required.
                      </div>
                    )}
                  </div>

                  {selectedItem.status === 'active' && (
                    <div className="p-3 bg-emerald-500/5 rounded-xl border border-emerald-500/10 text-emerald-400 flex items-center space-x-2.5 text-xs font-semibold">
                      <ShieldCheck className="w-4 h-4 flex-shrink-0" />
                      <span>Approved contract generating daily ROI.</span>
                    </div>
                  )}

                  {selectedItem.rejection_reason && (
                    <div className="p-3 bg-rose-500/5 rounded-xl border border-rose-500/10 text-rose-400 space-y-1 text-xs">
                      <div className="flex items-center space-x-2">
                        <XCircle className="w-4 h-4 text-rose-500" />
                        <span className="font-semibold">Rejection details</span>
                      </div>
                      <p className="opacity-90 leading-relaxed font-mono text-[10px] pl-6">{selectedItem.rejection_reason}</p>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </>
        )}
    </div>
  );
};
