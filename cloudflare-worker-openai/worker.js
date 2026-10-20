import {
	AttestError,
	base64ToBytes,
	bytesToBase64,
	checkChallenge,
	equalStrings,
	makeChallenge,
	sha256,
	verifyAttestation,
} from "./attest.js"

export { DeviceGuard } from "./guard.js"

const OPENAI_UPSTREAM = "https://api.openai.com/v1/images/edits"
const DEFAULT_FLARE_MODEL = "gpt-image-2.5-flare"
const DEFAULT_SUNBURST_MODEL = "gpt-image-2.5-sunburst"
const MAX_BODY_BYTES = 15 * 1024 * 1024
const MAX_IMAGES = 16
const MAX_ATTESTATION_BYTES = 64 * 1024
const DEFAULT_APP_ID = "5998UF2M9Y.com.albert.apps.design.ai"

const PRECISE_OPERATIONS = new Set(["reference", "replace", "delete"])
const ALLOWED_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp"])
const ALLOWED_MODELS = new Set([DEFAULT_FLARE_MODEL, DEFAULT_SUNBURST_MODEL])
const ALLOWED_QUALITIES = new Set(["low", "medium", "high", "xhigh", "max"])

export default {
	/**
	 * @param {Request} request
	 * @param {Record<string, any>} env
	 */
	async fetch(request, env) {
		const url = new URL(request.url)

		if (url.pathname === "/health" && request.method === "GET") {
			return json(200, {
				ok: true,
				service: "homeai-openai-images",
				api_version: 1,
				openai_configured: Boolean(env.OPENAI_API_KEY),
				attest: attestMode(env),
			})
		}

		const routes = {
			"/attest/challenge": "GET",
			"/attest/register": "POST",
			"/v1/images/generate": "POST",
		}
		if (!routes[url.pathname]) {
			return apiError(404, "not_found", "Route not found", false)
		}
		if (request.method !== routes[url.pathname]) {
			return apiError(405, "method_not_allowed", `Use ${routes[url.pathname]}`, false)
		}

		const gateError = validateMobileGate(request, env)
		if (gateError) return gateError

		switch (url.pathname) {
		case "/attest/challenge":
			return issueChallenge(request, env)
		case "/attest/register":
			return registerKey(request, env)
		default:
			return generateImage(request, env)
		}
	},
}

// MARK: App Attest

/** "enforce" (default) or "off" (emergency switch: `[vars] ATTEST_MODE = "off"` + deploy). */
function attestMode(env) {
	return String(env.ATTEST_MODE ?? "enforce").trim().toLowerCase() === "off" ? "off" : "enforce"
}

async function issueChallenge(request, env) {
	if (!env.ATTEST_CHALLENGE_SECRET) {
		return apiError(503, "attest_not_configured", "Device check is not configured", true)
	}
	const limited = await hitBucket(env, `attest-ip:${clientIP(request)}`, limitsFor(env, "ATTEST_IP"))
	if (limited) return limited
	return json(200, { version: 1, challenge: await makeChallenge(env.ATTEST_CHALLENGE_SECRET) })
}

async function registerKey(request, env) {
	const requestId = crypto.randomUUID()
	if (!env.ATTEST_CHALLENGE_SECRET || !env.DEVICE_GUARD) {
		return apiError(503, "attest_not_configured", "Device check is not configured", true, requestId)
	}
	const limited = await hitBucket(env, `attest-ip:${clientIP(request)}`, limitsFor(env, "ATTEST_IP"), requestId)
	if (limited) return limited

	let input
	try {
		const text = await request.text()
		if (text.length > MAX_ATTESTATION_BYTES) throw new Error("too large")
		input = JSON.parse(text)
	} catch {
		return apiError(400, "invalid_json", "Request body must be JSON", false, requestId)
	}
	if (typeof input?.keyId !== "string" || typeof input?.attestation !== "string") {
		return apiError(400, "attest_invalid", "keyId and attestation are required", false, requestId)
	}
	if (!(await checkChallenge(env.ATTEST_CHALLENGE_SECRET, input.challenge))) {
		return apiError(401, "attest_challenge", "Challenge is missing or expired", true, requestId)
	}

	let verified
	try {
		verified = await verifyAttestation({
			keyId: input.keyId,
			attestation: input.attestation,
			clientData: new TextEncoder().encode(input.challenge),
			appId: appID(env),
			allowDevelopment: String(env.ATTEST_ALLOW_DEVELOPMENT ?? "true") === "true",
		})
	} catch (error) {
		const code = error instanceof AttestError ? error.code : "attest_invalid"
		console.warn(JSON.stringify({ event: "attest_register_failed", requestId, code, reason: error?.message }))
		return apiError(401, code, "Device check failed", false, requestId)
	}

	const result = await callGuard(env, `key:${input.keyId}`, "/register", {
		publicKey: verified.publicKey,
		environment: verified.environment,
	})
	if (!result.ok) return apiError(500, "attest_store_failed", "Could not save device key", true, requestId)
	console.log(JSON.stringify({ event: "attest_registered", requestId, environment: verified.environment }))
	return json(200, { version: 1, requestId, ok: true, environment: verified.environment })
}

