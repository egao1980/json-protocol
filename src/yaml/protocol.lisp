(in-package #:yaml-protocol)

;;; Same predicates as json-protocol (shared mapping).

(defvar *yaml-backend* nil
  "Current YAML backend object.")

(defclass yaml-backend () ()
  (:documentation "Base class for yaml-protocol backends."))

(defgeneric backend-encode (backend value &key stream style)
  (:documentation "Encode VALUE as YAML. STYLE is :block or :json."))

(defgeneric backend-decode (backend source &key all)
  (:documentation "Decode SOURCE (string, octets, or character stream).
   ALL true → vector of documents."))

(defun null-p (object)
  (eq object :null))

(defun true-p (object)
  (eq object t))

(defun false-p (object)
  (and (null object) (not (eq object :null))))

(defun %source-string (source)
  (etypecase source
    (string source)
    ((vector (unsigned-byte 8))
     (babel:octets-to-string source :encoding :utf-8))
    (stream
     (with-output-to-string (o)
       (loop for c = (read-char source nil nil)
             while c do (write-char c o))))))

(defclass native-yaml-backend (yaml-backend) ()
  (:documentation "Built-in YAML 1.2 parser/emitter (JSON-compatible Core schema)."))

(defun make-yaml-backend ()
  (make-instance 'native-yaml-backend))

(defmethod backend-decode ((backend native-yaml-backend) source &key all)
  (declare (ignore backend))
  (handler-case
      (parse-yaml (%source-string source) :all all)
    (yaml-error (e) (error e))
    (error (e)
      (error 'yaml-parse-error
             :message (format nil "YAML parse failed: ~A" e)))))

(defmethod backend-encode ((backend native-yaml-backend) value &key stream style)
  (declare (ignore backend))
  (let ((style (or style :block)))
    (ecase style
      (:json
       (unless json-protocol:*json-backend*
         (error 'yaml-encode-error
                :message ":style :json needs a json-protocol backend (load json-backend-jzon)"))
       (json-protocol:encode value :stream stream))
      (:block
       (handler-case
           (if stream
               (progn (emit-block value stream) (values))
               (with-output-to-string (o)
                 (emit-block value o)))
         (yaml-error (e) (error e))
         (error (e)
           (error 'yaml-encode-error
                  :message (format nil "YAML encode failed: ~A" e))))))))

(defun use-yaml-backend ()
  (setf *yaml-backend* (make-yaml-backend)))

(defun encode (value &key stream (style :block))
  "Encode VALUE as YAML. STYLE :block (default) or :json (valid YAML 1.2)."
  (unless *yaml-backend*
    (error 'yaml-encode-error :message "*yaml-backend* is unbound — load yaml-protocol"))
  (backend-encode *yaml-backend* value :stream stream :style style))

(defun decode (source &key)
  "Decode the first YAML 1.2 document. Valid JSON is valid YAML."
  (unless *yaml-backend*
    (error 'yaml-parse-error :message "*yaml-backend* is unbound — load yaml-protocol"))
  (backend-decode *yaml-backend* source))

(defun decode-all (source &key)
  "Decode every YAML document in SOURCE → vector."
  (unless *yaml-backend*
    (error 'yaml-parse-error :message "*yaml-backend* is unbound — load yaml-protocol"))
  (backend-decode *yaml-backend* source :all t))

(defun encode-to-octets (value &key (style :block))
  (babel:string-to-octets (encode value :style style) :encoding :utf-8))

(defun decode-octets (octets &key)
  (decode octets))

(eval-when (:load-toplevel :execute)
  (use-yaml-backend))
