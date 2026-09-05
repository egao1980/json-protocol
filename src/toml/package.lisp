(defpackage #:toml-protocol
  (:use #:cl)
  (:nicknames #:stack-toml)
  (:export #:toml-error
           #:toml-parse-error
           #:toml-encode-error
           #:toml-error-message

           #:*toml-backend*
           #:toml-backend
           #:backend-encode
           #:backend-decode
           #:make-toml-backend
           #:use-toml-backend

           #:encode
           #:decode
           #:encode-to-octets
           #:decode-octets

           #:null-p
           #:true-p
           #:false-p

           #:toml-serdes-backend
           #:make-toml-serdes-backend
           #:use-toml-serdes-backend))

(in-package #:toml-protocol)
