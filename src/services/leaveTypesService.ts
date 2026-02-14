import type { PaginatedResponse } from '../types/people';

// =============================================================================
// Leave Type Types
// =============================================================================

export interface LeaveType {
  id: string;
  org_id: string;
  tenant_id: string;
  code: string;
  name: string;
  description?: string;
  is_paid: boolean;
  requires_approval: boolean;
  requires_documentation: boolean;
  accrual_type: 'annual' | 'monthly' | 'none';
  max_days_per_year?: number;
  accrual_rate?: number;
  carry_forward_allowed: boolean;
  max_carry_forward_days?: number;
  notice_period_days?: number;
  color?: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  created_by?: string;
  updated_by?: string;
}

export interface CreateLeaveTypePayload {
  code: string;
  name: string;
  description?: string;
  is_paid?: boolean;
  requires_approval?: boolean;
  requires_documentation?: boolean;
  accrual_type?: 'annual' | 'monthly' | 'none';
  max_days_per_year?: number;
  accrual_rate?: number;
  carry_forward_allowed?: boolean;
  max_carry_forward_days?: number;
  notice_period_days?: number;
  color?: string;
  is_active?: boolean;
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
// LEAVE TYPES API
// =============================================================================

export const leaveTypesApi = {
  getAll: async (params?: { is_active?: boolean; page?: number; limit?: number }): Promise<PaginatedResponse<LeaveType>> => {
    return api.get<PaginatedResponse<LeaveType>>('/leave-types', params);
  },

  getById: async (id: string): Promise<LeaveType> => {
    return api.get<LeaveType>(`/leave-types/${id}`);
  },

  create: async (data: CreateLeaveTypePayload): Promise<LeaveType> => {
    return api.post<LeaveType>('/leave-types', data);
  },

  update: async (id: string, data: Partial<LeaveType>): Promise<LeaveType> => {
    return api.patch<LeaveType>(`/leave-types/${id}`, data);
  },

  delete: async (id: string): Promise<{ message: string }> => {
    return api.delete<{ message: string }>(`/leave-types/${id}`);
  },
};

// =============================================================================
// SERVICE CONFIGURATION
// =============================================================================

export const leaveTypesService = {
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
