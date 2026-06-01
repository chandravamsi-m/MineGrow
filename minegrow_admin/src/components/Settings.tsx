import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import { useToast } from '../context/ToastContext';
import { useConfirm } from '../context/ConfirmContext';
import {
  Settings as SettingsIcon,
  CreditCard,
  Clock,
  Save,
  RefreshCw,
  AlertCircle,
  Mail,
  Phone,
  FileText,
  ShieldAlert,
  LifeBuoy,
} from 'lucide-react';

type FieldKind = 'text' | 'number' | 'email' | 'tel' | 'url' | 'textarea' | 'select';

interface ConfigField {
  key: string;
  label: string;
  description: string;
  placeholder: string;
  kind: FieldKind;
  icon: React.ComponentType<{ className?: string }>;
  iconTint: string;
  group: 'payments' | 'auth' | 'support' | 'legal' | 'system';
  min?: number;
  max?: number;
  required?: boolean;
  options?: { value: string; label: string }[];
  defaultValue?: string;
  validate?: (value: string) => string | null;
}

const FIELDS: ConfigField[] = [
  {
    key: 'payment_upi_id',
    label: 'Payment Gateway UPI ID',
    description: 'UPI / VPA displayed to users on the deposit sheet. Must be linked to the settlement account.',
    placeholder: 'pay@gateway',
    kind: 'text',
    icon: CreditCard,
    iconTint: 'emerald',
    group: 'payments',
    required: true,
  },
  {
    key: 'otp_resend_delay',
    label: 'OTP Resend Delay (seconds)',
    description: 'Throttle for the mobile OTP resend button. Lower values cost more SMS; higher values risk drop-off.',
    placeholder: '30',
    kind: 'number',
    icon: Clock,
    iconTint: 'indigo',
    group: 'auth',
    min: 10,
    max: 300,
    required: true,
  },
  {
    key: 'support_email',
    label: 'Support Email',
    description: 'Customer support email shown inside the mobile profile + onboarding screens.',
    placeholder: 'support@minegrow.app',
    kind: 'email',
    icon: Mail,
    iconTint: 'sky',
    group: 'support',
    required: true,
  },
  {
    key: 'support_phone',
    label: 'Support Phone',
    description: 'Phone number shown alongside support email. Include country code (e.g. +91 90000 00000).',
    placeholder: '+91 90000 00000',
    kind: 'tel',
    icon: Phone,
    iconTint: 'amber',
    group: 'support',
    required: true,
  },
  {
    key: 'terms_url',
    label: 'Terms of Service URL',
    description: 'Linked from the mobile login footer and profile legal section.',
    placeholder: 'https://minegrow.app/terms',
    kind: 'url',
    icon: FileText,
    iconTint: 'violet',
    group: 'legal',
    required: true,
  },
  {
    key: 'privacy_url',
    label: 'Privacy Policy URL',
    description: 'Linked from the mobile login footer and profile legal section.',
    placeholder: 'https://minegrow.app/privacy',
    kind: 'url',
    icon: ShieldAlert,
    iconTint: 'fuchsia',
    group: 'legal',
    required: true,
  },
  {
    key: 'risk_disclosure',
    label: 'Risk Disclosure Text',
    description: 'Long-form disclosure shown on the invest screen. Plain text, no markdown.',
    placeholder: 'Mining investment returns depend on active plan terms…',
    kind: 'textarea',
    icon: LifeBuoy,
    iconTint: 'rose',
    group: 'legal',
    required: true,
  },
  {
    key: 'maintenance_mode',
    label: 'Maintenance Mode',
    description:
      'When on, the mobile app shows a blocking "under maintenance" screen at launch and users cannot proceed.',
    placeholder: 'false',
    kind: 'select',
    icon: ShieldAlert,
    iconTint: 'rose',
    group: 'system',
    defaultValue: 'false',
    options: [
      { value: 'false', label: 'Operational' },
      { value: 'true', label: 'Maintenance mode (block app)' },
    ],
  },
  {
    key: 'maintenance_message',
    label: 'Maintenance Message',
    description:
      'Shown on the maintenance screen. Only displayed while maintenance mode is on.',
    placeholder: 'MineGrow is briefly down for maintenance. Please check back shortly.',
    kind: 'textarea',
    icon: LifeBuoy,
    iconTint: 'amber',
    group: 'system',
  },
  {
    key: 'min_supported_version',
    label: 'Minimum Supported Version',
    description:
      'Force-update gate. Clients older than this semver (e.g. 1.2.0) are blocked at launch. Leave blank to disable.',
    placeholder: '1.0.0',
    kind: 'text',
    icon: RefreshCw,
    iconTint: 'indigo',
    group: 'system',
    validate: (v) =>
      v.trim() && !/^\d+\.\d+\.\d+$/.test(v.trim())
        ? 'Use semver format x.y.z (e.g. 1.2.0) or leave blank'
        : null,
  },
  {
    key: 'update_url',
    label: 'Update URL',
    description:
      'Store link opened by the force-update screen. Leave blank to use the default Play Store / App Store link.',
    placeholder: 'https://play.google.com/store/apps/details?id=com.minegrow.app',
    kind: 'url',
    icon: FileText,
    iconTint: 'sky',
    group: 'system',
  },
];

