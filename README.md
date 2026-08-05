# json-protocol

CLOS JSON encode/decode for [cl-stack](https://github.com/egao1980/cl-stack) (RFC 8259).

| System | Role |
|--------|------|
| `json-protocol` | Generics, conditions, `encode` / `decode` |
| `json-backend-jzon` | **Default** — [com.inuoe.jzon](https://github.com/Zulu-Inuoe/jzon) |
| `json-backend-yason` | Alternate — [yason](https://github.com/phmarek/yason) |

Brief: [`cl-stack/docs/capabilities/json-protocol.md`](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/json-protocol.md) · Issues [#91](https://github.com/egao1980/cl-stack/issues/91) / [#97](https://github.com/egao1980/cl-stack/issues/97).

## Quick use

```lisp
(asdf:load-system "json-backend-jzon")   ; sets json:*json-backend*
(json:encode '(("a" . 1) ("b" . :null))) ; => "{\"a\":1,\"b\":null}"
(json:decode "{\"a\":false}")            ; hash-table, "a" → NIL
```

Value mapping: objects → string-key hash-tables; arrays → vectors; JSON `null` → `:null`; `false`/`true` → `nil`/`t`. Encoding `nil` → JSON `false`.

## License

MIT — see [LICENSE](LICENSE).
