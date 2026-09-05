(in-package #:schema-protocol-toml)

(define-condition toml-schema-error (schema-error)
  ((message :initarg :message :reader toml-schema-error-message :initform nil))
  (:report (lambda (c s)
             (format s "TOML Schema error~@[: ~A~]" (toml-schema-error-message c)))))

(define-condition toml-schema-ref-error (toml-schema-error)
  ((ref :initarg :ref :reader toml-schema-ref-error-ref))
  (:report (lambda (c s)
             (format s "Unresolved TOML Schema reference ~S~@[: ~A~]"
                     (toml-schema-ref-error-ref c)
                     (toml-schema-error-message c)))))

(define-condition toml-schema-validation-error (schema-validation-error)
  ()
  (:documentation "Instance failed TOML Schema validation. ISSUES use schema-issue loc paths."))
