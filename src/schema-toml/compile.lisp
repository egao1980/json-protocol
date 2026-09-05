(in-package #:schema-protocol-toml)

(defvar *generated-package* (find-package '#:schema-protocol-toml.generated))

(defstruct compile-ctx
  (package *generated-package*)
  (root-name nil)
  (types (make-hash-table :test #'equal))
  (filled (make-hash-table :test #'eq)))

(defun %sanitize (string)
  (let ((s (substitute #\- #\_ (substitute #\- #\Space (string string)))))
    (if (plusp (length s))
        (string-upcase s)
        "SCHEMA")))

(defun %name-symbol (name ctx)
  (etypecase name
    (symbol
     (if (eq (symbol-package name) (compile-ctx-package ctx))
         name
         (intern (symbol-name name) (compile-ctx-package ctx))))
    (string (intern (%sanitize name) (compile-ctx-package ctx)))))

(defun %ensure-shell (ctx name)
  (let ((sym (%name-symbol name ctx)))
    (or (find-class sym nil)
        (ensure-class sym
                      :metaclass (find-class 'schema-class)
                      :direct-superclasses (list (find-class 'schema-object))
                      :direct-slots '()))))

(defun lookup-named-type (ctx name)
  (let ((bare (strip-types-prefix name)))
    (or (gethash bare (compile-ctx-types ctx))
        (gethash name (compile-ctx-types ctx)))))

(defun definition-selector-type (def)
  (cond
    ((not (hash-table-p def)) nil)
    ((%get def "type") (%get def "type"))
    ((or (%get def "oneof") (%get def "anyof")) nil)
    ((plusp (hash-table-count (child-definitions def))) "table")
    (t "any")))

(defun simple-type-spec (ty def ctx &key name-hint)
  (let ((ty (if (stringp ty) (string-downcase ty) ty)))
    (cond
      ((or (null ty) (string= ty "any")) t)
      ((string= ty "string") 'string)
      ((string= ty "boolean") 'boolean)
      ((string= ty "integer")
       (let ((lo (%get def "min"))
             (hi (%get def "max")))
         (if (or lo hi)
             `(integer ,(or lo '*) ,(or hi '*))
             'integer)))
      ((string= ty "float") 'number)
      ((member ty '("offset-date-time" "local-date-time" "local-date" "local-time")
               :test #'string=)
       'string)
      ((string= ty "array")
       (let ((item (%get def "itemtype")))
         (if item
             `(vector ,(node-type-spec item ctx
                                       :name-hint (and name-hint
                                                       (format nil "~A-item" name-hint))))
             'vector)))
      ((string= ty "collection")
       'hash-table)
      ((string= ty "table")
       (if (plusp (hash-table-count (child-definitions def)))
           (let ((n (or name-hint (gentemp "OBJ" (compile-ctx-package ctx)))))
             (%ensure-shell ctx n)
             (%fill-class ctx n def)
             (%name-symbol n ctx))
           'hash-table))
      ((lookup-named-type ctx ty)
       (let ((n (%name-symbol (strip-types-prefix ty) ctx)))
         (%ensure-shell ctx n)
         (%fill-class ctx n (lookup-named-type ctx ty))
         n))
      (t t))))

(defun node-type-spec (node ctx &key name-hint)
  (cond
    ((stringp node)
     (simple-type-spec node nil ctx :name-hint name-hint))
    ((not (hash-table-p node))
     t)
    (t
     (let ((allowed (%get node "allowedvalues"))
           (one (%get node "oneof"))
           (any (%get node "anyof"))
           (ty (definition-selector-type node)))
       (cond
         ((and allowed (or (vectorp allowed) (listp allowed)))
          `(member ,@(map 'list #'identity (coerce allowed 'list))))
         (one
          `(or ,@(map 'list (lambda (n) (node-type-spec n ctx :name-hint name-hint))
                      (coerce one 'list))))
         (any
          `(or ,@(map 'list (lambda (n) (node-type-spec n ctx :name-hint name-hint))
                      (coerce any 'list))))
         (t (simple-type-spec ty node ctx :name-hint name-hint)))))))

(defun property-slot (prop-name node ctx)
  (let* ((sym (%name-symbol prop-name ctx))
         (optional (and (hash-table-p node) (%get node "optional")))
         (spec (node-type-spec node ctx :name-hint (format nil "~A" prop-name)))
         (slot `(:name ,sym
                 :type ,spec
                 :initargs (,(intern (symbol-name sym) :keyword))
                 :readers (,sym)
                 :writers ((setf ,sym))
                 :key ,(stringify-key prop-name)
                 :required ,(not optional)
                 :optional ,(and optional t))))
    (when (hash-table-p node)
      (flet ((opt (key initarg)
               (let ((v (%get node key)))
                 (when v
                   (setf slot (append slot (list initarg v)))))))
        (opt "minlength" :min-length)
        (opt "maxlength" :max-length)
        (opt "min" :minimum)
        (opt "max" :maximum)
        (opt "description" :description)
        (opt "pattern" :pattern)
        (let ((fmt (%get node "format")))
          (when (stringp fmt)
            (setf slot (append slot (list :format (intern (string-upcase fmt) :keyword))))))
        (let ((default (%get node "default")))
          (when default
            (setf slot (append slot (list :initform default
                                          :initfunction (constantly default))))))))
    slot))

(defun %fill-class (ctx name def)
  (let ((sym (%name-symbol name ctx)))
    (when (gethash sym (compile-ctx-filled ctx))
      (return-from %fill-class (find-class sym)))
    (setf (gethash sym (compile-ctx-filled ctx)) t)
    (let ((slots '()))
      (maphash (lambda (k v)
                 (push (property-slot k v ctx) slots))
               (if (hash-table-p def) (child-definitions def)
                   (make-hash-table :test #'equal)))
      (ensure-class sym
                    :metaclass (find-class 'schema-class)
                    :direct-superclasses (list (find-class 'schema-object))
                    :direct-slots (nreverse slots)
                    :extra :forbid)
      (find-class sym))))

(defun compile-schema (source &key name (package *generated-package*))
  "TOML Schema document → schema-class. NAME defaults to a generated symbol."
  (let* ((doc (parse-document source))
         (table (toml-schema-table doc))
         (name (or name (gentemp "SCHEMA" package)))
         (ctx (make-compile-ctx :package package
                                :root-name (%name-symbol name (make-compile-ctx :package package))))
         (types (%get table "types"))
         (elements (%get table "elements")))
    (when (hash-table-p types)
      (maphash (lambda (k v)
                 (setf (gethash k (compile-ctx-types ctx)) v)
                 (%ensure-shell ctx k))
               types))
    (%ensure-shell ctx (compile-ctx-root-name ctx))
    (when (hash-table-p types)
      (maphash (lambda (k v)
                 (%fill-class ctx k v))
               types))
    (%fill-class ctx (compile-ctx-root-name ctx) elements)
    (find-class (compile-ctx-root-name ctx))))
