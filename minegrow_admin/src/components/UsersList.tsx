import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import { useToast } from '../context/ToastContext';
import { useConfirm } from '../context/ConfirmContext';
import {
  Search,
  Filter,
  Check,
  X,
  AlertCircle,
  Eye,
  ShieldAlert,
  FileText,
  Wallet,
  Briefcase,
  History,
  User,
  Calendar,
  Building,
  QrCode,
  IndianRupee,
  Loader2,
} from 'lucide-react';

interface UserDetail {
  id: number;
  full_name: string;
  mobile: string;
  email: string | null;
  address: string | null;
  status: 'active' | 'suspended';
  kyc_verified: boolean;
  kyc_document_url?: string | null;
  kyc_rejection_reason?: string | null;
  created_at: string;
  notification_preferences?: {
    push?: boolean;
    investments?: boolean;
    wallet?: boolean;
    promotions?: boolean;
  } | null;
}

type WalletType = 'roi' | 'principal';
type WalletDirection = 'credit' | 'debit';

interface WalletAdjustmentForm {
  walletType: WalletType;
  direction: WalletDirection;
  amount: string;
  reason: string;
}

const getKycDocumentPath = (kycDoc: any): string | null => {
  return kycDoc?.doc_url || kycDoc?.document_url || null;
};

const hasNumericValue = (value: unknown): boolean => {
  return value !== null && value !== undefined && value !== '' && Number.isFinite(Number(value));
};

const toMoneyValue = (value: unknown): number => {
  return hasNumericValue(value) ? Number(value) : 0;
};

const sumAmounts = (items: any[] | undefined, statusFilter?: string[]): number => {
  if (!items) return 0;

  return items.reduce((total, item) => {
    const status = String(item?.status || '').toLowerCase();
    if (statusFilter && !statusFilter.includes(status)) return total;

    return total + toMoneyValue(item?.amount);
  }, 0);
};

const emptyWalletAdjustment: WalletAdjustmentForm = {
  walletType: 'roi',
  direction: 'credit',
  amount: '',
  reason: '',
};

