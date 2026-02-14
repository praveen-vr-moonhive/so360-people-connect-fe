-- SO360 People Connect - HR Enhancements Migration
-- Departments, User-Employee Linkage, Employment History

-- =============================================================================
-- 1. DEPARTMENTS (Hierarchical Structure)
-- =============================================================================

CREATE TABLE IF NOT EXISTS departments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  org_id UUID NOT NULL,
  tenant_id UUID NOT NULL,

  -- Department Identity
  code TEXT NOT NULL,                               -- Unique short code (e.g., 'ENG', 'SALES', 'HR')
  name TEXT NOT NULL,
  description TEXT,

  -- Hierarchy
  parent_id UUID REFERENCES departments(id),        -- For nested departments
  depth INTEGER DEFAULT 0,                          -- Tree depth (0 = root)
  path TEXT,                                        -- Materialized path (e.g., '/ENG/ENG-BE')

  -- Leadership & Cost Center
  head_person_id UUID REFERENCES people(id),        -- Department head
  cost_center_id UUID,                              -- Link to Accounting cost center

  -- Status
  is_active BOOLEAN DEFAULT TRUE,

  -- Metadata
  meta JSONB DEFAULT '{}',

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID,
  updated_by UUID,

  -- Constraints
  CONSTRAINT unique_dept_code_per_org UNIQUE(org_id, code),
  CONSTRAINT valid_depth CHECK (depth >= 0)
);

CREATE INDEX idx_departments_org_id ON departments(org_id);
CREATE INDEX idx_departments_tenant_id ON departments(tenant_id);
CREATE INDEX idx_departments_parent_id ON departments(parent_id);
CREATE INDEX idx_departments_head_person_id ON departments(head_person_id);
CREATE INDEX idx_departments_is_active ON departments(is_active);
CREATE INDEX idx_departments_path ON departments(path);

-- RLS
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON departments FOR ALL USING (true) WITH CHECK (true);

-- =============================================================================
-- 2. UPDATE PEOPLE TABLE - Add HR Fields
-- =============================================================================

-- Add new HR fields to existing people table
ALTER TABLE people ADD COLUMN IF NOT EXISTS department_id UUID REFERENCES departments(id);
ALTER TABLE people ADD COLUMN IF NOT EXISTS employee_id TEXT;                    -- Company employee ID (e.g., 'EMP-1001')
ALTER TABLE people ADD COLUMN IF NOT EXISTS date_of_birth DATE;
ALTER TABLE people ADD COLUMN IF NOT EXISTS date_of_joining DATE;
ALTER TABLE people ADD COLUMN IF NOT EXISTS emergency_contact JSONB DEFAULT '{}'; -- {name, phone, relationship}
ALTER TABLE people ADD COLUMN IF NOT EXISTS employment_type TEXT CHECK (employment_type IN ('full_time', 'part_time', 'contract', 'intern'));

-- Index for department_id
CREATE INDEX IF NOT EXISTS idx_people_department_id ON people(department_id);
CREATE INDEX IF NOT EXISTS idx_people_employee_id ON people(org_id, employee_id);
CREATE INDEX IF NOT EXISTS idx_people_employment_type ON people(employment_type);

-- Make department text field nullable (will be migrated to department_id)
ALTER TABLE people ALTER COLUMN department DROP NOT NULL;

-- Add comment to deprecated field
COMMENT ON COLUMN people.department IS 'DEPRECATED: Use department_id instead. Kept for backward compatibility during migration.';

-- =============================================================================
-- 3. PERSON-USER LINKAGE (Explicit Mapping)
-- =============================================================================

CREATE TABLE IF NOT EXISTS person_user_links (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  org_id UUID NOT NULL,
  tenant_id UUID NOT NULL,

  -- Link
  person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,                             -- References core user_profiles

  -- Invitation Tracking
  invitation_status TEXT CHECK (invitation_status IN ('pending', 'accepted', 'expired')),
  invitation_sent_at TIMESTAMP WITH TIME ZONE,
  invitation_accepted_at TIMESTAMP WITH TIME ZONE,

  -- Linkage Metadata
  linked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  linked_by UUID,                                    -- Admin who created the link
  unlinked_at TIMESTAMP WITH TIME ZONE,
  unlinked_by UUID,
  is_active BOOLEAN DEFAULT TRUE,

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_person_user_link UNIQUE(person_id, user_id),
  CONSTRAINT unique_active_person_link UNIQUE(person_id) WHERE is_active = TRUE,
  CONSTRAINT unique_active_user_link UNIQUE(user_id) WHERE is_active = TRUE
);

