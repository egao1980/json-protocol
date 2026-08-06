(in-package #:json-protocol)

;;;; Hard serdes-protocol implementor (:json).

(defclass json-serdes-backend (serdes-protocol:serdes-backend) ()
  (:documentation "serdes backend that delegates to *JSON-BACKEND*."))

(defun make-json-serdes-backend ()
  (make-instance 'json-serdes-backend))

(defmethod serdes-protocol:backend-encode ((backend json-serdes-backend) value &key stream)
  (declare (ignore backend))
  (encode value :stream stream))

(defmethod serdes-protocol:backend-decode ((backend json-serdes-backend) source &key)
  (declare (ignore backend))
  (decode source))

(defun use-json-serdes-backend ()
  "Register and select the JSON serdes backend. Returns the backend."
  (let ((backend (make-json-serdes-backend)))
    (serdes-protocol:register-format :json backend)
    (setf serdes-protocol:*serdes-format* :json
          serdes-protocol:*serdes-backend* backend)
    backend))

(defun install-serdes-json-hooks ()
  "Register :json with serdes-protocol when *JSON-BACKEND* is bound.
   Kept for call-site compat (jzon/yason use-*-backend)."
  (unless *json-backend*
    (return-from install-serdes-json-hooks nil))
  (use-json-serdes-backend)
  t)
