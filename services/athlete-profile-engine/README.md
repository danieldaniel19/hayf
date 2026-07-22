# Athlete Profile Engine

Stateless deterministic scoring service for the five-axis Athlete Blueprint profile. It accepts compact, derived training features only and never raw HealthKit samples.

## Local use

```sh
npm install
npm test
npm run check
npm run serve
```

Set `ATHLETE_PROFILE_ENGINE_API_KEY`; scoring requests require the matching `Authorization: Bearer …` header. If the key is not configured, scoring fails closed. `GET /health` remains public.

## Production deployment

The current production adapter is the independently deployed Supabase Edge Function at `supabase/functions/athlete-profile-engine`. It imports this package's scorer and validator directly, so the container and Edge deployments use one deterministic implementation.

Configure the shared service key plus the function base URL, then deploy the scorer before `onboarding-ai`:

```sh
npx supabase secrets set ATHLETE_PROFILE_ENGINE_API_KEY="..." \
  ATHLETE_PROFILE_ENGINE_URL="https://<project-ref>.supabase.co/functions/v1/athlete-profile-engine"
npx supabase functions deploy athlete-profile-engine
npx supabase functions deploy onboarding-ai
```

The included Fly configuration remains an alternative container deployment target.
