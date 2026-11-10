// OpenAI image proxy on Cloud Run (europe-west3). The Rehomely OpenAI worker (fragrant-fog-a5e3) can't reach
// api.openai.com from Cloudflare for visitors in Ukraine (OpenAI classifies Workers traffic by the visitor's
// country), and OpenAI support advised calling the API from our own server. The worker keeps App Attest, rate
// limits, the OpenAI key and the country gate (unsupported countries / occupied regions never reach this proxy);
// this service only forwards `POST /v1/images/edits` when the shared secret matches. Nothing is logged or stored.
const http = require("http")
const crypto = require("crypto")

const SECRET = process.env.PROXY_SECRET || ""
const UPSTREAM = "https://api.openai.com/v1/images/edits"
const MAX_BYTES = 20 * 1024 * 1024

function same(a, b) {
  const x = Buffer.from(String(a)), y = Buffer.from(String(b))
  return x.length === y.length && crypto.timingSafeEqual(x, y)
}

http.createServer(async (req, res) => {
  const reply = (status, body) => { res.writeHead(status, { "content-type": "application/json" }); res.end(JSON.stringify(body)) }
  if (req.method === "GET" && req.url === "/health") return reply(200, { ok: true })
  if (req.method !== "POST" || req.url !== "/v1/images/edits") return reply(404, { error: { code: "not_found" } })
  if (!SECRET || !same(req.headers["x-proxy-secret"] || "", SECRET)) return reply(401, { error: { code: "unauthorized" } })
  const auth = req.headers["authorization"], type = req.headers["content-type"]
  if (!auth || !type) return reply(400, { error: { code: "bad_request" } })

  const chunks = []; let size = 0
  for await (const chunk of req) { size += chunk.length; if (size > MAX_BYTES) return reply(413, { error: { code: "payload_too_large" } }); chunks.push(chunk) }

  try {
    const upstream = await fetch(UPSTREAM, { method: "POST", headers: { authorization: auth, "content-type": type }, body: Buffer.concat(chunks) })
    const headers = { "content-type": upstream.headers.get("content-type") || "application/json" }
    for (const h of ["x-request-id", "openai-organization", "openai-processing-ms"]) { const v = upstream.headers.get(h); if (v) headers[h] = v }
    res.writeHead(upstream.status, headers)
    res.end(Buffer.from(await upstream.arrayBuffer()))
  } catch {
    reply(502, { error: { code: "provider_unavailable" } })
  }
}).listen(process.env.PORT || 8080)
