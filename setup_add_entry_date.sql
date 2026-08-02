-- Adds an editable "entry date" to subscriptions - the day a membership was
-- actually sold/entered, independent of start_date (when it becomes valid)
-- and payments.payment_date (when money was received). Backfills existing
-- rows from created_at so nothing is left blank once reports read from it.
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS entry_date date;
UPDATE subscriptions SET entry_date = created_at::date WHERE entry_date IS NULL;
