-- Auto-set category on INSERT/UPDATE when category is null or empty.
-- Uses same logic as backend categoryDetector (description + amount_cents).
-- Backend categorizeUncategorizedBankTransactions can still overwrite with AI/rule-based.

CREATE OR REPLACE FUNCTION bank_transactions_set_category()
RETURNS TRIGGER AS $$
DECLARE
  t text;
BEGIN
  t := LOWER(COALESCE(NEW.description, '') || ' ' || COALESCE(NEW.merchant_name, ''));
  IF NEW.category IS NOT NULL AND NEW.category <> '' THEN
    RETURN NEW;
  END IF;
  IF NEW.amount_cents < 0 THEN
    IF t ~ '(rocket delivery|rocket deliveries|doordash|uber eats|deliveroo|grubhub|delivery)' THEN
      NEW.category := 'Dining Out';
    ELSIF t ~ '(rocket rides|uber|lyft|bolt|taxi|rides)' OR (t ~ 'ride' AND t !~ 'brides') THEN
      NEW.category := 'Rideshare & Taxi';
    ELSIF t ~ '(netflix|spotify|disney|hulu|streaming|apple music|youtube premium)' THEN
      NEW.category := 'Streaming Services';
    ELSIF t ~ '(apple.com|google play|adobe|microsoft|dropbox|icloud|software|saas)' THEN
      NEW.category := 'Software & Apps';
    ELSIF t ~ '(mcdonald|starbucks|restaurant|cafe|pizza|burger|coffee)' THEN
      NEW.category := 'Dining Out';
    ELSIF t ~ '(amazon|ebay)' THEN
      NEW.category := 'Shopping';
    ELSIF t ~ '(grocery|supermarket|aldi|lidl|tesco|walmart)' THEN
      NEW.category := 'Groceries';
    ELSIF t ~ '(rent|landlord)' THEN
      NEW.category := 'Rent';
    ELSIF t ~ '(mortgage)' THEN
      NEW.category := 'Mortgage';
    ELSIF t ~ '(electric|utility)' THEN
      NEW.category := 'Electricity';
    ELSIF t ~ '(internet|phone|mobile|broadband)' THEN
      NEW.category := 'Internet & Phone';
    ELSIF t ~ '(gym|fitness)' THEN
      NEW.category := 'Fitness & Gym';
    ELSE
      NEW.category := 'Shopping';
    END IF;
  ELSE
    IF t ~ '(salary|payroll)' THEN
      NEW.category := 'Salary';
    ELSE
      NEW.category := 'Freelance & Side Income';
    END IF;
  END IF;
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS bank_transactions_set_category_trigger ON bank_transactions;
CREATE TRIGGER bank_transactions_set_category_trigger
  BEFORE INSERT OR UPDATE OF description, merchant_name, amount_cents, category
  ON bank_transactions
  FOR EACH ROW
  WHEN (NEW.category IS NULL OR NEW.category = '')
  EXECUTE FUNCTION bank_transactions_set_category();
