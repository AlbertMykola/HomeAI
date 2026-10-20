import assert from "node:assert/strict"
import test from "node:test"
import worker from "../worker.js"

test("reports health without exposing secrets", async () => {
	const response = await worker.fetch(
		new Request("https://worker.test/health"),
		{ OPENAI_API_KEY: "secret", ATTEST_MODE: "off" },
	)
	const body = await response.json()

	assert.equal(response.status, 200)
	assert.equal(body.openai_configured, true)
	assert.equal(JSON.stringify(body).includes("secret"), false)
})

test("rejects unsupported API versions", async () => {
	const response = await worker.fetch(
		makeRequest({ version: 2 }),
		{ OPENAI_API_KEY: "secret", ATTEST_MODE: "off" },
	)
	const body = await response.json()

	assert.equal(response.status, 400)
	assert.equal(body.error.code, "unsupported_version")
	assert.equal(body.error.retryable, false)
})

test("requires the configured mobile gate", async () => {
	const response = await worker.fetch(
		makeRequest(),
		{ OPENAI_API_KEY: "secret", MOBILE_GATE_KEY: "expected", ATTEST_MODE: "off" },
	)
	const body = await response.json()

	assert.equal(response.status, 403)
	assert.equal(body.error.code, "forbidden")
})

test("uses Flare for standard generation and normalizes response", async () => {
	const originalFetch = globalThis.fetch
	let capturedURL
	let capturedHeaders
	let capturedForm

	globalThis.fetch = async (url, init) => {
		capturedURL = String(url)
		capturedHeaders = init.headers
		capturedForm = init.body
		return new Response(
			JSON.stringify({
				data: [{ b64_json: "generated-image" }],
				usage: { total_tokens: 100, input_tokens: 60, output_tokens: 40 },
			}),
			{ status: 200, headers: { "content-type": "application/json" } },
		)
	}

	try {
		const response = await worker.fetch(
			makeRequest(),
			{ OPENAI_API_KEY: "server-secret", ATTEST_MODE: "off" },
		)
		const body = await response.json()

		assert.equal(response.status, 200)
		assert.equal(capturedURL, "https://api.openai.com/v1/images/edits")
		assert.equal(capturedHeaders.authorization, "Bearer server-secret")
		assert.equal(capturedForm.get("model"), "gpt-image-2.5-flare")
		assert.equal(capturedForm.getAll("image[]").length, 1)
		assert.equal(body.provider, "openai")
		assert.equal(body.image.data, "generated-image")
		assert.equal(body.usage.totalTokens, 100)
	} finally {
		globalThis.fetch = originalFetch
	}
})

test("uses Sunburst and sends an alpha mask as mask", async () => {
	const originalFetch = globalThis.fetch
	let capturedForm

	globalThis.fetch = async (_url, init) => {
		capturedForm = init.body
		return new Response(
			JSON.stringify({ data: [{ b64_json: "generated-image" }] }),
			{ status: 200, headers: { "content-type": "application/json" } },
		)
	}

	try {
		const response = await worker.fetch(
			makeRequest({
				operation: "replace",
				images: [
					makeImage("base", "image/jpeg"),
					makeImage("mask", "image/png"),
				],
			}),
			{ OPENAI_API_KEY: "secret", ATTEST_MODE: "off" },
		)

		assert.equal(response.status, 200)
		assert.equal(capturedForm.get("model"), "gpt-image-2.5-sunburst")
		assert.equal(capturedForm.getAll("image[]").length, 1)
		assert.equal(capturedForm.get("mask").type, "image/png")
	} finally {
		globalThis.fetch = originalFetch
	}
})

test("returns stable error codes plus the upstream error, never the key", async () => {
	const originalFetch = globalThis.fetch
	globalThis.fetch = async () => new Response(
		JSON.stringify({ error: { message: "Internal upstream detail", code: "x" } }),
		{ status: 503, headers: { "content-type": "application/json" } },
	)

	try {
		const response = await worker.fetch(
			makeRequest(),
			{ OPENAI_API_KEY: "secret", ATTEST_MODE: "off" },
		)
		const body = await response.json()

		assert.equal(response.status, 503)
		assert.equal(body.error.code, "provider_unavailable")
		assert.equal(body.error.retryable, true)
		assert.equal(body.error.upstream.status, 503)
		assert.equal(body.error.upstream.code, "x")
		assert.equal(body.error.upstream.message, "Internal upstream detail")
		assert.equal(JSON.stringify(body).includes("secret"), false)
	} finally {
		globalThis.fetch = originalFetch
	}
})

function makeRequest(overrides = {}) {
	const body = {
		version: 1,
		operation: "interior",
		prompt: "Redesign this room",
		images: [makeImage("base", "image/jpeg")],
		...overrides,
	}
	return new Request("https://worker.test/v1/images/generate", {
		method: "POST",
		headers: { "content-type": "application/json" },
		body: JSON.stringify(body),
	})
}

function makeImage(role, mimeType) {
	return {
		role,
		mimeType,
		data: btoa(`${role}-image`),
	}
}

test("routes through AI Gateway with logging off when AI_GATEWAY_ID is set", async () => {
	const originalFetch = globalThis.fetch
	let capturedURL
	let capturedHeaders
	globalThis.fetch = async (url, init) => {
		capturedURL = String(url)
		capturedHeaders = init.headers
		return new Response(JSON.stringify({ data: [{ b64_json: "img" }] }), {
			status: 200, headers: { "content-type": "application/json" },
		})
	}
	try {
		const response = await worker.fetch(makeRequest(), {
			OPENAI_API_KEY: "secret",
			ATTEST_MODE: "off",
			AI_GATEWAY_ID: "rehomely",
			AI_GATEWAY_ACCOUNT_ID: "8da2a8ef7d6734a145d217f8663da27d",
		})
		assert.equal(response.status, 200)
		assert.equal(
			capturedURL,
			"https://gateway.ai.cloudflare.com/v1/8da2a8ef7d6734a145d217f8663da27d/rehomely/openai/images/edits",
		)
		assert.equal(capturedHeaders.authorization, "Bearer secret")
		assert.equal(capturedHeaders["cf-aig-collect-log"], "false")
		assert.equal(capturedHeaders["cf-aig-collect-log-payload"], "false")
	} finally {
		globalThis.fetch = originalFetch
	}
})
