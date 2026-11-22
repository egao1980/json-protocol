(in-package #:json-backend-jzon)

(defclass jzon-backend (json-backend) ())

(defun make-jzon-backend ()
  (make-instance 'jzon-backend))

(defun use-jzon-backend ()
  "Bind *JSON-BACKEND* to a fresh jzon backend. Returns the backend."
  (prog1 (setf *json-backend* (make-jzon-backend))
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

(defun %write (writer value)
  "Write VALUE with jzon WRITER per the json-protocol mapping. An alist is
written as an object in alist order (first occurrence of a key wins); a
hash-table in sorted key order (STRING<). Nothing goes through an intermediate hash-table."
  (cond
    ((eq value :null) (com.inuoe.jzon:write-value writer 'null))
    ((null value) (com.inuoe.jzon:write-value writer nil))
    ((stringp value) (com.inuoe.jzon:write-value writer value)) ; strings are vectors
    ((hash-table-p value)
     (com.inuoe.jzon:with-object writer
       (loop for (key . v) in (%sorted-members value)
             do (com.inuoe.jzon:write-key writer key)
                (%write writer v))))
    ((%alist-object-p value)
     (let ((seen (make-hash-table :test #'equal)))
       (com.inuoe.jzon:with-object writer
         (loop for (k . v) in value
               for key = (%object-key k)
               unless (gethash key seen)
                 do (setf (gethash key seen) t)
                    (com.inuoe.jzon:write-key writer key)
                    (%write writer v)))))
    ((or (consp value) (vectorp value))
     (com.inuoe.jzon:with-array writer
       (map nil (lambda (x) (%write writer x)) value)))
    (t (com.inuoe.jzon:write-value writer value))))

(defun %stringify (value stream)
  (com.inuoe.jzon:with-writer (writer :stream stream)
    (%write writer value)))

(defun %from-jzon (value)
  "Map jzon CL:NULL → :null."
  (cond
    ((eq value 'null) :null)
    ((stringp value) value)
    ((hash-table-p value)
     (let ((out (make-hash-table :test #'equal)))
       (maphash (lambda (k v) (setf (gethash k out) (%from-jzon v))) value)
       out))
    ((vectorp value)
     (map 'vector #'%from-jzon value))
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

(defmethod backend-encode ((backend jzon-backend) value &key stream false-nil)
  (declare (ignore false-nil))
  (handler-case
      (if stream
          (progn (%stringify value stream) (values))
          (with-output-to-string (out)
            (%stringify value out)))
    (error (e)
      (error 'json-encode-error
             :message (format nil "jzon encode failed: ~a" e)))))

(defmethod backend-decode ((backend jzon-backend) source &key)
  (let ((*read-default-float-format* 'double-float)
        (text (%source-string source)))
    (handler-case
        (%from-jzon (com.inuoe.jzon:parse text))
      (error (e)
        (error 'json-parse-error
               :message (format nil "jzon parse failed: ~a" e))))))

(use-jzon-backend)
