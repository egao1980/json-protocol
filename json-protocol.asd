(defsystem "json-protocol"
  :version "0.2.0"
  :description "CLOS JSON encode/decode protocol for cl-stack (RFC 8259); implements serdes-protocol"
  :author "egao1980"
  :license "MIT"
  :depends-on ("babel" "serdes-protocol")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "conditions")
               (:file "protocol")
               (:file "serdes"))
  :in-order-to ((test-op (test-op "json-protocol/tests"))))

(defsystem "json-protocol/tests"
  :depends-on ("json-protocol" "json-backend-jzon" "json-backend-yason" "serdes-protocol" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "protocol-test")
               (:file "jzon-test")
               (:file "yason-test")
               (:file "serdes-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
