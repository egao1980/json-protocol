(in-package #:json-backend-yason)

(defclass yason-backend (json-backend) ())

(defun make-yason-backend ()
  (make-instance 'yason-backend))

(defun use-yason-backend ()
  (prog1 (setf *json-backend* (make-yason-backend))
    (install-serdes-json-hooks)))

(defun %object-key (key)
  "JSON member name for an alist or hash-table KEY: a string as is, a symbol
downcased (:foo-bar → \"foo-bar\")."
  (if (stringp key) key (string-downcase (string key))))

(defun %alist-object-p (value)
  "True when VALUE is a non-empty alist whose keys are strings or symbols."
  (and (consp value)
       (every (lambda (c)
                (and (consp c) (or (stringp (car c)) (symbolp (car c)))))
              value)))

(defun %compound-p (value)
  (and (not (stringp value))
       (or (hash-table-p value) (consp value) (vectorp value))))

(defun %scalar (value)
  "VALUE as yason encodes a JSON scalar: NIL → false, :NULL → null."
  (cond ((eq value :null) :null)
        ((null value) 'yason:false)
        (t value)))

(defun %sorted-members (table)
  "Members of hash-table TABLE as (key-string . value), sorted by STRING< on
the key strings, so output never depends on MAPHASH order. Two keys naming
the same member (:a and \"a\") signal JSON-ENCODE-ERROR."
  (let ((members '()))
    (maphash (lambda (k v) (push (cons (%object-key k) v) members)) table)
    (setf members (sort members #'string< :key #'car))
    (loop for (a b) on members
          when (and b (string= (car a) (car b)))
            do (error 'json-encode-error
                      :message (format nil "hash-table keys collide on member ~s"
                                       (car a))))
    members))

(defun %members (value fn)
  "Call FN with each (key value) of object VALUE: an alist in alist order,
first occurrence of a key wins; a hash-table in sorted key order (STRING<)."
  (if (hash-table-p value)
      (loop for (key . v) in (%sorted-members value)
            do (funcall fn key v))
      (let ((seen (make-hash-table :test #'equal)))
        (loop for (k . v) in value
              for key = (%object-key k)
              unless (gethash key seen)
                do (setf (gethash key seen) t)
                   (funcall fn key v)))))

(defun %emit-compound (value)
  "Write compound VALUE in the current yason:with-output context."
  (if (or (hash-table-p value) (%alist-object-p value))
      (yason:with-object ()
        (%members value
                  (lambda (key v)
                    (if (%compound-p v)
                        (yason:with-object-element (key) (%emit-compound v))
                        (yason:encode-object-element key (%scalar v))))))
      (yason:with-array ()
        (map nil (lambda (x)
                   (if (%compound-p x)
                       (%emit-compound x)
                       (yason:encode-array-element (%scalar x))))
             value))))

(defun %encode-value (value stream)
  "Encode VALUE to STREAM. Objects and arrays go through yason's streaming
encoder, so alist order is kept and nested alists stay objects."
  (let ((yason:*symbol-key-encoder* #'yason:encode-symbol-as-lowercase))
    (if (%compound-p value)
        (yason:with-output (stream) (%emit-compound value))
        (yason:encode (%scalar value) stream))))

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
    ((stringp value) value) ; before vectorp — strings are vectors
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
                 (encoding-protocol:decode source))
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
