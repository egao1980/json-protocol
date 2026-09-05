(in-package #:json-protocol/tests)

(deftest toml-roundtrip-config-shape
  (let* ((text "
features = [\"auth\", \"cache\"]

[database]
host = \"localhost\"
port = 5432
enabled = true
")
         (ht (toml-protocol:decode text)))
    (ok (hash-table-p ht))
    (ok (equalp #("auth" "cache") (gethash "features" ht)))
    (let ((db (gethash "database" ht)))
      (ok (string= "localhost" (gethash "host" db)))
      (ok (= 5432 (gethash "port" db)))
      (ok (eq t (gethash "enabled" db))))
    (let ((again (toml-protocol:decode (toml-protocol:encode ht))))
      (ok (string= "localhost" (gethash "host" (gethash "database" again))))
      (ok (= 5432 (gethash "port" (gethash "database" again)))))))

(deftest toml-octets
  (let* ((ht (toml-protocol:decode "k = \"v\""))
         (oct (toml-protocol:encode-to-octets ht)))
    (ok (typep oct '(vector (unsigned-byte 8))))
    (ok (string= "v" (gethash "k" (toml-protocol:decode-octets oct))))))

(deftest toml-false-true
  (let ((ht (toml-protocol:decode "on = true
off = false
")))
    (ok (eq t (gethash "on" ht)))
    (ok (eq nil (gethash "off" ht)))))
