# Security

## Never commit secrets

- **`.env`** must never be committed. It is in `.gitignore`. It contains:
  - `STRIPE_SECRET_KEY`
  - `STRIPE_WEBHOOK_SECRET`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `OPENAI_API_KEY`
  - Other API keys and secrets.

- Use **`.env.example`** only as a template with empty or placeholder variable names. Do not put real keys or values that look like real secrets (e.g. no `whsec_...` or `sk_...` strings) in the repo.

## If a secret was exposed

1. **Rotate the secret immediately** in the provider’s dashboard (Stripe, Supabase, OpenAI, etc.).
2. For **Stripe webhook secret**: Stripe Dashboard → Developers → Webhooks → your endpoint → Roll signing secret (or add a new endpoint and remove the old one). Update `.env` and Railway Variables with the new value.
3. For **Stripe API keys**: Stripe Dashboard → Developers → API keys → Roll or create new keys. Update `.env` and Railway.
4. Do not push `.env` or any file containing real secrets. If it was committed in the past, consider using `git filter-repo` or GitHub’s support to remove it from history (and rotate all affected secrets).

## Reporting a vulnerability

If you find a security issue in this project, report it privately to the maintainers rather than opening a public issue.
