export const API_BASE = (import.meta.env?.VITE_MATHSDRILL_API || '/api/v1').replace(/\/+$/, '');

const DEFAULT_TIMEOUT = 45000;

export class ApiError extends Error {
  constructor(message, { status = 0, kind = 'network' } = {}) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.kind = kind;
  }
}

export async function apiRequest(path, { method = 'GET', body, headers, timeout = DEFAULT_TIMEOUT } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);
  try {
    const response = await fetch(`${API_BASE}${path}`, {
      method,
      body,
      headers,
      credentials: 'include',
      signal: controller.signal,
    });

    if (response.status === 401 || response.status === 403) {
      throw new ApiError('Sign in to Penrose to use the MathsDrill AI service.', {
        status: response.status,
        kind: 'auth',
      });
    }
    if (response.status === 404) {
      throw new ApiError('This build is not connected to the MathsDrill service.', {
        status: 404,
        kind: 'unavailable',
      });
    }
    if (!response.ok) {
      let detail = '';
      try {
        const payload = await response.json();
        detail = payload?.detail || payload?.message || '';
      } catch {
        /* non-JSON error body */
      }
      throw new ApiError(detail || `Request failed (${response.status}).`, {
        status: response.status,
        kind: 'server',
      });
    }
    return await response.json();
  } catch (error) {
    if (error instanceof ApiError) throw error;
    if (error?.name === 'AbortError') {
      throw new ApiError('The request timed out. Check your connection and try again.', { kind: 'timeout' });
    }
    throw new ApiError('Could not reach the MathsDrill service. Check your connection and try again.', {
      kind: 'network',
    });
  } finally {
    clearTimeout(timer);
  }
}

export async function discoverProviders() {
  const candidates = ['/mathsdrill/providers', '/ai/providers'];
  for (const path of candidates) {
    try {
      const payload = await apiRequest(path, { timeout: 12000 });
      const list = Array.isArray(payload) ? payload : payload?.providers;
      if (Array.isArray(list) && list.length) {
        return list.map((entry) => ({
          id: entry.id || entry.slug || entry.provider || entry.name,
          name: entry.label || entry.name || entry.provider || entry.id,
          models: (entry.models || entry.model_names || []).map((model) =>
            typeof model === 'string' ? { id: model, name: model } : { id: model.id || model.name, name: model.label || model.name || model.id },
          ),
        }));
      }
    } catch {
      /* try the next candidate */
    }
  }
  return [];
}