const TINT_BG: Record<string, string> = {
  emerald: 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400',
  indigo: 'bg-indigo-500/10 border-indigo-500/20 text-indigo-400',
  sky: 'bg-sky-500/10 border-sky-500/20 text-sky-400',
  amber: 'bg-amber-500/10 border-amber-500/20 text-amber-400',
  violet: 'bg-violet-500/10 border-violet-500/20 text-violet-400',
  fuchsia: 'bg-fuchsia-500/10 border-fuchsia-500/20 text-fuchsia-400',
  rose: 'bg-rose-500/10 border-rose-500/20 text-rose-400',
};

const GROUP_TITLES: Record<ConfigField['group'], string> = {
  payments: 'Payments',
  auth: 'Authentication',
  support: 'Support contacts',
  legal: 'Legal & compliance',
  system: 'App availability & updates',
};

function validateField(field: ConfigField, value: string): string | null {
  const trimmed = value.trim();
  if (field.required && !trimmed) return `${field.label} is required`;

  if (field.kind === 'number') {
    const n = Number(trimmed);
    if (!Number.isFinite(n)) return `${field.label} must be a number`;
    if (field.min !== undefined && n < field.min) return `${field.label} must be ≥ ${field.min}`;
    if (field.max !== undefined && n > field.max) return `${field.label} must be ≤ ${field.max}`;
  }

  if (field.kind === 'email' && trimmed && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)) {
    return `${field.label} must be a valid email`;
  }

  if (field.kind === 'url' && trimmed && !/^https?:\/\/.+/i.test(trimmed)) {
    return `${field.label} must start with http:// or https://`;
  }

  const custom = field.validate?.(value);
  if (custom) return custom;

  return null;
}

