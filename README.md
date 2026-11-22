# json-protocol

CLOS JSON encode/decode for [cl-stack](https://github.com/egao1980/cl-stack) (RFC 8259).

YAML 1.2 is a **superset of JSON**. [`yaml-protocol`](https://github.com/egao1980/yaml-protocol) is a **separate repo** that CLOS-extends this protocol (`yaml-backend` ⊆ `json-backend`). jzon stays the RFC 8259 `:json` path — we do not parse JSON through YAML by default, and this package does **not** depend on YAML.

| System | Role |
|--------|------|
| `json-protocol` | Generics, conditions, `encode` / `decode` |
| `json-backend-jzon` | **Default** — [com.inuoe.jzon](https://github.com/Zulu-Inuoe/jzon) |
| `json-backend-yason` | Alternate — [yason](https://github.com/phmarek/yason) |

OCI **0.2.3** (all three systems; alist key order guaranteed; octets decode through `encoding-protocol`; no decode size limits by default) — hard-implements [`serdes-protocol`](https://github.com/egao1980/serdes-protocol) `:json` (JSONL + event pull).  
**Cookbook:** [json.md](https://github.com/egao1980/cl-stack/blob/main/docs/cookbooks/json.md) · [serdes.md](https://github.com/egao1980/cl-stack/blob/main/docs/cookbooks/serdes.md) · Brief: [json-protocol.md](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/json-protocol.md).

## Publish

`publish-checkout.yml` publishes each system as its own package, tagged with its own `.asd` `:version`. Bump the `.asd` to release; there is no tag override.

## Quick use

```lisp
(asdf:load-system "json-backend-jzon")              ; sets *json-backend*
(json-protocol:encode '(("a" . 1) ("b" . :null))) ; => "{\"a\":1,\"b\":null}"
(stack-json:decode "{\"a\":false}")                 ; nick; "a" → NIL
```

**Decode limits:** none by default — strings of any length, nesting to the backend's cap (jzon 65535), since JSON-RPC peers (ACP, MCP) carry whole files. Cap untrusted input per call or by binding a special; past a limit `decode` signals `json-parse-limit-error` (both a `json-parse-error` and a `json-limit-error`; `json-limit-error-limit` → `:max-string-length` / `:max-depth`). The jzon event parser uses the same specials.

```lisp
(json-protocol:decode text :max-string-length (* 16 1024 1024) :max-depth 64)
(let ((json-protocol:*json-max-string-length* 65536)) (json-protocol:decode text))
```

Value mapping: objects → string-key hash-tables; arrays → vectors; `null` → `:null`; `false`/`true` → `nil`/`t`. Encoding `nil` → `false`.

**Deterministic encoding (every backend and implementation):** the same value always encodes to the same bytes, so output can feed content hashes, prompt-cache prefixes and golden files.

- An alist (ordered input) keeps its order, nested alists included. On a duplicate key the first occurrence wins (`assoc` semantics).
- A hash-table (unordered input) encodes with its keys sorted by `string<`, never in `maphash` order. Keys that name the same member (`:a` and `"a"`) signal `json-encode-error`.
- A plist is a list, so it encodes as an array, not an object.
- Output is compact (no whitespace).

```lisp
(json-protocol:encode '(("z" . 1) ("a" . (("y" . 2) ("b" . 3))) ("z" . 9)))
;; => "{\"z\":1,\"a\":{\"y\":2,\"b\":3}}"
```

## License

MIT — see [LICENSE](LICENSE).
