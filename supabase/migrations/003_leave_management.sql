-- SO360 People Connect - Leave Management System
-- Leave Types, Balances, Requests, Approvals

-- =============================================================================
-- 1. LEAVE TYPES (Master Data)
-- =============================================================================

CREATE TABLE IF NOT EXISTS leave_types (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  org_id UUID NOT NULL,
  tenant_id UUID NOT NULL,

  -- Leave Type Identity
  code TEXT NOT NULL,                                -- Unique code (e.g., 'AL', 'SL', 'ML', 'PL')
  name TEXT NOT NULL,                                -- Display name (e.g., 'Annual Leave', 'Sick Leave')
  description TEXT,

  -- Leave Type Configuration
  is_paid BOOLEAN DEFAULT TRUE,
  requires_approval BOOLEAN DEFAULT TRUE,
  requires_documentation BOOLEAN DEFAULT FALSE,      -- e.g., medical certificate for sick leave

  -- Accrual Configuration
  accrual_type TEXT NOT NULL DEFAULT 'annual' CHECK (accrual_type IN (
    'annual',          -- Fixed days per year
    'monthly',         -- Accrued monthly
    'none'             -- No accrual (unlimited/unpaid)
  )),
  max_days_per_year NUMERIC(5,2) DEFAULT 0,          -- Maximum days allowed per year
  accrual_rate NUMERIC(5,2) DEFAULT 0,               -- Days accrued per period (e.g., 1.67 days/month)

  -- Carry Forward Rules
  carry_forward_allowed BOOLEAN DEFAULT FALSE,
  max_carry_forward_days NUMERIC(5,2) DEFAULT 0,
  carry_forward_expiry_months INTEGER DEFAULT 3,     -- Carried days expire after N months

  -- Restrictions
  min_days_per_request NUMERIC(3,1) DEFAULT 0.5,     -- Minimum days (e.g., 0.5 for half-day)
  max_days_per_request NUMERIC(4,1) DEFAULT 30,
  notice_period_days INTEGER DEFAULT 0,              -- Advance notice required

  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  display_order INTEGER DEFAULT 0,                   -- For UI sorting

  -- Metadata
  color TEXT DEFAULT '#3B82F6',                      -- For calendar display
  icon TEXT,                                         -- Icon name
  meta JSONB DEFAULT '{}',

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID,
  updated_by UUID,

  -- Constraints
  CONSTRAINT unique_leave_type_code_per_org UNIQUE(org_id, code),
  CONSTRAINT valid_accrual_rate CHECK (accrual_rate >= 0),
  CONSTRAINT valid_max_days CHECK (max_days_per_year >= 0)
);

CREATE INDEX idx_leave_types_org_id ON leave_types(org_id);
CREATE INDEX idx_leave_types_tenant_id ON leave_types(tenant_id);
CREATE INDEX idx_leave_types_is_active ON leave_types(is_active);
CREATE INDEX idx_leave_types_display_order ON leave_types(display_order);

-- RLS
ALTER TABLE leave_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON leave_types FOR ALL USING (true) WITH CHECK (true);

-- =============================================================================
-- 2. LEAVE BALANCES (Per Person, Per Type, Per Year)
-- =============================================================================

CREATE TABLE IF NOT EXISTS leave_balances (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  org_id UUID NOT NULL,
  tenant_id UUID NOT NULL,
  person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,
  leave_type_id UUID NOT NULL REFERENCES leave_types(id) ON DELETE CASCADE,

  -- Period
  fiscal_year INTEGER NOT NULL,                      -- e.g., 2024

  -- Balance Computation
  opening_balance NUMERIC(5,2) DEFAULT 0,            -- Carried from previous year
  accrued NUMERIC(5,2) DEFAULT 0,                    -- Accrued this year
  used NUMERIC(5,2) DEFAULT 0,                       -- Used (approved leaves)
  pending NUMERIC(5,2) DEFAULT 0,                    -- Pending approval
  adjusted NUMERIC(5,2) DEFAULT 0,                   -- Manual adjustments (+/-)
  expired NUMERIC(5,2) DEFAULT 0,                    -- Carried balance that expired

  -- Computed Available = opening + accrued + adjusted - used - pending - expired
  available NUMERIC(5,2) GENERATED ALWAYS AS (
    opening_balance + accrued + adjusted - used - pending - expired
  ) STORED,

  -- Metadata
  last_accrual_date DATE,
  notes TEXT,
  meta JSONB DEFAULT '{}',

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID,
  updated_by UUID,

  -- Constraints
  CONSTRAINT unique_balance_per_person_type_year UNIQUE(person_id, leave_type_id, fiscal_year),
  CONSTRAINT valid_balance_values CHECK (
    opening_balance >= 0 AND
    accrued >= 0 AND
    used >= 0 AND
    pending >= 0 AND
    expired >= 0
  )
);

