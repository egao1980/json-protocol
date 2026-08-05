(in-package #:json-protocol/tests)

(deftest jzon-roundtrip-basics
  (json-backend-jzon:use-jzon-backend)
  (ok (string= "null" (encode :null)))
  (ok (string= "false" (encode nil)))
  (ok (string= "true" (encode t)))
  (ok (string= "42" (encode 42)))
  (ok (eq :null (decode "null")))
  (ok (eq nil (decode "false")))
  (ok (eq t (decode "true")))
  (let ((ht (decode "{\"a\":1,\"b\":null,\"c\":false,\"d\":[1,2]}")))
    (ok (hash-table-p ht))
    (ok (= 1 (gethash "a" ht)))
    (ok (eq :null (gethash "b" ht)))
    (ok (eq nil (gethash "c" ht)))
    (ok (equalp #(1 2) (gethash "d" ht)))))

(deftest jzon-encode-alist
  (json-backend-jzon:use-jzon-backend)
  (let* ((s (encode '(("x" . 1) ("y" . :null))))
         (ht (decode s)))
    (ok (= 1 (gethash "x" ht)))
    (ok (eq :null (gethash "y" ht)))))

(deftest jzon-octets
  (json-backend-jzon:use-jzon-backend)
  (let ((oct (encode-to-octets '(("k" . t)))))
    (ok (typep oct '(vector (unsigned-byte 8))))
    (ok (eq t (gethash "k" (decode-octets oct))))))
