/**
 * HomeAI proxy worker (Cloudflare Workers).
 *
 * Gemini: Vertex AI (GCP billing / $300 credit) або AI Studio API key (rollback).
 * iOS не змінюється — той самий шлях `/gemini/v1beta/models/...:generateContent`.
 *
 * ──────────────────── Secrets ────────────────────
 *   GCP_SERVICE_ACCOUNT_JSON  — JSON service account (Vertex; рекомендовано)
 *   GCP_PROJECT_ID            — опційно, якщо немає в JSON
 *   GCP_REGION                — опційно, default `us-central1`
 *   GEMINI_UPSTREAM           — `vertex` | `ai_studio` | порожньо (auto)
 *   GEMINI_API_KEY            — AI Studio rollback
 *   OPENAI_API_KEY
 *   MOBILE_GATE_KEY
 *
 * ──────────────────── Маршрути ────────────────────
 *  GET  /app/config
 *  GET  /health
 *  POST /, /gemini, /gemini/v1beta/models/{model}:generateContent
 *  POST /openai/v1/...
 */

const DEFAULT_GEMINI_MODEL = "gemini-3.1-flash-image-preview"
const GEMINI_DEFAULT_PATH = `/v1beta/models/${DEFAULT_GEMINI_MODEL}:generateContent`

const GEMINI_AI_STUDIO_UPSTREAM = "https://generativelanguage.googleapis.com"
const OPENAI_UPSTREAM = "https://api.openai.com"
const OAUTH_TOKEN_URL = "https://oauth2.googleapis.com/token"
const VERTEX_SCOPE = "https://www.googleapis.com/auth/cloud-platform"

const DEFAULT_GCP_REGION = "us-central1"
const MAX_GEMINI_BODY_BYTES = 15 * 1024 * 1024

/** @type {string | null} */
let cachedAccessToken = null
/** @type {number} */
let cachedAccessTokenExpiresAt = 0

/** Remote config для iOS (`GET /app/config`). */
const APP_CONFIG = {
	freeGenerationsLifetime: 1,
	premiumGenerationsPerDay: 15,
	paywallShowTopCloseButton: false,
	configVersion: 1,
}

/**
 * @returns {Record<string, unknown>}
 */
function buildAppConfigPayload() {
	return {
		...APP_CONFIG,
		lifetimeFreeScanLimit: APP_CONFIG.freeGenerationsLifetime,
	}
}

export default {
	/**
	 * @param {Request} request
	 * @param {Record<string, string | undefined>} env
	 */
	async fetch(request, env) {
		const gateResp = gateIfConfigured(request, env)
		if (gateResp) return gateResp

		const url = new URL(request.url)
		const pathname = url.pathname

		if (pathname === "/app/config" && request.method === "GET") {
			return json(200, buildAppConfigPayload())
		}

		if ((pathname === "/" || pathname === "/health") && request.method === "GET") {
			const mode = resolveGeminiUpstreamMode(env)
			return json(200, {
				ok: true,
				gemini_upstream: mode ?? "unconfigured",
				providers: {
					vertex: Boolean(env.GCP_SERVICE_ACCOUNT_JSON),
					gemini_ai_studio: Boolean(env.GEMINI_API_KEY),
					openai: Boolean(env.OPENAI_API_KEY),
				},
			})
		}

		if ((pathname === "/" || pathname === "/gemini") && request.method === "POST") {
			return proxyGemini(request, env, GEMINI_DEFAULT_PATH, url.search)
		}

		if (pathname.startsWith("/gemini/")) {
			const upstreamPath = pathname.slice("/gemini".length)
			return proxyGemini(request, env, upstreamPath, url.search)
		}

		if (pathname.startsWith("/openai/")) {
			const upstreamPath = pathname.slice("/openai".length)
			return proxyOpenAI(request, env, upstreamPath, url.search)
		}

		return json(404, {
			error: "not_found",
			hint: "Use /app/config, POST / (Gemini default), /gemini/v1beta/*, /openai/v1/*",
		})
	},
}

