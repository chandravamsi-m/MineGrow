import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import {
  Search,
  Filter,
  Check,
  X,
  AlertCircle,
  Eye,
  CheckSquare,
  ShieldAlert,
  Loader2,
  FileText,
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
}

export const UsersList: React.FC = () => {
  const [users, setUsers] = useState<UserDetail[]>([]);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Selected user for details drawer
  const [selectedUser, setSelectedUser] = useState<UserDetail | null>(null);
  const [detailsLoading, setDetailsLoading] = useState(false);
  
  // KYC Rejection state
  const [rejectReason, setRejectReason] = useState('');
  const [showRejectForm, setShowRejectForm] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);

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
    setShowRejectForm(false);
    setRejectReason('');
    try {
      const response = await api.get<any>(`admin/users/${userId}`);
      if (response.success && response.data) {
        // Backend returns: { profile, wallet, investments, withdrawals, kycDocs, bankAccounts }
        const { profile, kycDocs } = response.data;
        // Build a flat shape the drawer expects
        const latestKyc = kycDocs && kycDocs.length > 0 ? kycDocs[0] : null;
        setSelectedUser({
          ...profile,
          kyc_document_url: latestKyc?.document_url || null,
          kyc_rejection_reason: latestKyc?.admin_notes || null,
        });
      } else {
        alert(response.message || 'Failed to fetch user details');
      }
    } catch (e: any) {
      alert(e.message || 'Error fetching user profile details');
    } finally {
      setDetailsLoading(false);
    }
  };

  const toggleUserStatus = async (user: UserDetail) => {
    const nextStatus = user.status === 'active' ? 'suspended' : 'active';
    if (!window.confirm(`Are you sure you want to change the status of ${user.full_name} to ${nextStatus.toUpperCase()}?`)) {
      return;
    }
    
    setActionLoading(true);
    try {
      const response = await api.patch<any>(`admin/users/${user.id}/status`, { status: nextStatus });
      if (response.success) {
        // Update local list
        setUsers(users.map(u => u.id === user.id ? { ...u, status: nextStatus } : u));
        if (selectedUser?.id === user.id) {
          setSelectedUser({ ...selectedUser, status: nextStatus });
        }
      } else {
        alert(response.message || 'Failed to update status');
      }
    } catch (e: any) {
      alert(e.message || 'Network error updating user status');
    } finally {
      setActionLoading(false);
    }
  };

  const approveKyc = async (userId: number) => {
    if (!window.confirm('Are you sure you want to approve this KYC submission?')) {
      return;
    }
    
    setActionLoading(true);
    try {
      const response = await api.post<any>(`admin/users/${userId}/kyc/verify`);
      if (response.success) {
        alert('KYC verification status approved successfully');
        // Reload list and details
        fetchUsers();
        viewUserDetail(userId);
      } else {
        alert(response.message || 'Verification approval failed');
      }
    } catch (e: any) {
      alert(e.message || 'Network error verifying KYC');
    } finally {
      setActionLoading(false);
    }
  };

  const rejectKyc = async (userId: number) => {
    if (!rejectReason.trim()) {
      alert('Please specify a rejection reason for the client record.');
      return;
    }
    
    setActionLoading(true);
    try {
      const response = await api.post<any>(`admin/users/${userId}/kyc/reject`, { reason: rejectReason });
      if (response.success) {
        alert('KYC submission marked as rejected');
        setShowRejectForm(false);
        setRejectReason('');
        // Reload list and details
        fetchUsers();
        viewUserDetail(userId);
      } else {
        alert(response.message || 'Rejection action failed');
      }
    } catch (e: any) {
      alert(e.message || 'Network error rejecting KYC');
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div className="space-y-6 animate-fadeIn relative">
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

      {/* Tables Grid */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6 items-start">
        {/* Users Table */}
        <div className="xl:col-span-2 glass-panel rounded-2xl overflow-hidden shadow-2xl">
          <div className="overflow-x-auto custom-scrollbar">
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
                  <tr>
                    <td colSpan={5} className="p-12 text-center text-slate-500">
                      <div className="flex flex-col items-center justify-center space-y-3">
                        <Loader2 className="w-8 h-8 animate-spin text-indigo-500" />
                        <span>Loading member database records...</span>
                      </div>
                    </td>
                  </tr>
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

        {/* Profile / KYC Verification Drawer */}
        <div className="xl:col-span-1 glass-panel rounded-2xl p-6 shadow-2xl h-full space-y-6">
          <div className="flex items-center space-x-2 border-b border-slate-800 pb-4">
            <FileText className="w-5 h-5 text-indigo-400" />
            <h4 className="text-lg font-bold text-slate-100">Audit Desk</h4>
          </div>

          {detailsLoading ? (
            <div className="flex flex-col items-center justify-center py-12 text-slate-500 space-y-3">
              <Loader2 className="w-8 h-8 animate-spin text-indigo-400" />
              <span>Fetching profile dossier...</span>
            </div>
          ) : !selectedUser ? (
            <div className="text-center py-16 text-slate-500 text-sm">
              Select a member from the database registry grid to inspect their dossier profile and review KYC documents.
            </div>
          ) : (
            <div className="space-y-6 animate-fadeIn">
              {/* Profile Card Header */}
              <div className="bg-slate-950/40 rounded-xl p-4 border border-slate-800 space-y-2">
                <div className="flex items-center justify-between">
                  <span className="font-mono text-[10px] text-indigo-400 font-bold">DOSSIER #{selectedUser.id}</span>
                  <span className={`text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded ${
                    selectedUser.status === 'active' ? 'bg-indigo-600/10 text-indigo-400' : 'bg-rose-500/10 text-rose-400'
                  }`}>
                    {selectedUser.status}
                  </span>
                </div>
                <h5 className="text-base font-bold text-slate-100">{selectedUser.full_name}</h5>
                <p className="text-xs text-slate-400">{selectedUser.mobile}</p>
                {selectedUser.email && (
                  <p className="text-xs text-indigo-300 font-medium truncate">{selectedUser.email}</p>
                )}
              </div>

              {/* Address details */}
              <div className="space-y-1">
                <span className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold block">Registered Payout Address</span>
                <p className="text-xs text-slate-300 bg-slate-900/30 rounded-lg border border-slate-800/40 p-3 leading-relaxed">
                  {selectedUser.address || 'Address details missing or incomplete.'}
                </p>
              </div>

              {/* KYC Document Scan View */}
              <div className="space-y-3">
                <span className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold block">KYC Verification Document</span>
                
                {selectedUser.kyc_document_url ? (
                  <div className="space-y-3">
                    <a
                      href={`http://localhost:3000${selectedUser.kyc_document_url}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="group relative block rounded-xl overflow-hidden border border-slate-800 bg-slate-950/50 aspect-video flex items-center justify-center hover:border-indigo-500/30 transition-all duration-300 shadow-inner"
                    >
                      <img
                        src={`http://localhost:3000${selectedUser.kyc_document_url}`}
                        alt="KYC Document Preview"
                        className="w-full h-full object-cover opacity-60 group-hover:scale-105 transition-all duration-300 group-hover:opacity-85"
                        onError={(e) => {
                          // Fallback
                          e.currentTarget.style.display = 'none';
                        }}
                      />
                      <span className="absolute bottom-3 right-3 bg-slate-950/80 px-2.5 py-1 rounded text-[10px] font-semibold text-slate-300 group-hover:bg-indigo-600 transition-colors duration-300">
                        View Scan Fullscreen
                      </span>
                    </a>

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
                  <div className="p-6 rounded-xl border border-dashed border-slate-800/80 text-center text-xs text-slate-500">
                    No KYC document scans uploaded yet by user. Onboarding details pending.
                  </div>
                )}
              </div>

              {selectedUser.kyc_verified && (
                <div className="p-3 bg-emerald-500/5 rounded-xl border border-emerald-500/10 text-emerald-400 flex items-center space-x-2.5 text-xs">
                  <CheckSquare className="w-4 h-4 flex-shrink-0" />
                  <span>Dossier audit complete. KYC validation approved.</span>
                </div>
              )}

              {selectedUser.kyc_rejection_reason && !selectedUser.kyc_verified && (
                <div className="p-3 bg-rose-500/5 rounded-xl border border-rose-500/10 text-rose-400 space-y-1 text-xs">
                  <div className="flex items-center space-x-2">
                    <ShieldAlert className="w-4 h-4" />
                    <span className="font-semibold">Previously Rejected Submission</span>
                  </div>
                  <p className="opacity-90 leading-relaxed font-mono text-[10px] pl-6">{selectedUser.kyc_rejection_reason}</p>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
