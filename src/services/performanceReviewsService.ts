import type { PaginatedResponse } from '../types/people';
import type { ReviewTemplate } from './reviewTemplatesService';

// =============================================================================
// Performance Review Types
// =============================================================================

export interface PerformanceReview {
  id: string;
  org_id: string;
  tenant_id: string;
  person_id: string;
  template_id: string;
  reviewer_id: string;
  review_period_start: string;
  review_period_end: string;
  self_review_deadline?: string;
  manager_review_deadline?: string;
  status: 'draft' | 'self_review_pending' | 'manager_review_pending' | 'completed' | 'cancelled';
  self_review_data?: Record<string, unknown>; // JSONB
  manager_review_data?: Record<string, unknown>; // JSONB
  overall_rating?: number;
  self_review_submitted_at?: string;
  manager_review_submitted_at?: string;
  completed_at?: string;
  created_at: string;
  updated_at: string;
  created_by?: string;
  updated_by?: string;

  // Relations
  person?: { id: string; full_name: string; avatar_url?: string; job_title?: string };
  template?: { id: string; name: string; review_type: string };
  reviewer?: { id: string; full_name: string };
}

export interface CreatePerformanceReviewPayload {
  person_id: string;
  template_id: string;
  reviewer_id: string;
  review_period_start: string;
  review_period_end: string;
  self_review_deadline?: string;
  manager_review_deadline?: string;
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
// PERFORMANCE REVIEWS API
// =============================================================================

export const performanceReviewsApi = {
  getAll: async (params?: { person_id?: string; reviewer_id?: string; status?: string; page?: number; limit?: number }): Promise<PaginatedResponse<PerformanceReview>> => {
    return api.get<PaginatedResponse<PerformanceReview>>('/performance-reviews', params);
  },

  getById: async (id: string): Promise<PerformanceReview> => {
    return api.get<PerformanceReview>(`/performance-reviews/${id}`);
  },

  create: async (data: CreatePerformanceReviewPayload): Promise<PerformanceReview> => {
    return api.post<PerformanceReview>('/performance-reviews', data);
  },

  update: async (id: string, data: Partial<PerformanceReview>): Promise<PerformanceReview> => {
    return api.patch<PerformanceReview>(`/performance-reviews/${id}`, data);
  },

  delete: async (id: string): Promise<{ message: string }> => {
    return api.delete<{ message: string }>(`/performance-reviews/${id}`);
  },

  getMyReviews: async (): Promise<PaginatedResponse<PerformanceReview>> => {
    return api.get<PaginatedResponse<PerformanceReview>>('/performance-reviews/my-reviews');
  },

  submitSelfReview: async (id: string, data: Record<string, unknown>): Promise<PerformanceReview> => {
    return api.post<PerformanceReview>(`/performance-reviews/${id}/submit-self-review`, { self_review_data: data });
  },

  submitManagerReview: async (id: string, data: Record<string, unknown>, overallRating?: number): Promise<PerformanceReview> => {
    return api.post<PerformanceReview>(`/performance-reviews/${id}/submit-manager-review`, {
      manager_review_data: data,
      overall_rating: overallRating,
    });
  },

  complete: async (id: string): Promise<PerformanceReview> => {
    return api.post<PerformanceReview>(`/performance-reviews/${id}/complete`, {});
  },
};

// =============================================================================
// SERVICE CONFIGURATION
// =============================================================================

export const performanceReviewsService = {
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
