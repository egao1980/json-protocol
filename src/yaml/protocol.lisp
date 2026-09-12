(in-package #:yaml-protocol)

;;; YAML extends JSON (CLOS). Shared mapping; extra surface is :style / decode-all.
;;; A yaml-backend is a json-backend. Do not bind *json-backend* to one by
;;; default — JSON stays on jzon (RFC 8259), not the YAML parser.

(defvar *yaml-backend* nil
  "Current YAML backend object.")

(defclass yaml-backend (json-protocol:json-backend) ()
  (:documentation "YAML 1.2 backend; subclass of json-backend."))

(defgeneric backend-encode (backend value &key stream style)
  (:documentation "Encode VALUE as YAML. STYLE is :block or :json."))

(defgeneric backend-decode (backend source &key all)
  (:documentation "Decode SOURCE (string, octets, or character stream).
   ALL true → vector of documents."))

(defun null-p (object)
  (json-protocol:null-p object))

(defun true-p (object)
  (json-protocol:true-p object))

(defun false-p (object)
  (json-protocol:false-p object))

(defun %source-string (source)
  (etypecase source
    (string source)
    ((vector (unsigned-byte 8))
     (encoding-protocol:decode source))
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
  (encoding-protocol:encode (encode value :style style)))

(defun decode-octets (octets &key)
  (decode octets))

(eval-when (:load-toplevel :execute)
  (use-yaml-backend))
