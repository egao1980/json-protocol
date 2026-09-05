(defsystem "json-protocol"
  :version "0.3.0"
  :description "CLOS JSON encode/decode protocol for cl-stack (RFC 8259); implements serdes-protocol"
  :author "egao1980"
  :license "MIT"
  :depends-on ("encoding-protocol" "serdes-protocol")
  :properties (:cl-repo (:ci (:with ("json-backend-jzon" "json-backend-yason" "yaml-protocol"
                                      "toml-protocol" "schema-protocol-toml")
                             :sources (("serdes-protocol" :oci)
                                       ("encoding-protocol" :oci)
                                       ("schema-protocol" :oci)
                                       ("schema-protocol-json" :oci)
                                       ("tomlet" :oci)))))
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "conditions")
               (:file "protocol")
               (:file "serdes"))
  :in-order-to ((test-op (test-op "json-protocol/tests"))))

(defsystem "json-protocol/tests"
  :depends-on ("json-protocol" "json-backend-jzon" "json-backend-yason"
               "yaml-protocol" "toml-protocol" "schema-protocol-toml"
               "serdes-protocol" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "protocol-test")
               (:file "jzon-test")
               (:file "yason-test")
               (:file "serdes-test")
               (:file "yaml-test")
               (:file "toml-test")
               (:file "toml-schema-test")
               (:file "toml-schema-validate-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
