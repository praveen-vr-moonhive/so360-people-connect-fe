-- SO360 People Connect - Performance Reviews & Goals
-- Review Templates, Performance Reviews, Goals, 360-Degree Feedback

-- =============================================================================
-- 1. REVIEW TEMPLATES (Reusable Review Structures)
-- =============================================================================

CREATE TABLE IF NOT EXISTS review_templates (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  org_id UUID NOT NULL,
  tenant_id UUID NOT NULL,

  -- Template Identity
  name TEXT NOT NULL,                                -- e.g., 'Annual Review 2024', 'Quarterly Check-in'
  description TEXT,
  review_type TEXT NOT NULL CHECK (review_type IN (
    'annual',
    'quarterly',
    'probation',
    'project_end',
    'custom'
  )),

  -- Review Structure (JSONB for flexibility)
  sections JSONB NOT NULL DEFAULT '[]',              -- Array of review sections
  /* Example structure:
    [
      {
        "id": "goals",
        "title": "Goal Achievement",
        "description": "Rate achievement of goals",
        "weight": 30,
        "fields": [
          {"type": "rating", "label": "Overall goal achievement", "max": 5},
          {"type": "textarea", "label": "Comments"}
        ]
      },
      {
        "id": "skills",
        "title": "Skills & Competencies",
        "weight": 40,
        "fields": [...]
      }
    ]
  */

  -- Rating Configuration
  rating_scale INTEGER DEFAULT 5 CHECK (rating_scale IN (3, 5, 10, 100)),
  rating_labels JSONB DEFAULT '{}',                  -- {1: "Poor", 2: "Fair", 3: "Good", 4: "Very Good", 5: "Excellent"}

  -- Workflow Configuration
  requires_self_review BOOLEAN DEFAULT TRUE,
  requires_manager_review BOOLEAN DEFAULT TRUE,
  requires_peer_feedback BOOLEAN DEFAULT FALSE,
  requires_upward_feedback BOOLEAN DEFAULT FALSE,    -- Feedback to manager

  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  is_default BOOLEAN DEFAULT FALSE,                  -- Default template for type

  -- Metadata
  meta JSONB DEFAULT '{}',

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID,
  updated_by UUID,

  CONSTRAINT unique_template_name_per_org UNIQUE(org_id, name)
);

CREATE INDEX idx_review_templates_org_id ON review_templates(org_id);
CREATE INDEX idx_review_templates_tenant_id ON review_templates(tenant_id);
CREATE INDEX idx_review_templates_review_type ON review_templates(review_type);
CREATE INDEX idx_review_templates_is_active ON review_templates(is_active);

-- RLS
ALTER TABLE review_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON review_templates FOR ALL USING (true) WITH CHECK (true);

-- =============================================================================
-- 2. PERFORMANCE REVIEWS (Review Instances)
-- =============================================================================

CREATE TABLE IF NOT EXISTS performance_reviews (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  org_id UUID NOT NULL,
  tenant_id UUID NOT NULL,
  person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,
  template_id UUID NOT NULL REFERENCES review_templates(id) ON DELETE RESTRICT,

  -- Review Period
  review_period_start DATE NOT NULL,
  review_period_end DATE NOT NULL,
  review_name TEXT,                                  -- e.g., 'John Doe - Annual Review 2024'

  -- Reviewers
  reviewer_id UUID NOT NULL,                         -- Manager/reviewer
  reviewer_name TEXT,                                -- Denormalized for historical record

  -- Review Data (JSONB for flexibility)
  self_review_data JSONB DEFAULT '{}',               -- Employee's self-review responses
  manager_review_data JSONB DEFAULT '{}',            -- Manager's review responses
  peer_feedback_data JSONB DEFAULT '[]',             -- Array of peer feedback
  upward_feedback_data JSONB DEFAULT '{}',           -- Upward feedback

  -- Overall Rating
  overall_rating NUMERIC(4,2),                       -- Computed or manually set
  overall_comments TEXT,

  -- Workflow Status
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN (
    'draft',                  -- Being prepared
    'self_review_pending',    -- Waiting for employee self-review
    'manager_review_pending', -- Waiting for manager review
    'completed',              -- Review completed
    'cancelled'               -- Review cancelled
  )),

  -- Timestamps
  self_review_submitted_at TIMESTAMP WITH TIME ZONE,
  self_review_deadline DATE,
  manager_review_submitted_at TIMESTAMP WITH TIME ZONE,
  manager_review_deadline DATE,
  completed_at TIMESTAMP WITH TIME ZONE,

  -- Acknowledgment
  acknowledged_by_employee BOOLEAN DEFAULT FALSE,
  acknowledged_at TIMESTAMP WITH TIME ZONE,
  employee_comments TEXT,                            -- Employee's response to review

  -- Visibility
  is_visible_to_employee BOOLEAN DEFAULT FALSE,

  -- Metadata
  meta JSONB DEFAULT '{}',

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID,
  updated_by UUID,

  -- Constraints
  CONSTRAINT valid_review_period CHECK (review_period_end >= review_period_start),
  CONSTRAINT valid_overall_rating CHECK (overall_rating IS NULL OR (overall_rating >= 0 AND overall_rating <= 10))
);

