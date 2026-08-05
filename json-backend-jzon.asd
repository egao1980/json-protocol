(defsystem "json-backend-jzon"
  :version "0.1.0"
  :description "json-protocol backend — com.inuoe.jzon (stack default)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("json-protocol" "com.inuoe.jzon")
  :serial t
  :pathname "src/backend-jzon"
  :components ((:file "package")
               (:file "backend")))
