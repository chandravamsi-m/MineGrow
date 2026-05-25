export interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}

export const getPaginationWindow = (
  page?: number,
  limit?: number,
  defaultLimit = 50,
  maxLimit = 100,
) => {
  const safePage = Number.isFinite(page) && page && page > 0 ? Math.floor(page) : 1;
  const requestedLimit =
    Number.isFinite(limit) && limit && limit > 0 ? Math.floor(limit) : defaultLimit;
  const safeLimit = Math.min(requestedLimit, maxLimit);
  const from = (safePage - 1) * safeLimit;
  const to = from + safeLimit - 1;

  return {
    page: safePage,
    limit: safeLimit,
    from,
    to,
  };
};

export const buildPaginationMeta = (
  page: number,
  limit: number,
  total: number,
): PaginationMeta => ({
  page,
  limit,
  total,
  totalPages: Math.max(1, Math.ceil(total / limit)),
});
