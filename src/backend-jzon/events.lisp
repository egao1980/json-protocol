(in-package #:json-backend-jzon)

;;;; Event / pull parser via jzon (serdes-protocol GFs).

(defclass json-event-parser (serdes-protocol:serdes-event-parser)
  ((jzon :initarg :jzon :reader %jzon-parser)))

(defun %event-source (source)
  "Normalize SOURCE for jzon:make-parser."
  (etypecase source
    (stream source)
    (pathname source)
    (string source)
    ((vector (unsigned-byte 8))
     (babel:octets-to-string source :encoding :utf-8))))

(defmethod serdes-protocol:backend-make-event-parser
    ((backend json-serdes-backend) source
     &key max-depth max-string-length)
  (declare (ignore backend max-depth))
  (let* ((in (%event-source source))
         (parser (if max-string-length
                     (com.inuoe.jzon:make-parser in :max-string-length max-string-length)
                     (com.inuoe.jzon:make-parser in))))
    (make-instance 'json-event-parser
                   :backend (serdes-protocol:find-backend :json)
                   :source source
                   :jzon parser)))

(defmethod serdes-protocol:parse-next-event ((parser json-event-parser))
  (multiple-value-bind (event value)
      (com.inuoe.jzon:parse-next (%jzon-parser parser))
    (case event
      ((nil) (values nil nil))
      (:value (values :value (%from-jzon value)))
      (:object-key (values :object-key value))
      (otherwise (values event value)))))

(defmethod serdes-protocol:parse-next-element ((parser json-event-parser) &key)
  (%from-jzon
   (com.inuoe.jzon:parse-next-element (%jzon-parser parser)
                                      :eof-error-p nil
                                      :eof-value :eof)))
