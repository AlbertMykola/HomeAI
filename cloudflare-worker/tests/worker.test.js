import assert from "node:assert/strict"
import test from "node:test"
import worker from "../worker.js"

test("returns app generation limits", async () => {
	const response = await worker.fetch(new Request("https://worker.test/app/config"), {})
	const body = await response.json()

	assert.equal(response.status, 200)
	assert.equal(body.freeGenerationsLifetime, 1)
	assert.equal(body.premiumGenerationsPerDay, 15)
	assert.equal(body.lifetimeFreeScanLimit, body.freeGenerationsLifetime)
})

test("rejects payloads above the worker budget", async () => {
	const request = new Request(
		"https://worker.test/gemini/v1beta/models/gemini-test:generateContent",
		{
			method: "POST",
			headers: {
				"content-type": "application/json",
				"content-length": String(16 * 1024 * 1024),
			},
			body: "{}",
		},
	)

	const response = await worker.fetch(request, { GEMINI_API_KEY: "test-key" })
	const body = await response.json()

	assert.equal(response.status, 413)
	assert.equal(body.error, "payload_too_large")
	assert.equal(body.max_bytes, 15 * 1024 * 1024)
})

test("routes a model path and strips client secrets", async () => {
	const originalFetch = globalThis.fetch
	let capturedURL
	let capturedHeaders
	globalThis.fetch = async (url, init) => {
		capturedURL = String(url)
		capturedHeaders = init.headers
		return new Response('{"ok":true}', {
			status: 200,
			headers: { "content-type": "application/json" },
		})
	}

	try {
		const request = new Request(
			"https://worker.test/gemini/v1beta/models/gemini-3.1-flash-image-preview:generateContent",
			{
				method: "POST",
				headers: {
					"content-type": "application/json",
					"x-homeai-mobile-key": "client-secret",
				},
				body: "{}",
			},
		)

		const response = await worker.fetch(request, { GEMINI_API_KEY: "upstream-key" })

		assert.equal(response.status, 200)
		assert.equal(
			capturedURL,
			"https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent",
		)
		assert.equal(capturedHeaders.get("x-goog-api-key"), "upstream-key")
		assert.equal(capturedHeaders.has("x-homeai-mobile-key"), false)
	} finally {
		globalThis.fetch = originalFetch
	}
})

test("returns a structured error when Gemini is unconfigured", async () => {
	const response = await worker.fetch(
		new Request("https://worker.test/gemini", {
			method: "POST",
			body: "{}",
		}),
		{},
	)
	const body = await response.json()

	assert.equal(response.status, 500)
	assert.equal(body.error, "gemini_not_configured")
})

test("reads the older AI Studio secret name", async () => {
	const originalFetch = globalThis.fetch
	let capturedHeaders
	globalThis.fetch = async (url, init) => {
		capturedHeaders = init.headers
		return new Response("{}", { status: 200 })
	}
	try {
		const response = await worker.fetch(
			new Request("https://worker.test/gemini", { method: "POST", body: "{}" }),
			{ NEW_GEMINI_KEY_3: "legacy-key" },
		)
		assert.equal(response.status, 200)
		assert.equal(capturedHeaders.get("x-goog-api-key"), "legacy-key")
	} finally {
		globalThis.fetch = originalFetch
	}
})

test("refuses models and methods the app does not use", async () => {
	const env = { GEMINI_API_KEY: "k" }
	for (const path of [
		"/gemini/v1beta/models/gemini-3-pro-image-preview:generateContent",
		"/gemini/v1beta/models/gemini-2.5-flash:streamGenerateContent",
		"/gemini/v1beta/files",
	]) {
		const response = await worker.fetch(new Request(`https://worker.test${path}`, { method: "POST", body: "{}" }), env)
		assert.equal(response.status, 403, path)
		assert.equal((await response.json()).error.status, "PERMISSION_DENIED")
	}
	const get = await worker.fetch(new Request("https://worker.test/gemini/v1beta/models"), env)
	assert.equal(get.status, 404)
	const openai = await worker.fetch(
		new Request("https://worker.test/openai/v1/images/edits", { method: "POST", body: "x" }),
		{ ...env, OPENAI_API_KEY: "o" },
	)
	assert.equal(openai.status, 404)
})

