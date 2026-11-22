(defsystem "json-backend-jzon"
  :version "0.2.2"
  :description "json-protocol backend — com.inuoe.jzon (stack default); JSONL + event pull"
  :author "egao1980"
  :license "MIT"
  :depends-on ("json-protocol" "encoding-protocol" "serdes-protocol" "com.inuoe.jzon")
  ;; Own package and version: publish never mounts it onto its siblings.
  :properties (:cl-repo (:provides ("json-backend-jzon")))
  :serial t
  :pathname "src/backend-jzon"
  :components ((:file "package")
               (:file "backend")
               (:file "events")))