export const Settings: React.FC = () => {
  const [values, setValues] = useState<Record<string, string>>({});
  const [original, setOriginal] = useState<Record<string, string>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
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
      const list: { key: string; value: string }[] = Array.isArray(response)
        ? response
        : Array.isArray(response?.data)
          ? response.data
          : [];

      const map: Record<string, string> = {};
      for (const field of FIELDS) {
        const found = list.find((c) => c.key === field.key);
        map[field.key] = found
          ? String(found.value ?? '')
          : (field.defaultValue ?? '');
      }
      setValues(map);
      setOriginal(map);
      setErrors({});
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

  const updateValue = (key: string, value: string) => {
    setValues((prev) => ({ ...prev, [key]: value }));
    setErrors((prev) => {
      if (!prev[key]) return prev;
      const next = { ...prev };
      delete next[key];
      return next;
    });
  };

  const changedFields = FIELDS.filter((f) => values[f.key] !== original[f.key]);
  const hasChanges = changedFields.length > 0;

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();

    const nextErrors: Record<string, string> = {};
    for (const field of FIELDS) {
      const msg = validateField(field, values[field.key] ?? '');
      if (msg) nextErrors[field.key] = msg;
    }
    if (Object.keys(nextErrors).length > 0) {
      setErrors(nextErrors);
      toast.error('Fix the highlighted fields before saving');
      return;
    }

    if (!hasChanges) {
      toast.error('No changes to save');
      return;
    }

    confirm({
      title: 'Update App Parameters',
      message: `You are about to update ${changedFields.length} configuration ${
        changedFields.length === 1 ? 'value' : 'values'
      }. These changes are applied globally and take effect on the next request.`,
      confirmText: 'Save Parameters',
      type: 'warning',
      onConfirm: async () => {
        setSaving(true);
        try {
          for (const field of changedFields) {
            await api.patch(`admin/app-config/${field.key}`, {
              value: values[field.key].trim(),
            });
          }
          toast.success(
            changedFields.length === 1
              ? '1 configuration updated successfully'
              : `${changedFields.length} configurations updated successfully`,
          );
          fetchConfigs();
        } catch (err: any) {
          toast.error(err.message || 'Failed to save configuration settings');
        } finally {
          setSaving(false);
        }
      },
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
          {Array.from({ length: 4 }).map((_, i) => (
            <div
              key={i}
              className="h-48 bg-slate-900/60 border border-slate-900/80 rounded-2xl p-6"
            ></div>
          ))}
        </div>
      </div>
    );
  }

  const groups: ConfigField['group'][] = [
    'payments',
    'auth',
    'support',
    'legal',
    'system',
  ];

  return (
    <div className="space-y-8 animate-fadeIn">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center space-y-4 md:space-y-0">
        <div>
          <h2 className="text-3xl font-extrabold text-white tracking-tight flex items-center space-x-3">
            <SettingsIcon className="w-8 h-8 text-indigo-400" />
            <span>App Parameters</span>
          </h2>
          <p className="text-slate-400 text-sm mt-1">
            Runtime configuration consumed by the mobile app and the backend. Changes apply immediately.
          </p>
        </div>
        <button
          onClick={fetchConfigs}
          className="flex items-center space-x-2 px-4 py-2 text-xs font-semibold bg-slate-900/60 border border-slate-800/80 hover:bg-slate-800/60 rounded-xl text-slate-300 transition-all cursor-pointer"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          <span>Reload</span>
        </button>
      </div>

      {error && (
        <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 flex items-center space-x-3 text-sm">
          <AlertCircle className="w-5 h-5 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}

      <form onSubmit={handleSave} className="space-y-10">
        {groups.map((group) => {
          const fields = FIELDS.filter((f) => f.group === group);
          if (fields.length === 0) return null;
          return (
            <section key={group} className="space-y-4">
              <div className="flex items-baseline justify-between">
                <h3 className="text-sm font-bold text-slate-200 uppercase tracking-wider">
                  {GROUP_TITLES[group]}
                </h3>
                <span className="text-[10px] text-slate-500">
                  {fields.length} {fields.length === 1 ? 'setting' : 'settings'}
                </span>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {fields.map((field) => {
                  const Icon = field.icon;
                  const tint = TINT_BG[field.iconTint] || TINT_BG.indigo;
                  const value = values[field.key] ?? '';
                  const fieldError = errors[field.key];
                  const isDirty = value !== (original[field.key] ?? '');
                  return (
                    <div
                      key={field.key}
                      className="glass-panel p-6 rounded-2xl space-y-5 border border-slate-900/60"
                    >
                      <div className="flex items-start space-x-3 border-b border-slate-800 pb-4">
                        <div className={`p-2 border rounded-xl ${tint}`}>
                          <Icon className="w-5 h-5" />
                        </div>
                        <div className="flex-1">
                          <h4 className="text-base font-bold text-slate-100 flex items-center space-x-2">
                            <span>{field.label}</span>
                            {isDirty && (
                              <span className="text-[9px] uppercase tracking-wider px-1.5 py-0.5 rounded bg-amber-500/15 text-amber-300 border border-amber-500/30">
                                Unsaved
                              </span>
                            )}
                          </h4>
                          <p className="text-[11px] text-slate-500 mt-1 leading-relaxed">
                            {field.description}
                          </p>
                        </div>
                      </div>

                      <div className="space-y-2">
                        <label className="text-[10px] text-slate-500 uppercase tracking-wider font-bold">
                          Value
                        </label>
                        {field.kind === 'textarea' ? (
                          <textarea
                            value={value}
                            onChange={(e) => updateValue(field.key, e.target.value)}
                            placeholder={field.placeholder}
                            rows={4}
                            className={`w-full bg-slate-900/60 border rounded-xl py-3 px-4 text-sm text-slate-200 focus:outline-none placeholder-slate-700 transition-colors resize-y ${
                              fieldError
                                ? 'border-rose-500/60 focus:border-rose-500/80'
                                : 'border-slate-800 focus:border-indigo-500/40'
                            }`}
                          />
                        ) : field.kind === 'select' ? (
                          <select
                            value={value || (field.defaultValue ?? '')}
                            onChange={(e) => updateValue(field.key, e.target.value)}
                            className={`w-full bg-slate-900/60 border rounded-xl py-3 px-4 text-sm text-slate-200 focus:outline-none transition-colors ${
                              fieldError
                                ? 'border-rose-500/60 focus:border-rose-500/80'
                                : 'border-slate-800 focus:border-indigo-500/40'
                            }`}
                          >
                            {(field.options ?? []).map((opt) => (
                              <option key={opt.value} value={opt.value}>
                                {opt.label}
                              </option>
                            ))}
                          </select>
                        ) : (
                          <input
                            type={field.kind === 'number' ? 'number' : field.kind}
                            value={value}
                            min={field.min}
                            max={field.max}
                            placeholder={field.placeholder}
                            onChange={(e) => updateValue(field.key, e.target.value)}
                            className={`w-full bg-slate-900/60 border rounded-xl py-3 px-4 text-sm text-slate-200 focus:outline-none placeholder-slate-700 transition-colors ${
                              fieldError
                                ? 'border-rose-500/60 focus:border-rose-500/80'
                                : 'border-slate-800 focus:border-indigo-500/40'
                            }`}
                          />
                        )}
                        {fieldError && (
                          <p className="text-[11px] text-rose-400 flex items-center space-x-1">
                            <AlertCircle className="w-3 h-3" />
                            <span>{fieldError}</span>
                          </p>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </section>
          );
        })}

        <div className="flex flex-col md:flex-row md:justify-between md:items-center gap-3 pt-4 border-t border-slate-900/80">
          <div className="text-xs text-slate-500">
            {hasChanges ? (
              <span>
                <span className="text-amber-300 font-semibold">{changedFields.length}</span>{' '}
                unsaved {changedFields.length === 1 ? 'change' : 'changes'}
              </span>
            ) : (
              <span>All settings up to date</span>
            )}
          </div>
          <button
            type="submit"
            disabled={saving || !hasChanges}
            className={`flex items-center justify-center space-x-2 px-8 py-3.5 bg-gradient-to-r from-indigo-600 to-indigo-500 hover:from-indigo-500 hover:to-indigo-400 text-white rounded-xl font-bold text-xs tracking-wider transition-all shadow-lg shadow-indigo-600/20 ${
              saving || !hasChanges ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer active:scale-98'
            }`}
          >
            <Save className="w-4 h-4" />
            <span>{saving ? 'Saving…' : 'Save Parameters'}</span>
          </button>
        </div>
      </form>
    </div>
  );
};
