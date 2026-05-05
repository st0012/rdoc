# How Coding Agents Fetch Web Content — Research

Complement to [`markdown_for_agents.md`](markdown_for_agents.md). That file covers the **publishing** side (how doc sites expose Markdown). This file covers the **consumption** side (what the agent actually does with the bytes once fetched).

The distinction matters because serving `.md` only helps if the consuming agent preserves it. Agents that summarize via a small model will discard format advantages; agents that dump raw bytes will benefit dramatically.

## Research Question

Given a doc URL, what happens between "agent decides to fetch" and "content lands in the model's context"? Specifically:

1. Is there an HTTP fetch on the client at all?
2. Is the response body piped through a smaller "summarizer" LLM before reaching the main model?
3. Is HTML stripped to Markdown? With what library?
4. What truncation or size limits apply?

Four agents surveyed: **Claude Code**, **opencode** (sst/opencode), **Codex CLI** (openai/codex), **pi** (@mariozechner/pi-coding-agent).

---

## Claude Code — `WebFetch`

**Pipeline:** fetch → HTML-to-Markdown → small-model summarization → summary returned to agent

From the `WebFetch` tool's own documentation string:

> Fetches the URL content, converts HTML to markdown
> Processes the content with the prompt using a small, fast model
> Returns the model's response about the content
> Results may be summarized if the content is very large

**Implication:** The main model never sees the full page. It sees a paraphrase produced by a smaller model, conditioned on the prompt the caller passed in ("summarize", "extract the signature of X", etc.).

**Consequences for doc-site format:**
- The HTML-to-Markdown conversion happens *before* summarization, but the summary is what reaches the agent. So serving `.md` directly vs. HTML makes only a marginal difference — both end up summarized.
- If the caller asks a narrow question, relevant content that didn't match the prompt is dropped.
- Faithful quoting is impossible; the content is paraphrased.
- Workaround: shell out via `Bash` (`curl`) and `Read` the file. That gets raw bytes into context, bypassing the summarizer, at the cost of any size reduction.

**Empirical check:** fetching `https://docs.ruby-lang.org/en/master/Array.html` with a "summarize" prompt returned ~250 words; a direct fetch would have been ~200k tokens. ~99% reduction — but lossy.

---

## opencode (sst/opencode) — `webfetch`

**Pipeline:** fetch → HTML-to-Markdown via Turndown → return raw to agent (no summarizer)

**Source:** `packages/opencode/src/tool/webfetch.ts` (prompt file: `webfetch.txt`)

**Findings:**

1. Tool registered via `Tool.define("webfetch", ...)`. The `execute` function returns `{ output, title, metadata }` directly — **no intermediate LLM call**. This is a clear divergence from Claude Code.

2. The tool's prompt string claims "Results may be summarized if the content is very large" but **nothing in the implementation does this**. Copied-from-somewhere text that doesn't match the code.

