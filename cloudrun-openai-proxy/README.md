# OpenAI image proxy (Cloud Run, europe-west3)

Forwards `POST /v1/images/edits` from the OpenAI worker to api.openai.com. Why: OpenAI refuses Cloudflare Workers
requests from visitors in Ukraine (403 unsupported_country_region_territory, confirmed with OpenAI support
2026-11-10), and support recommended calling the API from our own server. The worker does App Attest, limits,
holds the OpenAI key and blocks unsupported countries / occupied regions before calling this proxy.

Project `homeai-41580`, service `openai-proxy`. Secret: env `PROXY_SECRET` (same value as the worker secret
`OPENAI_PROXY_SECRET`). Deploy: `gcloud run deploy openai-proxy --source . --region europe-west3 --project homeai-41580`.
