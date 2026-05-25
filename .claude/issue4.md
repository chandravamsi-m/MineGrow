## Context
Currently `GET /investments` returns each record with only `plan_id`. The mobile app (PR #6) cross-references the plans list client-side, but it's cleaner and avoids edge-case "Investment Plan" fallbacks when the plans list hasn't loaded yet if the backend joins the plan name into the response.

This is **purely additive** — mobile already handles its absence, so no coordinated release required.

## Acceptance criteria
- [ ] `GET /investments` response includes `plan_name` on each record
- [ ] Same change on `GET /admin/investments` so admin panel can also show plan names

## File to modify
`minegrow_backend/src/investments/investments.service.ts`

## Suggested Supabase query change
```ts
const { data } = await this.supabase
  .from('investments')
  .select('*, plans(plan_name)')
  .eq('user_id', userId);

// Flatten:
return data.map(r => ({ ...r, plan_name: r.plans?.plan_name, plans: undefined }));
```

## Mobile-side wiring (already done in PR #6)
- `InvestmentRecord.planName` field (optional) added — parses `plan_name` / `planName` from response
- Active + pending investment cards prefer `record.planName` over client-side lookup
