import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import {
  ArrowUpRight,
  ArrowDownLeft,
  ChevronLeft,
  ChevronRight,
  AlertCircle,
  Loader2,
  Calendar,
} from 'lucide-react';

interface LedgerEntry {
  id: number;
  user_id: number;
  amount: number;
  transaction_type: 'deposit' | 'roi' | 'withdrawal' | 'principal_return';
  description: string;
  reference_id?: number | null;
  created_at: string;
  users?: {
    full_name: string;
    email: string | null;
    mobile: string;
  } | null;
}

export const LedgerViewer: React.FC = () => {
  const [entries, setEntries] = useState<LedgerEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Pagination
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const limit = 20;

  const fetchLedger = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const response = await api.get<any>(`admin/reports/ledger?page=${page}&limit=${limit}`);
      if (response.success && response.data) {
        // Backend returns: { data: ledger[], pagination: { page, limit, total, totalPages } }
        const ledgerData = response.data.data || [];
        const paginationMeta = response.data.pagination || {};
        setEntries(ledgerData);
        setTotalCount(paginationMeta.total || 0);
      } else {
        throw new Error(response.message || 'Failed to fetch ledger logs');
      }
    } catch (e: any) {
      setError(e.message || 'Error occurred listing ledger entries');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLedger();
  }, [page]);

  const totalPages = Math.ceil(totalCount / limit) || 1;

  return (
    <div className="space-y-6 animate-fadeIn">
      <div>
        <h2 className="text-3xl font-extrabold text-white tracking-tight">System Audit Ledger</h2>
        <p className="text-slate-400 text-sm mt-1">Audit complete double-entry records, cash balances, deposits, and daily generated ROI interest payouts.</p>
      </div>

      {error && (
        <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 flex items-center space-x-3 text-sm">
          <AlertCircle className="w-5 h-5 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Main Ledger Table */}
      <div className="glass-panel rounded-2xl overflow-hidden shadow-2xl">
        <div className="overflow-x-auto custom-scrollbar">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-slate-800 bg-slate-950/40 text-xs font-semibold text-slate-400 uppercase tracking-wider">
                <th className="p-4 pl-6">ID</th>
                <th className="p-4">Transaction Date</th>
                <th className="p-4">Client Contact</th>
                <th className="p-4">Transaction Detail / Reference</th>
                <th className="p-4">Type</th>
                <th className="p-4 pr-6 text-right">Audited Amount</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 text-sm">
              {loading ? (
                <tr>
                  <td colSpan={6} className="p-12 text-center text-slate-500">
                    <div className="flex flex-col items-center justify-center space-y-3">
                      <Loader2 className="w-8 h-8 animate-spin text-indigo-500" />
                      <span>Retrieving audit books...</span>
                    </div>
                  </td>
                </tr>
              ) : entries.length === 0 ? (
                <tr>
                  <td colSpan={6} className="p-12 text-center text-slate-500">
                    No ledger transactions matching books found.
                  </td>
                </tr>
              ) : (
                entries.map((entry) => {
                  const isCredit = ['deposit', 'roi', 'principal_return'].includes(entry.transaction_type);
                  
                  return (
                    <tr key={entry.id} className="hover:bg-slate-900/30 transition-colors duration-250">
                      <td className="p-4 pl-6 font-mono text-xs text-indigo-400 font-semibold">#{entry.id}</td>
                      <td className="p-4 text-slate-400 text-xs whitespace-nowrap">
                        <div className="flex items-center space-x-1.5">
                          <Calendar className="w-3.5 h-3.5 text-slate-500" />
                          <span>{new Date(entry.created_at).toLocaleString()}</span>
                        </div>
                      </td>
                      <td className="p-4">
                        <div className="font-semibold text-slate-200">
                          {entry.users?.full_name || 'System Auto-Engine'}
                        </div>
                        <div className="text-[10px] text-slate-500 mt-0.5 font-mono">
                          Client: #{entry.user_id}
                        </div>
                      </td>
                      <td className="p-4">
                        <div className="text-slate-300 text-xs leading-normal">{entry.description}</div>
                        {entry.reference_id && (
                          <span className="text-[10px] text-indigo-400 font-medium">Reference Ref: #{entry.reference_id}</span>
                        )}
                      </td>
                      <td className="p-4">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded text-[10px] uppercase font-bold tracking-wider ${
                          entry.transaction_type === 'deposit'
                            ? 'bg-blue-500/10 text-blue-400'
                            : entry.transaction_type === 'roi'
                            ? 'bg-amber-500/10 text-amber-400'
                            : entry.transaction_type === 'withdrawal'
                            ? 'bg-rose-500/10 text-rose-400'
                            : 'bg-purple-500/10 text-purple-400'
                        }`}>
                          {entry.transaction_type.replace('_', ' ')}
                        </span>
                      </td>
                      <td className={`p-4 pr-6 text-right font-bold text-base whitespace-nowrap ${
                        isCredit ? 'text-emerald-400' : 'text-rose-400'
                      }`}>
                        <div className="flex items-center justify-end">
                          {isCredit ? (
                            <ArrowDownLeft className="w-4 h-4 mr-0.5 text-emerald-500" />
                          ) : (
                            <ArrowUpRight className="w-4 h-4 mr-0.5 text-rose-500" />
                          )}
                          <span>₹{entry.amount.toLocaleString()}</span>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination controls footer */}
        {!loading && totalPages > 1 && (
          <div className="p-4 bg-slate-950/40 border-t border-slate-800 flex flex-col sm:flex-row justify-between items-center space-y-4 sm:space-y-0 text-xs">
            <span className="text-slate-500 font-semibold uppercase tracking-wider">
              Showing {(page - 1) * limit + 1} - {Math.min(page * limit, totalCount)} of {totalCount} books
            </span>

            <div className="flex items-center space-x-2">
              <button
                onClick={() => setPage(p => Math.max(p - 1, 1))}
                disabled={page === 1}
                className="p-2 bg-slate-900 border border-slate-800 rounded-lg hover:border-slate-700 disabled:opacity-40 disabled:cursor-not-allowed text-slate-300 transition-all duration-300 cursor-pointer"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>

              <div className="px-4 py-2 bg-slate-900 border border-slate-800 rounded-lg font-bold text-slate-200">
                Page {page} of {totalPages}
              </div>

              <button
                onClick={() => setPage(p => Math.min(p + 1, totalPages))}
                disabled={page === totalPages}
                className="p-2 bg-slate-900 border border-slate-800 rounded-lg hover:border-slate-700 disabled:opacity-40 disabled:cursor-not-allowed text-slate-300 transition-all duration-300 cursor-pointer"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
