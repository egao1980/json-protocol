# json-protocol

CLOS JSON encode/decode for [cl-stack](https://github.com/egao1980/cl-stack) (RFC 8259).

YAML 1.2 is a **superset of JSON** (JSON schema). `yaml-protocol` lives in this repo, implements serdes `:yaml`, and uses the **same Lisp value mapping**. jzon stays the RFC 8259 `:json` path — we do not parse JSON through YAML by default.

| System | Role |
|--------|------|
| `json-protocol` | Generics, conditions, `encode` / `decode` |
| `json-backend-jzon` | **Default** — [com.inuoe.jzon](https://github.com/Zulu-Inuoe/jzon) |
| `json-backend-yason` | Alternate — [yason](https://github.com/phmarek/yason) |
| `yaml-protocol` | YAML 1.2 (comments, block, anchors, multi-doc). Any JSON is valid YAML. |
| `toml-protocol` | TOML v1.0 (tomlet decode + native emit). serdes `:toml`. |
| `schema-protocol-toml` | [TOML Schema](https://toml-schema.org/) (`.tosd`) + Taplo `#:schema` / `$schema` → JSON Schema. |

OCI **0.3.0** — hard-implements [`serdes-protocol`](https://github.com/egao1980/serdes-protocol) `:json` (JSONL + event pull).  
`yaml-protocol` **0.1.0** implements `:yaml`.  
`toml-protocol` **0.1.0** implements `:toml`.  
**Cookbook:** [json.md](https://github.com/egao1980/cl-stack/blob/main/docs/cookbooks/json.md) · [serdes.md](https://github.com/egao1980/cl-stack/blob/main/docs/cookbooks/serdes.md) · Brief: [json-protocol.md](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/json-protocol.md).

## Quick use

```lisp
(asdf:load-system "json-backend-jzon")              ; sets *json-backend*
(json-protocol:encode '(("a" . 1) ("b" . :null))) ; => "{\"a\":1,\"b\":null}"
(stack-json:decode "{\"a\":false}")                 ; nick; "a" → NIL
```

Value mapping (JSON **and** YAML): objects → string-key hash-tables; arrays → vectors; `null` → `:null`; `false`/`true` → `nil`/`t`. Encoding `nil` / `:false` → `false`; `t` / `:true` → `true`. Octets go through `encoding-protocol` (default UTF-8).

```lisp
(asdf:load-system "yaml-protocol")
(yaml-protocol:decode "foo: 1")           ; block YAML
(yaml-protocol:decode "{\"foo\":1}")      ; JSON ⊂ YAML
(yaml-protocol:encode ht :style :json)    ; JSON text = valid YAML
```

YAML 1.2 Core scalars (`NO` is a string, not boolean). Tags/merge keys are not implemented.

```lisp
(asdf:load-system "toml-protocol")
(toml-protocol:decode "host = \"localhost\"")
(toml-protocol:encode ht)
```

TOML has no null. Tables → hash-tables; arrays → vectors; booleans → `t`/`nil`.

TOML itself has no schema language. Two ecosystem conventions:

- **TOML Schema** (`.tosd`, [toml-schema.org](https://toml-schema.org/)) — native schema documents. Wave-1: `[toml-schema]` / `[types]` / `[elements]`, scalars, tables, arrays, collections, `oneof`/`anyof`, `allowedvalues` / `min`/`max` / `minlength`/`maxlength` / `pattern` / `format`. No `allof`, `if`/`then`/`else`, tuples, or remote fetch.
- **JSON Schema** via Taplo — `#:schema` comment or `$schema` key. Validation delegates to `schema-protocol-json`.

```lisp
(asdf:load-system "schema-protocol-toml")
(stack-schema:emit-schema 'user :format :toml)
(stack-schema-toml:validate-instance tosd-doc toml-table)
(stack-schema-toml:decode-validating "host = \"x\"" :schema tosd-doc)
(stack-schema-toml:discover-schema "#:schema ./app.json
host = \"x\"")
```

## License

MIT — see [LICENSE](LICENSE).
