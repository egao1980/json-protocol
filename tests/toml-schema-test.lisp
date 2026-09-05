(defpackage #:schema-protocol-toml/tests
  (:use #:cl #:rove #:schema-protocol #:schema-protocol-toml))

(in-package #:schema-protocol-toml/tests)

(defun %ht (&rest plist)
  (let ((ht (make-hash-table :test #'equal)))
    (loop for (k v) on plist by #'cddr
          do (setf (gethash k ht) v))
    ht))

(defun %slot (obj name)
  (slot-value obj (intern (string name) (symbol-package (class-name (class-of obj))))))

(defun %tosd (&key types elements (version "1.0.0"))
  (let ((root (%ht "toml-schema" (%ht "version" version)
                   "elements" (or elements (make-hash-table :test #'equal)))))
    (when types
      (setf (gethash "types" root) types))
    root))

(deftest emit-object
  (defschema %tosd-addr ()
    (city string))
  (defschema %tosd-user ()
    (name string :min-length 1)
    (age integer :minimum 0 :optional t)
    (address %tosd-addr)
    (tags (vector string))
    (:extra :forbid))
  (let* ((table (emit '%tosd-user))
         (elems (gethash "elements" table))
         (types (gethash "types" table)))
    (ok (equal "1.0.0" (gethash "version" (gethash "toml-schema" table))))
    (ok (equal "string" (gethash "type" (gethash "name" elems))))
    (ok (= 1 (gethash "minlength" (gethash "name" elems))))
    (ok (eq t (gethash "optional" (gethash "age" elems))))
    (ok (equal "integer" (gethash "type" (gethash "age" elems))))
    (ok (equal "array" (gethash "type" (gethash "tags" elems))))
    (ok (equal "string" (gethash "itemtype" (gethash "tags" elems))))
    (ok (equal "types.%tosd-addr" (gethash "type" (gethash "address" elems))))
    (ok (hash-table-p (gethash "%tosd-addr" types)))
    (ok (stringp (toml-schema '%tosd-user)))))

(deftest compile-and-parse
  (let* ((doc (%tosd :elements
                     (%ht "name" (%ht "type" "string" "minlength" 1)
                          "age" (%ht "type" "integer" "min" 0 "optional" t))))
         (class (compile-schema doc :name 'compiled-tosd-person))
         (obj (schema-protocol:parse class (%ht "name" "Ada" "age" 36))))
    (ok (equal "Ada" (%slot obj "NAME")))
    (ok (signals (schema-protocol:parse class (%ht "age" 1))
                 'schema-validation-error))))

(deftest emit-compile-roundtrip
  (defschema %rt-tosd-note ()
    (title string)
    (body string :optional t)
    (:extra :forbid))
  (let* ((table (emit '%rt-tosd-note))
         (class (compile-schema table :name 'rt-tosd-note))
         (obj (schema-protocol:parse class (%ht "title" "hi"))))
    (ok (equal "hi" (%slot obj "TITLE")))
    (ok (signals (schema-protocol:parse class (%ht))
                 'schema-validation-error))))

(deftest parse-document-requires-metadata
  (ok (signals (parse-document (%ht "elements" (%ht)))
               'toml-schema-error))
  (ok (toml-schema-document-p (parse-document (%tosd)))))
