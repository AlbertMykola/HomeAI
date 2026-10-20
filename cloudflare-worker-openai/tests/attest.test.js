import assert from "node:assert/strict"
import { execFileSync } from "node:child_process"
import { createHash, createPrivateKey, sign } from "node:crypto"
import { readFileSync } from "node:fs"
import test from "node:test"
import { checkChallenge, makeChallenge, verifyAttestation } from "../attest.js"
import worker, { DeviceGuard } from "../worker.js"

// Throwaway test CA + key, regenerated on every run (never committed).
execFileSync(process.execPath, [new URL("./make-attest-fixtures.mjs", import.meta.url).pathname])
const fixture = JSON.parse(readFileSync(new URL("./fixtures/attest.json", import.meta.url), "utf8"))

const encoder = new TextEncoder()
const sha256 = (data) => createHash("sha256").update(data).digest()

function attestationInput(overrides = {}) {
	return {
		keyId: fixture.keyId,
		attestation: fixture.attestation,
		clientData: encoder.encode(fixture.challenge),
		appId: fixture.appId,
		allowDevelopment: true,
		rootPem: fixture.rootPem,
		...overrides,
	}
}

test("accepts a well-formed attestation from the trusted root", async () => {
	const result = await verifyAttestation(attestationInput())
	assert.equal(result.environment, "development")
	assert.ok(result.publicKey.length > 0)
})

test("rejects attestations from another root (Apple's root by default)", async () => {
	await assert.rejects(verifyAttestation(attestationInput({ rootPem: undefined })), { code: "attest_invalid" })
})

test("rejects a different challenge, app id, key id or a development key when not allowed", async () => {
	await assert.rejects(verifyAttestation(attestationInput({ clientData: encoder.encode("other") })), /Nonce/)
	await assert.rejects(verifyAttestation(attestationInput({ appId: "OTHER.com.example" })), /App id/)
	await assert.rejects(verifyAttestation(attestationInput({ keyId: btoa("x".repeat(32)) })), /Key id/)
	await assert.rejects(verifyAttestation(attestationInput({ allowDevelopment: false })), /environment/)
})

test("challenges are signed and expire", async () => {
	const challenge = await makeChallenge("secret", 1_000_000)
	assert.equal(await checkChallenge("secret", challenge, 1_000_000 + 60_000), true)
	assert.equal(await checkChallenge("other", challenge, 1_000_000), false)
	assert.equal(await checkChallenge("secret", challenge, 1_000_000 + 6 * 60_000), false)
	assert.equal(await checkChallenge("secret", "garbage", 1_000_000), false)
})

// MARK: Worker flow with an in-memory Durable Object

function makeEnv(extra = {}) {
	const instances = new Map()
	const DEVICE_GUARD = {
		idFromName: (name) => name,
		get: (id) => {
			if (!instances.has(id)) {
				const data = new Map()
				const storage = {
					get: async (key) => structuredClone(data.get(key)),
					put: async (key, value) => { data.set(key, structuredClone(value)) },
				}
				instances.set(id, new DeviceGuard({ storage }))
			}
			const guard = instances.get(id)
			return { fetch: (url, init) => guard.fetch(new Request(url, init)) }
		},
	}
	return {
		OPENAI_API_KEY: "server-secret",
		ATTEST_CHALLENGE_SECRET: "challenge-secret",
		ATTEST_APP_ID: fixture.appId,
		DEVICE_GUARD,
		...extra,
	}
}

async function registerFixtureKey(env) {
	const verified = await verifyAttestation(attestationInput())
	const stub = env.DEVICE_GUARD.get(env.DEVICE_GUARD.idFromName(`key:${fixture.keyId}`))
	await stub.fetch("https://guard/register", {
		method: "POST",
		body: JSON.stringify({ publicKey: verified.publicKey, environment: verified.environment }),
	})
}

function makeAssertion(body, counter) {
	const authData = Buffer.concat([sha256(Buffer.from(fixture.appId)), Buffer.from([0x40]), uint32(counter)])
	const nonce = sha256(Buffer.concat([authData, sha256(Buffer.from(body))]))
	const signature = sign("sha256", nonce, createPrivateKey(fixture.leafPrivateKeyPem))
	return Buffer.concat([
		Buffer.from([0xa2]),
		cborText("signature"), cborBytes(signature),
		cborText("authenticatorData"), cborBytes(authData),
	]).toString("base64")
}

function generateRequest(body, headers = {}) {
	return new Request("https://worker.test/v1/images/generate", {
		method: "POST",
		headers: { "content-type": "application/json", "cf-connecting-ip": "203.0.113.7", ...headers },
		body,
	})
}

const body = JSON.stringify({
	version: 1,
	operation: "interior",
	prompt: "Redesign this room",
	images: [{ role: "base", mimeType: "image/jpeg", data: btoa("base-image") }],
})

