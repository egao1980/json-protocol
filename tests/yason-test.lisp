(in-package #:json-protocol/tests)

(deftest yason-roundtrip-basics
  (json-backend-yason:use-yason-backend)
  (ok (string= "null" (encode :null)))
  (ok (string= "false" (encode nil)))
  (ok (string= "true" (encode t)))
  (ok (eq :null (decode "null")))
  (ok (eq nil (decode "false")))
  (let ((ht (decode "{\"a\":1,\"b\":null,\"c\":[9]}")))
    (ok (= 1 (gethash "a" ht)))
    (ok (eq :null (gethash "b" ht)))
    (ok (equalp #(9) (gethash "c" ht))))
  ;; restore default for later suites
  (json-backend-jzon:use-jzon-backend))
