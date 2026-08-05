(in-package #:json-protocol/tests)

(deftest null-predicates
  (ok (null-p :null))
  (ng (null-p nil))
  (ok (false-p nil))
  (ng (false-p :null))
  (ok (true-p t)))
