import type { PaginatedResponse } from '../types/people';

// =============================================================================
// Goal Types
// =============================================================================

export interface Goal {
  id: string;
  org_id: string;
  tenant_id: string;
  person_id: string;
  title: string;
  description?: string;
  goal_type: 'individual' | 'team' | 'company' | 'development';
  start_date?: string;
  target_date: string;
  measurement_criteria?: string;
  target_value?: number;
  current_value?: number;
  unit?: string; // e.g., "sales", "projects", "%"
  priority: 'low' | 'medium' | 'high' | 'critical';
  status: 'draft' | 'in_progress' | 'completed' | 'cancelled';
  progress_percentage: number;
  completed_at?: string;
  created_at: string;
  updated_at: string;
  created_by?: string;
  updated_by?: string;

  // Relations
  person?: { id: string; full_name: string; avatar_url?: string; job_title?: string };
}

export interface CreateGoalPayload {
  person_id: string;
  title: string;
  description?: string;
  goal_type: 'individual' | 'team' | 'company' | 'development';
  start_date?: string;
  target_date: string;
  measurement_criteria?: string;
  target_value?: number;
  current_value?: number;
  unit?: string;
  priority?: 'low' | 'medium' | 'high' | 'critical';
  status?: 'draft' | 'in_progress' | 'completed' | 'cancelled';
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
// GOALS API
// =============================================================================

export const goalsApi = {
  getAll: async (params?: { person_id?: string; status?: string; goal_type?: string; page?: number; limit?: number }): Promise<PaginatedResponse<Goal>> => {
    return api.get<PaginatedResponse<Goal>>('/goals', params);
  },

  getById: async (id: string): Promise<Goal> => {
    return api.get<Goal>(`/goals/${id}`);
  },

  create: async (data: CreateGoalPayload): Promise<Goal> => {
    return api.post<Goal>('/goals', data);
  },

  update: async (id: string, data: Partial<Goal>): Promise<Goal> => {
    return api.patch<Goal>(`/goals/${id}`, data);
  },

  delete: async (id: string): Promise<{ message: string }> => {
    return api.delete<{ message: string }>(`/goals/${id}`);
  },

  updateProgress: async (id: string, currentValue: number): Promise<Goal> => {
    return api.post<Goal>(`/goals/${id}/update-progress`, { current_value: currentValue });
  },

  complete: async (id: string): Promise<Goal> => {
    return api.post<Goal>(`/goals/${id}/complete`, {});
  },
};

// =============================================================================
// SERVICE CONFIGURATION
// =============================================================================

export const goalsService = {
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