/**
 * @param {Record<string, string | undefined>} env
 * @returns {"vertex" | "ai_studio" | null}
 */
function resolveGeminiUpstreamMode(env) {
	const explicit = String(env.GEMINI_UPSTREAM ?? "")
		.trim()
		.toLowerCase()
	if (explicit === "vertex") return "vertex"
	if (explicit === "ai_studio" || explicit === "aistudio") return "ai_studio"

	if (env.GCP_SERVICE_ACCOUNT_JSON) return "vertex"
	if (env.GEMINI_API_KEY) return "ai_studio"
	return null
}

/**
 * @param {Request} request
 * @param {Record<string, string | undefined>} env
 * @param {string} upstreamPath
 * @param {string} search
 */
async function proxyGemini(request, env, upstreamPath, search) {
	const mode = resolveGeminiUpstreamMode(env)
	if (!mode) {
		return json(500, {
			error: "gemini_not_configured",
			hint: "Set GCP_SERVICE_ACCOUNT_JSON (Vertex) or GEMINI_API_KEY (AI Studio rollback)",
		})
	}

	const sizeError = await validateGeminiBodySize(request)
	if (sizeError) return sizeError

	const response = mode === "vertex"
		? await proxyVertexGemini(request, env, upstreamPath, search)
		: await proxyGeminiAIStudio(request, env, upstreamPath, search)
	if (!response.ok) await logUpstreamError("gemini", mode, upstreamPath, response)
	return response
}

/**
 * Logs a failed upstream answer for `wrangler tail` (status + provider error, no keys / no request body).
 * The body itself is still passed to the app unchanged.
 * @param {string} provider
 * @param {string} mode
 * @param {string} path
 * @param {Response} response
 */
async function logUpstreamError(provider, mode, path, response) {
	try {
		const text = await response.clone().text()
		let parsed = null
		try { parsed = JSON.parse(text) } catch { /* not JSON */ }
		const error = parsed?.error ?? parsed?.[0]?.error ?? null
		console.error(JSON.stringify({
			event: `${provider}_error`,
			mode,
			path,
			status: response.status,
			code: error?.code ?? null,
			upstreamStatus: error?.status ?? null,
			message: String(error?.message ?? text).slice(0, 500),
		}))
	} catch {
		console.error(JSON.stringify({ event: `${provider}_error`, mode, path, status: response.status }))
	}
}

/**
 * @param {Request} request
 */
async function validateGeminiBodySize(request) {
	if (request.method === "GET" || request.method === "HEAD") return null
	const raw = request.headers.get("content-length")
	if (!raw) return null
	const len = Number(raw)
	if (!Number.isFinite(len) || len <= MAX_GEMINI_BODY_BYTES) return null
	return json(413, {
		error: "payload_too_large",
		max_bytes: MAX_GEMINI_BODY_BYTES,
	})
}

/**
 * Vertex AI — generateContent (той самий JSON, що й AI Studio).
 * @param {Request} request
 * @param {Record<string, string | undefined>} env
 * @param {string} upstreamPath
 * @param {string} search
 */
async function proxyVertexGemini(request, env, upstreamPath, search) {
	let projectId
	let region
	try {
		;({ projectId, region } = parseVertexConfig(env))
	} catch (err) {
		return json(500, {
			error: "vertex_config_invalid",
			message: err instanceof Error ? err.message : String(err),
		})
	}

	const modelId = parseGeminiModelIdFromPath(upstreamPath) ?? DEFAULT_GEMINI_MODEL
	let accessToken
	try {
		accessToken = await getVertexAccessToken(env)
	} catch (err) {
		return json(500, {
			error: "vertex_auth_failed",
			message: err instanceof Error ? err.message : String(err),
		})
	}

	const upstream =
		`https://${region}-aiplatform.googleapis.com/v1/projects/${encodeURIComponent(projectId)}` +
		`/locations/${encodeURIComponent(region)}/publishers/google/models/${encodeURIComponent(modelId)}` +
		`:generateContent${search}`

	const headers = dropHopByHopHeaders(request.headers)
	headers.delete("x-goog-api-key")
	headers.delete("authorization")
	headers.set("authorization", `Bearer ${accessToken}`)
	stripClientSecrets(headers)

	return fetch(upstream, forwardInit(request, headers))
}

