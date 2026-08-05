(defpackage #:json-protocol
  (:use #:cl)
  ;; Nick stack-json (not json) — avoids clashes with other CL JSON packages.
  (:nicknames #:stack-json)
  (:export #:json-error

           #:json-parse-error
           #:json-encode-error
           #:json-limit-error
           #:json-error-message
           #:*json-backend*
           #:json-backend
           #:backend-encode
           #:backend-decode
           #:encode
           #:decode
           #:encode-to-octets
           #:decode-octets
           #:null-p
           #:true-p
           #:false-p
           #:install-http-json-hooks
           #:install-serdes-json-hooks))

(in-package #:json-protocol)
