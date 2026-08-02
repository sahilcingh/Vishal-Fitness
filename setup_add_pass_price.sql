-- Locks in the price actually charged for each subscription, independent of
-- gym_passes.price (which can change later and would otherwise retroactively
-- rewrite every past member's ledger/balance for that pass). Backfills
-- existing rows from the pass's CURRENT price - the best available guess,
-- since there's no historical price log. Anything you know was charged a
-- different price at the time can be hand-corrected via Edit Member.
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS pass_price numeric;
UPDATE subscriptions s SET pass_price = gp.price FROM gym_passes gp WHERE gp.id = s.pass_id AND s.pass_price IS NULL;
