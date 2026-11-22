(in-package #:json-backend-jzon)

;;;; Event / pull parser via jzon (serdes-protocol GFs).

(defclass json-event-parser (serdes-protocol:serdes-event-parser)
  ((jzon :initarg :jzon :reader %jzon-parser)
   (max-depth :initarg :max-depth :initform nil :reader %max-depth)))

(defun %event-source (source)
  "Normalize SOURCE for jzon:make-parser."
  (etypecase source
    (stream source)
    (pathname source)
    (string source)
    ((vector (unsigned-byte 8))
     (encoding-protocol:decode source))))

(defmethod serdes-protocol:backend-make-event-parser
    ((backend json-serdes-backend) source
     &key max-depth max-string-length)
  "NIL limits fall back to the json-protocol specials (NIL: none). jzon's own
defaults (1 MiB strings, depth 128) are never used (#25)."
  (declare (ignore backend))
  (let* ((max-depth (or max-depth *json-max-depth*))
         (max-string-length (or max-string-length *json-max-string-length*))
         (in (%event-source source))
         (parser (com.inuoe.jzon:make-parser
                  in :max-string-length (%jzon-max-string-length max-string-length))))
    (make-instance 'json-event-parser
                   :backend (serdes-protocol:find-backend :json)
                   :source source
                   :jzon parser
                   :max-depth (%jzon-max-depth max-depth))))

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
                                      :max-depth (%max-depth parser)
                                      :eof-error-p nil
                                      :eof-value :eof)))
