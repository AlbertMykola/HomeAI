// Apple App Attest verification (https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
// Only WebCrypto + a tiny CBOR / DER reader, so it runs in Workers and in `node --test`.

export const APPLE_APP_ATTEST_ROOT_PEM = `-----BEGIN CERTIFICATE-----
MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
Fw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
Yen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
oyFraWVIyd/dganmrduC1bmTBGwD
-----END CERTIFICATE-----`

const AAGUID_PRODUCTION = "617070617474657374" + "00".repeat(7) // "appattest" + 7 zero bytes
const AAGUID_DEVELOPMENT = "617070617474657374646576656c6f70" // "appattestdevelop"

const OID_NONCE_EXTENSION = "2a864886f763640802" // 1.2.840.113635.100.8.2
const OID_ECDSA_SHA256 = "2a8648ce3d040302"
const OID_ECDSA_SHA384 = "2a8648ce3d040303"
const OID_P256 = "2a8648ce3d030107"
const OID_P384 = "2b81040022"

export class AttestError extends Error {
	constructor(code, message) {
		super(message)
		this.code = code
	}
}

// MARK: Attestation (one time per key)

/**
 * Verifies an attestation object and returns what must be stored for the key.
 * @returns {Promise<{ publicKey: string, environment: "production" | "development", receipt: string | null }>}
 */
export async function verifyAttestation({
	keyId,
	attestation,
	clientData,
	appId,
	allowDevelopment,
	rootPem = APPLE_APP_ATTEST_ROOT_PEM,
	now = new Date(),
}) {
	let object
	try {
		object = decodeCBOR(base64ToBytes(attestation))
	} catch {
		throw new AttestError("attest_invalid", "Attestation is not CBOR")
	}
	if (object?.fmt !== "apple-appattest") throw new AttestError("attest_invalid", "Unexpected format")
	const x5c = object?.attStmt?.x5c
	const authData = object?.authData
	if (!Array.isArray(x5c) || x5c.length < 2 || !(authData instanceof Uint8Array)) {
		throw new AttestError("attest_invalid", "Attestation is incomplete")
	}

	// 1. Chain: credential cert ← intermediate ← Apple App Attestation Root CA.
	const leaf = parseCertificate(x5c[0])
	const intermediate = parseCertificate(x5c[1])
	const root = parseCertificate(pemToBytes(rootPem))
	for (const cert of [leaf, intermediate]) {
		if (now < cert.notBefore || now > cert.notAfter) throw new AttestError("attest_invalid", "Certificate expired")
	}
	if (!(await verifyCertificateSignature(leaf, intermediate)) ||
		!(await verifyCertificateSignature(intermediate, root))) {
		throw new AttestError("attest_invalid", "Certificate chain is not trusted")
	}

	// 2–4. nonce = SHA256(authData || SHA256(clientData)) must be in the credential cert.
	const clientDataHash = await sha256(clientData)
	const nonce = await sha256(concat(authData, clientDataHash))
	const certNonce = extractNonce(leaf)
	if (!certNonce || !equalBytes(certNonce, nonce)) throw new AttestError("attest_invalid", "Nonce mismatch")

	// 5. keyId = SHA256(public key point).
	const keyIdBytes = base64ToBytes(keyId)
	const pointHash = await sha256(leaf.publicKeyPoint)
	if (!equalBytes(pointHash, keyIdBytes)) throw new AttestError("attest_invalid", "Key id mismatch")

	// 6–9. authenticator data.
	const parsed = parseAuthData(authData, true)
	if (!equalBytes(parsed.rpIdHash, await sha256(new TextEncoder().encode(appId)))) {
		throw new AttestError("attest_invalid", "App id mismatch")
	}
	if (parsed.counter !== 0) throw new AttestError("attest_invalid", "Counter must be zero")
	let environment
	if (parsed.aaguid === AAGUID_PRODUCTION) environment = "production"
	else if (parsed.aaguid === AAGUID_DEVELOPMENT && allowDevelopment) environment = "development"
	else throw new AttestError("attest_invalid", "Unexpected environment")
	if (!equalBytes(parsed.credentialId, keyIdBytes)) throw new AttestError("attest_invalid", "Credential id mismatch")

	return {
		publicKey: bytesToBase64(leaf.spki),
		environment,
		receipt: object.attStmt.receipt instanceof Uint8Array ? bytesToBase64(object.attStmt.receipt) : null,
	}
}

