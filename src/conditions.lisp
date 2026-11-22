(in-package #:json-protocol)

(define-condition json-error (error)
  ((message :initarg :message :reader json-error-message :initform nil))
  (:report (lambda (c s)
             (format s "JSON error~@[: ~a~]" (json-error-message c)))))

(define-condition json-parse-error (json-error) ())
(define-condition json-encode-error (json-error) ())
(define-condition json-limit-error (json-error) ())

(define-condition json-parse-limit-error (json-parse-error json-limit-error)
  ((limit :initarg :limit :reader json-limit-error-limit :initform nil
          :documentation ":MAX-STRING-LENGTH or :MAX-DEPTH.")
   (value :initarg :value :reader json-limit-error-value :initform nil
          :documentation "The limit in force."))
  (:documentation "DECODE input exceeds a caller-set limit (see
*JSON-MAX-STRING-LENGTH* and *JSON-MAX-DEPTH*). A JSON-PARSE-ERROR, so
callers that map parse failures (JSON-RPC -32700) keep working, and a
JSON-LIMIT-ERROR."))
