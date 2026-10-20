const OPENAI_UPSTREAM = "https://api.openai.com/v1/images/edits"
const DEFAULT_FLARE_MODEL = "gpt-image-2.5-flare"
const DEFAULT_SUNBURST_MODEL = "gpt-image-2.5-sunburst"
const MAX_BODY_BYTES = 15 * 1024 * 1024
const MAX_IMAGES = 16

const PRECISE_OPERATIONS = new Set(["reference", "replace", "delete"])
const ALLOWED_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp"])
const ALLOWED_MODELS = new Set([DEFAULT_FLARE_MODEL, DEFAULT_SUNBURST_MODEL])
const ALLOWED_QUALITIES = new Set(["low", "medium", "high", "xhigh", "max"])

export default {
	/**
	 * @param {Request} request
	 * @param {Record<string, string | undefined>} env
	 */
	async fetch(request, env) {
		const url = new URL(request.url)

		if (url.pathname === "/health" && request.method === "GET") {
			return json(200, {
				ok: true,
				service: "homeai-openai-images",
				api_version: 1,
				openai_configured: Boolean(env.OPENAI_API_KEY),
			})
		}

		if (url.pathname !== "/v1/images/generate") {
			return apiError(404, "not_found", "Route not found", false)
		}
		if (request.method !== "POST") {
			return apiError(405, "method_not_allowed", "Use POST", false)
		}

		const gateError = validateMobileGate(request, env)
		if (gateError) return gateError

		return generateImage(request, env)
	},
}

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
		console.error(JSON.stringify({ event: "openai_error", requestId, model, operation: input.operation, ...upstreamError }))
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
	if (received !== required) {
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
