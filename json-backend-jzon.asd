(defsystem "json-backend-jzon"
  :version "0.2.4"
  :description "json-protocol backend — com.inuoe.jzon (stack default); JSONL + event pull"
  :author "egao1980"
  :license "MIT"
  :depends-on ((:version "json-protocol" "0.2.3")
               (:version "encoding-protocol" "0.2.0")
               (:version "serdes-protocol" "0.2.0")
               "com.inuoe.jzon")
  ;; Own package and version: publish never mounts it onto its siblings.
  :properties (:cl-repo (:provides ("json-backend-jzon")))
  :serial t
  :pathname "src/backend-jzon"
  :components ((:file "package")
               (:file "backend")
               (:file "events")))
