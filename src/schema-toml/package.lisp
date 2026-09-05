(defpackage #:schema-protocol-toml.generated
  (:use))

(eval-when (:compile-toplevel :load-toplevel :execute)
  ;; 0.2.0 OCI pin has no TOML-SCHEMA yet — intern so :import-from works.
  (let ((pkg (find-package '#:schema-protocol)))
    (dolist (name '("TOML-SCHEMA" "SCHEMA-FORMAT-BACKEND" "REGISTER-SCHEMA-FORMAT"
                    "BACKEND-EMIT-SCHEMA" "BACKEND-PARSE-SCHEMA"))
      (export (intern name pkg) pkg))))

(defpackage #:schema-protocol-toml
  (:use #:cl)
  (:nicknames #:stack-schema-toml)
  (:import-from #:closer-mop
                #:ensure-class
                #:slot-definition-name
                #:slot-definition-type)
  (:import-from #:schema-protocol
                #:schema-of
                #:schema-slots
                #:schema-class
                #:schema-object
                #:schema-class-extra
                #:schema-extra-policy
                #:schema-class-key-style
                #:schema-class-computes
                #:schema-class-tag
                #:schema-error
                #:find-schema
                #:schema-slot
                #:schema-tag
                #:schema-variants
                #:enum-of
                #:enum-members
                #:finalize-schema
                #:type-kind
                #:type-args
                #:sequence-element-type
                #:slot-is-required-p
                #:slot-wire-p
                #:slot-dump-p
                #:slot-wire-key
                #:slot-min-length
                #:slot-max-length
                #:slot-minimum
                #:slot-maximum
                #:slot-format
                #:slot-pattern
                #:slot-description
                #:style-key
                #:toml-schema
                #:schema-format-backend
                #:register-schema-format
                #:backend-emit-schema
                #:backend-parse-schema
                #:schema-validation-error
                #:schema-validation-error-issues
                #:make-schema-issue
                #:schema-issue-path
                #:schema-issue-message)
  (:export #:toml-schema-error
           #:toml-schema-error-message
           #:toml-schema-ref-error
           #:toml-schema-ref-error-ref
           #:toml-schema-document
           #:toml-schema-document-p
           #:toml-schema-table
           #:toml-schema-version
           #:parse-document
           #:emit
           #:compile-schema
           #:compile-validator
           #:validate-instance
           #:valid-instance-p
           #:toml-schema-validator
           #:toml-schema-validator-p
           #:toml-schema-validation-error
           #:toml-schema
           #:discover-schema
           #:decode-validating
           #:+tosd-version+))

(in-package #:schema-protocol-toml)

(unless (and (fboundp 'toml-schema)
             (typep (symbol-function 'toml-schema) 'generic-function))
  (defgeneric toml-schema (schema &key version)
    (:documentation "Emit a TOML Schema (.tosd) document (TOML string).")))
