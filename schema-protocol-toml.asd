(defsystem "schema-protocol-toml"
  :version "0.1.0"
  :description "TOML Schema (.tosd) parse/generate/validate for schema-protocol"
  :author "egao1980"
  :license "MIT"
  :depends-on ("schema-protocol" "closer-mop" "cl-ppcre" "toml-protocol" "schema-protocol-json")
  :properties (:cl-repo (:ci (:sources (("schema-protocol" :oci)
                                        ("schema-protocol-json" :oci)
                                        ("toml-protocol" :oci)
                                        ("tomlet" :oci)
                                        ("encoding-protocol" :oci)
                                        ("serdes-protocol" :oci)))))
  :serial t
  :pathname "src/schema-toml"
  :components ((:file "package")
               (:file "conditions")
               (:file "document")
               (:file "emit")
               (:file "compile")
               (:file "validate")
               (:file "protocol"))
  :in-order-to ((test-op (test-op "json-protocol/tests"))))