CREATE INDEX idx_performance_reviews_org_id ON performance_reviews(org_id);
CREATE INDEX idx_performance_reviews_tenant_id ON performance_reviews(tenant_id);
CREATE INDEX idx_performance_reviews_person_id ON performance_reviews(person_id);
CREATE INDEX idx_performance_reviews_reviewer_id ON performance_reviews(reviewer_id);
CREATE INDEX idx_performance_reviews_status ON performance_reviews(status);
CREATE INDEX idx_performance_reviews_period ON performance_reviews(review_period_start, review_period_end);

-- RLS
ALTER TABLE performance_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON performance_reviews FOR ALL USING (true) WITH CHECK (true);

-- =============================================================================
-- 3. GOALS (OKR Tracking)
-- =============================================================================

CREATE TABLE IF NOT EXISTS goals (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  org_id UUID NOT NULL,
  tenant_id UUID NOT NULL,
  person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,

  -- Goal Details
  title TEXT NOT NULL,
  description TEXT,
  goal_type TEXT NOT NULL CHECK (goal_type IN (
    'individual',      -- Individual performance goal
    'team',            -- Team goal
    'company',         -- Company-wide goal
    'development'      -- Learning/development goal
  )),

  -- Period
  start_date DATE NOT NULL,
  target_date DATE NOT NULL,

  -- Tracking
  progress_percentage INTEGER DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
  status TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN (
    'draft',
    'in_progress',
    'completed',
    'cancelled',
    'deferred'
  )),

  -- Measurement
  measurement_criteria TEXT,                         -- How success is measured
  target_value NUMERIC(12,2),                        -- Numeric target (optional)
  current_value NUMERIC(12,2),                       -- Current progress
  unit TEXT,                                         -- Unit of measurement

  -- Alignment
  parent_goal_id UUID REFERENCES goals(id),          -- Link to parent goal
  linked_review_id UUID REFERENCES performance_reviews(id),  -- Link to review cycle

  -- Ownership
  assigned_by UUID,                                  -- Who assigned the goal
  approved_by UUID,                                  -- Manager approval
  approved_at TIMESTAMP WITH TIME ZONE,

  -- Completion
  completed_at TIMESTAMP WITH TIME ZONE,
  completion_notes TEXT,

  -- Metadata
  priority TEXT CHECK (priority IN ('low', 'medium', 'high', 'critical')),
  tags TEXT[],                                       -- For categorization
  meta JSONB DEFAULT '{}',

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID,
  updated_by UUID,

  -- Constraints
  CONSTRAINT valid_goal_period CHECK (target_date >= start_date)
);

CREATE INDEX idx_goals_org_id ON goals(org_id);
CREATE INDEX idx_goals_tenant_id ON goals(tenant_id);
CREATE INDEX idx_goals_person_id ON goals(person_id);
CREATE INDEX idx_goals_status ON goals(status);
CREATE INDEX idx_goals_target_date ON goals(target_date);
CREATE INDEX idx_goals_parent_goal_id ON goals(parent_goal_id);
CREATE INDEX idx_goals_linked_review_id ON goals(linked_review_id);

-- RLS
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON goals FOR ALL USING (true) WITH CHECK (true);

-- =============================================================================
-- 4. FEEDBACK (360-Degree Feedback)
-- =============================================================================

