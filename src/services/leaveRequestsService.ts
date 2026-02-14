import type { PaginatedResponse } from '../types/people';

// =============================================================================
// Leave Request Types
// =============================================================================

export interface LeaveRequest {
  id: string;
  org_id: string;
  tenant_id: string;
  person_id: string;
  leave_type_id: string;
  start_date: string;
  end_date: string;
  is_half_day_start: boolean;
  is_half_day_end: boolean;
  total_days: number;
  reason?: string;
  status: 'draft' | 'pending' | 'approved' | 'rejected' | 'cancelled';
  submitted_at?: string;
  reviewed_by?: string;
  reviewed_at?: string;
  rejection_reason?: string;
  created_at: string;
  updated_at: string;
  created_by?: string;
  updated_by?: string;

  // Relations
  person?: { id: string; full_name: string; avatar_url?: string; email?: string };
  leave_type?: { id: string; name: string; code: string; color?: string };
  reviewer?: { id: string; full_name: string };
}

export interface CreateLeaveRequestPayload {
  person_id: string;
  leave_type_id: string;
  start_date: string;
  end_date: string;
  is_half_day_start?: boolean;
  is_half_day_end?: boolean;
  reason?: string;
}

export interface LeaveBalance {
  person_id: string;
  leave_type_id: string;
  leave_type_name: string;
  total_entitled: number;
  used: number;
  pending: number;
  available: number;
  carried_forward: number;
}

// =============================================================================
// API Client
// =============================================================================

const API_BASE_URL = '/people-api';
let TENANT_ID = '';
let ORG_ID = '';
let USER_ID = '';
let USER_NAME = '';
let ACCESS_TOKEN = '';

class ApiClient {
  private baseURL: string;

  constructor(baseURL: string) {
    this.baseURL = baseURL;
  }

  private getHeaders(): HeadersInit {
    return {
      'Content-Type': 'application/json',
      'X-Tenant-Id': TENANT_ID,
      'X-Org-Id': ORG_ID,
      'X-User-Id': USER_ID,
      'X-User-Name': USER_NAME,
      ...(ACCESS_TOKEN ? { Authorization: `Bearer ${ACCESS_TOKEN}` } : {}),
    };
  }

  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${this.baseURL}${endpoint}`;

    try {
      const response = await fetch(url, {
        ...options,
        headers: { ...this.getHeaders(), ...options.headers },
      });

      const text = await response.text();

      if (!response.ok) {
        let errorMessage = `API Error: ${response.status}`;
        try {
          const errorJson = JSON.parse(text);
          errorMessage = errorJson.message || errorJson.error || errorMessage;
        } catch {
          errorMessage = text || errorMessage;
        }
        throw new Error(errorMessage);
      }

      try {
        return JSON.parse(text);
      } catch {
        throw new Error(`Invalid JSON response: ${text.substring(0, 100)}`);
      }
    } catch (error) {
      console.error(`API request failed: ${endpoint}`, error);
      throw error;
    }
  }

  async get<T>(endpoint: string, params?: Record<string, unknown>): Promise<T> {
    const queryString = params
      ? '?' + new URLSearchParams(
          Object.entries(params).reduce((acc, [key, value]) => {
            if (value !== undefined && value !== null && value !== '') {
              acc[key] = String(value);
            }
            return acc;
          }, {} as Record<string, string>)
        ).toString()
      : '';
    return this.request<T>(`${endpoint}${queryString}`, { method: 'GET' });
  }

  async post<T>(endpoint: string, data: unknown): Promise<T> {
    return this.request<T>(endpoint, { method: 'POST', body: JSON.stringify(data) });
  }

  async patch<T>(endpoint: string, data: unknown): Promise<T> {
    return this.request<T>(endpoint, { method: 'PATCH', body: JSON.stringify(data) });
  }

  async delete<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'DELETE' });
  }
}

const api = new ApiClient(API_BASE_URL);

// =============================================================================
// LEAVE REQUESTS API
// =============================================================================

export const leaveRequestsApi = {
  getAll: async (params?: { person_id?: string; status?: string; from_date?: string; to_date?: string; page?: number; limit?: number }): Promise<PaginatedResponse<LeaveRequest>> => {
    return api.get<PaginatedResponse<LeaveRequest>>('/leave-requests', params);
  },

  getById: async (id: string): Promise<LeaveRequest> => {
    return api.get<LeaveRequest>(`/leave-requests/${id}`);
  },

  create: async (data: CreateLeaveRequestPayload): Promise<LeaveRequest> => {
    return api.post<LeaveRequest>('/leave-requests', data);
  },

  update: async (id: string, data: Partial<LeaveRequest>): Promise<LeaveRequest> => {
    return api.patch<LeaveRequest>(`/leave-requests/${id}`, data);
  },

  delete: async (id: string): Promise<{ message: string }> => {
    return api.delete<{ message: string }>(`/leave-requests/${id}`);
  },

  submit: async (id: string): Promise<LeaveRequest> => {
    return api.post<LeaveRequest>(`/leave-requests/${id}/submit`, {});
  },

  approve: async (id: string): Promise<LeaveRequest> => {
    return api.post<LeaveRequest>(`/leave-requests/${id}/approve`, {});
  },

  reject: async (id: string, reason: string): Promise<LeaveRequest> => {
    return api.post<LeaveRequest>(`/leave-requests/${id}/reject`, { reason });
  },

  getPendingApprovals: async (): Promise<PaginatedResponse<LeaveRequest>> => {
    return api.get<PaginatedResponse<LeaveRequest>>('/leave-requests/pending-approvals');
  },

  getBalances: async (personId: string): Promise<{ data: LeaveBalance[] }> => {
    return api.get<{ data: LeaveBalance[] }>(`/leave-balances/${personId}`);
  },
};

// =============================================================================
// SERVICE CONFIGURATION
// =============================================================================

export const leaveRequestsService = {
  setTenantId: (id: string) => { TENANT_ID = id; },
  setOrgId: (id: string) => { ORG_ID = id; },
  setUserId: (id: string) => { USER_ID = id; },
  setUserName: (name: string) => { USER_NAME = name; },
  setAccessToken: (token: string) => { ACCESS_TOKEN = token; },

  setUser: (user: { id: string; email: string; full_name?: string; name?: string }) => {
    USER_ID = user.id;
    USER_NAME = user.full_name || user.name || user.email;
  },
};