CREATE INDEX idx_person_user_links_org_id ON person_user_links(org_id);
CREATE INDEX idx_person_user_links_tenant_id ON person_user_links(tenant_id);
CREATE INDEX idx_person_user_links_person_id ON person_user_links(person_id);
CREATE INDEX idx_person_user_links_user_id ON person_user_links(user_id);
CREATE INDEX idx_person_user_links_is_active ON person_user_links(is_active);

-- RLS
ALTER TABLE person_user_links ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON person_user_links FOR ALL USING (true) WITH CHECK (true);

-- =============================================================================
-- 4. EMPLOYMENT HISTORY (Immutable Audit Trail)
-- =============================================================================

CREATE TABLE IF NOT EXISTS employment_history (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  org_id UUID NOT NULL,
  tenant_id UUID NOT NULL,
  person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,

  -- Event Classification
  event_type TEXT NOT NULL CHECK (event_type IN (
    'hired',
    'promoted',
    'transferred',
    'department_changed',
    'rate_changed',
    'status_changed',
    'employment_type_changed',
    'terminated'
  )),

  -- Effective Date
  effective_date DATE NOT NULL,

  -- Previous & New Values (stored as JSONB for flexibility)
  previous_values JSONB DEFAULT '{}',
  new_values JSONB DEFAULT '{}',

  -- Specific Fields (for common queries)
  new_department_id UUID REFERENCES departments(id),
  new_cost_rate NUMERIC(12,2),
  new_billing_rate NUMERIC(12,2),
  new_job_title TEXT,
  new_employment_type TEXT,
  new_status TEXT,

  -- Context
  notes TEXT,
  reason TEXT,                                       -- Reason for change

  -- Approval
  approved_by UUID,
  approved_at TIMESTAMP WITH TIME ZONE,

  -- Immutable timestamp
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID,

  -- No update/delete - append only
  -- (Application logic should prevent updates)

  CONSTRAINT valid_event_date CHECK (effective_date <= CURRENT_DATE + INTERVAL '1 year')
);

CREATE INDEX idx_employment_history_org_id ON employment_history(org_id);
CREATE INDEX idx_employment_history_tenant_id ON employment_history(tenant_id);
CREATE INDEX idx_employment_history_person_id ON employment_history(person_id);
CREATE INDEX idx_employment_history_event_type ON employment_history(event_type);
CREATE INDEX idx_employment_history_effective_date ON employment_history(effective_date);
CREATE INDEX idx_employment_history_created_at ON employment_history(created_at);

-- RLS
ALTER TABLE employment_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON employment_history FOR ALL USING (true) WITH CHECK (true);

-- =============================================================================
-- 5. FUNCTIONS & TRIGGERS
-- =============================================================================

