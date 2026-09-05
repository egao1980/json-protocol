(in-package #:schema-protocol-toml)

(defparameter +tosd-version+ "1.0.0"
  "TOML Schema language version implemented (wave-1 subset).")

(defparameter *property-keys*
  '("type" "oneof" "anyof" "allof" "if" "then" "else"
    "itemtype" "items" "optional" "default" "deprecated" "description"
    "format" "allowedvalues" "pattern" "keypattern" "min" "max"
    "minlength" "maxlength" "uniqueitems"
    "dependentrequired" "mutuallyexclusive" "exactlyone" "children")
  "Closed TOSD schema-definition property set (toml-schema.org 1.0).")

(defparameter *builtin-types*
  '("any" "string" "integer" "float" "boolean"
    "offset-date-time" "local-date-time" "local-date" "local-time"
    "array" "table" "collection"))

(defun stringify-key (key)
  (etypecase key
    (string key)
    (symbol (string-downcase (symbol-name key)))
    (character (string key))))

(defun stringify-toml (value)
  (cond
    ((hash-table-p value)
     (let ((out (make-hash-table :test #'equal)))
       (maphash (lambda (k v)
                  (setf (gethash (stringify-key k) out) (stringify-toml v)))
                value)
       out))
    ((and (vectorp value) (not (stringp value)))
     (map 'vector #'stringify-toml value))
    ((and (listp value) (keywordp (first value)))
     (let ((out (make-hash-table :test #'equal)))
       (loop for (k v) on value by #'cddr
             do (setf (gethash (stringify-key k) out) (stringify-toml v)))
       out))
    ((and (listp value) (consp (first value)))
     (let ((out (make-hash-table :test #'equal)))
       (dolist (pair value out)
         (setf (gethash (stringify-key (car pair)) out)
               (stringify-toml (cdr pair))))))
    ((listp value)
     (mapcar #'stringify-toml value))
    (t value)))

(defun %get (table key)
  (and (hash-table-p table) (gethash key table)))

(defun property-key-p (key)
  (member (stringify-key key) *property-keys* :test #'string-equal))

(defun builtin-type-p (name)
  (and (stringp name)
       (member name *builtin-types* :test #'string-equal)))

(defun strip-types-prefix (name)
  (if (and (stringp name)
           (>= (length name) 6)
           (string-equal name "types." :end1 6))
      (subseq name 6)
      name))

(defun child-definitions (def)
  "Fixed child definitions of DEF (non-property keys)."
  (let ((out (make-hash-table :test #'equal)))
    (when (hash-table-p def)
      (maphash (lambda (k v)
                 (unless (property-key-p k)
                   (setf (gethash k out) v)))
               def))
    out))

(defun table-from-source (source)
  (cond
    ((hash-table-p source) (stringify-toml source))
    ((typep source 'toml-schema-document) (toml-schema-table source))
    ((pathnamep source)
     (stringify-toml (toml-protocol:decode source)))
    ((or (stringp source)
         (and (vectorp source) (not (stringp source))
              (plusp (length source))
              (typep (aref source 0) '(unsigned-byte 8))))
     (stringify-toml (toml-protocol:decode source)))
    ((or (listp source))
     (stringify-toml source))
    (t
     (error 'toml-schema-error
            :message (format nil "cannot read TOML Schema from ~S" (type-of source))))))

(defclass toml-schema-document ()
  ((table :initarg :table :reader toml-schema-table)
   (version :initarg :version :reader toml-schema-version :initform +tosd-version+))
  (:documentation "Parsed TOML Schema document (hash-table, string keys)."))

(defun toml-schema-document-p (object)
  (typep object 'toml-schema-document))

(defun detect-version (table)
  (let ((meta (%get table "toml-schema")))
    (or (and (hash-table-p meta) (%get meta "version"))
        +tosd-version+)))

(defun parse-document (source)
  "TOML string / hash-table / pathname / document → TOML-SCHEMA-DOCUMENT."
  (cond
    ((toml-schema-document-p source)
     source)
    (t
     (let ((table (table-from-source source)))
       (unless (hash-table-p (%get table "toml-schema"))
         (error 'toml-schema-error
                :message "TOML Schema document requires [toml-schema]"))
       (unless (hash-table-p (%get table "elements"))
         (error 'toml-schema-error
                :message "TOML Schema document requires [elements]"))
       (let ((ver (detect-version table)))
         (unless (and (stringp ver) (plusp (length ver)))
           (error 'toml-schema-error
                  :message "[toml-schema].version must be a non-empty string"))
         (make-instance 'toml-schema-document
                        :table table
                        :version ver))))))

(defun schema-comment-location (text)
  "Taplo `#:schema <uri>` on a leading comment line."
  (when (stringp text)
    (with-input-from-string (in text)
      (loop for line = (read-line in nil nil)
            while line
            for trimmed = (string-trim '(#\Space #\Tab #\Return) line)
            do (cond
                 ((zerop (length trimmed)))
                 ((and (>= (length trimmed) 8)
                       (string-equal trimmed "#:schema" :end1 8))
                  (return (string-trim '(#\Space #\Tab)
                                       (subseq trimmed 8))))
                 ((and (plusp (length trimmed))
                       (char= (char trimmed 0) #\#)))
                 (t (return nil)))))))

(defun classify-schema-ref (location via)
  (cond
    ((eq via :toml-schema-location) :tosd)
    ((and (stringp location)
          (or (search ".tosd" location :test #'char-equal)
              (search "application/tosd" location :test #'char-equal)))
     :tosd)
    ((eq via :schema-comment) :json-schema)
    ((eq via :dollar-schema) :json-schema)
    (t :json-schema)))

(defun discover-schema (source &key pathname)
  "Locate a schema reference on a TOML instance.
   Returns (values location kind) or (values nil nil).
   KIND is :TOSD or :JSON-SCHEMA.
   Priority: `#:schema` comment, `$schema` key, `[toml-schema].location`."
  (declare (ignore pathname))
  (let* ((text (etypecase source
                 (string source)
                 (pathname
                  (with-open-file (in source :direction :input)
                    (let ((s (make-string (file-length in))))
                      (read-sequence s in)
                      s)))
                 (hash-table nil)
                 (t nil)))
         (table (cond
                  ((hash-table-p source) (stringify-toml source))
                  (text (ignore-errors (stringify-toml (toml-protocol:decode text))))
                  (t nil)))
         (comment (schema-comment-location text))
         (dollar (and table (let ((v (%get table "$schema")))
                              (and (stringp v) (plusp (length v)) v))))
         (meta (and table (%get table "toml-schema")))
         (loc (and (hash-table-p meta)
                   (let ((v (%get meta "location")))
                     (and (stringp v) (plusp (length v)) v)))))
    (cond
      (comment (values comment (classify-schema-ref comment :schema-comment)))
      (dollar (values dollar (classify-schema-ref dollar :dollar-schema)))
      (loc (values loc (classify-schema-ref loc :toml-schema-location)))
      (t (values nil nil)))))

(defun remote-schema-ref-p (location)
  (or (and (>= (length location) 7) (string-equal location "http://" :end1 7))
      (and (>= (length location) 8) (string-equal location "https://" :end1 8))))

(defun resolve-local-schema (location &key pathname)
  (when (remote-schema-ref-p location)
    (error 'toml-schema-ref-error
           :ref location
           :message "wave-1 does not fetch remote schemas"))
  (merge-pathnames location
                   (if pathname
                       (make-pathname :name nil :type nil :defaults pathname)
                       *default-pathname-defaults*)))
