const configuredBaseUrl = import.meta.env.VITE_BASE_URL?.trim();

if (!configuredBaseUrl && !import.meta.env.DEV) {
  throw new Error(
    'CRITICAL CONFIGURATION ERROR: The VITE_BASE_URL environment variable is missing or empty. ' +
    'The production build/runtime requires VITE_BASE_URL to be defined to communicate with the backend API. ' +
    'Please set VITE_BASE_URL in your environment or production .env file.'
  );
}

const BASE_URL = (
  configuredBaseUrl ||
  (import.meta.env.DEV ? 'http://localhost:3000/api/v1' : '')
).replace(/\/+$/, '');

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  message?: string;
  pagination?: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
  error?: {
    code: string;
    message: string;
    statusCode: number;
  };
}

class ApiService {
  private onUnauthorizedCallback: (() => void) | null = null;

  registerOnUnauthorized(callback: () => void) {
    this.onUnauthorizedCallback = callback;
  }

  private buildUrl(path: string): string {
    const cleanPath = path.replace(/^\/+/, '');
    return `${BASE_URL}/${cleanPath}`;
  }

  private getHeaders(isMultipart = false): HeadersInit {
    const token = localStorage.getItem('admin_access_token');
    const headers: Record<string, string> = {};
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    if (!isMultipart) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  private async handleResponse<T>(response: Response): Promise<T> {
    if (response.status === 401) {
      // Automatic session cleanup on unauthorized — React state handles showing the login page
      localStorage.removeItem('admin_access_token');
      localStorage.removeItem('admin_user');
      if (this.onUnauthorizedCallback) {
        this.onUnauthorizedCallback();
      }
      throw new Error('Session expired. Please log in again.');
    }

    const contentType = response.headers.get('Content-Type') || '';
    if (contentType.includes('text/csv')) {
      return (await response.text()) as any;
    }

    let payload: any;
    try {
      payload = await response.json();
    } catch {
      throw new Error('Unable to parse server response.');
    }

    if (!response.ok) {
      const errorMsg = payload?.error?.message || payload?.message || 'An unexpected error occurred.';
      throw new Error(errorMsg);
    }

    return payload;
  }

  async get<T>(path: string): Promise<T> {
    const response = await fetch(this.buildUrl(path), {
      method: 'GET',
      headers: this.getHeaders(),
    });
    return this.handleResponse<T>(response);
  }

  async post<T>(path: string, body?: any): Promise<T> {
    const response = await fetch(this.buildUrl(path), {
      method: 'POST',
      headers: this.getHeaders(),
      body: body ? JSON.stringify(body) : undefined,
    });
    return this.handleResponse<T>(response);
  }

  async put<T>(path: string, body: any): Promise<T> {
    const response = await fetch(this.buildUrl(path), {
      method: 'PUT',
      headers: this.getHeaders(),
      body: JSON.stringify(body),
    });
    return this.handleResponse<T>(response);
  }

  async patch<T>(path: string, body?: any): Promise<T> {
    const response = await fetch(this.buildUrl(path), {
      method: 'PATCH',
      headers: this.getHeaders(),
      body: body ? JSON.stringify(body) : undefined,
    });
    return this.handleResponse<T>(response);
  }

  async delete<T>(path: string): Promise<T> {
    const response = await fetch(this.buildUrl(path), {
      method: 'DELETE',
      headers: this.getHeaders(),
    });
    return this.handleResponse<T>(response);
  }

  async download(path: string): Promise<string> {
    const response = await fetch(this.buildUrl(path), {
      method: 'GET',
      headers: this.getHeaders(),
    });
    return this.handleResponse<string>(response);
  }
}

export const api = new ApiService();
