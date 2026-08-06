(defsystem "json-backend-yason"
  :version "0.2.0"
  :description "json-protocol backend — yason (alternate / migration)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("json-protocol" "yason")
  :serial t
  :pathname "src/backend-yason"
  :components ((:file "package")
               (:file "backend")))
