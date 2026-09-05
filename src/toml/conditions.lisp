(in-package #:toml-protocol)

(define-condition toml-error (error)
  ((message :initarg :message :reader toml-error-message :initform nil))
  (:report (lambda (c s)
             (format s "TOML error~@[: ~a~]" (toml-error-message c)))))

(define-condition toml-parse-error (toml-error) ())
(define-condition toml-encode-error (toml-error) ())
