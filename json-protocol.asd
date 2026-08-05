(defsystem "json-protocol"
  :version "0.1.0"
  :description "CLOS JSON encode/decode protocol for cl-stack (RFC 8259)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("babel")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "conditions")
               (:file "protocol"))
  :in-order-to ((test-op (test-op "json-protocol/tests"))))

(defsystem "json-backend-jzon"
  :version "0.1.0"
  :description "json-protocol backend — com.inuoe.jzon (stack default)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("json-protocol" "com.inuoe.jzon")
  :serial t
  :pathname "src/backend-jzon"
  :components ((:file "package")
               (:file "backend"))
  :in-order-to ((test-op (test-op "json-protocol/tests"))))

(defsystem "json-backend-yason"
  :version "0.1.0"
  :description "json-protocol backend — yason (alternate / migration)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("json-protocol" "yason")
  :serial t
  :pathname "src/backend-yason"
  :components ((:file "package")
               (:file "backend")))

(defsystem "json-protocol/tests"
  :depends-on ("json-protocol" "json-backend-jzon" "json-backend-yason" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "protocol-test")
               (:file "jzon-test")
               (:file "yason-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
