# json-protocol

CLOS JSON encode/decode for [cl-stack](https://github.com/egao1980/cl-stack) (RFC 8259).

| System | Role |
|--------|------|
| `json-protocol` | Generics, conditions, `encode` / `decode` |
| `json-backend-jzon` | **Default** — [com.inuoe.jzon](https://github.com/Zulu-Inuoe/jzon) |
| `json-backend-yason` | Alternate — [yason](https://github.com/phmarek/yason) |

OCI **0.2.0** — hard-implements [`serdes-protocol`](https://github.com/egao1980/serdes-protocol) `:json` (JSONL + event pull).  
**Cookbook:** [json.md](https://github.com/egao1980/cl-stack/blob/main/docs/cookbooks/json.md) · [serdes.md](https://github.com/egao1980/cl-stack/blob/main/docs/cookbooks/serdes.md) · Brief: [json-protocol.md](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/json-protocol.md).

## Quick use

```lisp
(asdf:load-system "json-backend-jzon")              ; sets *json-backend*
(json-protocol:encode '(("a" . 1) ("b" . :null))) ; => "{\"a\":1,\"b\":null}"
(stack-json:decode "{\"a\":false}")                 ; nick; "a" → NIL
```

Value mapping: objects → string-key hash-tables; arrays → vectors; JSON `null` → `:null`; `false`/`true` → `nil`/`t`. Encoding `nil` → JSON `false`.

## License

MIT — see [LICENSE](LICENSE).
