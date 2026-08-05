(in-package #:json-backend-jzon)

(defclass jzon-backend (json-backend) ())

(defun make-jzon-backend ()
  (make-instance 'jzon-backend))

(defun use-jzon-backend ()
  "Bind *JSON-BACKEND* to a fresh jzon backend. Returns the backend."
  (prog1 (setf *json-backend* (make-jzon-backend))
    (install-serdes-json-hooks)))

(defun %to-jzon (value)
  "Map protocol :null → CL:NULL for jzon. NIL stays NIL (JSON false)."
  (cond
    ((eq value :null) 'null)
    ((null value) nil)
    ((hash-table-p value)
     (let ((out (make-hash-table :test #'equal)))
       (maphash (lambda (k v)
                  (setf (gethash (if (stringp k) k (string-downcase (string k))) out)
                        (%to-jzon v)))
                value)
       out))
    ((and (consp value) (every #'consp value)
          (every (lambda (c) (or (stringp (car c)) (symbolp (car c)))) value))
     (let ((out (make-hash-table :test #'equal)))
       (dolist (pair value out)
         (setf (gethash (if (stringp (car pair))
                            (car pair)
                            (string-downcase (string (car pair))))
                        out)
               (%to-jzon (cdr pair))))))
    ((vectorp value)
     (map 'vector #'%to-jzon value))
    ((and (consp value) (every (lambda (x) (not (consp x))) value))
     (map 'vector #'%to-jzon value))
    (t value)))

(defun %from-jzon (value)
  "Map jzon CL:NULL → :null."
  (cond
    ((eq value 'null) :null)
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
     (babel:octets-to-string source :encoding :utf-8))
    (stream
     (with-output-to-string (o)
       (loop for c = (read-char source nil nil)
             while c do (write-char c o))))))

(defmethod backend-encode ((backend jzon-backend) value &key stream false-nil)
  (declare (ignore false-nil))
  (let ((payload (%to-jzon value)))
    (handler-case
        (if stream
            (progn
              (com.inuoe.jzon:stringify payload :stream stream)
              (values))
            (com.inuoe.jzon:stringify payload))
      (error (e)
        (error 'json-encode-error
               :message (format nil "jzon encode failed: ~a" e))))))

(defmethod backend-decode ((backend jzon-backend) source &key)
  (let ((*read-default-float-format* 'double-float)
        (text (%source-string source)))
    (handler-case
        (%from-jzon (com.inuoe.jzon:parse text))
      (error (e)
        (error 'json-parse-error
               :message (format nil "jzon parse failed: ~a" e))))))

(use-jzon-backend)