/** Every generation: a fresh assertion over SHA256(body) from an attested key, or the Debug simulator token. */
async function authorizeDevice(request, env, bodyBytes, requestId) {
	const devToken = String(env.DEV_BYPASS_TOKEN ?? "").trim()
	const receivedDevToken = request.headers.get("X-HomeAI-Dev-Token")
	if (devToken && receivedDevToken) {
		if (!equalStrings(receivedDevToken, devToken)) {
			return apiError(401, "attest_required", "Device check failed", false, requestId)
		}
		return hitBucket(env, "dev", limitsFor(env, "DEVICE"), requestId)
	}

	const keyId = request.headers.get("X-HomeAI-Attest-Key")
	const assertion = request.headers.get("X-HomeAI-Attest-Assertion")
	if (!keyId || !assertion) {
		if (attestMode(env) === "off") return null
		return apiError(401, "attest_required", "Device check is required", false, requestId)
	}
	if (!env.DEVICE_GUARD) {
		return apiError(503, "attest_not_configured", "Device check is not configured", true, requestId)
	}
	try {
		base64ToBytes(keyId)
	} catch {
		return apiError(401, "attest_invalid", "Device check failed", false, requestId)
	}

	const result = await callGuard(env, `key:${keyId}`, "/assert", {
		assertion,
		clientDataHash: bytesToBase64(await sha256(new Uint8Array(bodyBytes))),
		appId: appID(env),
		limits: limitsFor(env, "DEVICE"),
	})
	if (result.ok) return null
	if (result.code === "rate_limited") return rateLimited(result, "device", requestId)
	console.warn(JSON.stringify({ event: "attest_assert_failed", requestId, code: result.code }))
	// In "off" mode a broken assertion is logged but does not block (rollout safety).
	if (attestMode(env) === "off") return null
	return apiError(401, result.code ?? "attest_invalid", "Device check failed", false, requestId)
}

// MARK: Rate limits

function limitsFor(env, prefix) {
	const defaults = {
		DEVICE: { perMinute: 6, perDay: 100 },
		IP: { perMinute: 20, perDay: 400 },
		ATTEST_IP: { perMinute: 10, perDay: 50 },
	}[prefix]
	const read = (name, fallback) => {
		const value = Number(env[`LIMIT_${prefix}_${name}`])
		return Number.isFinite(value) && value > 0 ? value : fallback
	}
	return { perMinute: read("PER_MINUTE", defaults.perMinute), perDay: read("PER_DAY", defaults.perDay) }
}

async function hitBucket(env, name, limits, requestId = crypto.randomUUID()) {
	if (!env.DEVICE_GUARD) return null
	const result = await callGuard(env, name, "/hit", { limits })
	return result.ok ? null : rateLimited(result, name.split(":")[0], requestId)
}

function rateLimited(result, scope, requestId) {
	console.warn(JSON.stringify({ event: "rate_limited", requestId, scope, window: result.window }))
	const response = apiError(
		429,
		result.window === "day" ? "rate_limited_daily" : "rate_limited_minute",
		"Too many requests",
		false,
		requestId,
	)
	response.headers.set("retry-after", String(result.retryAfter ?? 60))
	return response
}

async function callGuard(env, name, path, body) {
	const stub = env.DEVICE_GUARD.get(env.DEVICE_GUARD.idFromName(name))
	const response = await stub.fetch(`https://guard${path}`, {
		method: "POST",
		headers: { "content-type": "application/json" },
		body: JSON.stringify(body),
	})
	return response.json()
}

function clientIP(request) {
	return request.headers.get("cf-connecting-ip") ?? "unknown"
}

function appID(env) {
	return String(env.ATTEST_APP_ID ?? DEFAULT_APP_ID).trim()
}

// MARK: Generation