function withOpenAIStub(run) {
	const originalFetch = globalThis.fetch
	let calls = 0
	globalThis.fetch = async () => {
		calls += 1
		return new Response(JSON.stringify({ data: [{ b64_json: "img" }] }), {
			status: 200, headers: { "content-type": "application/json" },
		})
	}
	return run(() => calls).finally(() => { globalThis.fetch = originalFetch })
}

test("generation without a device assertion is refused before OpenAI is called", () => withOpenAIStub(async (calls) => {
	const response = await worker.fetch(generateRequest(body), makeEnv())
	assert.equal(response.status, 401)
	assert.equal((await response.json()).error.code, "attest_required")
	assert.equal(calls(), 0)
}))

test("a valid assertion passes; replaying it or signing another body fails", () => withOpenAIStub(async (calls) => {
	const env = makeEnv()
	await registerFixtureKey(env)
	const headers = { "X-HomeAI-Attest-Key": fixture.keyId, "X-HomeAI-Attest-Assertion": makeAssertion(body, 1) }

	assert.equal((await worker.fetch(generateRequest(body, headers), env)).status, 200)

	const replay = await worker.fetch(generateRequest(body, headers), env)
	assert.equal(replay.status, 401)
	assert.equal((await replay.json()).error.code, "attest_replay")

	const tampered = body.replace("Redesign", "Steal")
	const forged = await worker.fetch(generateRequest(tampered, {
		...headers, "X-HomeAI-Attest-Assertion": makeAssertion(body, 2),
	}), env)
	assert.equal(forged.status, 401)
	assert.equal(calls(), 1)
}))

test("unknown keys are told to re-attest", () => withOpenAIStub(async () => {
	const response = await worker.fetch(generateRequest(body, {
		"X-HomeAI-Attest-Key": fixture.keyId, "X-HomeAI-Attest-Assertion": makeAssertion(body, 1),
	}), makeEnv())
	assert.equal(response.status, 401)
	assert.equal((await response.json()).error.code, "attest_unknown_key")
}))

test("per-device minute limit returns 429 with retry-after", () => withOpenAIStub(async (calls) => {
	const env = makeEnv({ LIMIT_DEVICE_PER_MINUTE: "2" })
	await registerFixtureKey(env)
	const statuses = []
	let last
	for (let counter = 1; counter <= 3; counter += 1) {
		last = await worker.fetch(generateRequest(body, {
			"X-HomeAI-Attest-Key": fixture.keyId, "X-HomeAI-Attest-Assertion": makeAssertion(body, counter),
		}), env)
		statuses.push(last.status)
	}
	assert.deepEqual(statuses, [200, 200, 429])
	assert.equal((await last.json()).error.code, "rate_limited_minute")
	assert.ok(Number(last.headers.get("retry-after")) > 0)
	assert.equal(calls(), 2)
}))

test("per-IP limit applies even before the body is checked", () => withOpenAIStub(async () => {
	const env = makeEnv({ LIMIT_IP_PER_MINUTE: "1" })
	assert.equal((await worker.fetch(generateRequest(body), env)).status, 401)
	const second = await worker.fetch(generateRequest(body), env)
	assert.equal(second.status, 429)
}))

test("dev token works only when it matches the worker secret", () => withOpenAIStub(async () => {
	const env = makeEnv({ DEV_BYPASS_TOKEN: "dev-secret" })
	assert.equal((await worker.fetch(generateRequest(body, { "X-HomeAI-Dev-Token": "dev-secret" }), env)).status, 200)
	assert.equal((await worker.fetch(generateRequest(body, { "X-HomeAI-Dev-Token": "guess" }), env)).status, 401)
	const noSecret = makeEnv()
	assert.equal((await worker.fetch(generateRequest(body, { "X-HomeAI-Dev-Token": "dev-secret" }), noSecret)).status, 401)
}))

test("challenge endpoint returns a verifiable challenge; register rejects a forged attestation", async () => {
	const env = makeEnv()
	const challengeResponse = await worker.fetch(new Request("https://worker.test/attest/challenge"), env)
	const { challenge } = await challengeResponse.json()
	assert.equal(await checkChallenge("challenge-secret", challenge), true)

	const register = await worker.fetch(new Request("https://worker.test/attest/register", {
		method: "POST",
		body: JSON.stringify({ keyId: fixture.keyId, attestation: fixture.attestation, challenge }),
	}), env)
	assert.equal(register.status, 401) // test CA is not Apple's root
	assert.equal((await register.json()).error.code, "attest_invalid")

	const stale = await worker.fetch(new Request("https://worker.test/attest/register", {
		method: "POST",
		body: JSON.stringify({ keyId: fixture.keyId, attestation: fixture.attestation, challenge: "old" }),
	}), env)
	assert.equal((await stale.json()).error.code, "attest_challenge")
})

function uint32(value) {
	const out = Buffer.alloc(4)
	out.writeUInt32BE(value)
	return out
}

function cborText(text) {
	return Buffer.concat([Buffer.from([0x60 | text.length]), Buffer.from(text)])
}

function cborBytes(bytes) {
	return Buffer.concat([Buffer.from([0x58, bytes.length]), bytes])
}
