(in-package #:json-protocol/tests)

;;; #27: a backend that calls new json-protocol API must say so in its .asd,
;;; or cl-repo can pair it with an older json-protocol already installed.

(defun declared-minimum (system dependency)
  "The (:version DEPENDENCY \"x.y.z\") minimum SYSTEM declares, or NIL."
  (loop for dep in (asdf:system-depends-on (asdf:find-system system))
        when (and (consp dep) (eq (first dep) :version)
                  (string= (second dep) dependency))
          return (third dep)))

(deftest backends-pin-minimum-dependencies
  ;; check-decode-limits, *json-max-depth*: json-protocol 0.2.3.
  ;; encoding-protocol:encode/decode default to UTF-8 since 0.2.0.
  ;; serdes event-parser GFs (jzon events.lisp): serdes-protocol 0.2.0.
  (dolist (case '(("json-backend-jzon" "json-protocol" "0.2.3")
                  ("json-backend-jzon" "encoding-protocol" "0.2.0")
                  ("json-backend-jzon" "serdes-protocol" "0.2.0")
                  ("json-backend-yason" "json-protocol" "0.2.3")
                  ("json-backend-yason" "encoding-protocol" "0.2.0")
                  ("json-protocol" "encoding-protocol" "0.2.0")))
    (destructuring-bind (system dependency needed) case
      (let ((declared (declared-minimum system dependency)))
        (ok (and declared (uiop:version<= needed declared))
            (format nil "~A pins ~A >= ~A (declared ~S)"
                    system dependency needed declared))))))

(deftest loaded-versions-satisfy-pins
  (dolist (system '("json-backend-jzon" "json-backend-yason" "json-protocol"))
    (dolist (dep (asdf:system-depends-on (asdf:find-system system)))
      (when (and (consp dep) (eq (first dep) :version))
        (ok (asdf:version-satisfies (asdf:find-system (second dep)) (third dep))
            (format nil "~A: loaded ~A satisfies ~A" system (second dep) (third dep)))))))
