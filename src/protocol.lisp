(in-package #:json-protocol)

;;; Normative Lisp ↔ JSON mapping (see cl-stack/docs/capabilities/json-protocol.md):
;;;   object → hash-table (equal), string keys
;;;   array  → vector
;;;   null   → :null
;;;   false  → nil    true → t
;;; Encode: nil → JSON false; :null → JSON null.

(defvar *json-backend* nil
  "Current JSON backend object (satisfies BACKEND-ENCODE / BACKEND-DECODE).")

(defclass json-backend () ()
  (:documentation "Base class for json-protocol backends."))

(defgeneric backend-encode (backend value &key stream false-nil)
  (:documentation "Encode VALUE to JSON string, or write to STREAM when non-nil.
   FALSE-NIL is reserved; default nil means Lisp NIL → JSON false."))

(defgeneric backend-decode (backend source &key)
  (:documentation "Decode SOURCE (string, octet-vector, or character stream) to Lisp."))

(defun null-p (object)
  (eq object :null))

(defun true-p (object)
  (eq object t))

(defun false-p (object)
  (and (null object) (not (eq object :null))))

(defun encode (value &key stream (false-nil nil))
  "Encode VALUE via *JSON-BACKEND*. Returns a string unless STREAM is given."
  (unless *json-backend*
    (error 'json-encode-error :message "*json-backend* is unbound — load json-backend-jzon"))
  (backend-encode *json-backend* value :stream stream :false-nil false-nil))

(defun decode (source &key)
  "Decode SOURCE via *JSON-BACKEND*."
  (unless *json-backend*
    (error 'json-parse-error :message "*json-backend* is unbound — load json-backend-jzon"))
  (backend-decode *json-backend* source))

(defun encode-to-octets (value &key (false-nil nil))
  "UTF-8 octets of (ENCODE VALUE)."
  (babel:string-to-octets (encode value :false-nil false-nil) :encoding :utf-8))

(defun decode-octets (octets &key)
  "DECODE UTF-8 OCTETS."
  (decode (babel:octets-to-string octets :encoding :utf-8)))

(defun install-http-json-hooks ()
  "If http-protocol is loaded, bind *json-encoder* / *json-decoder* and :json serdes.
   No-op when http-protocol is absent. Returns T when hooks installed."
  (let ((pkg (find-package :http-protocol)))
    (unless pkg
      (return-from install-http-json-hooks nil))
    (flet ((set-sym (name value)
             (let ((s (find-symbol name pkg)))
               (when (and s (boundp s))
                 (setf (symbol-value s) value)))))
      (set-sym "*JSON-ENCODER*" #'encode)
      (set-sym "*JSON-DECODER*" #'decode)
      (let ((ser (find-symbol "*DATA-SERIALIZERS*" pkg))
            (des (find-symbol "*DATA-DESERIALIZERS*" pkg)))
        (when (and ser (boundp ser))
          (setf (symbol-value ser)
                (acons :json #'encode
                       (remove :json (symbol-value ser) :key #'car))))
        (when (and des (boundp des))
          (setf (symbol-value des)
                (acons :json #'decode
                       (remove :json (symbol-value des) :key #'car))))))
    t))

(defun install-serdes-json-hooks ()
  "If serdes-protocol is loaded, register a thin :json adapter that calls ENCODE/DECODE.
   Soft hook until json-protocol hard-depends on serdes (#133). Returns T when registered."
  (unless *json-backend*
    (return-from install-serdes-json-hooks nil))
  (let ((pkg (find-package :serdes-protocol)))
    (unless pkg
      (return-from install-serdes-json-hooks nil))
    (let ((register (find-symbol "REGISTER-FORMAT" pkg))
          (encode-gf (find-symbol "BACKEND-ENCODE" pkg))
          (decode-gf (find-symbol "BACKEND-DECODE" pkg))
          (serdes-base (find-symbol "SERDES-BACKEND" pkg)))
      (unless (and register encode-gf decode-gf serdes-base (find-class serdes-base nil))
        (return-from install-serdes-json-hooks nil))
      (unless (find-class 'json-serdes-adapter nil)
        (eval `(defclass json-serdes-adapter (,serdes-base) ()))
        (eval
         `(progn
            (defmethod ,encode-gf ((backend json-serdes-adapter) value &key stream)
              (declare (ignore backend))
              (encode value :stream stream))
            (defmethod ,decode-gf ((backend json-serdes-adapter) source &key)
              (declare (ignore backend))
              (decode source)))))
      (funcall register :json (make-instance 'json-serdes-adapter))
      t)))