async function generateImage(request, env) {
	const requestId = crypto.randomUUID()
	if (!env.OPENAI_API_KEY) {
		return apiError(
			503,
			"provider_not_configured",
			"Image provider is not configured",
			true,
			requestId,
		)
	}

	const ipLimited = await hitBucket(env, `ip:${clientIP(request)}`, limitsFor(env, "IP"), requestId)
	if (ipLimited) return ipLimited

	const contentLength = Number(request.headers.get("content-length") ?? 0)
	if (contentLength > MAX_BODY_BYTES) {
		return apiError(413, "payload_too_large", "Request body is too large", false, requestId)
	}

	let bodyBytes
	try {
		bodyBytes = await request.arrayBuffer()
	} catch {
		return apiError(400, "invalid_body", "Could not read request body", false, requestId)
	}
	if (bodyBytes.byteLength > MAX_BODY_BYTES) {
		return apiError(413, "payload_too_large", "Request body is too large", false, requestId)
	}

	const deviceError = await authorizeDevice(request, env, bodyBytes, requestId)
	if (deviceError) return deviceError

	let input
	try {
		input = JSON.parse(new TextDecoder().decode(bodyBytes))
	} catch {
		return apiError(400, "invalid_json", "Request body must be JSON", false, requestId)
	}

	const validationError = validateInput(input, requestId)
	if (validationError) return validationError

	const model = resolveModel(input.operation, env)
	const quality = resolveQuality(env)
	const form = new FormData()
	form.append("model", model)
	form.append("prompt", input.prompt)
	form.append("quality", quality)
	form.append("size", "auto")
	form.append("background", "opaque")
	form.append("output_format", "jpeg")
	form.append("output_compression", "90")
	form.append("n", "1")

	for (const [index, image] of input.images.entries()) {
		let bytes
		try {
			bytes = decodeBase64(image.data)
		} catch {
			return apiError(
				400,
				"invalid_image_data",
				`Image ${index} is not valid base64`,
				false,
				requestId,
			)
		}

		const extension = extensionForMimeType(image.mimeType)
		const blob = new Blob([bytes], { type: image.mimeType })
		if (image.role === "mask") {
			form.append("mask", blob, `mask.${extension}`)
		} else {
			form.append("image[]", blob, `${image.role}-${index}.${extension}`)
		}
	}

	let upstream
	try {
		upstream = await fetch(OPENAI_UPSTREAM, {
			method: "POST",
			headers: {
				authorization: `Bearer ${env.OPENAI_API_KEY}`,
			},
			body: form,
		})
	} catch {
		return apiError(
			502,
			"provider_unavailable",
			"Image provider is unavailable",
			true,
			requestId,
		)
	}

	let output
	try {
		output = await upstream.json()
	} catch {
		return apiError(
			502,
			"invalid_provider_response",
			"Image provider returned an invalid response",
			true,
			requestId,
		)
	}

	if (!upstream.ok) {
		const providerCode = String(output?.error?.code ?? "")
		const category = classifyProviderError(upstream.status, providerCode)
		// What OpenAI itself said (never the key): visible in `wrangler tail` and in the app's error reports.
		const upstreamError = {
			status: upstream.status,
			code: output?.error?.code ?? null,
			type: output?.error?.type ?? null,
			message: truncate(String(output?.error?.message ?? ""), 500),
			// OpenAI's own ids for support tickets (no secrets).
			requestId: upstream.headers.get("x-request-id"),
			organization: upstream.headers.get("openai-organization"),
			project: upstream.headers.get("openai-project"),
		}
		console.error(JSON.stringify({
			event: "openai_error", model, operation: input.operation,
			...upstreamError, openaiRequestId: upstreamError.requestId, requestId,
		}))
		return apiError(
			upstream.status,
			category.code,
			category.publicMessage,
			category.retryable,
			requestId,
			upstreamError,
		)
	}

	const imageData = output?.data?.[0]?.b64_json
	if (!imageData) {
		return apiError(
			502,
			"no_image",
			"Image provider returned no image",
			true,
			requestId,
		)
	}

	return json(200, {
		version: 1,
		requestId,
		provider: "openai",
		model,
		image: {
			mimeType: "image/jpeg",
			data: imageData,
		},
		usage: normalizeUsage(output?.usage),
	})
}