CREATE TABLE IF NOT EXISTS feedback (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  org_id UUID NOT NULL,
  tenant_id UUID NOT NULL,

  -- Feedback Subject & Provider
  person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,  -- Person receiving feedback
  provider_id UUID,                                  -- Person giving feedback (NULL if anonymous)
  provider_relationship TEXT CHECK (provider_relationship IN (
    'manager',
    'peer',
    'direct_report',
    'other'
  )),

  -- Feedback Content
  feedback_type TEXT NOT NULL CHECK (feedback_type IN (
    'performance',     -- Performance feedback
    'behavioral',      -- Behavioral/cultural feedback
    'skill',           -- Skill-specific feedback
    'general'          -- General feedback
  )),

  feedback_text TEXT NOT NULL,
  strengths TEXT,
  areas_for_improvement TEXT,

  -- Rating (optional)
  overall_rating INTEGER CHECK (overall_rating >= 1 AND overall_rating <= 5),

  -- Context
  linked_review_id UUID REFERENCES performance_reviews(id),
  linked_goal_id UUID REFERENCES goals(id),

  -- Privacy
  is_anonymous BOOLEAN DEFAULT FALSE,
  is_visible_to_subject BOOLEAN DEFAULT TRUE,        -- Can the person see this feedback?

  -- Acknowledgment
  acknowledged BOOLEAN DEFAULT FALSE,
  acknowledged_at TIMESTAMP WITH TIME ZONE,

  -- Metadata
  tags TEXT[],
  meta JSONB DEFAULT '{}',

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID
);

CREATE INDEX idx_feedback_org_id ON feedback(org_id);
CREATE INDEX idx_feedback_tenant_id ON feedback(tenant_id);
CREATE INDEX idx_feedback_person_id ON feedback(person_id);
CREATE INDEX idx_feedback_provider_id ON feedback(provider_id);
CREATE INDEX idx_feedback_feedback_type ON feedback(feedback_type);
CREATE INDEX idx_feedback_linked_review_id ON feedback(linked_review_id);
CREATE INDEX idx_feedback_created_at ON feedback(created_at);

-- RLS
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON feedback FOR ALL USING (true) WITH CHECK (true);

-- =============================================================================
-- 5. FUNCTIONS & TRIGGERS
-- =============================================================================

-- Function to auto-generate review name
CREATE OR REPLACE FUNCTION auto_generate_review_name()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_person_name TEXT;
  v_template_name TEXT;
BEGIN
  IF NEW.review_name IS NULL THEN
    SELECT full_name INTO v_person_name FROM people WHERE id = NEW.person_id;
    SELECT name INTO v_template_name FROM review_templates WHERE id = NEW.template_id;

    NEW.review_name := v_person_name || ' - ' || v_template_name;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS review_name_trigger ON performance_reviews;
CREATE TRIGGER review_name_trigger
  BEFORE INSERT ON performance_reviews
  FOR EACH ROW
  EXECUTE FUNCTION auto_generate_review_name();

-- Function to auto-update goal progress from current/target values
CREATE OR REPLACE FUNCTION auto_calculate_goal_progress()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.target_value IS NOT NULL AND NEW.target_value > 0 AND NEW.current_value IS NOT NULL THEN
    NEW.progress_percentage := LEAST(100, GREATEST(0, ROUND((NEW.current_value / NEW.target_value) * 100)));
  END IF;

  -- Auto-complete goal if progress reaches 100%
  IF NEW.progress_percentage >= 100 AND NEW.status = 'in_progress' THEN
    NEW.status := 'completed';
    NEW.completed_at := NOW();
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS goal_progress_trigger ON goals;
CREATE TRIGGER goal_progress_trigger
  BEFORE INSERT OR UPDATE ON goals
  FOR EACH ROW
  EXECUTE FUNCTION auto_calculate_goal_progress();

