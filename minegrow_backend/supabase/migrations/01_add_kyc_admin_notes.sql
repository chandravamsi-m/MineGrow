-- ============================================================
-- Migration: Add admin_notes to kyc_documents
-- Fixes: Gap 1 (KYC rejection schema mismatch)
-- 
-- Description:
--   - Adds 'admin_notes' text column to kyc_documents table
--     so rejection notes can be persisted without SQL crashes.
-- ============================================================

ALTER TABLE kyc_documents
  ADD COLUMN IF NOT EXISTS admin_notes TEXT;
