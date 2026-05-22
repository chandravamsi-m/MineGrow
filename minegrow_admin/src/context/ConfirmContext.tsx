import React, { createContext, useContext, useState } from 'react';
import { ShieldAlert, AlertTriangle, Info, CheckCircle2, X } from 'lucide-react';

interface ConfirmOptions {
  title: string;
  message: string;
  confirmText?: string;
  cancelText?: string;
  type?: 'danger' | 'warning' | 'info' | 'success';
  onConfirm: () => void | Promise<void>;
}

interface ConfirmContextType {
  confirm: (options: ConfirmOptions) => void;
}

const ConfirmContext = createContext<ConfirmContextType | undefined>(undefined);

export const useConfirm = () => {
  const context = useContext(ConfirmContext);
  if (!context) {
    throw new Error('useConfirm must be used within a ConfirmProvider');
  }
  return context.confirm;
};

export const ConfirmProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [options, setOptions] = useState<ConfirmOptions | null>(null);
  const [isOpen, setIsOpen] = useState(false);
  const [loading, setLoading] = useState(false);

  const confirm = (opts: ConfirmOptions) => {
    setOptions(opts);
    setIsOpen(true);
    setLoading(false);
  };

  const handleClose = () => {
    if (loading) return;
    setIsOpen(false);
    setTimeout(() => setOptions(null), 200);
  };

  const handleConfirm = async () => {
    if (!options) return;
    setLoading(true);
    try {
      await options.onConfirm();
    } catch (err) {
      console.error('Error during confirm callback:', err);
    } finally {
      setLoading(false);
      setIsOpen(false);
      setTimeout(() => setOptions(null), 200);
    }
  };

  const getIcon = () => {
    switch (options?.type) {
      case 'danger':
        return <ShieldAlert className="w-6 h-6 text-rose-500" />;
      case 'success':
        return <CheckCircle2 className="w-6 h-6 text-emerald-500" />;
      case 'info':
        return <Info className="w-6 h-6 text-blue-500" />;
      case 'warning':
      default:
        return <AlertTriangle className="w-6 h-6 text-amber-500" />;
    }
  };

  const getConfirmButtonStyles = () => {
    switch (options?.type) {
      case 'danger':
        return 'bg-rose-600 hover:bg-rose-500 text-white shadow-rose-900/20';
      case 'success':
        return 'bg-emerald-600 hover:bg-emerald-500 text-white shadow-emerald-900/20';
      case 'info':
        return 'bg-blue-600 hover:bg-blue-500 text-white shadow-blue-900/20';
      case 'warning':
      default:
        return 'bg-amber-600 hover:bg-amber-500 text-white shadow-amber-900/20';
    }
  };

  return (
    <ConfirmContext.Provider value={{ confirm }}>
      {children}
      {isOpen && options && (
        <div className="fixed inset-0 z-999 flex items-center justify-center px-4">
          {/* Backdrop */}
          <div 
            className="fixed inset-0 bg-slate-950/85 transition-opacity duration-300 animate-fadeIn"
            onClick={handleClose}
          />
          
          {/* Modal Content */}
          <div className="relative glass-panel rounded-2xl p-6 max-w-md w-full mx-auto shadow-2xl border border-slate-800/80 z-10 transform transition-all duration-300 animate-scaleUp">
            {/* Close button */}
            <button 
              onClick={handleClose} 
              disabled={loading}
              className="absolute top-4 right-4 p-1 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-800/40 transition-colors"
            >
              <X className="w-4 h-4" />
            </button>

            {/* Header info */}
            <div className="flex items-center space-x-3 mb-3">
              <div className="p-2 rounded-xl bg-slate-950/50 border border-slate-800">
                {getIcon()}
              </div>
              <h3 className="text-lg font-bold text-white tracking-tight">{options.title}</h3>
            </div>

            {/* Message */}
            <p className="text-slate-300 text-sm leading-relaxed mb-6 pl-1">
              {options.message}
            </p>

            {/* Buttons */}
            <div className="flex justify-end space-x-3">
              <button
                type="button"
                onClick={handleClose}
                disabled={loading}
                className="px-4 py-2 text-xs font-semibold rounded-xl text-slate-400 hover:text-slate-200 hover:bg-slate-800/40 border border-transparent transition-all duration-200"
              >
                {options.cancelText || 'Cancel'}
              </button>
              <button
                type="button"
                onClick={handleConfirm}
                disabled={loading}
                className={`px-4 py-2 text-xs font-bold rounded-xl shadow-lg transition-all duration-200 flex items-center space-x-1.5 ${getConfirmButtonStyles()}`}
              >
                {loading ? (
                  <span className="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-1"></span>
                ) : null}
                <span>{options.confirmText || 'Confirm'}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </ConfirmContext.Provider>
  );
};
