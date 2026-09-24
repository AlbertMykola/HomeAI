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
			"https://worker.test/gemini/v1beta/models/gemini-test:generateContent",
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
			"https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent",
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

test("proxies OpenAI image edits and injects the Worker secret", async () => {
	const originalFetch = globalThis.fetch
	let capturedURL
	let capturedHeaders
	let capturedMethod

	globalThis.fetch = async (url, init) => {
		capturedURL = String(url)
		capturedHeaders = init.headers
		capturedMethod = init.method
		return new Response('{"data":[]}', {
			status: 200,
			headers: { "content-type": "application/json" },
		})
	}

	try {
		const request = new Request(
			"https://worker.test/openai/v1/images/edits",
			{
				method: "POST",
				headers: {
					"content-type": "multipart/form-data; boundary=test",
					authorization: "Bearer client-key",
					"x-homeai-mobile-key": "client-secret",
				},
				body: "--test--\r\n",
			},
		)

		const response = await worker.fetch(request, {
			OPENAI_API_KEY: "worker-openai-key",
		})

		assert.equal(response.status, 200)
		assert.equal(capturedMethod, "POST")
		assert.equal(capturedURL, "https://api.openai.com/v1/images/edits")
		assert.equal(capturedHeaders.get("authorization"), "Bearer worker-openai-key")
		assert.equal(capturedHeaders.has("x-homeai-mobile-key"), false)
		assert.match(capturedHeaders.get("content-type"), /multipart\/form-data/)
	} finally {
		globalThis.fetch = originalFetch
	}
})

test("returns a structured error when OpenAI is unconfigured", async () => {
	const response = await worker.fetch(
		new Request("https://worker.test/openai/v1/images/edits", {
			method: "POST",
			body: "test",
		}),
		{},
	)
	const body = await response.json()

	assert.equal(response.status, 500)
	assert.equal(body.error, "OPENAI_API_KEY secret is not set")
})

