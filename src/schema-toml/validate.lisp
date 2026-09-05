(in-package #:schema-protocol-toml)

(defstruct (toml-schema-validator (:conc-name validator-))
  root
  version
  types
  elements)

(defstruct vctx
  validator
  (path nil)
  (issues nil))

(defun vfail (ctx message &optional value)
  (push (make-schema-issue :path (reverse (vctx-path ctx))
                           :message message
                           :value value)
        (vctx-issues ctx))
  nil)

(defun with-path (ctx token fn)
  (push token (vctx-path ctx))
  (unwind-protect (funcall fn)
    (pop (vctx-path ctx))))

(defun object-p (value)
  (hash-table-p value))

(defun array-p (value)
  (and (vectorp value) (not (stringp value))))

(defun instance-table (source)
  (cond
    ((hash-table-p source)
     (let ((out (make-hash-table :test #'equal)))
       (maphash (lambda (k v)
                  (setf (gethash (stringify-key k) out) (normalize-instance v)))
                source)
       out))
    ((pathnamep source)
     (instance-table (toml-protocol:decode source)))
    ((or (stringp source)
         (and (vectorp source) (not (stringp source))
              (plusp (length source))
              (integerp (ignore-errors (aref source 0)))))
     (instance-table (toml-protocol:decode source)))
    ((and (listp source) (keywordp (first source)))
     (let ((out (make-hash-table :test #'equal)))
       (loop for (k v) on source by #'cddr
             do (setf (gethash (stringify-key k) out) (normalize-instance v)))
       out))
    ((and (listp source) (consp (first source)))
     (let ((out (make-hash-table :test #'equal)))
       (dolist (pair source out)
         (setf (gethash (stringify-key (car pair)) out)
               (normalize-instance (cdr pair))))))
    (t source)))

(defun normalize-instance (value)
  (cond
    ((hash-table-p value) (instance-table value))
    ((and (vectorp value) (not (stringp value)))
     (map 'vector #'normalize-instance value))
    ((and (listp value) (or (keywordp (first value)) (consp (first value))))
     (instance-table value))
    (t value)))

(defun as-definition (node)
  (cond
    ((hash-table-p node) node)
    ((stringp node) (let ((ht (make-hash-table :test #'equal)))
                      (setf (gethash "type" ht) node)
                      ht))
    (t (make-hash-table :test #'equal))))

(defun lookup-type (validator name)
  (let ((bare (strip-types-prefix name)))
    (or (gethash bare (validator-types validator))
        (gethash name (validator-types validator)))))

(defun resolve-definition (ctx node)
  "Follow a named type reference. Returns the effective definition table."
  (let ((def (as-definition node)))
    (let ((ty (%get def "type")))
      (if (and (stringp ty) (not (builtin-type-p ty)))
          (let ((named (lookup-type (vctx-validator ctx) ty)))
            (unless named
              (error 'toml-schema-ref-error
                     :ref ty
                     :message "unknown [types] reference"))
            named)
          def))))

(defun effective-type-name (ctx def)
  (let ((resolved (resolve-definition ctx def))
        (written (and (hash-table-p def) (%get def "type"))))
    (or (and (hash-table-p resolved) (%get resolved "type"))
        written
        (when (or (%get def "oneof") (%get def "anyof")
                  (%get resolved "oneof") (%get resolved "anyof"))
          nil)
        (when (plusp (hash-table-count (child-definitions resolved)))
          "table")
        "any")))

(defun type-matches (ty value)
  (let ((ty (string-downcase (string ty))))
    (cond
      ((string= ty "any") t)
      ((string= ty "string") (stringp value))
      ((string= ty "integer") (integerp value))
      ((string= ty "float") (and (realp value) (not (integerp value))))
      ((string= ty "boolean") (or (eq value t) (eq value nil) (eq value :true) (eq value :false)))
      ((string= ty "table") (object-p value))
      ((string= ty "collection") (object-p value))
      ((string= ty "array") (array-p value))
      ((member ty '("offset-date-time" "local-date-time" "local-date" "local-time")
               :test #'string=)
       (or (stringp value)
           (not (or (object-p value) (array-p value)
                    (realp value) (eq value t) (null value)))))
      (t t))))

(defun silent-valid-p (ctx def value)
  (let ((*issues* (vctx-issues ctx)))
    (declare (ignore *issues*))
    (let ((saved (vctx-issues ctx)))
      (setf (vctx-issues ctx) nil)
      (unwind-protect
           (progn
             (check-definition ctx def value)
             (null (vctx-issues ctx)))
        (setf (vctx-issues ctx) saved)))))

(defun check-allowed (ctx def value)
  (let ((allowed (%get def "allowedvalues")))
    (when (and allowed (or (vectorp allowed) (listp allowed)))
      (unless (some (lambda (item)
                      (cond
                        ((and (stringp item) (stringp value)) (string= item value))
                        ((and (realp item) (realp value)) (= item value))
                        ((and (or (eq item t) (eq item :true))
                              (or (eq value t) (eq value :true)))
                         t)
                        ((and (or (null item) (eq item :false))
                              (or (null value) (eq value :false)))
                         t)
                        (t (equal item value))))
                    (coerce allowed 'list))
        (vfail ctx "allowedvalues" value)))))

(defun check-range (ctx def value)
  (when (realp value)
    (let ((lo (%get def "min"))
          (hi (%get def "max")))
      (when (and (realp lo) (< value lo))
        (vfail ctx (format nil "min ~A" lo) value))
      (when (and (realp hi) (> value hi))
        (vfail ctx (format nil "max ~A" hi) value)))))

(defun check-length (ctx def value)
  (let ((n (cond
             ((stringp value) (length value))
             ((array-p value) (length value))
             ((object-p value) (hash-table-count value))
             (t nil)))
        (lo (%get def "minlength"))
        (hi (%get def "maxlength")))
    (when n
      (when (and (integerp lo) (< n lo))
        (vfail ctx (format nil "minlength ~A" lo) value))
      (when (and (integerp hi) (> n hi))
        (vfail ctx (format nil "maxlength ~A" hi) value)))))

(defun check-pattern (ctx def value)
  (let ((pat (%get def "pattern")))
    (when (and (stringp pat) (stringp value))
      (handler-case
          (unless (cl-ppcre:scan pat value)
            (vfail ctx (format nil "pattern ~A" pat) value))
        (error ()
          (vfail ctx (format nil "invalid pattern ~A" pat) value))))))

(defun check-format (ctx def value)
  (let ((fmt (%get def "format")))
    (when (and (stringp fmt) (stringp value))
      (let ((ok (string-downcase fmt)))
        (unless (cond
                  ((string= ok "email")
                   (cl-ppcre:scan "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$" value))
                  ((string= ok "uuid")
                   (cl-ppcre:scan
                    "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
                    value))
                  ((string= ok "uri")
                   (cl-ppcre:scan "^[a-zA-Z][a-zA-Z0-9+.-]*:" value))
                  ((string= ok "hostname")
                   (cl-ppcre:scan "^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$" value))
                  ((string= ok "ipv4")
                   (cl-ppcre:scan
                    "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
                    value))
                  ((string= ok "ipv6")
                   (find #\: value))
                  (t t))
          (vfail ctx (format nil "format ~A" fmt) value))))))

(defun check-scalar-constraints (ctx def value)
  (check-allowed ctx def value)
  (check-range ctx def value)
  (check-length ctx def value)
  (check-pattern ctx def value)
  (check-format ctx def value))

(defun check-alternatives (ctx def value kind)
  (let ((alts (coerce (%get def kind) 'list)))
    (let ((n (count-if (lambda (alt) (silent-valid-p ctx alt value)) alts)))
      (cond
        ((string-equal kind "oneof")
         (unless (= n 1)
           (vfail ctx (format nil "oneof matched ~D" n) value)))
        ((string-equal kind "anyof")
         (unless (>= n 1)
           (vfail ctx "anyof" value)))))))

(defun check-table (ctx def value)
  (unless (object-p value)
    (vfail ctx "type table" value)
    (return-from check-table))
  (let ((children (child-definitions def))
        (seen (make-hash-table :test #'equal)))
    ;; Bare `type = "table"` (no children) is an open bag. Children close it.
    (when (zerop (hash-table-count children))
      (return-from check-table))
    (maphash (lambda (k child)
               (setf (gethash k seen) t)
               (with-path ctx k
                 (lambda ()
                   (multiple-value-bind (raw present) (gethash k value)
                     (cond
                       ((not present)
                        (unless (%get (as-definition child) "optional")
                          (vfail ctx "required")))
                       (t (check-definition ctx child raw)))))))
             children)
    (maphash (lambda (k v)
               (declare (ignore v))
               (unless (gethash k seen)
                 (with-path ctx k
                   (lambda () (vfail ctx "unexpected field" (gethash k value))))))
             value)))

(defun check-collection (ctx def value)
  (unless (object-p value)
    (vfail ctx "type collection" value)
    (return-from check-collection))
  (check-length ctx def value)
  (let ((item (%get def "itemtype")))
    (unless item
      (vfail ctx "collection requires itemtype")
      (return-from check-collection))
    (maphash (lambda (k v)
               (with-path ctx k
                 (lambda () (check-definition ctx item v))))
             value)))

(defun check-array (ctx def value)
  (unless (array-p value)
    (vfail ctx "type array" value)
    (return-from check-array))
  (check-length ctx def value)
  (let ((item (%get def "itemtype")))
    (when item
      (loop for i from 0 below (length value)
            do (with-path ctx i
                 (lambda () (check-definition ctx item (aref value i))))))))

(defun check-definition (ctx node value)
  (let* ((def (as-definition node))
         (one (%get def "oneof"))
         (any (%get def "anyof")))
    (cond
      (one (check-alternatives ctx def value "oneof"))
      (any (check-alternatives ctx def value "anyof"))
      (t
       (let* ((resolved (resolve-definition ctx def))
              (ty (effective-type-name ctx def)))
         (when (and (stringp ty) (not (string= ty "any")) (not (type-matches ty value)))
           (vfail ctx (format nil "type ~A" ty) value)
           (return-from check-definition))
         (check-scalar-constraints ctx resolved value)
         (when (and (hash-table-p def) (not (eq def resolved)))
           (check-scalar-constraints ctx def value))
         (cond
           ((and ty (string-equal ty "table"))
            (check-table ctx resolved value))
           ((and ty (string-equal ty "collection"))
            (check-collection ctx resolved value))
           ((and ty (string-equal ty "array"))
            (check-array ctx resolved value))))))))

(defun compile-validator (source)
  "TOML Schema document → reusable validator."
  (when (toml-schema-validator-p source)
    (return-from compile-validator source))
  (let* ((doc (parse-document source))
         (table (toml-schema-table doc))
         (types (make-hash-table :test #'equal))
         (raw-types (%get table "types")))
    (when (hash-table-p raw-types)
      (maphash (lambda (k v) (setf (gethash k types) v)) raw-types))
    (make-toml-schema-validator :root table
                                :version (toml-schema-version doc)
                                :types types
                                :elements (%get table "elements"))))

(defun validate-instance (schema instance)
  "Validate INSTANCE against a TOML Schema document / validator.
   Signals TOML-SCHEMA-VALIDATION-ERROR. Returns INSTANCE on success."
  (let* ((validator (compile-validator schema))
         (data (instance-table instance))
         (ctx (make-vctx :validator validator)))
    (check-definition ctx
                      (let ((ht (make-hash-table :test #'equal)))
                        (setf (gethash "type" ht) "table")
                        (let ((elems (validator-elements validator)))
                          (when (hash-table-p elems)
                            (maphash (lambda (k v) (setf (gethash k ht) v)) elems)))
                        ht)
                      data)
    (when (vctx-issues ctx)
      (error 'toml-schema-validation-error
             :issues (nreverse (vctx-issues ctx))))
    instance))

(defun valid-instance-p (schema instance)
  (handler-case
      (progn (validate-instance schema instance) t)
    (toml-schema-validation-error () nil)
    (toml-schema-ref-error () nil)))

(defun %decode-json (source)
  (let* ((pkg (find-package "JSON-PROTOCOL"))
         (fn (and pkg (find-symbol "DECODE" pkg))))
    (unless fn
      (error 'toml-schema-error
             :message "load json-protocol to read JSON Schema files"))
    (funcall fn source)))

(defun load-discovered-schema (location kind &key pathname)
  (cond
    ((remote-schema-ref-p location)
     (error 'toml-schema-ref-error
            :ref location
            :message "wave-1 does not fetch remote schemas"))
    ((eq kind :json-schema)
     (let ((path (resolve-local-schema location :pathname pathname)))
       (schema-protocol-json:parse-document (%decode-json path))))
    (t
     (parse-document (resolve-local-schema location :pathname pathname)))))

(defun decode-validating (source &key schema discover pathname)
  "Decode a TOML instance and validate it.
   SCHEMA is a TOSD document, JSON Schema document, or validator.
   :DISCOVER T reads `#:schema` / `$schema` / `[toml-schema].location`."
  (let* ((text (etypecase source
                 (string source)
                 (pathname
                  (with-open-file (in source :direction :input)
                    (let ((s (make-string (file-length in))))
                      (read-sequence s in)
                      s)))
                 (hash-table nil)))
         (data (if (hash-table-p source)
                   (stringify-toml source)
                   (toml-protocol:decode (or text source))))
         (path (or pathname (and (pathnamep source) source))))
    (cond
      (schema
       (if (or (schema-protocol-json:json-schema-document-p schema)
               (schema-protocol-json:json-schema-validator-p schema)
               (and (hash-table-p schema) (%get schema "$schema")))
           (schema-protocol-json:validate-instance schema data)
           (validate-instance schema data)))
      (discover
       (multiple-value-bind (location kind) (discover-schema (or text data) :pathname path)
         (unless location
           (error 'toml-schema-error
                  :message "no #:schema, $schema, or [toml-schema].location"))
         (let ((loaded (load-discovered-schema location kind :pathname path)))
           (if (eq kind :json-schema)
               (schema-protocol-json:validate-instance loaded data)
               (validate-instance loaded data)))))
      (t
       (error 'toml-schema-error
              :message "supply :schema or :discover t")))
    data))
