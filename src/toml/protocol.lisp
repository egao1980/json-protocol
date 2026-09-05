(in-package #:toml-protocol)

(defvar *toml-backend* nil
  "Current TOML backend object.")

(defclass toml-backend () ()
  (:documentation "Base class for toml-protocol backends."))

(defgeneric backend-encode (backend value &key stream)
  (:documentation "Encode VALUE as TOML."))

(defgeneric backend-decode (backend source &key)
  (:documentation "Decode SOURCE (string, octets, pathname, or character stream)."))

(defun null-p (object)
  (eq object :null))

(defun true-p (object)
  (or (eq object t) (eq object :true)))

(defun false-p (object)
  (or (eq object :false)
      (and (null object) (not (eq object :null)))))

(defun %stringish-vector-p (value)
  (and (vectorp value)
       (not (stringp value))
       (plusp (length value))
       (every #'characterp value)))

(defun %normalize (value)
  (cond
    ((hash-table-p value)
     (let ((out (make-hash-table :test #'equal)))
       (maphash (lambda (k v) (setf (gethash k out) (%normalize v))) value)
       out))
    ((stringp value) value)
    ((%stringish-vector-p value) (coerce value 'string))
    ((vectorp value) (map 'vector #'%normalize value))
    ((consp value) (mapcar #'%normalize value))
    (t value)))

(defun %source-string (source)
  (etypecase source
    (string source)
    ((vector (unsigned-byte 8))
     (encoding-protocol:decode source))
    (stream
     (with-output-to-string (o)
       (loop for c = (read-char source nil nil)
             while c do (write-char c o))))))

(defclass tomlet-backend (toml-backend) ()
  (:documentation "tomlet decode + native TOML emitter."))

(defun make-toml-backend ()
  (make-instance 'tomlet-backend))

(defmethod backend-decode ((backend tomlet-backend) source &key)
  (declare (ignore backend))
  (handler-case
      (%normalize
       (if (pathnamep source)
           (tomlet:parse-file source)
           (tomlet:parse (%source-string source))))
    (toml-error (e) (error e))
    (error (e)
      (error 'toml-parse-error
             :message (format nil "TOML parse failed: ~A" e)))))

(defmethod backend-encode ((backend tomlet-backend) value &key stream)
  (declare (ignore backend))
  (handler-case
      (if stream
          (progn (emit-toml value stream) (values))
          (with-output-to-string (o)
            (emit-toml value o)))
    (toml-error (e) (error e))
    (error (e)
      (error 'toml-encode-error
             :message (format nil "TOML encode failed: ~A" e)))))

(defun use-toml-backend ()
  (setf *toml-backend* (make-toml-backend)))

(defun encode (value &key stream)
  "Encode VALUE as TOML. VALUE is a hash-table or alist."
  (unless *toml-backend*
    (error 'toml-encode-error :message "*toml-backend* is unbound — load toml-protocol"))
  (backend-encode *toml-backend* value :stream stream))

(defun decode (source &key)
  "Decode a TOML document (string, octets, pathname, or stream)."
  (unless *toml-backend*
    (error 'toml-parse-error :message "*toml-backend* is unbound — load toml-protocol"))
  (backend-decode *toml-backend* source))

(defun encode-to-octets (value &key)
  (encoding-protocol:encode (encode value)))

(defun decode-octets (octets &key)
  (decode octets))

(eval-when (:load-toplevel :execute)
  (use-toml-backend))