CREATE INDEX idx_leave_balances_org_id ON leave_balances(org_id);
CREATE INDEX idx_leave_balances_tenant_id ON leave_balances(tenant_id);
CREATE INDEX idx_leave_balances_person_id ON leave_balances(person_id);
CREATE INDEX idx_leave_balances_leave_type_id ON leave_balances(leave_type_id);
CREATE INDEX idx_leave_balances_fiscal_year ON leave_balances(fiscal_year);

-- RLS
ALTER TABLE leave_balances ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON leave_balances FOR ALL USING (true) WITH CHECK (true);

-- =============================================================================
-- 3. LEAVE REQUESTS (Workflow Entity)
-- =============================================================================

CREATE TABLE IF NOT EXISTS leave_requests (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  org_id UUID NOT NULL,
  tenant_id UUID NOT NULL,
  person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,
  leave_type_id UUID NOT NULL REFERENCES leave_types(id) ON DELETE RESTRICT,

  -- Request Details
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  total_days NUMERIC(4,1) NOT NULL,                  -- Can be fractional (0.5 for half-day)
  is_half_day_start BOOLEAN DEFAULT FALSE,           -- Half day on start date
  is_half_day_end BOOLEAN DEFAULT FALSE,             -- Half day on end date

  -- Request Context
  reason TEXT NOT NULL,
  notes TEXT,
  documentation_url TEXT,                            -- Link to uploaded medical cert, etc.

  -- Workflow Status
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN (
    'draft',           -- Being composed
    'pending',         -- Submitted, awaiting approval
    'approved',        -- Approved
    'rejected',        -- Rejected
    'cancelled'        -- Cancelled by employee
  )),

  -- Approval Tracking
  submitted_at TIMESTAMP WITH TIME ZONE,
  submitted_by UUID,
  approver_id UUID,                                  -- Manager/approver
  approved_at TIMESTAMP WITH TIME ZONE,
  rejected_at TIMESTAMP WITH TIME ZONE,
  rejection_reason TEXT,
  cancelled_at TIMESTAMP WITH TIME ZONE,
  cancellation_reason TEXT,

  -- Notification
  notification_sent BOOLEAN DEFAULT FALSE,

  -- Metadata
  meta JSONB DEFAULT '{}',

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID,
  updated_by UUID,

  -- Constraints
  CONSTRAINT valid_date_range CHECK (end_date >= start_date),
  CONSTRAINT valid_total_days CHECK (total_days > 0 AND total_days <= 365),
  CONSTRAINT valid_status_timestamps CHECK (
    (status = 'pending' AND submitted_at IS NOT NULL) OR
    (status = 'approved' AND approved_at IS NOT NULL) OR
    (status = 'rejected' AND rejected_at IS NOT NULL AND rejection_reason IS NOT NULL) OR
    (status = 'cancelled' AND cancelled_at IS NOT NULL) OR
    (status = 'draft')
  )
);

CREATE INDEX idx_leave_requests_org_id ON leave_requests(org_id);
CREATE INDEX idx_leave_requests_tenant_id ON leave_requests(tenant_id);
CREATE INDEX idx_leave_requests_person_id ON leave_requests(person_id);
CREATE INDEX idx_leave_requests_leave_type_id ON leave_requests(leave_type_id);
CREATE INDEX idx_leave_requests_status ON leave_requests(status);
CREATE INDEX idx_leave_requests_dates ON leave_requests(start_date, end_date);
CREATE INDEX idx_leave_requests_approver_id ON leave_requests(approver_id);

-- RLS
ALTER TABLE leave_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON leave_requests FOR ALL USING (true) WITH CHECK (true);

-- =============================================================================
-- 4. LEAVE REQUEST APPROVALS (Multi-Level Approval Tracking)
-- =============================================================================

CREATE TABLE IF NOT EXISTS leave_request_approvals (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  org_id UUID NOT NULL,
  tenant_id UUID NOT NULL,
  leave_request_id UUID NOT NULL REFERENCES leave_requests(id) ON DELETE CASCADE,

  -- Approval Level
  approval_level INTEGER NOT NULL DEFAULT 1,         -- 1 = manager, 2 = director, etc.
  approver_id UUID NOT NULL,                         -- User who can approve
  approver_role TEXT,                                -- 'manager', 'hr', 'director'

  -- Approval Status
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
    'pending',
    'approved',
    'rejected',
    'skipped'
  )),

  -- Timestamps
  notified_at TIMESTAMP WITH TIME ZONE,
  responded_at TIMESTAMP WITH TIME ZONE,
  decision_notes TEXT,

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_approval_level UNIQUE(leave_request_id, approval_level)
);

