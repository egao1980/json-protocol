(in-package #:json-protocol/tests)

;;;; Backend conformance: encoding is deterministic and every backend must
;;;; produce the same bytes (see ENCODE). Alists keep their order (first
;;;; duplicate wins, nested alists too); hash-tables encode in STRING< key
;;;; order, never MAPHASH order. Plists are not objects in json-protocol (a
;;;; plist is a list, so it encodes as an array) and are not covered here.

(defun %use-backend (name)
  (ecase name
    (:jzon (json-backend-jzon:use-jzon-backend))
    (:yason (json-backend-yason:use-yason-backend))))

(defmacro with-backend ((name) &body body)
  `(unwind-protect (progn (%use-backend ,name) ,@body)
     (json-backend-jzon:use-jzon-backend)))

(defun %long-alist (n)
  "N members k<i> in descending order, with K0 first moved to the middle:
far from any sorted or insertion-hash order."
  (let ((keys (loop for i from (1- n) downto 0 collect i)))
    (setf keys (append (subseq keys (floor n 2)) (subseq keys 0 (floor n 2))))
    (mapcar (lambda (i) (cons (format nil "k~D" i) i)) keys)))

(defun %expected-object (alist)
  (format nil "{~{~A~^,~}}"
          (mapcar (lambda (c) (format nil "\"~A\":~D" (car c) (cdr c))) alist)))

(deftest-parametrize alist-order-flat
    ((backend) :ids ("jzon" "yason") (:jzon) (:yason))
  (with-backend (backend)
    (ok (string= "{\"z\":1,\"a\":2,\"m\":3}"
                 (encode '(("z" . 1) ("a" . 2) ("m" . 3)))))
    (ok (string= "{\"zeta\":1,\"alpha\":2,\"mid-key\":3}"
                 (encode '((:zeta . 1) (:alpha . 2) (:mid-key . 3)))))
    (ok (string= "{\"z\":1,\"a\":2}"
                 (with-output-to-string (s)
                   (encode '(("z" . 1) ("a" . 2)) :stream s))))))

(deftest-parametrize alist-order-nested
    ((backend) :ids ("jzon" "yason") (:jzon) (:yason))
  (with-backend (backend)
    (ok (string= (concatenate 'string
                              "{\"outer\":{\"z\":1,\"a\":null},"
                              "\"list\":[{\"q\":true,\"b\":false}],"
                              "\"arr\":[1,2],"
                              "\"deep\":{\"y\":{\"x\":{\"w\":\"v\"}}}}")
                 (encode `(("outer" . (("z" . 1) ("a" . :null)))
                           ("list" . #((("q" . t) ("b" . nil))))
                           ("arr" 1 2)
                           ("deep" . (("y" . (("x" . (("w" . "v")))))))))))
    (ok (string= "[{\"b\":1},{\"a\":2}]"
                 (encode '((("b" . 1)) (("a" . 2))))))))

(deftest-parametrize alist-duplicate-keys
    ((backend) :ids ("jzon" "yason") (:jzon) (:yason))
  (with-backend (backend)
    (ok (string= "{\"k\":1,\"j\":2}"
                 (encode '(("k" . 1) ("j" . 2) ("k" . 3)))))
    ;; :a and "a" name the same member.
    (ok (string= "{\"a\":1}" (encode '(("a" . 1) (:a . 2)))))))

(deftest-parametrize alist-order-long
    ((backend n) :ids ("jzon-60" "yason-60" "jzon-500" "yason-500")
     (:jzon 60) (:yason 60) (:jzon 500) (:yason 500))
  (with-backend (backend)
    (let* ((alist (%long-alist n))
           (json (encode alist)))
      (ok (string= (%expected-object alist) json))
      (let ((back (decode json)))
        (ok (= n (hash-table-count back)))
        (ok (every (lambda (c) (eql (cdr c) (gethash (car c) back))) alist))))))

(deftest-parametrize hash-table-still-encodes
    ((backend) :ids ("jzon" "yason") (:jzon) (:yason))
  (with-backend (backend)
    (let ((ht (make-hash-table :test #'equal)))
      (setf (gethash "only" ht) '(("z" . 1) ("a" . 2)))
      (ok (string= "{\"only\":{\"z\":1,\"a\":2}}" (encode ht))))
    (ok (string= "{}" (encode (make-hash-table :test #'equal))))
    (ok (string= "[]" (encode #())))))

(defun %maphash-keys (table)
  (let ((keys '()))
    (maphash (lambda (k v) (declare (ignore v)) (push k keys)) table)
    (nreverse keys)))

(defun %table-inserted (keys)
  (let ((table (make-hash-table :test #'equal)))
    (dolist (key keys table)
      (setf (gethash key table) (parse-integer key :start 1)))))

(defun %unsorted-table (n)
  "Hash-table of N keys k<i> whose MAPHASH order is not STRING< order.
Tries reverse-sorted insertion, then sorted, then a rotation, since the
implementation decides iteration order."
  (let* ((sorted (sort (loop for i below n collect (format nil "k~D" i))
                       #'string<))
         (half (floor n 2)))
    (dolist (keys (list (reverse sorted)
                        sorted
                        (append (subseq sorted half) (subseq sorted 0 half)))
                  (%table-inserted (reverse sorted)))
      (let ((table (%table-inserted keys)))
        (unless (equal sorted (%maphash-keys table))
          (return table))))))

(deftest-parametrize hash-table-sorted-keys
    ((backend n) :ids ("jzon-3" "yason-3" "jzon-60" "yason-60" "jzon-500" "yason-500")
     (:jzon 3) (:yason 3) (:jzon 60) (:yason 60) (:jzon 500) (:yason 500))
  (with-backend (backend)
    (let* ((table (%unsorted-table n))
           (sorted (sort (copy-list (%maphash-keys table)) #'string<)))
      ;; Precondition: iteration order is not already sorted, else the test
      ;; would prove nothing on this implementation.
      (ok (not (equal sorted (%maphash-keys table))))
      (ok (string= (%expected-object
                    (mapcar (lambda (k) (cons k (gethash k table))) sorted))
                   (encode table))))))

(deftest-parametrize hash-table-sorted-mixed
    ((backend) :ids ("jzon" "yason") (:jzon) (:yason))
  (with-backend (backend)
    (let ((table (make-hash-table :test #'equal))
          (inner (make-hash-table :test #'equal)))
      (setf (gethash "b" inner) 2 (gethash "a" inner) 1)
      (setf (gethash :zeta table) inner
            (gethash "Mid" table) '(("y" . 1) ("x" . 2))
            (gethash "alpha" table) #(3))
      ;; "Mid" < "alpha" < "zeta" by STRING< (uppercase sorts first);
      ;; the alist value keeps its own order.
      (ok (string= "{\"Mid\":{\"y\":1,\"x\":2},\"alpha\":[3],\"zeta\":{\"a\":1,\"b\":2}}"
                   (encode table)))
      ;; Same bytes on a second encode, and inside an alist.
      (ok (string= (encode table) (encode table)))
      (ok (string= "{\"h\":{\"a\":1,\"b\":2}}" (encode `(("h" . ,inner))))))
    (let ((clash (make-hash-table :test #'equal)))
      (setf (gethash "a" clash) 1 (gethash :a clash) 2)
      (ok (signals (encode clash) 'json-encode-error)))))

;;;; Decode limits (#25). No limit by default: JSON-RPC peers (ACP, MCP)
;;;; carry whole files and tool results. jzon's own defaults (1 MiB strings,
;;;; depth 128) must not leak through. A caller-set limit signals
;;;; JSON-PARSE-LIMIT-ERROR, which is also a JSON-PARSE-ERROR.

(defun %big-string (n)
  "N characters, with a non-ASCII one and an escape so the parser does work."
  (let ((s (make-string n :initial-element #\x)))
    (setf (char s 0) (code-char #x3bb)
          (char s (floor n 2)) #\"
          (char s (1- n)) #\\)
    s))

(defun %nested (depth)
  (concatenate 'string
               (make-string depth :initial-element #\[)
               (make-string depth :initial-element #\])))

(defun %depth-of (v)
  (if (and (vectorp v) (not (stringp v)))
      (1+ (if (plusp (length v)) (%depth-of (aref v 0)) 0))
      0))

(deftest-parametrize decode-string-over-3-mib
    ((backend) :ids ("jzon" "yason") (:jzon) (:yason))
  (with-backend (backend)
    (let* ((n (+ (* 3 1024 1024) 17))
           (big (%big-string n))
           (json (encode `(("text" . ,big) (,big . 1))))
           (value (decode json)))
      (ok (= n (length (gethash "text" value))))
      (ok (string= big (gethash "text" value)))
      (ok (eql 1 (gethash big value)))
      (ok (string= big (decode (encode big))))
      (ok (string= big (decode-octets (encode-to-octets big)))))))

(deftest-parametrize decode-deep-nesting
    ((backend) :ids ("jzon" "yason") (:jzon) (:yason))
  (with-backend (backend)
    ;; Past jzon's default max-depth (128).
    (ok (= 200 (%depth-of (decode (%nested 200)))))))

(deftest-parametrize decode-caller-limits
    ((backend) :ids ("jzon" "yason") (:jzon) (:yason))
  (with-backend (backend)
    (let ((json (encode (%big-string 100))))
      (ok (string= (%big-string 100) (decode json :max-string-length 100)))
      (ok (signals (decode json :max-string-length 99) 'json-parse-limit-error))
      (ok (signals (decode json :max-string-length 99) 'json-parse-error))
      (ok (signals (decode json :max-string-length 99) 'json-limit-error))
      (handler-case (decode json :max-string-length 99)
        (json-parse-limit-error (e)
          (ok (eq :max-string-length (json-limit-error-limit e)))
          (ok (eql 99 (json-limit-error-value e)))))
      ;; Member names count too.
      (ok (signals (decode "{\"abcdef\":1}" :max-string-length 3)
                   'json-parse-limit-error))
      (ok (signals (decode "\"ab\"" :max-string-length 0)
                   'json-parse-limit-error))
      (let ((*json-max-string-length* 99))
        (ok (signals (decode json) 'json-parse-limit-error))
        (ok (signals (decode-octets (encode-to-octets (%big-string 100)))
                     'json-parse-limit-error))))
    (ok (= 5 (%depth-of (decode (%nested 5) :max-depth 5))))
    (ok (signals (decode (%nested 6) :max-depth 5) 'json-parse-limit-error))
    (handler-case (decode (%nested 6) :max-depth 5)
      (json-parse-limit-error (e)
        (ok (eq :max-depth (json-limit-error-limit e)))))
    (let ((*json-max-depth* 2))
      (ok (signals (decode "{\"a\":[[1]]}") 'json-parse-limit-error))
      (ok (hash-table-p (decode "{\"a\":[1]}"))))
    ;; Ordinary syntax errors stay plain parse errors.
    (handler-case (progn (decode "[1,") (ok nil))
      (json-parse-error (e) (ok (not (typep e 'json-limit-error)))))))