/**
 * @param {Request} request
 * @param {Record<string, string | undefined>} env
 * @param {string} upstreamPath
 * @param {string} search
 */
async function proxyGeminiAIStudio(request, env, upstreamPath, search) {
	if (!env.GEMINI_API_KEY) {
		return json(500, { error: "GEMINI_API_KEY secret is not set" })
	}
	const upstream = GEMINI_AI_STUDIO_UPSTREAM + ensureLeadingSlash(upstreamPath) + search
	const headers = dropHopByHopHeaders(request.headers)
	headers.delete("x-goog-api-key")
	headers.set("x-goog-api-key", env.GEMINI_API_KEY)
	headers.delete("authorization")
	stripClientSecrets(headers)
	return fetch(upstream, forwardInit(request, headers))
}

/**
 * @param {string} path e.g. `/v1beta/models/gemini-3.1-flash-image-preview:generateContent`
 * @returns {string | null}
 */
function parseGeminiModelIdFromPath(path) {
	const match = path.match(/\/models\/([^/:]+):generateContent/i)
	return match?.[1] ?? null
}

/**
 * @param {Record<string, string | undefined>} env
 */
function parseVertexConfig(env) {
	const raw = String(env.GCP_SERVICE_ACCOUNT_JSON ?? "").trim()
	if (!raw) throw new Error("GCP_SERVICE_ACCOUNT_JSON is not set")

	let sa
	try {
		sa = JSON.parse(raw)
	} catch {
		throw new Error("GCP_SERVICE_ACCOUNT_JSON is not valid JSON")
	}

	const projectId = String(env.GCP_PROJECT_ID ?? sa.project_id ?? "").trim()
	if (!projectId) throw new Error("GCP project id missing (GCP_PROJECT_ID or project_id in SA JSON)")

	const region = String(env.GCP_REGION ?? DEFAULT_GCP_REGION).trim() || DEFAULT_GCP_REGION
	if (!sa.client_email || !sa.private_key) {
		throw new Error("Service account JSON must include client_email and private_key")
	}

	return { projectId, region, serviceAccount: sa }
}

/**
 * @param {Record<string, string | undefined>} env
 */
async function getVertexAccessToken(env) {
	const now = Math.floor(Date.now() / 1000)
	if (cachedAccessToken && cachedAccessTokenExpiresAt > now + 60) {
		return cachedAccessToken
	}

	const { serviceAccount } = parseVertexConfig(env)
	const assertion = await buildServiceAccountJwt(serviceAccount)

	const tokenResponse = await fetch(OAUTH_TOKEN_URL, {
		method: "POST",
		headers: { "content-type": "application/x-www-form-urlencoded" },
		body: new URLSearchParams({
			grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
			assertion,
		}),
	})

	const tokenBody = await tokenResponse.json().catch(() => ({}))
	if (!tokenResponse.ok) {
		const message =
			typeof tokenBody.error_description === "string"
				? tokenBody.error_description
				: typeof tokenBody.error === "string"
					? tokenBody.error
					: `HTTP ${tokenResponse.status}`
		throw new Error(message)
	}

	const accessToken = tokenBody.access_token
	if (typeof accessToken !== "string" || !accessToken) {
		throw new Error("OAuth response missing access_token")
	}

	const expiresIn = Number(tokenBody.expires_in) || 3600
	cachedAccessToken = accessToken
	cachedAccessTokenExpiresAt = now + Math.max(300, expiresIn - 120)
	return accessToken
}

/**
 * @param {{ client_email: string, private_key: string }} serviceAccount
 */
