# Public Persona 20 Native Sources Design

Date: 2026-08-10

## Goal

Extend the existing four-source public-persona catalog with exactly 20 high-value sources that the installed HarmonyOS app can verify directly. The initial broad username scan must make zero Firecrawl calls. A source is enabled only after the production probe path on one real device distinguishes a known claimed account, a known unclaimed account, and a fresh random fake account.

The final product catalog therefore contains 24 sources: the existing Bilibili, Zhihu, Weibo, and GitHub sources plus the highest-ranked 20 candidates that pass the admission gate. Candidate order comes from `docs/research/public-persona-maigret-native-sources.md`; a failing candidate is replaced by the next candidate rather than weakened until it appears to pass.

## Approaches considered

### 1. Copy Maigret's database and runtime

Rejected. Maigret is Python, its site database includes desktop-specific TLS and activation assumptions, and many entries trust any 2xx response. Shipping that runtime would add a dependency without proving that HarmonyOS native HTTP sees the same response.

### 2. Add one hand-written client per source

Rejected. Twenty more platform switches would duplicate URL construction, marker matching, canonical checks, and error handling. It would also make the UI, parser, and smoke catalog drift independently.

### 3. Extend the existing data-driven probe catalog

Selected. Keep `PublicPersonaProbe` as the source of truth, add only the fields required to express a Maigret-style template and check mode, and keep a small platform-specific JSON identity adapter only where a generic response cannot provide username, display name, avatar, and canonical URL. No new dependency or crawler is introduced.

## Source admission gate

A candidate remains in the final shipping `publicPersonaCatalog()` only when all checks below pass through the same `probePublicPersonaProfile()` code that ships in the HAP. Internal validation HAPs may temporarily enable a candidate batch, but those builds are not pushed or reported as product support:

1. The official Maigret `usernameClaimed` fixture returns `found` and an identity bound to the requested username.
2. The official `usernameUnclaimed` fixture returns `not_found`.
3. A fresh random valid username returns `not_found`; if it returns `found`, the source has a soft-200 false positive and is rejected.
4. The claimed result exposes a usable HTTPS account avatar, display name or username, canonical profile URL, and a platform-specific identity signal. A generic site shell or site logo is insufficient.
5. A timeout, transport failure, redirect to login, 401, 403, 429, 5xx, CAPTCHA, challenge page, rate limit, or identical claimed/unclaimed body is `unknown`, never a pass.
6. The exact same final HAP and the same device/network session are used for the three requests. Evidence records platform, fixture class, requested URL, final URL when available, status, body length, matched rule names, terminal state, HAP hash, device serial, and timestamp. Full profile bodies are not retained.

Only a reliable HTTP 404 is a generic `not_found`. A validated `message` source may also use its configured account-specific absence marker on a 2xx response. HTTP 410 and generic missing-page prose remain `unknown`.

## Candidate order

The first admission batch is:

1. QQ
2. Baidu Tieba
3. Douban
4. NPM
5. LeetCode CN
6. Gitee
7. GitCode
8. Yuque
9. CNBlogs
10. V2EX
11. Tuchong
12. Stack Overflow
13. GitLab
14. Bitbucket
15. Docker Hub
16. DEV Community
17. Product Hunt
18. Keybase
19. Hugging Face
20. CSDN

If any item fails, replacement continues in this fixed value order: Codecademy, Pinterest, Medium, Reddit, Instagram, Behance, Dribbble, SoundCloud, Spotify, Goodreads, Letterboxd, Last.fm, Telegram, Steam, Tumblr, mastodon.social, Flickr, About.me, VK, Facebook, Quora, Patreon, then Substack. Protection-heavy and disabled Maigret entries are not promoted merely to reach 20.

## Discovery flow and Firecrawl boundary

The existing non-blocking discovery page remains the user surface and streams one terminal state per enabled source.

```text
username + exact/fuzzy mode
  -> native exact probes for all 24 enabled sources, concurrency 3
  -> native verification of one layer of explicit cross-profile links
  -> exact mode ends
  -> fuzzy mode may make one web.research.search call over unresolved domains
  -> every fuzzy row is re-verified by its native source probe
  -> rank, deduplicate, return at most 10 accounts
```

The initial native scan and explicit-link phase make zero `web.research.search` and zero `web.page.read` calls. Fuzzy mode may make at most one Search call only after every native source has reached `found`, `not_found`, or `unknown`. Discovery never calls Firecrawl page read. Snapshot generation keeps the existing bounded fallback read behavior and is outside the source-existence check.

Exact mode uses only the supplied username. Fuzzy mode keeps the existing deterministic alias generation and contains matching, including case variants, `yigeluo`, `luoyige`, and strings such as `abc_luoyige_abc`; no model-generated alias is introduced.

## Probe model

`PublicPersonaProbe` gains the smallest declarative additions needed by the generic path:

- `checkType: 'message' | 'status_code'`
- `enabled: boolean`
- optional request headers
- optional response encoding for QQ's GBK response
- fixture metadata used by tests and device smoke, never by product discovery

Existing fields continue to define display URL, probe URL, username regex, case sensitivity, presence markers, absence markers, and error markers. Path-based and subdomain-based display templates are parsed from the template rather than through twenty new platform switch branches.

Classification order is fixed:

1. transport failure and configured error marker -> `unknown`
2. 401, 403, 429, or 5xx -> `unknown`
3. 404 -> `not_found`
4. `message` absence marker -> `not_found`
5. `message` presence marker -> continue to identity verification
6. `status_code` 2xx -> continue to identity verification
7. everything else -> `unknown`

An existence signal alone does not yield `found`. The identity parser must also bind the response to the requested platform and username and extract a usable account avatar. API probes may perform one additional native display-profile GET when the probe response proves existence but lacks those identity fields. This remains zero Firecrawl.

## UI and source metadata

The UI resolves label and visual metadata from the catalog rather than adding another 20-case switch. Each confirmed account row shows the account avatar, platform label, display name, and username. A platform badge may decorate the row but cannot replace a missing account avatar for admission.

The candidate result cap remains 10. This cap limits accounts shown to the user, not the number of sources scanned.

## Testing seams

Hypium covers:

- template URL construction and username extraction for path, `@`, numeric, and subdomain forms
- classification order, including 200 soft shell, 410, login/rate-limit, and explicit absence markers
- claimed identity binding and rejection of generic OG shells
- exact discovery making zero tool calls
- fuzzy discovery making at most one Search call after all native terminal states
- 24 enabled sources and a 20-source addition count
- every enabled source having claimed, unclaimed, and random-fake fixture metadata
- UI labels coming from catalog metadata

Node smoke assertions cover the product total, structured terminal counts, zero-Firecrawl exact discovery, and per-source device matrix evidence. Existing model, snapshot, Markdown editing, MBTI, and persona-store behavior stays unchanged.

## Completion criteria

The feature is complete only when:

- exactly 20 new sources pass the real-device admission gate and are enabled;
- every enabled source has a three-fixture evidence record from one final signed HAP;
- Hypium, Node smoke assertions, Loopy verification, signed HAP build, and diff checks pass;
- a final device UI run shows the expanded source total, a known claimed account, and no false candidate for a known unclaimed account;
- the app is force-stopped and the selected device is released after validation.

If fewer than 20 candidates pass, the honest result is incomplete with the failing boundaries listed; no `unknown` source is counted as enabled.
