(defsystem "yaml-protocol"
  :version "0.1.2"
  :description "CLOS YAML 1.2 encode/decode; extends json-protocol (JSON ⊂ YAML); implements serdes-protocol :yaml"
  :author "egao1980"
  :license "MIT"
  :depends-on ("encoding-protocol" "json-protocol" "serdes-protocol")
  :serial t
  :pathname "src/yaml"
  :components ((:file "package")
               (:file "conditions")
               (:file "parser")
               (:file "emitter")
               (:file "protocol")
               (:file "serdes"))
  :in-order-to ((test-op (test-op "yaml-protocol/tests"))))

(defsystem "yaml-protocol/tests"
  :depends-on ("yaml-protocol" "json-protocol" "json-backend-jzon" "serdes-protocol" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "yaml-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