-- Function to compute overall rating from review sections
CREATE OR REPLACE FUNCTION compute_overall_rating(
  p_review_id UUID
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
  v_review RECORD;
  v_template RECORD;
  v_section JSONB;
  v_total_weight NUMERIC := 0;
  v_weighted_sum NUMERIC := 0;
  v_section_rating NUMERIC;
  v_section_weight NUMERIC;
BEGIN
  -- Get review and template
  SELECT * INTO v_review FROM performance_reviews WHERE id = p_review_id;
  SELECT * INTO v_template FROM review_templates WHERE id = v_review.template_id;

  -- Iterate through template sections
  FOR v_section IN SELECT * FROM jsonb_array_elements(v_template.sections)
  LOOP
    v_section_weight := COALESCE((v_section->>'weight')::NUMERIC, 0);

    -- Extract rating from manager_review_data (simplified - real logic would be more complex)
    v_section_rating := COALESCE(
      (v_review.manager_review_data->(v_section->>'id')->>'rating')::NUMERIC,
      0
    );

    v_total_weight := v_total_weight + v_section_weight;
    v_weighted_sum := v_weighted_sum + (v_section_rating * v_section_weight);
  END LOOP;

  -- Compute weighted average
  IF v_total_weight > 0 THEN
    RETURN ROUND(v_weighted_sum / v_total_weight, 2);
  ELSE
    RETURN NULL;
  END IF;
END;
$$;

-- =============================================================================
-- 6. HELPER VIEWS
-- =============================================================================

-- View for active goals summary
CREATE OR REPLACE VIEW active_goals AS
SELECT
  g.id,
  g.org_id,
  g.person_id,
  p.full_name AS person_name,
  p.avatar_url AS person_avatar,
  g.title,
  g.description,
  g.goal_type,
  g.start_date,
  g.target_date,
  g.progress_percentage,
  g.status,
  g.priority,
  CASE
    WHEN g.target_date < CURRENT_DATE AND g.status = 'in_progress' THEN TRUE
    ELSE FALSE
  END AS is_overdue,
  g.created_at
FROM goals g
JOIN people p ON g.person_id = p.id
WHERE g.status IN ('in_progress', 'draft');

-- View for pending reviews
CREATE OR REPLACE VIEW pending_reviews AS
SELECT
  pr.id,
  pr.org_id,
  pr.person_id,
  p.full_name AS person_name,
  p.email AS person_email,
  pr.reviewer_id,
  pr.review_period_start,
  pr.review_period_end,
  pr.status,
  pr.self_review_deadline,
  pr.manager_review_deadline,
  CASE
    WHEN pr.status = 'self_review_pending' AND pr.self_review_deadline < CURRENT_DATE THEN TRUE
    WHEN pr.status = 'manager_review_pending' AND pr.manager_review_deadline < CURRENT_DATE THEN TRUE
    ELSE FALSE
  END AS is_overdue,
  pr.created_at
FROM performance_reviews pr
JOIN people p ON pr.person_id = p.id
WHERE pr.status IN ('self_review_pending', 'manager_review_pending');

-- View for feedback summary per person
CREATE OR REPLACE VIEW feedback_summary AS
SELECT
  f.person_id,
  p.full_name AS person_name,
  f.feedback_type,
  COUNT(*) AS feedback_count,
  AVG(f.overall_rating) AS average_rating,
  MAX(f.created_at) AS latest_feedback_date
FROM feedback f
JOIN people p ON f.person_id = p.id
WHERE f.is_visible_to_subject = TRUE
GROUP BY f.person_id, p.full_name, f.feedback_type;

-- View for team performance (manager view)
CREATE OR REPLACE VIEW team_performance AS
SELECT
  d.id AS department_id,
  d.name AS department_name,
  d.head_person_id AS manager_id,
  p.id AS person_id,
  p.full_name AS person_name,
  p.job_title,
  COUNT(DISTINCT g.id) FILTER (WHERE g.status = 'in_progress') AS active_goals,
  COUNT(DISTINCT g.id) FILTER (WHERE g.status = 'completed') AS completed_goals,
  AVG(g.progress_percentage) FILTER (WHERE g.status = 'in_progress') AS avg_goal_progress,
  COUNT(DISTINCT pr.id) FILTER (WHERE pr.status = 'completed' AND pr.review_period_end > CURRENT_DATE - INTERVAL '1 year') AS reviews_last_year,
  AVG(pr.overall_rating) FILTER (WHERE pr.status = 'completed' AND pr.review_period_end > CURRENT_DATE - INTERVAL '1 year') AS avg_rating_last_year
FROM departments d
JOIN people p ON p.department_id = d.id
LEFT JOIN goals g ON g.person_id = p.id
LEFT JOIN performance_reviews pr ON pr.person_id = p.id
WHERE p.status = 'active'
GROUP BY d.id, d.name, d.head_person_id, p.id, p.full_name, p.job_title;

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================
-- This migration adds:
-- 1. Review templates with flexible JSONB structure
-- 2. Performance reviews with self/manager/360 feedback
-- 3. Goals (OKR) tracking with progress and alignment
-- 4. 360-degree feedback system
-- 5. Automatic progress calculation and rating computation
-- 6. Helper views for dashboards and manager views
