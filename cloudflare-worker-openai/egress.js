/**
 * Unused placeholder. Created by migration v4 for a region test (2026-10-20): from every Cloudflare locationHint
 * OpenAI saw the caller's country (loc=UA) and answered 403 unsupported_country_region_territory.
 * Kept because removing a Durable Object class needs a delete migration.
 */
export class OpenAIEgress {
	async fetch() {
		return new Response("not found", { status: 404 })
	}
}