/** In-memory stand-in for the DeviceGuard Durable Object. */
function fakeGuard({ assertOK = true } = {}) {
	const counts = new Map()
	const calls = []
	return {
		calls,
		idFromName: (name) => name,
		get: (name) => ({
			fetch: async (url, init) => {
				const path = new URL(url).pathname
				const input = JSON.parse(init.body)
				calls.push({ name, path, input })
				if (path === "/assert") return Response.json(assertOK ? { ok: true } : { ok: false, code: "attest_replay" })
				const n = (counts.get(name) ?? 0) + 1
				if (input.limits.perDay && n > input.limits.perDay) {
					return Response.json({ ok: false, code: "rate_limited", window: "day", retryAfter: 100 })
				}
				counts.set(name, n)
				return Response.json({ ok: true })
			},
		}),
	}
}

async function withUpstream(fn) {
	const originalFetch = globalThis.fetch
	let upstreamCalls = 0
	globalThis.fetch = async () => {
		upstreamCalls += 1
		return new Response("{}", { status: 200 })
	}
	try {
		await fn(() => upstreamCalls)
	} finally {
		globalThis.fetch = originalFetch
	}
}

const imagePath = "https://worker.test/gemini/v1beta/models/gemini-3.1-flash-image-preview:generateContent"

test("limits requests without App Attest per IP and stops at the daily cap", async () => {
	await withUpstream(async (upstreamCalls) => {
		const guard = fakeGuard()
		const env = { GEMINI_API_KEY: "k", DEVICE_GUARD: guard, LIMIT_IMAGE_IP_PER_DAY: "2" }
		const send = () => worker.fetch(new Request(imagePath, {
			method: "POST", body: "{}", headers: { "cf-connecting-ip": "1.2.3.4" },
		}), env)
		assert.equal((await send()).status, 200)
		assert.equal((await send()).status, 200)
		const third = await send()
		assert.equal(third.status, 429)
		assert.equal((await third.json()).error.status, "RESOURCE_EXHAUSTED")
		assert.equal(upstreamCalls(), 2)
		assert.equal(guard.calls[0].name, "gemini-image:ip:1.2.3.4")
	})
})

test("uses the device bucket for a valid assertion over the body hash", async () => {
	await withUpstream(async () => {
		const guard = fakeGuard()
		const env = { GEMINI_API_KEY: "k", DEVICE_GUARD: guard }
		const response = await worker.fetch(new Request(imagePath, {
			method: "POST", body: "{}",
			headers: { "X-HomeAI-Attest-Key": "a2V5aWRrZXlpZA==", "X-HomeAI-Attest-Assertion": "c2ln" },
		}), env)
		assert.equal(response.status, 200)
		assert.equal(guard.calls[0].path, "/assert")
		assert.equal(guard.calls[0].input.clientDataHash, "RBNvo1WzZ4oRRq0W9+hknpT7T8If536DEMBg9hyq/4o=")
		assert.equal(guard.calls[1].name, "gemini-image:key:a2V5aWRrZXlpZA==")
	})
})

test("enforce mode refuses requests without a valid assertion", async () => {
	await withUpstream(async (upstreamCalls) => {
		const env = { GEMINI_API_KEY: "k", DEVICE_GUARD: fakeGuard({ assertOK: false }), GEMINI_ATTEST_MODE: "enforce" }
		const plain = await worker.fetch(new Request(imagePath, { method: "POST", body: "{}" }), env)
		assert.equal(plain.status, 401)
		const bad = await worker.fetch(new Request(imagePath, {
			method: "POST", body: "{}",
			headers: { "X-HomeAI-Attest-Key": "a2V5aWRrZXlpZA==", "X-HomeAI-Attest-Assertion": "c2ln" },
		}), env)
		assert.equal(bad.status, 401)
		assert.equal(upstreamCalls(), 0)
	})
})
