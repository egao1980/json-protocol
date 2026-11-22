(in-package #:json-protocol/tests)

;;;; Backend conformance: every backend must produce the same bytes.
;;;; Alist key order is normative (see ENCODE): alist order, first duplicate
;;;; wins, nested alists too. Plists are not objects in json-protocol (a plist
;;;; is a list, so it encodes as an array) and are not covered here.

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
