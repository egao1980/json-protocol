(in-package #:json-protocol/tests)

(defun %ensure-json ()
  (json-backend-jzon:use-jzon-backend))

(defun %lisp= (a b)
  (cond
    ((and (hash-table-p a) (hash-table-p b))
     (and (= (hash-table-count a) (hash-table-count b))
          (loop for k being the hash-keys of a using (hash-value v)
                always (and (nth-value 1 (gethash k b))
                            (%lisp= v (gethash k b))))))
    ((and (vectorp a) (not (stringp a))
          (vectorp b) (not (stringp b)))
     (and (= (length a) (length b))
          (loop for i from 0 below (length a)
                always (%lisp= (aref a i) (aref b i)))))
    ((and (floatp a) (floatp b))
     (< (abs (- a b)) 1d-9))
    ((and (numberp a) (numberp b))
     (= a b))
    (t (equal a b))))

(deftest yaml-json-subset-scalars
  "Any JSON scalar is valid YAML and shares json-protocol's mapping."
  (%ensure-json)
  (dolist (s '("null" "true" "false" "0" "42" "-7" "1.5" "1e2" "\"hi\""))
    (ok (%lisp= (decode s) (yaml:decode s)) s)))

(deftest yaml-json-subset-structures
  (%ensure-json)
  (dolist (s '("[]" "{}" "[1,2,3]" "{\"a\":1}"
               "{\"a\":[1,{\"b\":null}],\"c\":false,\"d\":true}"
               " [ 1 , { \"k\" : \"v\" } ] "))
    (ok (%lisp= (decode s) (yaml:decode s)) s)))

(deftest yaml-json-encode-is-valid-yaml
  "json-protocol encode output is YAML 1.2 (JSON schema)."
  (%ensure-json)
  (let ((ht (make-hash-table :test #'equal)))
    (setf (gethash "n" ht) 1
          (gethash "z" ht) :null
          (gethash "ok" ht) t
          (gethash "no" ht) nil
          (gethash "xs" ht) #(1 2))
    (let ((json (encode ht)))
      (ok (%lisp= (decode json) (yaml:decode json))))))

(deftest yaml-style-json-matches-json-protocol
  (%ensure-json)
  (let ((ht (make-hash-table :test #'equal)))
    (setf (gethash "a" ht) 1)
    (ok (string= (encode ht) (yaml:encode ht :style :json)))))

(deftest yaml-block-roundtrip
  (let ((ht (yaml:decode (format nil "a: 1~%b: null~%c:~%  - x~%  - y~%"))))
    (ok (hash-table-p ht))
    (ok (= 1 (gethash "a" ht)))
    (ok (eq :null (gethash "b" ht)))
    (ok (equalp #("x" "y") (gethash "c" ht)))
    (ok (%lisp= ht (yaml:decode (yaml:encode ht :style :block))))))

(deftest yaml-comments
  (let ((v (yaml:decode (format nil "# head~%foo: bar # tail~%"))))
    (ok (string= "bar" (gethash "foo" v)))))

(deftest yaml-norway-is-string
  "YAML 1.2 Core — NO is not a boolean (unlike YAML 1.1)."
  (ok (string= "NO" (yaml:decode "NO")))
  (ok (string= "Yes" (yaml:decode "Yes"))))

(deftest yaml-core-bools
  (ok (eq t (yaml:decode "true")))
  (ok (eq nil (yaml:decode "false")))
  (ok (eq :null (yaml:decode "~")))
  (ok (eq :null (yaml:decode ""))))

(deftest yaml-hex-oct
  (ok (= 255 (yaml:decode "0xff")))
  (ok (= 8 (yaml:decode "0o10"))))

(deftest yaml-quoted
  (ok (string= "a:b" (yaml:decode "\"a:b\"")))
  (ok (string= "it's" (yaml:decode "'it''s'")))
  (ok (string= (format nil "a~%b") (yaml:decode "\"a\\nb\""))))

(deftest yaml-literal-block
  (ok (string= (format nil "hi~%there~%")
               (yaml:decode (format nil "|~%  hi~%  there~%")))))

(deftest yaml-nested-block
  (let ((v (yaml:decode (format nil "outer:~%  inner: 2~%"))))
    (ok (= 2 (gethash "inner" (gethash "outer" v))))))

(deftest yaml-anchors
  (let ((v (yaml:decode (format nil "a: &x 1~%b: *x~%"))))
    (ok (= 1 (gethash "a" v)))
    (ok (= 1 (gethash "b" v)))))

(deftest yaml-multi-doc
  (let ((docs (yaml:decode-all (format nil "1~%---~%2~%"))))
    (ok (equalp #(1 2) docs))))

(deftest yaml-serdes
  (let ((ht (make-hash-table :test #'equal)))
    (setf (gethash "k" ht) "v")
    (ok (%lisp= ht (serdes-protocol:decode
                    (serdes-protocol:encode ht :format :yaml)
                    :format :yaml)))))

(deftest yaml-jsonl-style-stream
  (let ((raw (with-output-to-string (o)
               (let ((out (serdes-protocol:make-output-stream o :format :yaml)))
                 (serdes-protocol:stream-encode-value out 1)
                 (serdes-protocol:stream-encode-value out 2))))
        (acc '()))
    (let ((in (serdes-protocol:make-input-stream
               (make-string-input-stream raw) :format :yaml)))
      (loop
        (let ((v (serdes-protocol:stream-decode-value in)))
          (when (eq v :eof) (return))
          (push v acc))))
    (ok (equal '(2 1) acc))))

(deftest yaml-predicates
  (ok (yaml:null-p :null))
  (ok (yaml:true-p t))
  (ok (yaml:false-p nil))
  (ok (not (yaml:false-p :null))))

(deftest yaml-extends-json
  "YAML is a CLOS extension of JSON, not a sibling and not the parent."
  (ok (subtypep 'yaml:yaml-backend 'json-backend))
  (ok (subtypep 'yaml:yaml-error 'json-error))
  (ok (subtypep 'yaml:yaml-parse-error 'json-parse-error))
  (ok (subtypep 'yaml:yaml-encode-error 'json-encode-error))
  (ok (signals (yaml:decode "[") 'json-parse-error)))
