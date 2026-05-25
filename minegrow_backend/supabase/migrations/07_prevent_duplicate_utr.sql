-- Prevent the same payment UTR/reference from being submitted more than once.
-- Empty/null UTRs remain allowed for providers that do not expose a reference.

CREATE UNIQUE INDEX IF NOT EXISTS idx_investments_utr_number_unique
ON investments (lower(utr_number))
WHERE utr_number IS NOT NULL AND utr_number <> '';
