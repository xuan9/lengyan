-- Add explicit product ownership without interrupting the existing Lengyan App
-- or support form. The historical endpoint served only Lengyan, so the default
-- classifies old rows and legacy writes without inventing a user attribute.
-- Apply this additive migration before deploying the multi-product Worker.

ALTER TABLE feedback
ADD COLUMN product_id TEXT NOT NULL DEFAULT 'lengyan' CHECK (
  length(product_id) BETWEEN 1 AND 64
  AND substr(product_id, 1, 1) GLOB '[a-z]'
  AND product_id NOT GLOB '*[^a-z0-9-]*'
  AND product_id NOT GLOB '*--*'
  AND substr(product_id, -1, 1) GLOB '[a-z0-9]'
);

CREATE INDEX idx_feedback_product_read_created_at
  ON feedback(product_id, is_read, created_at DESC);
