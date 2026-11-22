(in-package #:json-protocol)

;;; Normative Lisp ↔ JSON mapping (see cl-stack/docs/capabilities/json-protocol.md):
;;;   object → hash-table (equal), string keys
;;;   array  → vector
;;;   null   → :null
;;;   false  → nil    true → t
;;; Encode: nil → JSON false; :null → JSON null.
;;;
;;; Deterministic encoding (normative, every backend, every implementation):
;;; the same value always encodes to the same bytes, so output can feed
;;; content hashes, prompt-cache prefixes and golden files.
;;;   alist      → ordered input: members in alist order, nested alists too.
;;;                Keys are strings (as is) or symbols (downcased). On a
;;;                duplicate key the first occurrence wins and later ones are
;;;                dropped (ASSOC semantics).
;;;   hash-table → unordered input: members in sorted key order (STRING< on
;;;                the key strings), never MAPHASH order. Two keys that name
;;;                the same member (:a and "a") signal JSON-ENCODE-ERROR.
;;;   plist      → not an object: a plist is a list, so it encodes as an array.
;;; Output is compact: no whitespace between tokens.

(defvar *json-backend* nil
  "Current JSON backend object (satisfies BACKEND-ENCODE / BACKEND-DECODE).")

(defvar *json-max-string-length* nil
  "Longest string (key or value, in characters) DECODE accepts, or NIL for no
limit (the default). JSON-RPC peers (ACP, MCP) carry whole files and tool
results, so the protocol sets no cap; bind this to cap untrusted input.")

(defvar *json-max-depth* nil
  "Deepest array/object nesting DECODE accepts, or NIL for no limit (the
default; a backend may still have an implementation cap, jzon's is 65535).")

(defclass json-backend () ()
  (:documentation "Base class for json-protocol backends."))

(defgeneric backend-encode (backend value &key stream false-nil)
  (:documentation "Encode VALUE to JSON string, or write to STREAM when non-nil.
   FALSE-NIL is reserved; default nil means Lisp NIL → JSON false.
   Methods must write alist members in alist order (first occurrence of a
   duplicate key wins), without passing them through a hash-table, write
   hash-table members sorted by STRING< on the key strings, and emit compact
   output. See ENCODE."))

(defgeneric backend-decode (backend source &key max-string-length max-depth)
  (:documentation "Decode SOURCE (string, octet-vector, or character stream) to Lisp.
   MAX-STRING-LENGTH / MAX-DEPTH: NIL means no limit. Input past a limit
   signals JSON-PARSE-LIMIT-ERROR. A backend without native limits calls
   CHECK-DECODE-LIMITS on its result. See DECODE."))

(defun %limit-error (limit value)
  (error 'json-parse-limit-error
         :limit limit :value value
         :message (format nil "~(~a~) ~d exceeded" limit value)))

(defun check-decode-limits (value &key max-string-length max-depth)
  "Signal JSON-PARSE-LIMIT-ERROR when decoded VALUE holds a string (member
name or value) longer than MAX-STRING-LENGTH, or nests arrays/objects deeper
than MAX-DEPTH. NIL means no limit. Returns VALUE. For backends whose parser
has no limits of its own."
  (when (or max-string-length max-depth)
    (labels ((str (s)
               (when (and max-string-length (> (length s) max-string-length))
                 (%limit-error :max-string-length max-string-length)))
             (walk (v depth)
               (cond ((stringp v) (str v))
                     ((or (hash-table-p v) (vectorp v))
                      (when (and max-depth (> (1+ depth) max-depth))
                        (%limit-error :max-depth max-depth))
                      (if (hash-table-p v)
                          (maphash (lambda (k x)
                                     (when (stringp k) (str k))
                                     (walk x (1+ depth)))
                                   v)
                          (loop for x across v do (walk x (1+ depth))))))))
      (walk value 0)))
  value)

(defun null-p (object)
  (eq object :null))

(defun true-p (object)
  (eq object t))

(defun false-p (object)
  (and (null object) (not (eq object :null))))

(defun encode (value &key stream (false-nil nil))
  "Encode VALUE via *JSON-BACKEND*. Returns a string unless STREAM is given.
Encoding is deterministic on every backend and implementation: an alist
encodes as an object in alist order (first occurrence of a duplicate key
wins), nested alists included; a hash-table encodes in sorted key order
(STRING<), never MAPHASH order. Output is compact."
  (unless *json-backend*
    (error 'json-encode-error :message "*json-backend* is unbound — load json-backend-jzon"))
  (backend-encode *json-backend* value :stream stream :false-nil false-nil))

(defun decode (source &key (max-string-length *json-max-string-length*)
                          (max-depth *json-max-depth*))
  "Decode SOURCE via *JSON-BACKEND*. MAX-STRING-LENGTH and MAX-DEPTH default
to *JSON-MAX-STRING-LENGTH* and *JSON-MAX-DEPTH* (NIL: no limit); input past
either signals JSON-PARSE-LIMIT-ERROR."
  (check-type max-string-length (or null (integer 0)))
  (check-type max-depth (or null (integer 0)))
  (unless *json-backend*
    (error 'json-parse-error :message "*json-backend* is unbound — load json-backend-jzon"))
  (backend-decode *json-backend* source
                  :max-string-length max-string-length :max-depth max-depth))

(defun encode-to-octets (value &key (false-nil nil))
  "UTF-8 octets of (ENCODE VALUE)."
  (encoding-protocol:encode (encode value :false-nil false-nil)))

(defun decode-octets (octets &key (max-string-length *json-max-string-length*)
                                  (max-depth *json-max-depth*))
  "DECODE UTF-8 OCTETS."
  (decode (encoding-protocol:decode octets)
          :max-string-length max-string-length :max-depth max-depth))

(defun install-http-json-hooks ()
  "If http-protocol is loaded, bind *json-encoder* / *json-decoder* and :json serdes.
   No-op when http-protocol is absent. Returns T when hooks installed."
  (let ((pkg (find-package :http-protocol)))
    (unless pkg
      (return-from install-http-json-hooks nil))
    (flet ((set-sym (name value)
             (let ((s (find-symbol name pkg)))
               (when (and s (boundp s))
                 (setf (symbol-value s) value)))))
      (set-sym "*JSON-ENCODER*" #'encode)
      (set-sym "*JSON-DECODER*" #'decode)
      (let ((ser (find-symbol "*DATA-SERIALIZERS*" pkg))
            (des (find-symbol "*DATA-DESERIALIZERS*" pkg)))
        (when (and ser (boundp ser))
          (setf (symbol-value ser)
                (acons :json #'encode
                       (remove :json (symbol-value ser) :key #'car))))
        (when (and des (boundp des))
          (setf (symbol-value des)
                (acons :json #'decode
                       (remove :json (symbol-value des) :key #'car))))))
    t))

;;; install-serdes-json-hooks — defined in serdes.lisp (hard dep on serdes-protocol)
