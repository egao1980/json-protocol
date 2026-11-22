(defsystem "json-backend-yason"
  :version "0.2.3"
  :description "json-protocol backend — yason (alternate / migration)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("json-protocol" "encoding-protocol" "yason")
  ;; Own package and version: publish never mounts it onto its siblings.
  :properties (:cl-repo (:provides ("json-backend-yason")))
  :serial t
  :pathname "src/backend-yason"
  :components ((:file "package")
               (:file "backend")))
