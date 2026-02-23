import type { PaginatedResponse } from '../types/people';
import { api } from './apiClient';

// =============================================================================
// Feedback Types
// =============================================================================

export interface Feedback {
  id: string;
  org_id: string;
  tenant_id: string;
  person_id: string;
  provider_id: string;
  provider_relationship?: 'manager' | 'peer' | 'direct_report' | 'cross_functional' | 'self';
  feedback_type: 'positive' | 'constructive' | 'general' | '360_degree';
  feedback_text: string;
  strengths?: string;
  areas_for_improvement?: string;
  overall_rating?: number;
  is_anonymous: boolean;
  is_visible_to_subject: boolean;
  review_id?: string;
  acknowledged_at?: string;
  created_at: string;
  updated_at: string;

  // Relations
  person?: { id: string; full_name: string; avatar_url?: string; job_title?: string };
  provider?: { id: string; full_name: string; avatar_url?: string };
}

export interface CreateFeedbackPayload {
  person_id: string;
  provider_id: string;
  provider_relationship?: string;
  feedback_type: string;
  feedback_text: string;
  strengths?: string;
  areas_for_improvement?: string;
  overall_rating?: number;
  is_anonymous?: boolean;
  is_visible_to_subject?: boolean;
  review_id?: string;
}

// =============================================================================
// FEEDBACK API
// =============================================================================

export const feedbackApi = {
  getAll: async (params?: {
    person_id?: string;
    provider_id?: string;
    feedback_type?: string;
    page?: number;
    limit?: number;
  }): Promise<PaginatedResponse<Feedback>> => {
    return api.get<PaginatedResponse<Feedback>>('/feedback', params);
  },

  getById: async (id: string): Promise<Feedback> => {
    return api.get<Feedback>(`/feedback/${id}`);
  },

  create: async (data: CreateFeedbackPayload): Promise<Feedback> => {
    return api.post<Feedback>('/feedback', data);
  },

  acknowledge: async (id: string): Promise<Feedback> => {
    return api.patch<Feedback>(`/feedback/${id}/acknowledge`, {});
  },
};