CREATE INDEX idx_leave_request_approvals_org_id ON leave_request_approvals(org_id);
CREATE INDEX idx_leave_request_approvals_leave_request_id ON leave_request_approvals(leave_request_id);
CREATE INDEX idx_leave_request_approvals_approver_id ON leave_request_approvals(approver_id);
CREATE INDEX idx_leave_request_approvals_status ON leave_request_approvals(status);

-- RLS
ALTER TABLE leave_request_approvals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON leave_request_approvals FOR ALL USING (true) WITH CHECK (true);

-- =============================================================================
-- 5. FUNCTIONS & TRIGGERS
-- =============================================================================

-- Function to calculate working days between two dates (excluding weekends)
CREATE OR REPLACE FUNCTION calculate_working_days(
  p_start_date DATE,
  p_end_date DATE,
  p_is_half_day_start BOOLEAN DEFAULT FALSE,
  p_is_half_day_end BOOLEAN DEFAULT FALSE
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
  v_working_days NUMERIC;
  v_total_days INTEGER;
BEGIN
  -- Count working days (excluding Saturday=6, Sunday=0)
  SELECT COUNT(*)::NUMERIC INTO v_working_days
  FROM generate_series(p_start_date, p_end_date, '1 day'::interval) d
  WHERE EXTRACT(DOW FROM d) NOT IN (0, 6);

  -- Adjust for half days
  IF p_is_half_day_start THEN
    v_working_days := v_working_days - 0.5;
  END IF;

  IF p_is_half_day_end AND p_start_date != p_end_date THEN
    v_working_days := v_working_days - 0.5;
  END IF;

  RETURN v_working_days;
END;
$$;

-- Trigger to auto-calculate total_days on leave request
CREATE OR REPLACE FUNCTION auto_calculate_leave_days()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Auto-calculate working days if total_days not provided or dates changed
  IF NEW.total_days IS NULL OR
     OLD.start_date IS DISTINCT FROM NEW.start_date OR
     OLD.end_date IS DISTINCT FROM NEW.end_date OR
     OLD.is_half_day_start IS DISTINCT FROM NEW.is_half_day_start OR
     OLD.is_half_day_end IS DISTINCT FROM NEW.is_half_day_end THEN

    NEW.total_days := calculate_working_days(
      NEW.start_date,
      NEW.end_date,
      NEW.is_half_day_start,
      NEW.is_half_day_end
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS leave_request_days_trigger ON leave_requests;
CREATE TRIGGER leave_request_days_trigger
  BEFORE INSERT OR UPDATE ON leave_requests
  FOR EACH ROW
  EXECUTE FUNCTION auto_calculate_leave_days();

-- Trigger to update leave balances when request status changes
CREATE OR REPLACE FUNCTION update_leave_balance_on_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_fiscal_year INTEGER;
BEGIN
  v_fiscal_year := EXTRACT(YEAR FROM NEW.start_date);

  -- When request moves to pending, increase pending balance
  IF NEW.status = 'pending' AND OLD.status = 'draft' THEN
    UPDATE leave_balances
    SET pending = pending + NEW.total_days,
        updated_at = NOW()
    WHERE person_id = NEW.person_id
      AND leave_type_id = NEW.leave_type_id
      AND fiscal_year = v_fiscal_year;

  -- When request is approved, move from pending to used
  ELSIF NEW.status = 'approved' AND OLD.status = 'pending' THEN
    UPDATE leave_balances
    SET pending = pending - NEW.total_days,
        used = used + NEW.total_days,
        updated_at = NOW()
    WHERE person_id = NEW.person_id
      AND leave_type_id = NEW.leave_type_id
      AND fiscal_year = v_fiscal_year;

  -- When request is rejected, reduce pending
  ELSIF NEW.status = 'rejected' AND OLD.status = 'pending' THEN
    UPDATE leave_balances
    SET pending = pending - NEW.total_days,
        updated_at = NOW()
    WHERE person_id = NEW.person_id
      AND leave_type_id = NEW.leave_type_id
      AND fiscal_year = v_fiscal_year;

  -- When approved request is cancelled, reduce used
  ELSIF NEW.status = 'cancelled' AND OLD.status = 'approved' THEN
    UPDATE leave_balances
    SET used = used - NEW.total_days,
        updated_at = NOW()
    WHERE person_id = NEW.person_id
      AND leave_type_id = NEW.leave_type_id
      AND fiscal_year = v_fiscal_year;

  -- When pending request is cancelled, reduce pending
  ELSIF NEW.status = 'cancelled' AND OLD.status = 'pending' THEN
    UPDATE leave_balances
    SET pending = pending - NEW.total_days,
        updated_at = NOW()
    WHERE person_id = NEW.person_id
      AND leave_type_id = NEW.leave_type_id
      AND fiscal_year = v_fiscal_year;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS leave_balance_update_trigger ON leave_requests;
CREATE TRIGGER leave_balance_update_trigger
  AFTER UPDATE ON leave_requests
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION update_leave_balance_on_status_change();

-- Function to initialize leave balances for a person (call from backend)
CREATE OR REPLACE FUNCTION initialize_leave_balances(
  p_person_id UUID,
  p_org_id UUID,
  p_tenant_id UUID,
  p_fiscal_year INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  -- Create balance records for all active leave types
  INSERT INTO leave_balances (
    org_id, tenant_id, person_id, leave_type_id, fiscal_year,
    opening_balance, accrued
  )
  SELECT
    p_org_id,
    p_tenant_id,
    p_person_id,
    lt.id,
    p_fiscal_year,
    0,  -- opening_balance (can be updated later)
    CASE
      WHEN lt.accrual_type = 'annual' THEN lt.max_days_per_year
      ELSE 0  -- Monthly accrual will be calculated via cron
    END
  FROM leave_types lt
  WHERE lt.org_id = p_org_id
    AND lt.is_active = TRUE
  ON CONFLICT (person_id, leave_type_id, fiscal_year) DO NOTHING;
END;
$$;

-- =============================================================================
-- 6. HELPER VIEWS
-- =============================================================================

-- View for leave calendar (all approved leaves)
CREATE OR REPLACE VIEW leave_calendar AS
SELECT
  lr.id,
  lr.org_id,
  lr.person_id,
  p.full_name AS person_name,
  p.avatar_url AS person_avatar,
  p.department_id,
  d.name AS department_name,
  lr.leave_type_id,
  lt.name AS leave_type_name,
  lt.color AS leave_type_color,
  lr.start_date,
  lr.end_date,
  lr.total_days,
  lr.status
FROM leave_requests lr
JOIN people p ON lr.person_id = p.id
LEFT JOIN departments d ON p.department_id = d.id
JOIN leave_types lt ON lr.leave_type_id = lt.id
WHERE lr.status IN ('pending', 'approved');

-- View for pending approvals
CREATE OR REPLACE VIEW pending_leave_approvals AS
SELECT
  lr.id AS request_id,
  lr.org_id,
  lr.person_id,
  p.full_name AS requestor_name,
  p.email AS requestor_email,
  p.avatar_url AS requestor_avatar,
  lt.name AS leave_type,
  lt.color AS leave_type_color,
  lr.start_date,
  lr.end_date,
  lr.total_days,
  lr.reason,
  lr.submitted_at,
  lra.approver_id,
  lra.approval_level,
  lra.status AS approval_status
FROM leave_requests lr
JOIN people p ON lr.person_id = p.id
JOIN leave_types lt ON lr.leave_type_id = lt.id
LEFT JOIN leave_request_approvals lra ON lr.id = lra.leave_request_id
WHERE lr.status = 'pending';

-- View for leave balances with type details
CREATE OR REPLACE VIEW leave_balance_summary AS
SELECT
  lb.id,
  lb.org_id,
  lb.person_id,
  p.full_name AS person_name,
  lb.leave_type_id,
  lt.code AS leave_type_code,
  lt.name AS leave_type_name,
  lt.color AS leave_type_color,
  lb.fiscal_year,
  lb.opening_balance,
  lb.accrued,
  lb.used,
  lb.pending,
  lb.adjusted,
  lb.expired,
  lb.available
FROM leave_balances lb
JOIN people p ON lb.person_id = p.id
JOIN leave_types lt ON lb.leave_type_id = lt.id;

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================
-- This migration adds:
-- 1. Leave types master data with accrual configuration
-- 2. Leave balances per person/type/year with computed available
-- 3. Leave requests with workflow (draft → pending → approved/rejected)
-- 4. Multi-level approval tracking
-- 5. Automatic balance updates via triggers
-- 6. Helper views for calendar and pending approvals