async function buildServiceAccountJwt(serviceAccount) {
	const now = Math.floor(Date.now() / 1000)
	const header = { alg: "RS256", typ: "JWT" }
	const payload = {
		iss: serviceAccount.client_email,
		sub: serviceAccount.client_email,
		aud: OAUTH_TOKEN_URL,
		iat: now,
		exp: now + 3600,
		scope: VERTEX_SCOPE,
	}

	const unsigned = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(JSON.stringify(payload))}`
	const key = await importPkcs8PrivateKey(serviceAccount.private_key)
	const signature = await crypto.subtle.sign(
		"RSASSA-PKCS1-v1_5",
		key,
		new TextEncoder().encode(unsigned),
	)
	return `${unsigned}.${base64UrlEncode(signature)}`
}

/**
 * @param {string} pem
 */
async function importPkcs8PrivateKey(pem) {
	const normalized = pem.replace(/\\n/g, "\n")
	const der = pemToArrayBuffer(normalized)
	return crypto.subtle.importKey(
		"pkcs8",
		der,
		{ name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
		false,
		["sign"],
	)
}

/**
 * @param {string} pem
 */
function pemToArrayBuffer(pem) {
	const b64 = pem
		.replace(/-----BEGIN PRIVATE KEY-----/g, "")
		.replace(/-----END PRIVATE KEY-----/g, "")
		.replace(/\s/g, "")
	const binary = atob(b64)
	const bytes = new Uint8Array(binary.length)
	for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
	return bytes.buffer
}

/**
 * @param {string | ArrayBuffer} input
 */
function base64UrlEncode(input) {
	let bytes
	if (typeof input === "string") {
		bytes = new TextEncoder().encode(input)
	} else {
		bytes = new Uint8Array(input)
	}
	let binary = ""
	for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i])
	return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "")
}

/**
 * @param {Request} request
 * @param {Record<string, string | undefined>} env
 * @param {string} upstreamPath
 * @param {string} search
 */
async function proxyOpenAI(request, env, upstreamPath, search) {
	if (!env.OPENAI_API_KEY) {
		return json(500, { error: "OPENAI_API_KEY secret is not set" })
	}
	const upstream = OPENAI_UPSTREAM + ensureLeadingSlash(upstreamPath) + search
	const headers = dropHopByHopHeaders(request.headers)
	headers.delete("authorization")
	headers.set("authorization", `Bearer ${env.OPENAI_API_KEY}`)
	headers.delete("x-goog-api-key")
	stripClientSecrets(headers)
	return fetch(upstream, forwardInit(request, headers))
}

/**
 * @param {Request} request
 * @param {Record<string, string | undefined>} env
 */
function gateIfConfigured(request, env) {
	const required = String(env.MOBILE_GATE_KEY ?? "").trim()
	if (!required) return null
	const got = request.headers.get("X-HomeAI-Mobile-Key") ?? ""
	if (got !== required) {
		return json(403, { error: "forbidden" })
	}
	return null
}

/**
 * @param {Request} request
 * @param {Headers} headers
 */
function forwardInit(request, headers) {
	const method = request.method
	const hasBody = method !== "GET" && method !== "HEAD"
	return {
		method,
		headers,
		body: hasBody ? request.body : undefined,
	}
}

/** @param {Headers} input */
function dropHopByHopHeaders(input) {
	const deny = new Set([
		"host",
		"connection",
		"keep-alive",
		"proxy-authenticate",
		"proxy-authorization",
		"te",
		"trailers",
		"transfer-encoding",
		"upgrade",
		"cf-connecting-ip",
		"cf-ray",
		"cf-visitor",
		"cdn-loop",
		"content-length",
	])
	const out = new Headers()
	input.forEach((value, key) => {
		if (deny.has(key.toLowerCase())) return
		out.append(key, value)
	})
	return out
}

/** @param {Headers} headers */
function stripClientSecrets(headers) {
	headers.delete("x-homeai-mobile-key")
	headers.delete("x-tcg-mobile-key")
}

/** @param {string} path */
function ensureLeadingSlash(path) {
	if (!path) return "/"
	return path.startsWith("/") ? path : `/${path}`
}

/**
 * @param {number} status
 * @param {Record<string, unknown>} obj
 */
function json(status, obj) {
	return new Response(JSON.stringify(obj), {
		status,
		headers: {
			"content-type": "application/json;charset=utf-8",
			"cache-control": "no-store",
		},
	})
}