3. HTML-to-Markdown conversion:
   - Library: **[Turndown](https://github.com/mixmark-io/turndown)** (npm `turndown`, imported as `TurndownService`).
   - Triggered when `format: "markdown"` (default) *and* response `Content-Type` is `text/html`.
   - Config: ATX-style headings (`#`), `---` horizontal rule, `-` bullet markers, fenced code blocks, `*` for emphasis.
   - `<script>`, `<style>`, `<meta>`, `<link>` stripped via `turndownService.remove(...)` before conversion.
   - For `format: "text"`, Bun's `HTMLRewriter` strips tags and concatenates text nodes.

4. Size limits:
   - `MAX_RESPONSE_SIZE = 5 * 1024 * 1024` (5 MB). Checked against both the `Content-Length` header *and* the actual `arrayBuffer.byteLength`; throws on exceed.
   - `DEFAULT_TIMEOUT = 30s`, `MAX_TIMEOUT = 120s`.
   - **No character or token truncation** of the converted output — everything under 5 MB raw is returned in full.

**Consequences for doc-site format:**
- **Biggest beneficiary of canonical `.md`.** Turndown is a general-purpose HTML-to-Markdown converter; doc pages with navigation sidebars, version pickers, TOC widgets, syntax-highlighting spans, etc. convert unevenly and noisily. Chrome leaks into the Markdown output as cruft.
- Serving `.md` bypasses Turndown entirely — the agent gets clean, canonical Markdown.
- 5 MB raw ceiling hits much later on clean `.md` than on HTML: a typical doc page is ~200 KB as HTML but ~20-50 KB as Markdown.

---

## Codex CLI (openai/codex) — `web_search`

**Pipeline:** client-side declaration only; actual fetching and content extraction happen **server-side at OpenAI's Responses API**.

**Source locations (`codex-rs/` crate, verified against HEAD):**
- `codex-rs/tools/src/tool_spec.rs:42-54` — `ToolSpec::WebSearch` variant (pure serde config, no handler)
- `codex-rs/tools/src/tool_spec.rs:89` — `create_web_search_tool(options: WebSearchToolOptions<'_>) -> Option<ToolSpec>`
- `codex-rs/tools/src/tool_spec.rs:143` — `create_tools_json_for_responses_api` (emits the tool JSON sent to the API)
- `codex-rs/core/src/web_search.rs` — 39 lines; only exports `web_search_action_detail` and `web_search_detail` for display formatting
- `codex-rs/protocol/src/models.rs:1252-1280` — `WebSearchAction` enum. Variants: `Search` (L1256), `OpenPage { url }` (L1264), `FindInPage { url, pattern }` (L1269, `pattern: Option<String>`), plus `#[serde(other)] Other` catch-all (L1278-79)
- `codex-rs/protocol/src/config_types.rs:128-132` — `WebSearchMode` enum (`Cached | Live | Disabled`)

**Findings:**

1. **No `fetch(url)` tool exists.** Exhaustive inventory of `create_*_tool` functions across `codex-rs/tools/src/` turns up no `fetch`, `browse`, `open_url`, `http_get`, or `download` tool. Only `web_search` is web-adjacent, and it's declared by Codex but implemented by OpenAI's Responses API. The CLI never opens HTTP connections to user-supplied URLs to pull page content.

2. Mode selection via `WebSearchMode` → serialized as `external_web_access: Option<bool>` tool-config field (`tool_spec.rs:45`, mapping at `:90-94`):
   - `Cached` → `Some(false)`
   - `Live` → `Some(true)`
   - `Disabled` / unset → tool omitted entirely
   Note: `external_web_access` is a field on the tool config sent to the API, **not** a standalone user-facing config key. Users pick via `WebSearchMode`.

3. When the model triggers `web_search`, Codex receives `web_search_call` response items from the Responses API. Codex's handling is **display-only** — `web_search.rs` formats events into UI strings like `open_page https://…`. There is no response-body decoding, no HTML-to-Markdown, no summarizer pass on the client.

4. HTML-to-Markdown library in Codex: **none**. Workspace-wide grep for `html2md|readability|scraper|html5ever|markup5ever|kuchiki|html-parser` across every `Cargo.toml` returns zero hits. `pulldown-cmark` appears in `codex-rs/Cargo.toml` and `tui/Cargo.toml` — exclusively for rendering Markdown in the TUI.

5. Client-side size limits: **none**. Codex never sees raw bytes; whatever truncation or summarization happens is entirely OpenAI's responsibility.

6. **Caveat: MCP side channel.** `codex-rs/tools/src/mcp_tool.rs` lets user-configured MCP servers expose arbitrary tools, which can in principle do HTTP fetching. Nothing in Codex's core tool set does, but a user's MCP config could introduce a raw-fetch path outside the scope of this analysis.

**Consequences for doc-site format:**
- **Out of your hands for the core CLI.** Whether a doc site serves `.md` or HTML affects nothing Codex itself does — the Responses API decides what citations/text to return to the model.
- **Reachable via MCP.** If a user adds a fetch-capable MCP server to their Codex config, that server's behavior determines benefit — same analysis as any other raw-fetch agent. Not a publisher-side optimization target either way.

---

## pi (@mariozechner/pi-coding-agent) — no fetch tool

**Pipeline:** none built in. Users fetch by invoking `bash` (e.g. `curl`), which returns raw bytes via generic bash-output truncation.

**Source:** `badlogic/pi-mono` monorepo, package `packages/coding-agent/`.

**Findings:**

1. Tool registry enumerates exactly **seven tools**: `read`, `bash`, `edit`, `write`, `grep`, `find`, `ls` (`packages/coding-agent/src/core/tools/index.ts:83-84`). No `fetch`, `web_fetch`, or URL tool.

2. The only string `WebFetch` anywhere in the repo is in `examples/extensions/custom-provider-anthropic/index.ts:169`, where it appears in a list of Claude Code tool names used for OAuth stealth-mode renaming — not a capability pi provides.

3. HTML-to-Markdown: no `turndown`, `readability`, `cheerio`, `jsdom`, or `html-to-text` dependency in the `coding-agent` package. The `web-ui` sibling package has its own browser-side extractor (`packages/web-ui/src/tools/extract-document.ts`) but that's not wired into the CLI agent.

4. How users actually fetch URLs: shell out via `bash` — e.g. `bash$ curl https://docs.ruby-lang.org/en/master/Array.html`. Raw bytes pipe straight into the model's context.

5. Size limits on bash output: generic truncation via `packages/coding-agent/src/core/tools/truncate.ts` (`DEFAULT_MAX_BYTES`, `DEFAULT_MAX_LINES`). That's the only ceiling.

6. Design philosophy: Zechner's blog post ["What I learned building an opinionated and minimal coding agent"](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/) argues for a tiny core with capabilities added via extensions/skills or by asking the agent to write a script on the fly.

**Consequences for doc-site format:**
- **Biggest single win from serving `.md`.** A `curl` of an HTML doc page dumps tag soup, script blobs, and CSS class chatter into context. A `curl` of canonical `.md` is usable as-is.
- Pi users who don't serve `.md`-aware scraping in their shell scripts are paying the HTML tax every fetch.

---

## Comparison

| Agent | Fetch tool | Summarizer? | HTML→MD library | Size cap | Doc site benefits from `.md`? |
|---|---|---|---|---|---|
| Claude Code | `WebFetch` | **Yes** (small model) | built-in (unspecified) | summary only | **Neutral** (summary dominates) |
| opencode | `webfetch` | No | Turndown | 5 MB raw | **Yes — big** (skips lossy Turndown) |
| Codex CLI | `web_search` (declaration) | server-side (OpenAI) | N/A client-side | N/A | **N/A** (can't influence) |
| pi | none | — | — | bash output truncation | **Yes — biggest** (raw curl straight to context) |

---

## Implications for Doc Publishing (esp. RDoc)

1. **Summarizing agents (Claude Code) are a non-optimization target.** Whatever format you serve, the agent paraphrases it. No action.

2. **Raw-content agents (opencode, pi) are high-leverage targets.** They paste bytes directly into context; format quality compounds with every fetch. Clean Markdown is the biggest single improvement.

3. **Server-side agents (Codex) are unreachable from the publisher side.** The upstream provider controls the pipeline.

4. **Turndown-class conversion is lossy and inconsistent.** Relying on "the agent will convert it" means each agent's tool produces different Markdown for the same page: nav bars included/excluded differently, code blocks wrapped in divs that become nested fences, syntax-highlight spans leaking as `<span>` fragments when Turndown is misconfigured. Canonical server-provided `.md` removes this variance.

5. **The win isn't uniform.** A marketing page where the Markdown summary is "good enough" benefits less. API reference pages — where exact method signatures, argument names, parameter types, and default values matter — benefit disproportionately. RDoc's output is almost entirely of the second kind.

6. **llms.txt is orthogonal.** It tells agents *where* to look; it doesn't change what happens once they fetch. An agent using `WebFetch` on an `llms-full.txt` file still gets summarized. An agent using `curl` gets the raw Markdown. Same conclusion: the consuming agent determines the benefit.

---

## Open Questions

- Does **Cursor's agent mode** use a summarizer or return raw? (Not researched here.)
- Does **GitHub Copilot's agent mode** follow the Codex server-side model or the Claude Code client-side model? (Not researched here.)
- When an agent *does* see raw bytes, is there a convention for preferring `.md` over `.html` (e.g. `Accept: text/markdown`, a `.md` suffix probe)? `markdown_for_agents.md` notes there isn't one yet.
- Does serving `.md` with stable anchors (`#method-i-push`) let agents do faithful deep-linking back to user-visible pages? Matters for citation quality.

---

## Sources

- **Claude Code WebFetch**: tool documentation string (visible in this session).
- **opencode**: `packages/opencode/src/tool/webfetch.ts` in [sst/opencode](https://github.com/sst/opencode).
- **Codex CLI**:
  - `codex-rs/tools/src/tool_spec.rs:42-54` and `:89` in [openai/codex](https://github.com/openai/codex)
  - `codex-rs/core/src/web_search.rs`
  - `codex-rs/protocol/src/models.rs:1231-1259`
  - OpenAI web-search docs: https://platform.openai.com/docs/guides/tools-web-search
- **pi**:
  - `packages/coding-agent/src/core/tools/index.ts:83-84` in [badlogic/pi-mono](https://github.com/badlogic/pi-mono)
  - `packages/coding-agent/src/core/tools/truncate.ts`
  - [@mariozechner/pi-coding-agent on npm](https://www.npmjs.com/package/@mariozechner/pi-coding-agent)
  - [Design post (Nov 2025)](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/)