function validateInput(input, requestId) {
	if (input?.version !== 1) {
		return apiError(400, "unsupported_version", "Unsupported API version", false, requestId)
	}
	if (typeof input.operation !== "string" || input.operation.length > 64) {
		return apiError(400, "invalid_operation", "Invalid generation operation", false, requestId)
	}
	if (
		typeof input.prompt !== "string" ||
		input.prompt.trim().length === 0 ||
		input.prompt.length > 32_000
	) {
		return apiError(400, "invalid_prompt", "Invalid generation prompt", false, requestId)
	}
	if (!Array.isArray(input.images) || input.images.length === 0) {
		return apiError(400, "missing_image", "At least one image is required", false, requestId)
	}
	if (input.images.length > MAX_IMAGES) {
		return apiError(400, "too_many_images", "Too many input images", false, requestId)
	}
	if (input.images[0]?.role !== "base") {
		return apiError(400, "missing_base_image", "The first image must be the base image", false, requestId)
	}

	let maskCount = 0
	for (const image of input.images) {
		if (!["base", "reference", "mask"].includes(image?.role)) {
			return apiError(400, "invalid_image_role", "Invalid image role", false, requestId)
		}
		if (!ALLOWED_MIME_TYPES.has(image?.mimeType)) {
			return apiError(400, "invalid_image_type", "Unsupported image type", false, requestId)
		}
		if (typeof image?.data !== "string" || image.data.length === 0) {
			return apiError(400, "invalid_image_data", "Image data is missing", false, requestId)
		}
		if (image.role === "mask") {
			maskCount += 1
			if (image.mimeType !== "image/png") {
				return apiError(400, "invalid_mask_type", "Mask must be PNG", false, requestId)
			}
		}
	}
	if (maskCount > 1) {
		return apiError(400, "too_many_masks", "Only one mask is supported", false, requestId)
	}
	return null
}

function validateMobileGate(request, env) {
	const required = String(env.MOBILE_GATE_KEY ?? "").trim()
	if (!required) return null
	const received = request.headers.get("X-HomeAI-Mobile-Key") ?? ""
	if (!equalStrings(received, required)) {
		return apiError(403, "forbidden", "Request is not authorized", false)
	}
	return null
}

function resolveModel(operation, env) {
	const override = String(env.OPENAI_IMAGE_MODEL ?? "").trim()
	if (ALLOWED_MODELS.has(override)) return override
	return PRECISE_OPERATIONS.has(operation)
		? DEFAULT_SUNBURST_MODEL
		: DEFAULT_FLARE_MODEL
}

function resolveQuality(env) {
	const quality = String(env.OPENAI_IMAGE_QUALITY ?? "").trim().toLowerCase()
	return ALLOWED_QUALITIES.has(quality) ? quality : "medium"
}

function classifyProviderError(status, providerCode) {
	if (
		providerCode === "moderation_blocked" ||
		providerCode === "image_generation_user_error"
	) {
		return {
			code: "content_policy",
			publicMessage: "The image request could not be processed",
			retryable: false,
		}
	}
	if (status === 429) {
		return {
			code: "rate_limited",
			publicMessage: "The image service is busy",
			retryable: true,
		}
	}
	if (status >= 500) {
		return {
			code: "provider_unavailable",
			publicMessage: "The image service is temporarily unavailable",
			retryable: true,
		}
	}
	return {
		code: "provider_error",
		publicMessage: "The image request could not be processed",
		retryable: false,
	}
}

function decodeBase64(value) {
	const binary = atob(value)
	const bytes = new Uint8Array(binary.length)
	for (let index = 0; index < binary.length; index += 1) {
		bytes[index] = binary.charCodeAt(index)
	}
	return bytes
}

function extensionForMimeType(mimeType) {
	switch (mimeType) {
	case "image/png":
		return "png"
	case "image/webp":
		return "webp"
	default:
		return "jpg"
	}
}

function normalizeUsage(usage) {
	if (!usage || typeof usage !== "object") return null
	return {
		totalTokens: numberOrNull(usage.total_tokens),
		inputTokens: numberOrNull(usage.input_tokens),
		outputTokens: numberOrNull(usage.output_tokens),
	}
}

function numberOrNull(value) {
	return typeof value === "number" ? value : null
}

function apiError(status, code, message, retryable, requestId = crypto.randomUUID(), upstream = undefined) {
	const error = { code, message, retryable }
	if (upstream) error.upstream = upstream
	return json(status, {
		version: 1,
		requestId,
		error,
	})
}

function truncate(text, limit) {
	return text.length > limit ? `${text.slice(0, limit)}…` : text
}

function json(status, body) {
	return new Response(JSON.stringify(body), {
		status,
		headers: {
			"content-type": "application/json; charset=utf-8",
			"cache-control": "no-store",
		},
	})
}
