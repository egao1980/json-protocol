(in-package #:json-protocol/tests)

(defun %ensure-jzon ()
  (json-backend-jzon:use-jzon-backend))

(deftest serdes-json-roundtrip
  (%ensure-jzon)
  (let* ((ht (make-hash-table :test #'equal)))
    (setf (gethash "n" ht) 1
          (gethash "z" ht) :null)
    (let ((decoded (serdes-protocol:decode
                    (serdes-protocol:encode ht :format :json)
                    :format :json)))
      (ok (hash-table-p decoded))
      (ok (= 1 (gethash "n" decoded)))
      (ok (eq :null (gethash "z" decoded))))))

(deftest jsonl-roundtrip
  (%ensure-jzon)
  (let ((raw (with-output-to-string (o)
               (let ((out (serdes-protocol:make-output-stream o :format :json)))
                 (serdes-protocol:stream-encode-value out 1)
                 (let ((ht (make-hash-table :test #'equal)))
                   (setf (gethash "k" ht) "v")
                   (serdes-protocol:stream-encode-value out ht)))))
        (acc '()))
    (serdes-protocol:map-jsonl (lambda (v) (push v acc)) raw :format :json)
    (ok (= 2 (length acc)))
    (ok (hash-table-p (first acc)))
    (ok (string= "v" (gethash "k" (first acc))))
    (ok (= 1 (second acc)))))

(deftest event-parser-array
  (%ensure-jzon)
  (let ((events '())
        (parser (serdes-protocol:make-event-parser "[1,null,true]" :format :json)))
    (loop
      (multiple-value-bind (ev val) (serdes-protocol:parse-next-event parser)
        (unless ev (return))
        (push (list ev val) events)))
    (setf events (nreverse events))
    (ok (eq :begin-array (first (first events))))
    (ok (eq :value (first (second events))))
    (ok (= 1 (second (second events))))
    (ok (eq :value (first (third events))))
    (ok (eq :null (second (third events))))
    (ok (eq :end-array (first (car (last events)))))))
