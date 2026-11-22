# json-protocol

CLOS JSON encode/decode for [cl-stack](https://github.com/egao1980/cl-stack) (RFC 8259).

YAML 1.2 is a **superset of JSON**. [`yaml-protocol`](https://github.com/egao1980/yaml-protocol) is a **separate repo** that CLOS-extends this protocol (`yaml-backend` ⊆ `json-backend`). jzon stays the RFC 8259 `:json` path — we do not parse JSON through YAML by default, and this package does **not** depend on YAML.

| System | Role |
|--------|------|
| `json-protocol` | Generics, conditions, `encode` / `decode` |
| `json-backend-jzon` | **Default** — [com.inuoe.jzon](https://github.com/Zulu-Inuoe/jzon) |
| `json-backend-yason` | Alternate — [yason](https://github.com/phmarek/yason) |

OCI **0.2.2** (all three systems; alist key order guaranteed; octets decode through `encoding-protocol`) — hard-implements [`serdes-protocol`](https://github.com/egao1980/serdes-protocol) `:json` (JSONL + event pull).  
**Cookbook:** [json.md](https://github.com/egao1980/cl-stack/blob/main/docs/cookbooks/json.md) · [serdes.md](https://github.com/egao1980/cl-stack/blob/main/docs/cookbooks/serdes.md) · Brief: [json-protocol.md](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/json-protocol.md).

## Publish

`publish-checkout.yml` publishes each system as its own package, tagged with its own `.asd` `:version`. Bump the `.asd` to release; there is no tag override.

## Quick use

```lisp
(asdf:load-system "json-backend-jzon")              ; sets *json-backend*
(json-protocol:encode '(("a" . 1) ("b" . :null))) ; => "{\"a\":1,\"b\":null}"
(stack-json:decode "{\"a\":false}")                 ; nick; "a" → NIL
```

Value mapping: objects → string-key hash-tables; arrays → vectors; `null` → `:null`; `false`/`true` → `nil`/`t`. Encoding `nil` → `false`.

**Key order (guaranteed on every backend and implementation):** an alist encodes as an object with its members in alist order, nested alists included. On a duplicate key the first occurrence wins (`assoc` semantics). A hash-table encodes in `maphash` order, which ANSI CL leaves unspecified, so use an alist when the bytes must be deterministic. Output is compact (no whitespace).

```lisp
(json-protocol:encode '(("z" . 1) ("a" . (("y" . 2) ("b" . 3))) ("z" . 9)))
;; => "{\"z\":1,\"a\":{\"y\":2,\"b\":3}}"
```

## License

MIT — see [LICENSE](LICENSE).
