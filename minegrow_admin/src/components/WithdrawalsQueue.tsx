import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import { useConfirm } from '../context/ConfirmContext';
import { useToast } from '../context/ToastContext';

import {
  FileText,
  Check,
  X,
  AlertCircle,
  Clock,
  Eye,
  IndianRupee,
  Building,
  QrCode,
  ArrowRight,
  Download,
  AlertTriangle,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react';

interface WithdrawalDetail {
  id: number;
  user_id: number;
  amount: number;
  withdrawal_type: 'roi' | 'principal';
  status: 'pending' | 'approved' | 'rejected' | 'completed';
  rejection_reason?: string | null;
  bank_name?: string | null;
  account_number?: string | null;
  ifsc_code?: string | null;
  upi_id?: string | null;
  requested_at: string;
  processed_at?: string | null;
  users?: {
    full_name: string;
    mobile: string;
  } | null;
}

interface PaginationState {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}

const PAGE_SIZE = 20;
const initialPagination: PaginationState = {
  page: 1,
  limit: PAGE_SIZE,
  total: 0,
  totalPages: 1,
};

export const WithdrawalsQueue: React.FC = () => {
  const [withdrawals, setWithdrawals] = useState<WithdrawalDetail[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const toast = useToast();
  const confirm = useConfirm();
  
  // Selected detail card
  const [selectedItem, setSelectedItem] = useState<WithdrawalDetail | null>(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [rejectReason, setRejectReason] = useState('');
  const [showRejectForm, setShowRejectForm] = useState(false);
  
  // Tab states: 'pending' | 'approved' | 'completed' | 'rejected'
  const [statusFilter, setStatusFilter] = useState<'pending' | 'approved' | 'completed' | 'rejected'>('pending');
  const [page, setPage] = useState(1);
  const [pagination, setPagination] = useState<PaginationState>(initialPagination);

  const fetchWithdrawals = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const params = new URLSearchParams({
        page: String(page),
        limit: String(PAGE_SIZE),
      });
      if (statusFilter) params.set('status', statusFilter);
      const query = `?${params.toString()}`;
      const response = await api.get<any>(`admin/withdrawals${query}`);
      if (response.success && response.data) {
        setWithdrawals(response.data);
        setPagination({
          page: response.pagination?.page || page,
          limit: response.pagination?.limit || PAGE_SIZE,
          total: response.pagination?.total || response.data.length,
          totalPages: response.pagination?.totalPages || 1,
        });
      } else {
        throw new Error(response.message || 'Failed to fetch withdrawals queue');
      }
    } catch (e: any) {
      setError(e.message || 'Error occurred listing withdrawals');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchWithdrawals();
    setSelectedItem(null);
    setShowRejectForm(false);
    setRejectReason('');
  }, [statusFilter, page]);

  const approveRequest = async (id: number) => {
    confirm({
      title: 'Approve Withdrawal Request',
      message: 'Are you sure you want to approve this withdrawal request? This transitions the transaction to APPROVED (Pending physical bank dispatch/UPI wire transfer).',
      confirmText: 'Approve Withdrawal',
      type: 'success',
      onConfirm: async () => {
        setActionLoading(true);
        try {
          const response = await api.post<any>(`admin/withdrawals/${id}/approve`);
          if (response.success) {
            toast.success('Withdrawal request approved');
            fetchWithdrawals();
            if (selectedItem?.id === id) {
              setSelectedItem(null);
            }
          } else {
            toast.error(response.message || 'Approval action failed');
          }
        } catch (e: any) {
          toast.error(e.message || 'Error occurred approving withdrawal');
        } finally {
          setActionLoading(false);
        }
      },
    });
  };

  const rejectRequest = async (id: number) => {
    if (!rejectReason.trim()) {
      toast.warning('Please specify the reason for transaction rejection.');
      return;
    }
    
    setActionLoading(true);
    try {
      const response = await api.post<any>(`admin/withdrawals/${id}/reject`, { adminNote: rejectReason });
      if (response.success) {
        toast.success('Withdrawal request rejected and ledger funds returned to wallet balance');
        setShowRejectForm(false);
        setRejectReason('');
        fetchWithdrawals();
        if (selectedItem?.id === id) {
          setSelectedItem(null);
        }
      } else {
        toast.error(response.message || 'Rejection action failed');
      }
    } catch (e: any) {
      toast.error(e.message || 'Error occurred rejecting withdrawal');
    } finally {
      setActionLoading(false);
    }
  };

  const completeRequest = async (id: number) => {
    confirm({
      title: 'Complete Withdrawal',
      message: 'Are you sure you want to mark this withdrawal as physically COMPLETED? This confirms the cash transfer has been successfully settled with the client bank/UPI and completes the system agreement.',
      confirmText: 'Complete Withdrawal',
      type: 'success',
      onConfirm: async () => {
        setActionLoading(true);
        try {
          const response = await api.post<any>(`admin/withdrawals/${id}/complete`);
          if (response.success) {
            toast.success('Withdrawal transaction marked completed successfully!');
            fetchWithdrawals();
            if (selectedItem?.id === id) {
              setSelectedItem(null);
            }
          } else {
            toast.error(response.message || 'Completion update failed');
          }
        } catch (e: any) {
          toast.error(e.message || 'Error occurred completing withdrawal');
        } finally {
          setActionLoading(false);
        }
      },
    });
  };

  const triggerExportCsv = async () => {
    try {
      const path = `admin/withdrawals/export?status=${statusFilter}&type=`;
      const csvContent = await api.download(path);
      
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.setAttribute('href', url);
      link.setAttribute('download', `withdrawals_${statusFilter}_export_${Date.now()}.csv`);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      toast.success('Withdrawals list exported to CSV successfully');
    } catch (e: any) {
      toast.error(e.message || 'Error occurred exporting CSV ledger file');
    }
  };

  return (
    <div className="relative">
      <div className="space-y-6 animate-fadeIn">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center space-y-4 sm:space-y-0">
          <div>
            <h2 className="text-3xl font-extrabold text-white tracking-tight">Withdrawal Queue</h2>
            <p className="text-slate-400 text-sm mt-1">Approve pending withdrawal requests, manage physical transfers, and complete settlements.</p>
          </div>
        <button
          onClick={triggerExportCsv}
          className="flex items-center space-x-2 px-4 py-2.5 bg-slate-900 border border-slate-800 hover:border-slate-700 text-indigo-400 font-semibold rounded-xl text-xs hover:text-indigo-300 transition-all duration-300 shadow-md cursor-pointer"
        >
          <Download className="w-4 h-4" />
          <span>Export {statusFilter.toUpperCase()} CSV</span>
        </button>
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
          onClick={() => {
            setStatusFilter('pending');
            setPage(1);
          }}
          className={`pb-4 px-2 text-sm font-semibold border-b-2 cursor-pointer transition-all duration-300 flex-shrink-0 ${
            statusFilter === 'pending'
              ? 'border-indigo-500 text-indigo-400 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-300'
          }`}
        >
          Pending Approvals
        </button>
        <button
          onClick={() => {
            setStatusFilter('approved');
            setPage(1);
          }}
          className={`pb-4 px-2 text-sm font-semibold border-b-2 cursor-pointer transition-all duration-300 flex-shrink-0 ${
            statusFilter === 'approved'
              ? 'border-amber-500 text-amber-400 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-300'
          }`}
        >
          Approved Transfers
        </button>
        <button
          onClick={() => {
            setStatusFilter('completed');
            setPage(1);
          }}
          className={`pb-4 px-2 text-sm font-semibold border-b-2 cursor-pointer transition-all duration-300 flex-shrink-0 ${
            statusFilter === 'completed'
              ? 'border-emerald-500 text-emerald-400 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-300'
          }`}
        >
          Completed Settlements
        </button>
        <button
          onClick={() => {
            setStatusFilter('rejected');
            setPage(1);
          }}
          className={`pb-4 px-2 text-sm font-semibold border-b-2 cursor-pointer transition-all duration-300 flex-shrink-0 ${
            statusFilter === 'rejected'
              ? 'border-rose-500 text-rose-400 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-300'
          }`}
        >
          Rejected Requests
        </button>
      </div>

      {/* Layout Grid */}
      <div className="w-full">
        {/* Main table */}
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
            ) : withdrawals.length === 0 ? (
              <div className="p-12 text-center text-slate-500">
                No withdrawal records match this filter tab.
              </div>
            ) : (
              withdrawals.map((item) => (
                <div
                  key={item.id}
                  className={`p-4 space-y-3 hover:bg-slate-900/10 transition-colors duration-250 cursor-pointer ${
                    selectedItem?.id === item.id ? 'bg-slate-900/40' : ''
                  }`}
                  onClick={() => {
                    setSelectedItem(item);
                    setShowRejectForm(false);
                    setRejectReason('');
                  }}
                >
                  <div className="flex justify-between items-center">
                    <span className="font-mono text-xs text-indigo-400 font-semibold">#{item.id}</span>
                    <div className="flex items-center space-x-1.5">
                      <span className={`inline-flex items-center px-1.5 py-0.5 rounded text-[10px] uppercase font-bold tracking-wider ${
                        item.withdrawal_type === 'roi'
                          ? 'bg-amber-500/10 text-amber-400 border border-amber-500/20'
                          : 'bg-purple-500/10 text-purple-400 border border-purple-500/20'
                      }`}>
                        {item.withdrawal_type === 'roi' ? 'ROI Profit' : 'Principal'}
                      </span>
                      <span className={`text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded ${
                        item.status === 'completed'
                          ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                          : item.status === 'approved'
                          ? 'bg-amber-500/10 text-amber-400 border border-amber-500/20'
                          : item.status === 'pending'
                          ? 'bg-blue-500/10 text-blue-400 border border-blue-500/20 animate-pulse'
                          : 'bg-rose-500/10 text-rose-400 border border-rose-500/20'
                      }`}>
                        {item.status}
                      </span>
                    </div>
                  </div>

                  <div>
                    <div className="font-semibold text-slate-200 text-sm">
                      {item.users?.full_name || 'System Member'}
                    </div>
                    <div className="text-xs text-slate-400 mt-0.5">
                      Mobile: {item.users?.mobile || `ID #${item.user_id}`}
                    </div>
                    <div className="text-xs text-slate-500 mt-1">
                      Requested: {new Date(item.requested_at).toLocaleString()}
                    </div>
                  </div>

                  <div className="flex justify-between items-center pt-2 border-t border-slate-800/40" onClick={(e) => e.stopPropagation()}>
                    <div className="space-y-0.5">
                      <span className="text-[10px] text-slate-500 block uppercase tracking-wider font-semibold">Transfer Amount</span>
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
                  <th className="p-4">Requested By</th>
                  <th className="p-4">Transfer Amount</th>
                  <th className="p-4">Type</th>
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
                      <td className="p-4"><div className="h-4 bg-slate-800 rounded w-12"></div></td>
                      <td className="p-4 pr-6 text-center"><div className="h-8 bg-slate-800 rounded-lg w-8 mx-auto"></div></td>
                    </tr>
                  ))
                ) : withdrawals.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="p-12 text-center text-slate-500">
                      No withdrawal records match this filter tab.
                    </td>
                  </tr>
                ) : (
                  withdrawals.map((item) => (
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
                          {item.users?.full_name || 'System Member'}
                        </div>
                        <div className="text-xs text-slate-500 mt-0.5">
                          {item.users?.mobile || `ID #${item.user_id}`}
                        </div>
                      </td>
                      <td className="p-4">
                        <div className="flex items-center text-slate-200 font-semibold">
                          <IndianRupee className="w-3.5 h-3.5 mr-0.5 text-slate-400" />
                          <span>{item.amount.toLocaleString()}</span>
                        </div>
                        <span className="text-[10px] text-slate-500">Net payout</span>
                      </td>
                      <td className="p-4">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded text-[10px] uppercase font-bold tracking-wider ${
                          item.withdrawal_type === 'roi'
                            ? 'bg-amber-500/10 text-amber-400'
                            : 'bg-purple-500/10 text-purple-400'
                        }`}>
                          {item.withdrawal_type === 'roi' ? 'ROI Profit' : 'Principal'}
                        </span>
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

          {!loading && pagination.totalPages > 1 && (
            <div className="p-4 bg-slate-950/40 border-t border-slate-800 flex flex-col sm:flex-row justify-between items-center gap-4 text-xs">
              <span className="text-slate-500 font-semibold uppercase tracking-wider">
                Showing {(pagination.page - 1) * pagination.limit + 1} - {Math.min(pagination.page * pagination.limit, pagination.total)} of {pagination.total} withdrawals
              </span>

              <div className="flex items-center space-x-2">
                <button
                  onClick={() => setPage((current) => Math.max(current - 1, 1))}
                  disabled={pagination.page === 1}
                  className="p-2 bg-slate-900 border border-slate-800 rounded-lg hover:border-slate-700 disabled:opacity-40 disabled:cursor-not-allowed text-slate-300 transition-all duration-300 cursor-pointer"
                  title="Previous page"
                >
                  <ChevronLeft className="w-4 h-4" />
                </button>

                <div className="px-4 py-2 bg-slate-900 border border-slate-800 rounded-lg font-bold text-slate-200">
                  Page {pagination.page} of {pagination.totalPages}
                </div>

                <button
                  onClick={() => setPage((current) => Math.min(current + 1, pagination.totalPages))}
                  disabled={pagination.page === pagination.totalPages}
                  className="p-2 bg-slate-900 border border-slate-800 rounded-lg hover:border-slate-700 disabled:opacity-40 disabled:cursor-not-allowed text-slate-300 transition-all duration-300 cursor-pointer"
                  title="Next page"
                >
                  <ChevronRight className="w-4 h-4" />
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>

    {/* Slide-over Settlement drawer */}
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
                    <h4 className="text-lg font-bold text-slate-100">Settlement Desk</h4>
                    <span className="font-mono text-[10px] text-indigo-400 font-bold uppercase">Payout ID: #{selectedItem.id}</span>
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
                  {/* Profile Card Header */}
                  <div className="bg-slate-900/40 rounded-xl p-4 border border-slate-800 space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="font-mono text-[10px] text-indigo-400 font-bold">WITHDRAWAL REQUEST #{selectedItem.id}</span>
                      <span className={`text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded ${
                        selectedItem.status === 'completed'
                          ? 'bg-emerald-600/10 text-emerald-400'
                          : selectedItem.status === 'approved'
                          ? 'bg-amber-600/10 text-amber-400'
                          : selectedItem.status === 'pending'
                          ? 'bg-blue-600/10 text-blue-400 animate-pulse'
                          : 'bg-rose-500/10 text-rose-400'
                      }`}>
                        {selectedItem.status}
                      </span>
                    </div>
                    <h5 className="text-sm font-bold text-slate-200">{selectedItem.users?.full_name || 'System Member'}</h5>
                    <p className="text-xs text-slate-400">Contact: {selectedItem.users?.mobile}</p>
                  </div>

                  {/* Settlement stats */}
                  <div className="p-4 bg-slate-900/20 rounded-xl border border-slate-800 space-y-2 text-xs">
                    <div className="flex justify-between">
                      <span className="text-slate-500 font-medium">Payout Amount:</span>
                      <span className="text-emerald-400 font-bold">₹{selectedItem.amount.toLocaleString()}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500 font-medium">Fund Type:</span>
                      <span className="text-slate-300 font-semibold uppercase">{selectedItem.withdrawal_type}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500 font-medium">Requested On:</span>
                      <span className="text-slate-400">{new Date(selectedItem.requested_at).toLocaleString()}</span>
                    </div>
                    {selectedItem.processed_at && (
                      <div className="flex justify-between border-t border-slate-800/60 pt-2 mt-2">
                        <span className="text-slate-400 font-medium">Processed On:</span>
                        <span className="text-slate-400">{new Date(selectedItem.processed_at).toLocaleString()}</span>
                      </div>
                    )}
                  </div>

                  {/* Bank accounts / UPI info */}
                  <div className="space-y-3">
                    <span className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold block">Client Payout Directions</span>
                    
                    {selectedItem.bank_name ? (
                      /* Bank transfer */
                      <div className="p-4 bg-slate-900/40 rounded-xl border border-slate-800 space-y-3 text-xs animate-fadeIn">
                        <div className="flex items-center space-x-2 text-indigo-400 font-semibold border-b border-slate-800/60 pb-1.5 mb-2">
                          <Building className="w-4 h-4" />
                          <span>Bank Wire Transfer</span>
                        </div>
                        <div className="grid grid-cols-2 gap-y-2.5 text-slate-300">
                          <div className="text-slate-500 font-medium">Bank Name:</div>
                          <div className="font-semibold text-right truncate">{selectedItem.bank_name}</div>
                          
                          <div className="text-slate-500 font-medium">Account Number:</div>
                          <div className="font-mono font-semibold text-right select-all">{selectedItem.account_number}</div>
                          
                          <div className="text-slate-500 font-medium">IFSC Code:</div>
                          <div className="font-mono font-semibold text-right select-all text-indigo-300">{selectedItem.ifsc_code}</div>
                        </div>
                      </div>
                    ) : selectedItem.upi_id ? (
                      /* UPI details */
                      <div className="p-4 bg-slate-900/40 rounded-xl border border-slate-800 space-y-3 text-xs animate-fadeIn">
                        <div className="flex items-center space-x-2 text-indigo-400 font-semibold border-b border-slate-800/60 pb-1.5 mb-2">
                          <QrCode className="w-4 h-4" />
                          <span>UPI Address Direct</span>
                        </div>
                        <div className="flex justify-between items-center text-slate-300">
                          <span className="text-slate-500 font-medium">UPI Address ID:</span>
                          <span className="font-mono font-bold text-slate-200 select-all p-1 bg-slate-950/60 border border-slate-800/40 rounded-md block">
                            {selectedItem.upi_id}
                          </span>
                        </div>
                      </div>
                    ) : (
                      <div className="p-4 rounded-xl border border-dashed border-rose-500/20 text-center text-xs text-rose-400 flex items-center space-x-2 justify-center bg-rose-500/5">
                        <AlertTriangle className="w-4 h-4" />
                        <span>Payment instructions not configured.</span>
                      </div>
                    )}
                  </div>

                  {/* State dependent action panel */}
                  {selectedItem.status === 'pending' && (
                    <div className="space-y-2 border-t border-slate-800/60 pt-4 animate-fadeIn">
                      {!showRejectForm ? (
                        <div className="grid grid-cols-2 gap-3">
                          <button
                            onClick={() => approveRequest(selectedItem.id)}
                            disabled={actionLoading}
                            className="flex items-center justify-center space-x-1.5 py-2.5 rounded-xl border border-emerald-500/20 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 text-xs font-semibold transition-all duration-300 cursor-pointer"
                          >
                            <Check className="w-3.5 h-3.5" />
                            <span>Approve Payout</span>
                          </button>
                          
                          <button
                            onClick={() => setShowRejectForm(true)}
                            className="flex items-center justify-center space-x-1.5 py-2.5 rounded-xl border border-rose-500/20 bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 text-xs font-semibold transition-all duration-300 cursor-pointer"
                          >
                            <X className="w-3.5 h-3.5" />
                            <span>Reject Payout</span>
                          </button>
                        </div>
                      ) : (
                        <div className="space-y-3 p-3 bg-rose-500/5 rounded-xl border border-rose-500/15 animate-fadeIn">
                          <label className="text-[10px] font-bold text-rose-400 uppercase">Reason for Withdrawal Rejection</label>
                          <textarea
                            rows={3}
                            placeholder="Specify reason (e.g. Invalid bank credentials, missing UPI identifier)..."
                            value={rejectReason}
                            onChange={(e) => setRejectReason(e.target.value)}
                            className="w-full bg-slate-950/80 border border-slate-800 rounded-lg p-2 text-xs text-slate-100 placeholder-slate-500 focus:outline-none focus:border-rose-500/40"
                          />
                          <div className="flex space-x-2">
                            <button
                              onClick={() => rejectRequest(selectedItem.id)}
                              disabled={actionLoading}
                              className="flex-1 py-1.5 bg-rose-600 hover:bg-rose-500 text-white rounded-lg text-xs font-semibold transition-colors duration-300 cursor-pointer"
                            >
                              Confirm Rejection
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

                  {selectedItem.status === 'approved' && (
                    <div className="space-y-3 border-t border-slate-800/60 pt-4 animate-fadeIn">
                      <div className="p-3 bg-amber-500/5 rounded-xl border border-amber-500/10 text-amber-400 text-xs flex items-start space-x-2.5">
                        <Clock className="w-4 h-4 flex-shrink-0 mt-0.5" />
                        <span>Withdrawal approved. Physically process payout transfer now using the client banking instructions above.</span>
                      </div>

                      <button
                        onClick={() => completeRequest(selectedItem.id)}
                        disabled={actionLoading}
                        className="w-full flex items-center justify-center space-x-2 py-3 bg-indigo-600 hover:bg-indigo-500 text-white font-semibold rounded-xl text-xs transition-colors duration-300 cursor-pointer shadow-lg shadow-indigo-600/10"
                      >
                        <span>Mark Payout Physically Complete</span>
                        <ArrowRight className="w-4 h-4 text-white" />
                      </button>
                    </div>
                  )}

                  {selectedItem.status === 'completed' && (
                    <div className="p-3 bg-emerald-500/5 rounded-xl border border-emerald-500/10 text-emerald-400 flex items-center space-x-2.5 text-xs font-semibold animate-fadeIn">
                      <Check className="w-4 h-4 flex-shrink-0" />
                      <span>Settlement settled completely. Client funds paid.</span>
                    </div>
                  )}

                  {selectedItem.status === 'rejected' && selectedItem.rejection_reason && (
                    <div className="p-3 bg-rose-500/5 rounded-xl border border-rose-500/10 text-rose-400 space-y-1 text-xs animate-fadeIn">
                      <div className="flex items-center space-x-2">
                        <X className="w-4 h-4 text-rose-500" />
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
