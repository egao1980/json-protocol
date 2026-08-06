(defsystem "json-backend-jzon"
  :version "0.2.0"
  :description "json-protocol backend — com.inuoe.jzon (stack default); JSONL + event pull"
  :author "egao1980"
  :license "MIT"
  :depends-on ("json-protocol" "serdes-protocol" "com.inuoe.jzon")
  :serial t
  :pathname "src/backend-jzon"
  :components ((:file "package")
               (:file "backend")
               (:file "events")))
