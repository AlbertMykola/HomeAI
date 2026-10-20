import { AttestError, base64ToBytes, verifyAssertion } from "./attest.js"

/**
 * One instance per App Attest key ("key:<keyId>"), per client IP ("ip:<ip>") or for the Debug simulator ("dev").
 * Holds the attested public key + assertion counter, and per-minute / per-day request counters.
 * Durable Object storage is strongly consistent, so a counter can't be raced past its limit or replayed.
 */
export class DeviceGuard {
	constructor(state) {
		this.storage = state.storage
	}

	async fetch(request) {
		const url = new URL(request.url)
		const input = await request.json()
		try {
			switch (url.pathname) {
			case "/register": return reply(await this.register(input))
			case "/assert": return reply(await this.assert(input))
			case "/hit": return reply(await this.hit(input.limits))
			default: return reply({ ok: false, code: "not_found" }, 404)
			}
		} catch (error) {
			if (error instanceof AttestError) return reply({ ok: false, code: error.code })
			throw error
		}
	}

	async register({ publicKey, environment }) {
		const existing = await this.storage.get("key")
		// keyId is the hash of the public key, so a second registration can only be the same key.
		if (!existing) {
			await this.storage.put("key", { publicKey, environment, counter: 0, createdAt: Date.now() })
		}
		return { ok: true }
	}

	async assert({ assertion, clientDataHash, appId, limits }) {
		const key = await this.storage.get("key")
		if (!key) return { ok: false, code: "attest_unknown_key" }
		if (key.revoked) return { ok: false, code: "attest_revoked" }
		const counter = await verifyAssertion({
			assertion,
			clientDataHash: base64ToBytes(clientDataHash),
			publicKey: key.publicKey,
			previousCounter: key.counter,
			appId,
		})
		// Re-read after the async crypto: another request for this key may have landed meanwhile.
		const latest = await this.storage.get("key")
		if (counter <= latest.counter) return { ok: false, code: "attest_replay" }
		await this.storage.put("key", { ...latest, counter, lastUsedAt: Date.now() })
		return this.hit(limits)
	}

	async hit(limits = {}) {
		const now = Date.now()
		const minute = Math.floor(now / 60_000)
		const day = Math.floor(now / 86_400_000)
		const rate = (await this.storage.get("rate")) ?? {}
		const minuteCount = rate.minute === minute ? rate.minuteCount : 0
		const dayCount = rate.day === day ? rate.dayCount : 0
		if (limits.perMinute && minuteCount >= limits.perMinute) {
			return { ok: false, code: "rate_limited", window: "minute", retryAfter: 60 - Math.floor((now / 1000) % 60) }
		}
		if (limits.perDay && dayCount >= limits.perDay) {
			return { ok: false, code: "rate_limited", window: "day", retryAfter: 86_400 - Math.floor((now / 1000) % 86_400) }
		}
		await this.storage.put("rate", { minute, minuteCount: minuteCount + 1, day, dayCount: dayCount + 1 })
		return { ok: true }
	}
}

function reply(body, status = 200) {
	return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } })
}
