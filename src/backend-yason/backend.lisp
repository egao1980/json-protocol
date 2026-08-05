(in-package #:json-backend-yason)

(defclass yason-backend (json-backend) ())

(defun make-yason-backend ()
  (make-instance 'yason-backend))

(defun use-yason-backend ()
  (setf *json-backend* (make-yason-backend)))

(defun %encode-value (value stream)
  (cond
    ((eq value :null)
     (write-string "null" stream))
    ((null value)
     (write-string "false" stream))
    ((eq value t)
     (write-string "true" stream))
    ((hash-table-p value)
     (yason:encode value stream))
    ((and (consp value) (every #'consp value)
          (every (lambda (c) (or (stringp (car c)) (symbolp (car c)))) value))
     (let ((yason:*symbol-key-encoder* #'yason:encode-symbol-as-lowercase))
       (yason:encode-alist value stream)))
    (t
     (let ((yason:*symbol-key-encoder* #'yason:encode-symbol-as-lowercase))
       (yason:encode value stream)))))

(defmethod backend-encode ((backend yason-backend) value &key stream false-nil)
  (declare (ignore false-nil))
  (handler-case
      (if stream
          (progn (%encode-value value stream) (values))
          (with-output-to-string (out)
            (%encode-value value out)))
    (error (e)
      (error 'json-encode-error
             :message (format nil "yason encode failed: ~a" e)))))

(defun %from-yason (value)
  (cond
    ((eq value :null) :null)
    ((eq value 'null) :null)
    ((null value) nil) ; JSON false — before LISTP (NIL is a list)
    ((hash-table-p value)
     (let ((out (make-hash-table :test #'equal)))
       (maphash (lambda (k v) (setf (gethash k out) (%from-yason v))) value)
       out))
    ((vectorp value)
     (map 'vector #'%from-yason value))
    ((consp value)
     ;; yason may return lists for arrays depending on options
     (map 'vector #'%from-yason value))
    (t value)))

(defmethod backend-decode ((backend yason-backend) source &key)
  (let ((*read-default-float-format* 'double-float)
        (text (etypecase source
                (string source)
                ((vector (unsigned-byte 8))
                 (babel:octets-to-string source :encoding :utf-8))
                (stream
                 (with-output-to-string (o)
                   (loop for c = (read-char source nil nil)
                         while c do (write-char c o)))))))
    (handler-case
        (%from-yason
         (yason:parse text
                      :object-as :hash-table
                      :json-arrays-as-vectors t
                      :json-nulls-as-keyword t))
      (error (e)
        (error 'json-parse-error
               :message (format nil "yason parse failed: ~a" e))))))
