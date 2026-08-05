(in-package #:json-protocol)

(define-condition json-error (error)
  ((message :initarg :message :reader json-error-message :initform nil))
  (:report (lambda (c s)
             (format s "JSON error~@[: ~a~]" (json-error-message c)))))

(define-condition json-parse-error (json-error) ())
(define-condition json-encode-error (json-error) ())
(define-condition json-limit-error (json-error) ())
