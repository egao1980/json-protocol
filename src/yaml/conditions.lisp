(in-package #:yaml-protocol)

(define-condition yaml-error (error)
  ((message :initarg :message :reader yaml-error-message :initform nil))
  (:report (lambda (c s)
             (format s "YAML error~@[: ~a~]" (yaml-error-message c)))))

(define-condition yaml-parse-error (yaml-error) ())
(define-condition yaml-encode-error (yaml-error) ())
(define-condition yaml-unsupported-feature (yaml-error) ())
