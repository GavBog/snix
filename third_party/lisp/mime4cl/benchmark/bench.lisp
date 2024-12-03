(defpackage :mime4cl-bench
  (:use :common-lisp :mime4cl)
  (:export :main))

(in-package :mime4cl-bench)

;; Write to /dev/null so that I/O is less (?) of a factor
(defparameter *output-path* (pathname "/dev/null"))

(defun parse-message (path)
  (let ((msg (mime-message path)))
    ;; to prove we are doing something, print the subject
    (format t "Subject: ~A~%" (car (mime-message-header-values "Subject" msg :decode t)))
    msg))

(defun main ()
  (destructuring-bind (bench-name message-path) (uiop:command-line-arguments)
    (let ((action (intern (string-upcase bench-name) :mime4cl-bench))
          (message-path (pathname message-path)))
      (ccase action
        ((parse) (parse-message message-path))
        ((extract) (do-parts (part (parse-message message-path))
                     (format t "Content-Type: ~A~%" (mime-type-string part))
                     (let ((in (mime-body-stream part)))
                       (with-open-file (output-stream (pathname *output-path*)
                                                      :direction :output
                                                      :if-does-not-exist :create
                                                      :element-type (stream-element-type in)
                                                      :if-exists :overwrite)
                         (redirect-stream in output-stream)))))))))
