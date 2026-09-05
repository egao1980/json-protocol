(defsystem "toml-protocol"
  :version "0.1.0"
  :description "CLOS TOML encode/decode for cl-stack (tomlet decode + native emit); implements serdes-protocol :toml"
  :author "egao1980"
  :license "MIT"
  :depends-on ("tomlet" "encoding-protocol" "serdes-protocol")
  :properties (:cl-repo (:ci (:sources (("tomlet" :oci)
                                        ("encoding-protocol" :oci)
                                        ("serdes-protocol" :oci)))))
  :serial t
  :pathname "src/toml"
  :components ((:file "package")
               (:file "conditions")
               (:file "emitter")
               (:file "protocol")
               (:file "serdes"))
  :in-order-to ((test-op (test-op "json-protocol/tests"))))