export const UsersList: React.FC = () => {
  const [users, setUsers] = useState<UserDetail[]>([]);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const toast = useToast();
  const confirm = useConfirm();
  
  // Selected user for details drawer
  const [selectedUser, setSelectedUser] = useState<UserDetail | null>(null);
  const [userDetailPayload, setUserDetailPayload] = useState<any | null>(null);
  const [drawerTab, setDrawerTab] = useState<'profile' | 'wallet' | 'investments' | 'withdrawals'>('profile');
  const [detailsLoading, setDetailsLoading] = useState(false);
  
  // KYC Rejection state
  const [rejectReason, setRejectReason] = useState('');
  const [showRejectForm, setShowRejectForm] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [previewUrl, setPreviewUrl] = useState<string>('');
  const [previewLoading, setPreviewLoading] = useState(false);
  const [walletAdjustment, setWalletAdjustment] = useState<WalletAdjustmentForm>(emptyWalletAdjustment);
  const [walletAdjusting, setWalletAdjusting] = useState(false);

  useEffect(() => {
    if (selectedUser?.kyc_document_url) {
      setPreviewLoading(true);
      setPreviewUrl('');
      api.get<{ signedUrl: string }>(`admin/files/view?path=${encodeURIComponent(selectedUser.kyc_document_url)}&json=true`)
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
  }, [selectedUser]);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const queryParams = [];
      if (search) queryParams.push(`search=${encodeURIComponent(search)}`);
      if (statusFilter) queryParams.push(`status=${statusFilter}`);
      const queryString = queryParams.length ? `?${queryParams.join('&')}` : '';
      
      const response = await api.get<any>(`admin/users${queryString}`);
      if (response.success && response.data) {
        setUsers(response.data);
      } else {
        throw new Error(response.message || 'Failed to fetch users list');
      }
    } catch (e: any) {
      setError(e.message || 'Error occurred listing users');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const timer = setTimeout(() => {
      fetchUsers();
    }, 300); // Debounce search
    return () => clearTimeout(timer);
  }, [search, statusFilter]);

  const viewUserDetail = async (userId: number) => {
    setDetailsLoading(true);
    setSelectedUser(null);
    setUserDetailPayload(null);
    setDrawerTab('profile');
    setShowRejectForm(false);
    setRejectReason('');
    setWalletAdjustment(emptyWalletAdjustment);
    try {
      const response = await api.get<any>(`admin/users/${userId}`);
      if (response.success && response.data) {
        setUserDetailPayload(response.data);
        // Backend returns: { profile, wallet, investments, withdrawals, kycDocs, bankAccounts }
        const { profile, kycDocs } = response.data;
        // Build a flat shape the drawer expects
        const latestKyc = kycDocs && kycDocs.length > 0 ? kycDocs[0] : null;
        setSelectedUser({
          ...profile,
          kyc_document_url: getKycDocumentPath(latestKyc),
          kyc_rejection_reason: latestKyc?.admin_notes || null,
        });
      } else {
        toast.error(response.message || 'Failed to fetch user details');
      }
    } catch (e: any) {
      toast.error(e.message || 'Error fetching user profile details');
    } finally {
      setDetailsLoading(false);
    }
  };

  const toggleUserStatus = (user: UserDetail) => {
    const nextStatus = user.status === 'active' ? 'suspended' : 'active';
    confirm({
      title: `${nextStatus === 'suspended' ? 'Suspend' : 'Activate'} Client Account`,
      message: `Are you sure you want to change the status of ${user.full_name} to ${nextStatus.toUpperCase()}?`,
      confirmText: nextStatus === 'suspended' ? 'Suspend Account' : 'Activate Account',
      type: nextStatus === 'suspended' ? 'danger' : 'info',
      onConfirm: async () => {
        setActionLoading(true);
        try {
          const response = await api.patch<any>(`admin/users/${user.id}/status`, { status: nextStatus });
          if (response.success) {
            // Update local list
            setUsers(users.map(u => u.id === user.id ? { ...u, status: nextStatus } : u));
            if (selectedUser?.id === user.id) {
              setSelectedUser({ ...selectedUser, status: nextStatus });
            }
            toast.success(`User account status set to ${nextStatus.toUpperCase()} successfully`);
          } else {
            toast.error(response.message || 'Failed to update status');
          }
        } catch (e: any) {
          toast.error(e.message || 'Network error updating user status');
        } finally {
          setActionLoading(false);
        }
      }
    });
  };

  const approveKyc = (userId: number) => {
    confirm({
      title: 'Approve KYC Submission',
      message: 'Are you sure you want to approve this KYC submission? This will mark the client onboarding documents as valid.',
      confirmText: 'Approve KYC',
      type: 'success',
      onConfirm: async () => {
        setActionLoading(true);
        try {
          const response = await api.post<any>(`admin/users/${userId}/kyc/verify`);
          if (response.success) {
            toast.success('KYC verification status approved successfully');
            // Reload list and details
            fetchUsers();
            viewUserDetail(userId);
          } else {
            toast.error(response.message || 'Verification approval failed');
          }
        } catch (e: any) {
          toast.error(e.message || 'Network error verifying KYC');
        } finally {
          setActionLoading(false);
        }
      }
    });
  };

  const rejectKyc = async (userId: number) => {
    if (!rejectReason.trim()) {
      toast.warning('Please specify a rejection reason for the client record.');
      return;
    }
    
    setActionLoading(true);
    try {
      const response = await api.post<any>(`admin/users/${userId}/kyc/reject`, { reason: rejectReason });
      if (response.success) {
        toast.success('KYC submission marked as rejected');
        setShowRejectForm(false);
        setRejectReason('');
        // Reload list and details
        fetchUsers();
        viewUserDetail(userId);
      } else {
        toast.error(response.message || 'Rejection action failed');
      }
    } catch (e: any) {
      toast.error(e.message || 'Network error rejecting KYC');
    } finally {
      setActionLoading(false);
    }
  };

  const submitWalletAdjustment = () => {
    if (!selectedUser) return;

    const amount = Number(walletAdjustment.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      toast.warning('Enter a positive adjustment amount.');
      return;
    }

    if (!walletAdjustment.reason.trim()) {
      toast.warning('Add a reason for the wallet adjustment.');
      return;
    }

    const walletLabel = walletAdjustment.walletType === 'roi' ? 'ROI profit' : 'principal';
    const directionLabel = walletAdjustment.direction === 'credit' ? 'credit' : 'debit';

    confirm({
      title: `Confirm Wallet ${directionLabel}`,
      message: `Apply a ${directionLabel} of Rs. ${amount.toLocaleString()} to ${selectedUser.full_name}'s ${walletLabel} wallet? This action will be written to the wallet ledger and audit log.`,
      confirmText: `Apply ${directionLabel}`,
      type: walletAdjustment.direction === 'debit' ? 'danger' : 'success',
      onConfirm: async () => {
        setWalletAdjusting(true);
        try {
          const response = await api.patch<any>(`admin/users/${selectedUser.id}/wallet`, {
            walletType: walletAdjustment.walletType,
            direction: walletAdjustment.direction,
            amount,
            reason: walletAdjustment.reason.trim(),
          });

          if (response.success) {
            const updatedWallet = response.data?.wallet;
            if (updatedWallet) {
              setUserDetailPayload((current: any) =>
                current ? { ...current, wallet: updatedWallet } : current,
              );
            }
            setWalletAdjustment(emptyWalletAdjustment);
            toast.success('Wallet adjustment recorded successfully');
          } else {
            toast.error(response.message || 'Wallet adjustment failed');
          }
        } catch (e: any) {
          toast.error(e.message || 'Network error adjusting wallet');
        } finally {
          setWalletAdjusting(false);
        }
      },
    });
  };

  const wallet = userDetailPayload?.wallet;
  const hasBackendDepositedTotal = hasNumericValue(wallet?.total_deposited);
  const hasBackendWithdrawnTotal = hasNumericValue(wallet?.total_withdrawn);
  const displayedDepositedTotal = hasBackendDepositedTotal
    ? toMoneyValue(wallet?.total_deposited)
    : sumAmounts(userDetailPayload?.investments);
  const displayedWithdrawnTotal = hasBackendWithdrawnTotal
    ? toMoneyValue(wallet?.total_withdrawn)
    : sumAmounts(userDetailPayload?.withdrawals, ['completed']);
  const depositedTotalLabel = hasBackendDepositedTotal ? 'total deposited' : 'total invested';
  const withdrawnTotalLabel = hasBackendWithdrawnTotal ? 'total settled' : 'settled payouts';

  return (
    <div className="relative">
      <div className="space-y-6 animate-fadeIn">
        <div>
          <h2 className="text-3xl font-extrabold text-white tracking-tight">Users & KYC Audit</h2>
          <p className="text-slate-400 text-sm mt-1">Audit onboarding status, toggle suspensions, and approve client KYC submissions.</p>
        </div>

      {error && (
        <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 flex items-center space-x-3 text-sm">
          <AlertCircle className="w-5 h-5 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Control Grid */}
      <div className="flex flex-col md:flex-row space-y-4 md:space-y-0 md:space-x-4">
        {/* Search */}
        <div className="flex-1 relative">
          <Search className="w-5 h-5 text-slate-500 absolute left-4 top-3.5" />
          <input
            type="text"
            placeholder="Search users by name, mobile number or client ID..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full bg-slate-900/60 border border-slate-800/80 rounded-xl py-3 pl-12 pr-4 text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:border-indigo-500/50 focus:ring-1 focus:ring-indigo-500/30 transition-all duration-300"
          />
        </div>

        {/* Filter */}
        <div className="w-full md:w-64 relative">
          <Filter className="w-4 h-4 text-slate-500 absolute left-4 top-4" />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="w-full bg-slate-900/60 border border-slate-800/80 rounded-xl py-3 pl-10 pr-4 text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:border-indigo-500/50 focus:ring-1 focus:ring-indigo-500/30 transition-all duration-300 appearance-none cursor-pointer"
          >
            <option value="">Filter Status: All</option>
            <option value="active">Active Members</option>
            <option value="suspended">Suspended Accounts</option>
          </select>
        </div>
      </div>

      {/* Layout Grid */}
      <div className="w-full">
        {/* Users Table */}
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
                    <div className="h-5 bg-slate-800 rounded w-20"></div>
                    <div className="h-8 bg-slate-800 rounded-lg w-20"></div>
                  </div>
                </div>
              ))
            ) : users.length === 0 ? (
              <div className="p-12 text-center text-slate-500">
                No matching user profile records found.
              </div>
            ) : (
              users.map((user) => (
                <div
                  key={user.id}
                  className={`p-4 space-y-3 hover:bg-slate-900/10 transition-colors duration-250 cursor-pointer ${
                    selectedUser?.id === user.id ? 'bg-slate-900/20' : ''
                  }`}
                  onClick={() => viewUserDetail(user.id)}
                >
                  <div className="flex justify-between items-center">
                    <span className="font-mono text-xs text-indigo-400 font-semibold">#{user.id}</span>
                    <div className="flex space-x-1.5">
                      <span className={`inline-flex items-center space-x-1.5 px-2.5 py-0.5 rounded-full text-[10px] font-bold ${
                        user.kyc_verified
                          ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                          : 'bg-amber-500/10 text-amber-400 border border-amber-500/20'
                      }`}>
                        <span className={`w-1.5 h-1.5 rounded-full ${user.kyc_verified ? 'bg-emerald-400 animate-pulse' : 'bg-amber-400'}`}></span>
                        <span>{user.kyc_verified ? 'Verified' : 'Pending'}</span>
                      </span>
                      <span className={`inline-flex items-center px-2 py-0.5 rounded text-[10px] font-medium ${
                        user.status === 'active'
                          ? 'bg-blue-500/10 text-blue-400'
                          : 'bg-rose-500/10 text-rose-400'
                      }`}>
                        {user.status === 'active' ? 'Active' : 'Suspended'}
                      </span>
                    </div>
                  </div>

                  <div>
                    <div className="font-semibold text-slate-200 text-sm">{user.full_name}</div>
                    <div className="text-xs text-slate-400 mt-0.5">Mobile: {user.mobile}</div>
                    {user.email && (
                      <div className="text-xs text-slate-500 mt-0.5 truncate">{user.email}</div>
                    )}
                  </div>

                  <div className="flex justify-between items-center pt-2 border-t border-slate-800/40" onClick={(e) => e.stopPropagation()}>
                    <button
                      onClick={() => viewUserDetail(user.id)}
                      className="flex items-center space-x-1 py-1.5 px-3 rounded-lg border border-slate-800 hover:bg-slate-800 text-slate-400 hover:text-slate-100 text-xs transition-all duration-300"
                    >
                      <Eye className="w-3.5 h-3.5" />
                      <span>Details</span>
                    </button>

                    <button
                      onClick={() => toggleUserStatus(user)}
                      disabled={actionLoading}
                      className={`py-1.5 px-3 rounded-lg border text-xs font-semibold cursor-pointer transition-all duration-300 ${
                        user.status === 'active'
                          ? 'border-rose-500/20 hover:bg-rose-500/10 text-rose-400'
                          : 'border-emerald-500/20 hover:bg-emerald-500/10 text-emerald-400'
                      }`}
                    >
                      {user.status === 'active' ? 'Suspend' : 'Activate'}
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
                  <th className="p-4 pl-6">Client ID</th>
                  <th className="p-4">Name / Contact</th>
                  <th className="p-4">KYC State</th>
                  <th className="p-4">Account Status</th>
                  <th className="p-4 pr-6 text-center">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 text-sm">
                {loading ? (
                  Array.from({ length: 5 }).map((_, idx) => (
                    <tr key={idx} className="animate-pulse border-b border-slate-800/40">
                      <td className="p-4 pl-6"><div className="h-4 bg-slate-800 rounded w-8"></div></td>
                      <td className="p-4">
                        <div className="h-4 bg-slate-800 rounded w-32 mb-1.5"></div>
                        <div className="h-3 bg-slate-800/60 rounded w-20"></div>
                      </td>
                      <td className="p-4"><div className="h-6 bg-slate-800 rounded-full w-20"></div></td>
                      <td className="p-4"><div className="h-5 bg-slate-800 rounded w-16"></div></td>
                      <td className="p-4 pr-6 text-center"><div className="h-8 bg-slate-800 rounded-lg w-8 mx-auto"></div></td>
                    </tr>
                  ))
                ) : users.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="p-12 text-center text-slate-500">
                      No matching user profile records found.
                    </td>
                  </tr>
                ) : (
                  users.map((user) => (
                    <tr
                      key={user.id}
                      className={`hover:bg-slate-900/30 transition-colors duration-250 cursor-pointer ${
                        selectedUser?.id === user.id ? 'bg-slate-900/40' : ''
                      }`}
                      onClick={() => viewUserDetail(user.id)}
                    >
                      <td className="p-4 pl-6 font-mono text-xs text-indigo-400 font-semibold">#{user.id}</td>
                      <td className="p-4">
                        <div className="font-semibold text-slate-200">{user.full_name}</div>
                        <div className="text-xs text-slate-500 mt-0.5">{user.mobile}</div>
                      </td>
                      <td className="p-4">
                        <span className={`inline-flex items-center space-x-1.5 px-2.5 py-1 rounded-full text-xs font-bold ${
                          user.kyc_verified
                            ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                            : 'bg-amber-500/10 text-amber-400 border border-amber-500/20'
                        }`}>
                          <span className={`w-1.5 h-1.5 rounded-full ${user.kyc_verified ? 'bg-emerald-400 animate-pulse' : 'bg-amber-400'}`}></span>
                          <span>{user.kyc_verified ? 'Verified' : 'Pending'}</span>
                        </span>
                      </td>
                      <td className="p-4">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                          user.status === 'active'
                            ? 'bg-blue-500/10 text-blue-400'
                            : 'bg-rose-500/10 text-rose-400'
                        }`}>
                          {user.status === 'active' ? 'Active' : 'Suspended'}
                        </span>
                      </td>
                      <td className="p-4 pr-6 text-center" onClick={(e) => e.stopPropagation()}>
                        <div className="flex justify-center space-x-2">
                          <button
                            onClick={() => viewUserDetail(user.id)}
                            className="p-1.5 rounded-lg border border-slate-800 hover:bg-slate-800 text-slate-400 hover:text-slate-100 transition-all duration-300"
                            title="View Profile Details"
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                          
                          <button
                            onClick={() => toggleUserStatus(user)}
                            disabled={actionLoading}
                            className={`p-1.5 rounded-lg border text-xs font-semibold cursor-pointer transition-all duration-300 ${
                              user.status === 'active'
                                ? 'border-rose-500/20 hover:bg-rose-500/10 text-rose-400'
                                : 'border-emerald-500/20 hover:bg-emerald-500/10 text-emerald-400'
                            }`}
                            title={user.status === 'active' ? 'Suspend Account' : 'Activate Account'}
                          >
                            {user.status === 'active' ? 'Suspend' : 'Activate'}
                          </button>
                        </div>
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

    {/* Slide-over Profile / KYC / Dossier Drawer */}
    {selectedUser && (
      <>
        {/* Backdrop */}
        <div 
          className="fixed inset-0 bg-slate-950/70 z-40 animate-fadeIn"
          onClick={() => {
            setSelectedUser(null);
            setUserDetailPayload(null);
          }}
        />
        {/* Drawer */}
        <div className="fixed inset-y-0 right-0 z-50 w-full max-w-2xl h-full bg-slate-950/98 border-l border-slate-800/80 shadow-[-10px_0_30px_-5px_rgba(0,0,0,0.5)] flex flex-col animate-slideIn">
              {/* Header */}
              <div className="p-6 border-b border-slate-800 flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className="p-2 bg-indigo-500/10 rounded-xl text-indigo-400">
                    <FileText className="w-5 h-5" />
                  </div>
                  <div>
                    <h4 className="text-lg font-bold text-slate-100">Audit Dossier</h4>
                    <span className="font-mono text-[10px] text-indigo-400 font-bold uppercase">Client ID: #{selectedUser.id}</span>
                  </div>
                </div>
                <button
                  onClick={() => {
                    setSelectedUser(null);
                    setUserDetailPayload(null);
                  }}
                  className="p-1.5 text-slate-400 hover:text-slate-100 hover:bg-slate-800/40 rounded-lg cursor-pointer transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Tab Navigation */}
              <div className="flex border-b border-slate-800 bg-slate-900/30 overflow-x-auto whitespace-nowrap scrollbar-none flex-nowrap">
                <button
                  onClick={() => setDrawerTab('profile')}
                  className={`flex-shrink-0 sm:flex-1 flex items-center justify-center space-x-1.5 py-3 px-5 sm:px-1 text-xs font-semibold border-b-2 cursor-pointer transition-all duration-200 ${
                    drawerTab === 'profile'
                      ? 'border-indigo-500 text-indigo-400 font-bold bg-indigo-500/5'
                      : 'border-transparent text-slate-400 hover:text-slate-200'
                  }`}
                >
                  <User className="w-3.5 h-3.5" />
                  <span>Profile & KYC</span>
                </button>
                <button
                  onClick={() => setDrawerTab('wallet')}
                  className={`flex-shrink-0 sm:flex-1 flex items-center justify-center space-x-1.5 py-3 px-5 sm:px-1 text-xs font-semibold border-b-2 cursor-pointer transition-all duration-200 ${
                    drawerTab === 'wallet'
                      ? 'border-indigo-500 text-indigo-400 font-bold bg-indigo-500/5'
                      : 'border-transparent text-slate-400 hover:text-slate-200'
                  }`}
                >
                  <Wallet className="w-3.5 h-3.5" />
                  <span>Balances & Banks</span>
                </button>
                <button
                  onClick={() => setDrawerTab('investments')}
                  className={`flex-shrink-0 sm:flex-1 flex items-center justify-center space-x-1.5 py-3 px-5 sm:px-1 text-xs font-semibold border-b-2 cursor-pointer transition-all duration-200 ${
                    drawerTab === 'investments'
                      ? 'border-indigo-500 text-indigo-400 font-bold bg-indigo-500/5'
                      : 'border-transparent text-slate-400 hover:text-slate-200'
                  }`}
                >
                  <Briefcase className="w-3.5 h-3.5" />
                  <span>Investments ({userDetailPayload?.investments?.length || 0})</span>
                </button>
                <button
                  onClick={() => setDrawerTab('withdrawals')}
                  className={`flex-shrink-0 sm:flex-1 flex items-center justify-center space-x-1.5 py-3 px-5 sm:px-1 text-xs font-semibold border-b-2 cursor-pointer transition-all duration-200 ${
                    drawerTab === 'withdrawals'
                      ? 'border-indigo-500 text-indigo-400 font-bold bg-indigo-500/5'
                      : 'border-transparent text-slate-400 hover:text-slate-200'
                  }`}
                >
                  <History className="w-3.5 h-3.5" />
                  <span>Payouts ({userDetailPayload?.withdrawals?.length || 0})</span>
                </button>
              </div>

              {/* Body */}
              <div className="flex-grow overflow-y-auto p-6 space-y-6 custom-scrollbar">
                {detailsLoading ? (
                  <div className="space-y-6 animate-pulse">
                    <div className="bg-slate-900/20 rounded-xl p-4 border border-slate-900 h-28 space-y-3">
                      <div className="h-5 bg-slate-800 rounded w-1/3"></div>
                      <div className="h-4 bg-slate-800 rounded w-1/2"></div>
                    </div>
                    <div className="space-y-3">
                      <div className="h-4 bg-slate-900 rounded w-24"></div>
                      <div className="grid grid-cols-2 gap-4">
                        <div className="h-20 bg-slate-900/60 rounded-xl"></div>
                        <div className="h-20 bg-slate-900/60 rounded-xl"></div>
                      </div>
                    </div>
                  </div>
                ) : (
                  <>
                    {/* Tab: Profile & KYC */}
                    {drawerTab === 'profile' && (
                      <div className="space-y-6 animate-fadeIn">
                        {/* Member card */}
                        <div className="bg-slate-900/40 rounded-xl p-4 border border-slate-800 space-y-3">
                          <div className="flex justify-between items-start">
                            <div>
                              <h5 className="text-base font-bold text-slate-200">{selectedUser.full_name}</h5>
                              <p className="text-xs text-slate-400 mt-0.5">Mobile: {selectedUser.mobile}</p>
                              {selectedUser.email && (
                                <p className="text-xs text-indigo-300 font-medium mt-1 truncate">{selectedUser.email}</p>
                              )}
                            </div>
                            <div className="flex flex-col items-end space-y-2">
                              <span className={`text-[10px] uppercase font-bold tracking-wider px-2.5 py-1 rounded-full border ${
                                selectedUser.status === 'active' 
                                  ? 'bg-emerald-500/5 border-emerald-500/10 text-emerald-400' 
                                  : 'bg-rose-500/5 border-rose-500/10 text-rose-400'
                              }`}>
                                Account: {selectedUser.status}
                              </span>
                              <span className={`text-[10px] uppercase font-bold tracking-wider px-2.5 py-1 rounded-full border ${
                                selectedUser.kyc_verified 
                                  ? 'bg-indigo-500/5 border-indigo-500/10 text-indigo-400' 
                                  : 'bg-amber-500/5 border-amber-500/10 text-amber-400'
                              }`}>
                                KYC: {selectedUser.kyc_verified ? 'Verified' : 'Pending'}
                              </span>
                            </div>
                          </div>

                          <div className="border-t border-slate-800/80 pt-3 flex justify-between items-center text-xs text-slate-500">
                            <div className="flex items-center space-x-1">
                              <Calendar className="w-3.5 h-3.5" />
                              <span>Joined: {new Date(selectedUser.created_at).toLocaleDateString()}</span>
                            </div>
                            <button
                              onClick={() => toggleUserStatus(selectedUser)}
                              disabled={actionLoading}
                              className={`px-3 py-1.5 rounded-lg border text-xs font-semibold cursor-pointer transition-all duration-300 ${
                                selectedUser.status === 'active'
                                  ? 'border-rose-500/20 hover:bg-rose-500/10 text-rose-400'
                                  : 'border-emerald-500/20 hover:bg-emerald-500/10 text-emerald-400'
                              }`}
                            >
                              {selectedUser.status === 'active' ? 'Suspend Account' : 'Activate Account'}
                            </button>
                          </div>
                        </div>

                        {/* Address */}
                        <div className="space-y-1.5">
                          <span className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold block">Registered Payout Address</span>
                          <p className="text-xs text-slate-300 bg-slate-900/30 rounded-xl border border-slate-800/40 p-4 leading-relaxed">
                            {selectedUser.address || 'Address details missing or incomplete.'}
                          </p>
                        </div>

                        {/* KYC Document Scan View */}
                        <div className="space-y-3">
                          <span className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold block">KYC Verification Document</span>
                          
                          {selectedUser.kyc_document_url ? (
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
                                    alt="KYC Document Preview"
                                    className="w-full h-full object-contain opacity-75 group-hover:scale-105 transition-all duration-300 group-hover:opacity-95"
                                    onError={(e) => {
                                      e.currentTarget.style.display = 'none';
                                    }}
                                  />
                                  <span className="absolute bottom-3 right-3 bg-slate-950/80 px-2.5 py-1 rounded text-[10px] font-semibold text-slate-300 group-hover:bg-indigo-600 transition-colors duration-300">
                                    View Scan Fullscreen
                                  </span>
                                </a>
                              ) : (
                                <div className="p-6 rounded-xl border border-dashed border-slate-800/80 text-center text-xs text-slate-500 bg-slate-900/10">
                                  Failed to generate view URL.
                                </div>
                              )}

                              {/* Decisions block */}
                              {!selectedUser.kyc_verified && (
                                <div className="space-y-2 pt-2 border-t border-slate-800/60">
                                  {!showRejectForm ? (
                                    <div className="grid grid-cols-2 gap-3">
                                      <button
                                        onClick={() => approveKyc(selectedUser.id)}
                                        disabled={actionLoading}
                                        className="flex items-center justify-center space-x-1.5 py-2.5 rounded-xl border border-emerald-500/20 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 text-xs font-semibold transition-all duration-300 cursor-pointer"
                                      >
                                        <Check className="w-3.5 h-3.5" />
                                        <span>Approve KYC</span>
                                      </button>
                                      
                                      <button
                                        onClick={() => setShowRejectForm(true)}
                                        className="flex items-center justify-center space-x-1.5 py-2.5 rounded-xl border border-rose-500/20 bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 text-xs font-semibold transition-all duration-300 cursor-pointer"
                                      >
                                        <X className="w-3.5 h-3.5" />
                                        <span>Reject Submission</span>
                                      </button>
                                    </div>
                                  ) : (
                                    <div className="space-y-3 p-3 bg-rose-500/5 rounded-xl border border-rose-500/15 animate-fadeIn">
                                      <label className="text-[10px] font-bold text-rose-400 uppercase">Reason for KYC Rejection</label>
                                      <textarea
                                        rows={3}
                                        placeholder="Specify reason (e.g. Blur proof image, incorrect ID details matching onboarding)..."
                                        value={rejectReason}
                                        onChange={(e) => setRejectReason(e.target.value)}
                                        className="w-full bg-slate-950/80 border border-slate-800 rounded-lg p-2 text-xs text-slate-100 placeholder-slate-500 focus:outline-none focus:border-rose-500/40"
                                      />
                                      <div className="flex space-x-2">
                                        <button
                                          onClick={() => rejectKyc(selectedUser.id)}
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
                              No KYC document scans uploaded yet by user. Onboarding details pending.
                            </div>
                          )}
                        </div>

                        {selectedUser.kyc_rejection_reason && !selectedUser.kyc_verified && (
                          <div className="p-3.5 bg-rose-500/5 rounded-xl border border-rose-500/10 text-rose-400 space-y-1 text-xs">
                            <div className="flex items-center space-x-2">
                              <ShieldAlert className="w-4 h-4 text-rose-500" />
                              <span className="font-semibold">Previously Rejected Submission</span>
                            </div>
                            <p className="opacity-90 leading-relaxed font-mono text-[10px] pl-6">{selectedUser.kyc_rejection_reason}</p>
                          </div>
                        )}

                        {/* Notification Preferences */}
                        <div className="space-y-3">
                          <span className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold block">Notification Permissions</span>
                          <div className="grid grid-cols-2 gap-3 bg-slate-900/20 p-4 rounded-xl border border-slate-800/60 text-xs animate-fadeIn">
                            <div className="flex items-center space-x-2.5">
                              <input
                                type="checkbox"
                                checked={!!selectedUser.notification_preferences?.push}
                                readOnly
                                className="w-4 h-4 rounded border-slate-800 text-indigo-500 bg-slate-950/60 focus:ring-0 focus:ring-offset-0 cursor-not-allowed"
                              />
                              <span className="text-slate-300">Push Notifications</span>
                            </div>
                            <div className="flex items-center space-x-2.5">
                              <input
                                type="checkbox"
                                checked={!!selectedUser.notification_preferences?.investments}
                                readOnly
                                className="w-4 h-4 rounded border-slate-800 text-indigo-500 bg-slate-950/60 focus:ring-0 focus:ring-offset-0 cursor-not-allowed"
                              />
                              <span className="text-slate-300">Investment Alerts</span>
                            </div>
                            <div className="flex items-center space-x-2.5">
                              <input
                                type="checkbox"
                                checked={!!selectedUser.notification_preferences?.wallet}
                                readOnly
                                className="w-4 h-4 rounded border-slate-800 text-indigo-500 bg-slate-950/60 focus:ring-0 focus:ring-offset-0 cursor-not-allowed"
                              />
                              <span className="text-slate-300">Wallet Transactions</span>
                            </div>
                            <div className="flex items-center space-x-2.5">
                              <input
                                type="checkbox"
                                checked={!!selectedUser.notification_preferences?.promotions}
                                readOnly
                                className="w-4 h-4 rounded border-slate-800 text-indigo-500 bg-slate-950/60 focus:ring-0 focus:ring-offset-0 cursor-not-allowed"
                              />
                              <span className="text-slate-300">Promotions & Offers</span>
                            </div>
                          </div>
                        </div>
                      </div>
                    )}

                    {/* Tab: Balances & Banks */}
                    {drawerTab === 'wallet' && (
                      <div className="space-y-6 animate-fadeIn">
                        {/* Balance Grid */}
                        <div className="grid grid-cols-2 gap-4">
                          <div className="bg-slate-900/40 p-4 rounded-xl border border-slate-800">
                            <span className="text-[10px] text-slate-500 uppercase tracking-wider font-semibold block mb-1">ROI profit wallet</span>
                            <div className="flex items-baseline text-amber-400 font-bold text-lg">
                              <IndianRupee className="w-4 h-4 mr-0.5 text-amber-500 self-center" />
                              <span>{(userDetailPayload?.wallet?.roi_balance || 0).toLocaleString()}</span>
                            </div>
                          </div>
                          <div className="bg-slate-900/40 p-4 rounded-xl border border-slate-800">
                            <span className="text-[10px] text-slate-500 uppercase tracking-wider font-semibold block mb-1">principal balance</span>
                            <div className="flex items-baseline text-indigo-400 font-bold text-lg">
                              <IndianRupee className="w-4 h-4 mr-0.5 text-indigo-500 self-center" />
                              <span>{(userDetailPayload?.wallet?.principal_balance || 0).toLocaleString()}</span>
                            </div>
                          </div>
                          <div className="bg-slate-900/40 p-4 rounded-xl border border-slate-800">
                            <span className="text-[10px] text-slate-500 uppercase tracking-wider font-semibold block mb-1">{depositedTotalLabel}</span>
                            <div className="flex items-baseline text-slate-300 font-bold text-lg">
                              <IndianRupee className="w-4 h-4 mr-0.5 text-slate-500 self-center" />
                              <span>{displayedDepositedTotal.toLocaleString()}</span>
                            </div>
                          </div>
                          <div className="bg-slate-900/40 p-4 rounded-xl border border-slate-800">
                            <span className="text-[10px] text-slate-500 uppercase tracking-wider font-semibold block mb-1">{withdrawnTotalLabel}</span>
                            <div className="flex items-baseline text-slate-300 font-bold text-lg">
                              <IndianRupee className="w-4 h-4 mr-0.5 text-slate-500 self-center" />
                              <span>{displayedWithdrawnTotal.toLocaleString()}</span>
                            </div>
                          </div>
                        </div>

                        {/* Wallet Adjustment */}
                        <div className="space-y-3 p-4 rounded-xl border border-slate-800 bg-slate-900/30">
                          <div className="flex items-center justify-between gap-3">
                            <div>
                              <span className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold block">Admin wallet adjustment</span>
                              <p className="text-xs text-slate-400 mt-1">Credits and debits are recorded in the wallet ledger.</p>
                            </div>
                            <Wallet className="w-4 h-4 text-indigo-400 shrink-0" />
                          </div>

                          <div className="grid grid-cols-2 gap-3">
                            <label className="space-y-1.5">
                              <span className="text-[10px] text-slate-500 uppercase tracking-wider font-semibold">Wallet</span>
                              <select
                                value={walletAdjustment.walletType}
                                onChange={(e) =>
                                  setWalletAdjustment((current) => ({
                                    ...current,
                                    walletType: e.target.value as WalletType,
                                  }))
                                }
                                className="w-full bg-slate-950/60 border border-slate-800 rounded-lg px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                                disabled={walletAdjusting}
                              >
                                <option value="roi">ROI profit</option>
                                <option value="principal">Principal</option>
                              </select>
                            </label>

                            <label className="space-y-1.5">
                              <span className="text-[10px] text-slate-500 uppercase tracking-wider font-semibold">Direction</span>
                              <select
                                value={walletAdjustment.direction}
                                onChange={(e) =>
                                  setWalletAdjustment((current) => ({
                                    ...current,
                                    direction: e.target.value as WalletDirection,
                                  }))
                                }
                                className="w-full bg-slate-950/60 border border-slate-800 rounded-lg px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                                disabled={walletAdjusting}
                              >
                                <option value="credit">Credit</option>
                                <option value="debit">Debit</option>
                              </select>
                            </label>
                          </div>

                          <label className="space-y-1.5 block">
                            <span className="text-[10px] text-slate-500 uppercase tracking-wider font-semibold">Amount</span>
                            <div className="relative">
                              <IndianRupee className="w-3.5 h-3.5 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
                              <input
                                type="number"
                                min="0.01"
                                step="0.01"
                                value={walletAdjustment.amount}
                                onChange={(e) =>
                                  setWalletAdjustment((current) => ({
                                    ...current,
                                    amount: e.target.value,
                                  }))
                                }
                                className="w-full bg-slate-950/60 border border-slate-800 rounded-lg pl-8 pr-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                                placeholder="0.00"
                                disabled={walletAdjusting}
                              />
                            </div>
                          </label>

                          <label className="space-y-1.5 block">
                            <span className="text-[10px] text-slate-500 uppercase tracking-wider font-semibold">Reason</span>
                            <textarea
                              value={walletAdjustment.reason}
                              onChange={(e) =>
                                setWalletAdjustment((current) => ({
                                  ...current,
                                  reason: e.target.value,
                                }))
                              }
                              className="w-full min-h-[74px] bg-slate-950/60 border border-slate-800 rounded-lg px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 resize-none"
                              placeholder="Explain the correction for audit review"
                              disabled={walletAdjusting}
                            />
                          </label>

                          <button
                            type="button"
                            onClick={submitWalletAdjustment}
                            disabled={walletAdjusting}
                            className="w-full inline-flex items-center justify-center space-x-2 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-60 disabled:hover:bg-indigo-600 text-white rounded-lg py-2.5 text-xs font-semibold transition-colors"
                          >
                            {walletAdjusting ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Wallet className="w-3.5 h-3.5" />}
                            <span>{walletAdjusting ? 'Recording Adjustment...' : 'Record Wallet Adjustment'}</span>
                          </button>
                        </div>

                        {/* Last ROI Withdrawal date */}
                        {userDetailPayload?.wallet?.last_roi_withdrawal_at && (
                          <div className="text-xs text-slate-500 bg-slate-900/20 border border-slate-800/40 p-3 rounded-lg flex items-center space-x-2">
                            <Calendar className="w-4 h-4 text-indigo-400" />
                            <span>Last ROI profit withdrawal was processed on: <strong>{new Date(userDetailPayload.wallet.last_roi_withdrawal_at).toLocaleDateString()}</strong></span>
                          </div>
                        )}

                        {/* Banks/UPI Accounts */}
                        <div className="space-y-3.5">
                          <span className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold block">Payout Banking Profiles</span>
                          
                          {userDetailPayload?.bankAccounts && userDetailPayload.bankAccounts.length > 0 ? (
                            userDetailPayload.bankAccounts.map((account: any) => (
                              <div key={account.id} className="p-4 bg-slate-900/30 rounded-xl border border-slate-800/80 space-y-3 text-xs">
                                {account.bank_name ? (
                                  <div className="space-y-2">
                                    <div className="flex items-center space-x-2 text-indigo-400 font-semibold border-b border-slate-800/60 pb-1.5 mb-2">
                                      <Building className="w-4 h-4" />
                                      <span>Wire Account ({account.bank_name})</span>
                                    </div>
                                    <div className="grid grid-cols-2 gap-y-2.5 text-slate-300">
                                      <div className="text-slate-500 font-medium">Bank Name:</div>
                                      <div className="font-semibold text-right truncate">{account.bank_name}</div>
                                      
                                      <div className="text-slate-500 font-medium">Account Number:</div>
                                      <div className="font-mono font-semibold text-right select-all">{account.account_number}</div>
                                      
                                      <div className="text-slate-500 font-medium">IFSC Identifier:</div>
                                      <div className="font-mono font-semibold text-right text-indigo-300 select-all">{account.ifsc_code}</div>
                                    </div>
                                  </div>
                                ) : account.upi_id ? (
                                  <div className="space-y-2">
                                    <div className="flex items-center space-x-2 text-indigo-400 font-semibold border-b border-slate-800/60 pb-1.5 mb-2">
                                      <QrCode className="w-4 h-4" />
                                      <span>UPI Direct Address</span>
                                    </div>
                                    <div className="flex justify-between items-center text-slate-300">
                                      <span className="text-slate-500 font-medium">UPI Address ID:</span>
                                      <span className="font-mono font-bold text-slate-200 select-all p-1 bg-slate-950/60 border border-slate-800/40 rounded-md block">
                                        {account.upi_id}
                                      </span>
                                    </div>
                                  </div>
                                ) : null}
                              </div>
                            ))
                          ) : (
                            <div className="p-6 rounded-xl border border-dashed border-slate-800/80 text-center text-xs text-slate-500 bg-slate-900/10">
                              No bank payout coordinates configured by user.
                            </div>
                          )}
                        </div>
                      </div>
                    )}

                    {/* Tab: Investments */}
                    {drawerTab === 'investments' && (
                      <div className="space-y-4 animate-fadeIn">
                        <span className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold block">investment contract history</span>
                        
                        {userDetailPayload?.investments && userDetailPayload.investments.length > 0 ? (
                          <div className="space-y-3">
                            {userDetailPayload.investments.map((inv: any) => (
                              <div key={inv.id} className="p-3.5 bg-slate-900/30 rounded-xl border border-slate-800 flex justify-between items-center text-xs">
                                <div className="space-y-1">
                                  <div className="flex items-center space-x-2">
                                    <span className="font-semibold text-slate-200">₹{inv.amount.toLocaleString()}</span>
                                    <span className="text-[10px] text-indigo-400">({inv.daily_roi_pct}% ROI)</span>
                                  </div>
                                  <div className="text-[10px] text-slate-500">
                                    Placed: {new Date(inv.created_at).toLocaleDateString()} • Lock: {inv.lock_days} days
                                  </div>
                                  {inv.maturity_date && (
                                    <div className="text-[9px] text-slate-400">
                                      Matures: {new Date(inv.maturity_date).toLocaleDateString()}
                                    </div>
                                  )}
                                </div>
                                <span className={`text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded ${
                                  inv.status === 'active' 
                                    ? 'bg-emerald-600/10 text-emerald-400' 
                                    : inv.status === 'pending'
                                    ? 'bg-amber-600/10 text-amber-400'
                                    : inv.status === 'matured'
                                    ? 'bg-blue-600/10 text-blue-400'
                                    : 'bg-rose-500/10 text-rose-400'
                                }`}>
                                  {inv.status}
                                </span>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <div className="p-6 rounded-xl border border-dashed border-slate-800/80 text-center text-xs text-slate-500 bg-slate-900/10">
                            No investments found under profile dossier.
                          </div>
                        )}
                      </div>
                    )}

                    {/* Tab: Payouts */}
                    {drawerTab === 'withdrawals' && (
                      <div className="space-y-4 animate-fadeIn">
                        <span className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold block">withdrawal payout registry</span>
                        
                        {userDetailPayload?.withdrawals && userDetailPayload.withdrawals.length > 0 ? (
                          <div className="space-y-3">
                            {userDetailPayload.withdrawals.map((w: any) => (
                              <div key={w.id} className="p-3.5 bg-slate-900/30 rounded-xl border border-slate-800 flex justify-between items-center text-xs">
                                <div className="space-y-1">
                                  <div className="flex items-center space-x-2">
                                    <span className="font-semibold text-slate-200">₹{w.amount.toLocaleString()}</span>
                                    <span className="text-[9px] uppercase tracking-wider bg-slate-800 text-slate-400 px-1.5 py-0.5 rounded">
                                      {w.withdrawal_type}
                                    </span>
                                  </div>
                                  <div className="text-[10px] text-slate-500">
                                    Requested: {new Date(w.requested_at).toLocaleDateString()}
                                  </div>
                                </div>
                                <span className={`text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded ${
                                  w.status === 'completed' 
                                    ? 'bg-emerald-600/10 text-emerald-400' 
                                    : w.status === 'pending' || w.status === 'requested'
                                    ? 'bg-blue-600/10 text-blue-400'
                                    : w.status === 'approved'
                                    ? 'bg-amber-600/10 text-amber-400'
                                    : 'bg-rose-500/10 text-rose-400'
                                }`}>
                                  {w.status}
                                </span>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <div className="p-6 rounded-xl border border-dashed border-slate-800/80 text-center text-xs text-slate-500 bg-slate-900/10">
                            No withdrawals found under profile dossier.
                          </div>
                        )}
                      </div>
                    )}
                  </>
                )}
              </div>
            </div>
          </>
        )}
    </div>
  );
};
