-- Migration: Align base schema with backend fields used by auth/admin/users and plan CRUD.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS address TEXT;

ALTER TABLE investment_plan
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE
  DEFAULT timezone('utc'::text, now()) NOT NULL;