-- Trigger function to track employment changes automatically
CREATE OR REPLACE FUNCTION track_employment_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Track department changes
  IF NEW.department_id IS DISTINCT FROM OLD.department_id THEN
    INSERT INTO employment_history (
      org_id, tenant_id, person_id, event_type, effective_date,
      previous_values, new_values, new_department_id, created_by
    ) VALUES (
      NEW.org_id, NEW.tenant_id, NEW.id, 'department_changed', CURRENT_DATE,
      jsonb_build_object('department_id', OLD.department_id),
      jsonb_build_object('department_id', NEW.department_id),
      NEW.department_id, NEW.updated_by
    );
  END IF;

  -- Track rate changes
  IF NEW.cost_rate IS DISTINCT FROM OLD.cost_rate OR NEW.billing_rate IS DISTINCT FROM OLD.billing_rate THEN
    INSERT INTO employment_history (
      org_id, tenant_id, person_id, event_type, effective_date,
      previous_values, new_values, new_cost_rate, new_billing_rate, created_by
    ) VALUES (
      NEW.org_id, NEW.tenant_id, NEW.id, 'rate_changed', CURRENT_DATE,
      jsonb_build_object('cost_rate', OLD.cost_rate, 'billing_rate', OLD.billing_rate),
      jsonb_build_object('cost_rate', NEW.cost_rate, 'billing_rate', NEW.billing_rate),
      NEW.cost_rate, NEW.billing_rate, NEW.updated_by
    );
  END IF;

  -- Track job title changes (promotion)
  IF NEW.job_title IS DISTINCT FROM OLD.job_title THEN
    INSERT INTO employment_history (
      org_id, tenant_id, person_id, event_type, effective_date,
      previous_values, new_values, new_job_title, created_by
    ) VALUES (
      NEW.org_id, NEW.tenant_id, NEW.id, 'promoted', CURRENT_DATE,
      jsonb_build_object('job_title', OLD.job_title),
      jsonb_build_object('job_title', NEW.job_title),
      NEW.job_title, NEW.updated_by
    );
  END IF;

  -- Track employment type changes
  IF NEW.employment_type IS DISTINCT FROM OLD.employment_type THEN
    INSERT INTO employment_history (
      org_id, tenant_id, person_id, event_type, effective_date,
      previous_values, new_values, new_employment_type, created_by
    ) VALUES (
      NEW.org_id, NEW.tenant_id, NEW.id, 'employment_type_changed', CURRENT_DATE,
      jsonb_build_object('employment_type', OLD.employment_type),
      jsonb_build_object('employment_type', NEW.employment_type),
      NEW.employment_type, NEW.updated_by
    );
  END IF;

  -- Track status changes
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO employment_history (
      org_id, tenant_id, person_id, event_type, effective_date,
      previous_values, new_values, new_status, created_by
    ) VALUES (
      NEW.org_id, NEW.tenant_id, NEW.id,
      CASE WHEN NEW.status = 'terminated' THEN 'terminated' ELSE 'status_changed' END,
      CURRENT_DATE,
      jsonb_build_object('status', OLD.status),
      jsonb_build_object('status', NEW.status),
      NEW.status, NEW.updated_by
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Attach trigger to people table (only on UPDATE)
DROP TRIGGER IF EXISTS employment_changes_trigger ON people;
CREATE TRIGGER employment_changes_trigger
  AFTER UPDATE ON people
  FOR EACH ROW
  EXECUTE FUNCTION track_employment_changes();

-- Trigger to record hiring event on INSERT
CREATE OR REPLACE FUNCTION track_hiring()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO employment_history (
    org_id, tenant_id, person_id, event_type, effective_date,
    new_values, new_department_id, new_cost_rate, new_billing_rate,
    new_job_title, new_employment_type, new_status, created_by
  ) VALUES (
    NEW.org_id, NEW.tenant_id, NEW.id, 'hired', COALESCE(NEW.start_date, CURRENT_DATE),
    jsonb_build_object(
      'full_name', NEW.full_name,
      'job_title', NEW.job_title,
      'department_id', NEW.department_id,
      'employment_type', NEW.employment_type,
      'cost_rate', NEW.cost_rate,
      'billing_rate', NEW.billing_rate
    ),
    NEW.department_id, NEW.cost_rate, NEW.billing_rate,
    NEW.job_title, NEW.employment_type, NEW.status, NEW.created_by
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS hiring_trigger ON people;
CREATE TRIGGER hiring_trigger
  AFTER INSERT ON people
  FOR EACH ROW
  EXECUTE FUNCTION track_hiring();

-- Function to update department tree paths
CREATE OR REPLACE FUNCTION update_department_path()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_parent_path TEXT;
BEGIN
  IF NEW.parent_id IS NULL THEN
    -- Root department
    NEW.path := '/' || NEW.code;
    NEW.depth := 0;
  ELSE
    -- Child department
    SELECT path, depth INTO v_parent_path, NEW.depth FROM departments WHERE id = NEW.parent_id;
    NEW.path := v_parent_path || '/' || NEW.code;
    NEW.depth := NEW.depth + 1;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS department_path_trigger ON departments;
CREATE TRIGGER department_path_trigger
  BEFORE INSERT OR UPDATE ON departments
  FOR EACH ROW
  EXECUTE FUNCTION update_department_path();

-- =============================================================================
-- 6. HELPER VIEWS
-- =============================================================================

-- View to easily get active person-user links with names
CREATE OR REPLACE VIEW active_person_user_links AS
SELECT
  pul.*,
  p.full_name AS person_name,
  p.email AS person_email,
  p.job_title,
  p.department_id,
  d.name AS department_name
FROM person_user_links pul
JOIN people p ON pul.person_id = p.id
LEFT JOIN departments d ON p.department_id = d.id
WHERE pul.is_active = TRUE;

-- View for department hierarchy
CREATE OR REPLACE VIEW department_hierarchy AS
SELECT
  d.id,
  d.org_id,
  d.code,
  d.name,
  d.parent_id,
  d.depth,
  d.path,
  d.head_person_id,
  p.full_name AS head_name,
  d.cost_center_id,
  d.is_active,
  (SELECT COUNT(*) FROM people WHERE department_id = d.id AND status = 'active') AS employee_count
FROM departments d
LEFT JOIN people p ON d.head_person_id = p.id;

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================
-- This migration adds:
-- 1. Departments table with hierarchical structure
-- 2. Person-user linkage tracking
-- 3. Employment history immutable audit trail
-- 4. Automatic triggers for tracking changes
-- 5. Helper views for common queries