// MARK: Assertion (every request)

/**
 * Checks one assertion against a stored key. `clientDataHash` = SHA256 of the exact request body the app signed.
 * Returns the new counter (must be stored by the caller).
 */
export async function verifyAssertion({ assertion, clientDataHash, publicKey, previousCounter, appId }) {
	let object
	try {
		object = decodeCBOR(base64ToBytes(assertion))
	} catch {
		throw new AttestError("attest_invalid", "Assertion is not CBOR")
	}
	const signature = object?.signature
	const authData = object?.authenticatorData
	if (!(signature instanceof Uint8Array) || !(authData instanceof Uint8Array)) {
		throw new AttestError("attest_invalid", "Assertion is incomplete")
	}
	const nonce = await sha256(concat(authData, clientDataHash))
	const key = await crypto.subtle.importKey(
		"spki", base64ToBytes(publicKey), { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"],
	)
	const valid = await crypto.subtle.verify(
		{ name: "ECDSA", hash: "SHA-256" }, key, derSignatureToRaw(signature, 32), nonce,
	)
	if (!valid) throw new AttestError("attest_invalid", "Bad assertion signature")

	const parsed = parseAuthData(authData, false)
	if (!equalBytes(parsed.rpIdHash, await sha256(new TextEncoder().encode(appId)))) {
		throw new AttestError("attest_invalid", "App id mismatch")
	}
	if (parsed.counter <= previousCounter) throw new AttestError("attest_replay", "Assertion was already used")
	return parsed.counter
}

// MARK: Challenges (stateless, HMAC-signed, short-lived)

const CHALLENGE_TTL_MS = 5 * 60 * 1000

export async function makeChallenge(secret, now = Date.now()) {
	const body = new Uint8Array(24)
	new DataView(body.buffer).setBigUint64(0, BigInt(now))
	crypto.getRandomValues(body.subarray(8))
	const mac = await hmac(secret, body)
	return bytesToBase64Url(concat(body, mac.subarray(0, 16)))
}

export async function checkChallenge(secret, challenge, now = Date.now()) {
	let bytes
	try {
		bytes = base64UrlToBytes(String(challenge ?? ""))
	} catch {
		return false
	}
	if (bytes.length !== 40) return false
	const body = bytes.subarray(0, 24)
	const mac = await hmac(secret, body)
	if (!equalBytes(mac.subarray(0, 16), bytes.subarray(24))) return false
	const issued = Number(new DataView(body.buffer, body.byteOffset).getBigUint64(0))
	return issued <= now + 30_000 && now - issued <= CHALLENGE_TTL_MS
}

async function hmac(secret, data) {
	const key = await crypto.subtle.importKey(
		"raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
	)
	return new Uint8Array(await crypto.subtle.sign("HMAC", key, data))
}

// MARK: Authenticator data

function parseAuthData(data, withCredential) {
	if (data.length < 37) throw new AttestError("attest_invalid", "Authenticator data is too short")
	const view = new DataView(data.buffer, data.byteOffset, data.byteLength)
	const result = {
		rpIdHash: data.subarray(0, 32),
		flags: data[32],
		counter: view.getUint32(33),
	}
	if (withCredential) {
		if (data.length < 55) throw new AttestError("attest_invalid", "Missing credential data")
		result.aaguid = hex(data.subarray(37, 53))
		const length = view.getUint16(53)
		result.credentialId = data.subarray(55, 55 + length)
	}
	return result
}

// MARK: X.509 (just what App Attest needs)

function parseCertificate(der) {
	const cert = readTLV(der, 0)
	const [tbs, signatureAlgorithm, signatureValue] = children(der, cert)
	const fields = children(der, tbs)
	const offset = fields[0].tag === 0xa0 ? 1 : 0
	const validity = children(der, fields[offset + 3])
	const spki = fields[offset + 5]
	const [spkiAlgorithm, spkiKey] = children(der, spki)
	const [, curve] = children(der, spkiAlgorithm)
	const extensionsWrapper = fields.find((field) => field.tag === 0xa3)
	const extensions = new Map()
	if (extensionsWrapper) {
		const [list] = children(der, extensionsWrapper)
		for (const extension of children(der, list)) {
			const parts = children(der, extension)
			extensions.set(hex(value(der, parts[0])), value(der, parts[parts.length - 1]))
		}
	}
	return {
		tbs: der.subarray(tbs.start, tbs.end),
		signatureAlgorithm: hex(value(der, children(der, signatureAlgorithm)[0])),
		signature: value(der, signatureValue).subarray(1),
		spki: der.subarray(spki.start, spki.end),
		curve: hex(value(der, curve)),
		publicKeyPoint: value(der, spkiKey).subarray(1),
		notBefore: parseTime(der, validity[0]),
		notAfter: parseTime(der, validity[1]),
		extensions,
	}
}

async function verifyCertificateSignature(cert, issuer) {
	const hash = cert.signatureAlgorithm === OID_ECDSA_SHA384 ? "SHA-384"
		: cert.signatureAlgorithm === OID_ECDSA_SHA256 ? "SHA-256" : null
	const curve = issuer.curve === OID_P384 ? "P-384" : issuer.curve === OID_P256 ? "P-256" : null
	if (!hash || !curve) return false
	try {
		const key = await crypto.subtle.importKey("spki", issuer.spki, { name: "ECDSA", namedCurve: curve }, false, ["verify"])
		return await crypto.subtle.verify(
			{ name: "ECDSA", hash }, key, derSignatureToRaw(cert.signature, curve === "P-384" ? 48 : 32), cert.tbs,
		)
	} catch {
		return false
	}
}

function extractNonce(cert) {
	const extension = cert.extensions.get(OID_NONCE_EXTENSION)
	if (!extension) return null
	try {
		const sequence = readTLV(extension, 0)
		const tagged = children(extension, sequence).find((item) => item.tag === 0xa1)
		const [octets] = children(extension, tagged)
		return value(extension, octets)
	} catch {
		return null
	}
}

function parseTime(der, tlv) {
	const text = new TextDecoder().decode(value(der, tlv))
	const full = tlv.tag === 0x17 ? `${Number(text.slice(0, 2)) >= 50 ? "19" : "20"}${text}` : text
	return new Date(Date.UTC(
		Number(full.slice(0, 4)), Number(full.slice(4, 6)) - 1, Number(full.slice(6, 8)),
		Number(full.slice(8, 10)), Number(full.slice(10, 12)), Number(full.slice(12, 14)),
	))
}

function derSignatureToRaw(der, size) {
	const sequence = readTLV(der, 0)
	const [r, s] = children(der, sequence).map((item) => value(der, item))
	const out = new Uint8Array(size * 2)
	const put = (int, at) => {
		const trimmed = int.subarray(Math.max(0, int.length - size))
		out.set(trimmed, at + size - trimmed.length)
	}
	put(r, 0)
	put(s, size)
	return out
}

function readTLV(buf, offset) {
	if (offset + 2 > buf.length) throw new Error("DER truncated")
	const tag = buf[offset]
	let length = buf[offset + 1]
	let header = 2
	if (length & 0x80) {
		const count = length & 0x7f
		if (count === 0 || count > 4) throw new Error("DER length")
		length = 0
		for (let index = 0; index < count; index += 1) length = length * 256 + buf[offset + 2 + index]
		header += count
	}
	const end = offset + header + length
	if (end > buf.length) throw new Error("DER truncated")
	return { tag, start: offset, valueStart: offset + header, end }
}

function children(buf, parent) {
	const list = []
	let offset = parent.valueStart
	while (offset < parent.end) {
		const item = readTLV(buf, offset)
		list.push(item)
		offset = item.end
	}
	return list
}

function value(buf, tlv) {
	return buf.subarray(tlv.valueStart, tlv.end)
}

// MARK: CBOR (maps, arrays, byte / text strings, ints — all App Attest uses)

export function decodeCBOR(bytes) {
	const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
	let offset = 0
	const readLength = (info) => {
		if (info < 24) return info
		if (info === 24) return bytes[offset++]
		if (info === 25) { const v = view.getUint16(offset); offset += 2; return v }
		if (info === 26) { const v = view.getUint32(offset); offset += 4; return v }
		if (info === 27) { const v = Number(view.getBigUint64(offset)); offset += 8; return v }
		throw new Error("CBOR length")
	}
	const read = (depth) => {
		if (depth > 16 || offset >= bytes.length) throw new Error("CBOR")
		const initial = bytes[offset++]
		const major = initial >> 5
		const info = initial & 0x1f
		switch (major) {
		case 0: return readLength(info)
		case 1: return -1 - readLength(info)
		case 2: {
			const length = readLength(info)
			if (offset + length > bytes.length) throw new Error("CBOR truncated")
			const out = bytes.slice(offset, offset + length)
			offset += length
			return out
		}
		case 3: {
			const length = readLength(info)
			if (offset + length > bytes.length) throw new Error("CBOR truncated")
			const out = new TextDecoder().decode(bytes.subarray(offset, offset + length))
			offset += length
			return out
		}
		case 4: {
			const length = readLength(info)
			const out = []
			for (let index = 0; index < length; index += 1) out.push(read(depth + 1))
			return out
		}
		case 5: {
			const length = readLength(info)
			const out = {}
			for (let index = 0; index < length; index += 1) {
				const key = read(depth + 1)
				out[String(key)] = read(depth + 1)
			}
			return out
		}
		case 7:
			if (info === 20) return false
			if (info === 21) return true
			if (info === 22) return null
			throw new Error("CBOR simple")
		default:
			throw new Error("CBOR major")
		}
	}
	return read(0)
}

// MARK: Bytes

export async function sha256(data) {
	return new Uint8Array(await crypto.subtle.digest("SHA-256", data))
}

export function concat(...parts) {
	const out = new Uint8Array(parts.reduce((sum, part) => sum + part.length, 0))
	let offset = 0
	for (const part of parts) {
		out.set(part, offset)
		offset += part.length
	}
	return out
}

export function equalBytes(a, b) {
	if (!a || !b || a.length !== b.length) return false
	let diff = 0
	for (let index = 0; index < a.length; index += 1) diff |= a[index] ^ b[index]
	return diff === 0
}

export function equalStrings(a, b) {
	return equalBytes(new TextEncoder().encode(String(a)), new TextEncoder().encode(String(b)))
}

function hex(bytes) {
	return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("")
}

export function base64ToBytes(text) {
	const binary = atob(String(text))
	const out = new Uint8Array(binary.length)
	for (let index = 0; index < binary.length; index += 1) out[index] = binary.charCodeAt(index)
	return out
}

export function bytesToBase64(bytes) {
	let binary = ""
	for (const byte of bytes) binary += String.fromCharCode(byte)
	return btoa(binary)
}

function bytesToBase64Url(bytes) {
	return bytesToBase64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

function base64UrlToBytes(text) {
	const normal = text.replace(/-/g, "+").replace(/_/g, "/")
	return base64ToBytes(normal + "=".repeat((4 - (normal.length % 4)) % 4))
}

function pemToBytes(pem) {
	return base64ToBytes(pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, ""))
}
