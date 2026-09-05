(in-package #:schema-protocol-toml/tests)

(deftest validate-required-and-types
  (let ((schema (%tosd :elements
                       (%ht "title" (%ht "type" "string")
                            "enabled" (%ht "type" "boolean" "optional" t)))))
    (ok (valid-instance-p schema (%ht "title" "ok")))
    (ok (valid-instance-p schema (%ht "title" "ok" "enabled" t)))
    (ng (valid-instance-p schema (%ht)))
    (ng (valid-instance-p schema (%ht "title" 1)))
    (ng (valid-instance-p schema (%ht "title" "ok" "extra" 1)))
    (ok (signals (validate-instance schema (%ht "title" 1))
                 'toml-schema-validation-error))))

(deftest validate-constraints
  (let ((schema (%tosd :elements
                       (%ht "env" (%ht "type" "string"
                                       "allowedvalues" #("dev" "prod"))
                            "retries" (%ht "type" "integer" "min" 0 "max" 10)
                            "label" (%ht "type" "string" "minlength" 2 "pattern" "^[a-z]+$")))))
    (ok (valid-instance-p schema (%ht "env" "prod" "retries" 3 "label" "ab")))
    (ng (valid-instance-p schema (%ht "env" "qa" "retries" 3 "label" "ab")))
    (ng (valid-instance-p schema (%ht "env" "prod" "retries" 11 "label" "ab")))
    (ng (valid-instance-p schema (%ht "env" "prod" "retries" 3 "label" "A")))))

(deftest validate-array-and-collection
  (let ((schema (%tosd :types
                       (%ht "server" (%ht "type" "table"
                                          "ip" (%ht "type" "string" "format" "ipv4")
                                          "role" (%ht "type" "string")))
                       :elements
                       (%ht "ports" (%ht "type" "array" "itemtype" "integer" "minlength" 1)
                            "servers" (%ht "type" "collection"
                                           "itemtype" "types.server"
                                           "minlength" 1)))))
    (ok (valid-instance-p schema
                         (%ht "ports" #(8000 8001)
                              "servers" (%ht "alpha" (%ht "ip" "10.0.0.1" "role" "frontend")))))
    (ng (valid-instance-p schema
                         (%ht "ports" #()
                              "servers" (%ht "alpha" (%ht "ip" "10.0.0.1" "role" "frontend")))))
    (ng (valid-instance-p schema
                         (%ht "ports" #(8000)
                              "servers" (%ht "alpha" (%ht "ip" "not-an-ip" "role" "frontend")))))))

(deftest validate-oneof
  (let ((schema (%tosd :elements
                       (%ht "id" (%ht "oneof" #("string" "integer"))))))
    (ok (valid-instance-p schema (%ht "id" "a")))
    (ok (valid-instance-p schema (%ht "id" 1)))
    (ng (valid-instance-p schema (%ht "id" t)))))

(deftest validate-toml-io-example
  (let ((schema (%tosd :types
                       (%ht "serverType" (%ht "type" "table"
                                              "ip" (%ht "type" "string")
                                              "role" (%ht "type" "string")))
                       :elements
                       (%ht "title" (%ht "type" "string")
                            "owner" (%ht "type" "table"
                                         "name" (%ht "type" "string")
                                         "dob" (%ht "type" "offset-date-time" "optional" t))
                            "database" (%ht "type" "table"
                                            "enabled" (%ht "type" "boolean")
                                            "ports" (%ht "type" "array" "itemtype" "integer")
                                            "data" (%ht "type" "array" "itemtype" "array" "optional" t)
                                            "temp_targets" (%ht "type" "table" "optional" t))
                            "servers" (%ht "type" "collection"
                                           "itemtype" "types.serverType"
                                           "minlength" 1)))))
    (ok (valid-instance-p
         schema
         (%ht "title" "TOML Example"
              "owner" (%ht "name" "Tom Preston-Werner")
              "database" (%ht "enabled" t "ports" #(8000 8001 8002))
              "servers" (%ht "alpha" (%ht "ip" "10.0.0.1" "role" "frontend")
                             "beta" (%ht "ip" "10.0.0.2" "role" "backend")))))))

(deftest discover-schema-taplo-and-tosd
  (multiple-value-bind (loc kind)
      (discover-schema "#:schema ./app.schema.json
title = \"x\"
")
    (ok (equal "./app.schema.json" loc))
    (ok (eq :json-schema kind)))
  (multiple-value-bind (loc kind)
      (discover-schema (%ht "$schema" "https://json.schemastore.org/foo.json"
                            "title" "x"))
    (ok (equal "https://json.schemastore.org/foo.json" loc))
    (ok (eq :json-schema kind)))
  (multiple-value-bind (loc kind)
      (discover-schema (%ht "toml-schema" (%ht "location" "config.tosd" "version" "1.0.0")
                            "title" "x"))
    (ok (equal "config.tosd" loc))
    (ok (eq :tosd kind)))
  (multiple-value-bind (loc kind)
      (discover-schema (%ht "title" "x"))
    (ok (null loc))
    (ok (null kind))))

(deftest decode-validating-tosd
  (let* ((schema (%tosd :elements (%ht "host" (%ht "type" "string"))))
         (data (decode-validating "host = \"localhost\"" :schema schema)))
    (ok (string= "localhost" (gethash "host" data))))
  (ok (signals (decode-validating "host = 1" :schema
                                  (%tosd :elements (%ht "host" (%ht "type" "string"))))
               'toml-schema-validation-error)))

(deftest decode-validating-json-schema
  (let ((js (%ht "type" "object"
                 "$schema" "http://json-schema.org/draft-07/schema#"
                 "required" #("host")
                 "properties" (%ht "host" (%ht "type" "string"))
                 "additionalProperties" nil)))
    (ok (hash-table-p (decode-validating "host = \"x\"" :schema js)))
    (ok (signals (decode-validating "host = 1" :schema js)
                 'schema-protocol-json:json-schema-validation-error))))

(deftest compile-validator-reuse
  (let ((v (compile-validator (%tosd :elements (%ht "k" (%ht "type" "string" "minlength" 2))))))
    (ok (toml-schema-validator-p v))
    (ok (valid-instance-p v (%ht "k" "ab")))
    (ng (valid-instance-p v (%ht "k" "a")))))
