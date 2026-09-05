(in-package #:schema-protocol-toml)

(defclass toml-schema-backend (schema-format-backend) ()
  (:documentation "schema-protocol format backend for :toml (TOML Schema / .tosd)."))

(defmethod backend-emit-schema ((backend toml-schema-backend) schema
                                &key (version +tosd-version+) (as :toml) &allow-other-keys)
  (declare (ignore backend))
  (emit schema :version version :as as))

(defmethod backend-parse-schema ((backend toml-schema-backend) source
                                 &key name package &allow-other-keys)
  (declare (ignore backend))
  (apply #'compile-schema source
         (append (when name (list :name name))
                 (when package (list :package package)))))

(eval-when (:load-toplevel :execute)
  (register-schema-format :toml (make-instance 'toml-schema-backend)))

(defmethod toml-schema ((schema symbol) &key (version +tosd-version+))
  (emit schema :as :toml :version version))

(defmethod toml-schema ((schema standard-object) &key (version +tosd-version+))
  (emit schema :as :toml :version version))

(defmethod toml-schema ((schema hash-table) &key (version +tosd-version+))
  (declare (ignore version))
  (emit schema :as :toml))

(defmethod toml-schema ((schema toml-schema-document) &key (version +tosd-version+))
  (declare (ignore version))
  (emit schema :as :toml))

(defmethod toml-schema ((schema string) &key (version +tosd-version+))
  (declare (ignore version))
  schema)
