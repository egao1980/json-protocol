(in-package #:toml-protocol)

(defclass toml-serdes-backend (serdes-protocol:serdes-backend) ()
  (:documentation "serdes backend that delegates to *TOML-BACKEND*."))

(defun make-toml-serdes-backend ()
  (make-instance 'toml-serdes-backend))

(defmethod serdes-protocol:backend-encode ((backend toml-serdes-backend) value &key stream)
  (declare (ignore backend))
  (encode value :stream stream))

(defmethod serdes-protocol:backend-decode ((backend toml-serdes-backend) source &key)
  (declare (ignore backend))
  (decode source))

(defun use-toml-serdes-backend ()
  (let ((backend (make-toml-serdes-backend)))
    (serdes-protocol:register-format :toml backend)
    (setf serdes-protocol:*serdes-format* :toml
          serdes-protocol:*serdes-backend* backend)
    backend))

(eval-when (:load-toplevel :execute)
  (use-toml-serdes-backend))
