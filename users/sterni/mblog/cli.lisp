;; SPDX-License-Identifier: GPL-3.0-only
;; SPDX-FileCopyrightText: Copyright (C) 2022-2024 by sterni

(in-package :cli)
(declaim (optimize (safety 3)))

;; TODO(sterni): nicer messages for various errors signaled?

(defun partition-by (f seq)
  "Split SEQ into two lists, returned as multiple values. The first list
  contains all elements for which F returns T, the second one the remaining
  elements."
  (loop for x in seq
        if (funcall f x)
          collecting x into yes
        else
          collecting x into no
        finally (return (values yes no))))

(defparameter +help+ '(("mnote-html" . "FILE [FILE [ ... ]]")
                       ("mblog"      . "MAILDIR OUT")))

(defun mnote-html (name flags &rest args)
  "Convert all note mime messages given as ARGS to HTML fragments."
  (declare (ignore name flags))
  (loop for arg in args
        do (mail-note-html-fragment
            (make-mail-note (mime:mime-message (pathname arg)))
            *standard-output*)))

(defun mblog (name flags maildir outdir)
  "Read a MAILDIR and build an mblog in OUTDIR "
  (declare (ignore name flags))
  (build-mblog (pathname maildir) (pathname outdir)))

(defun display-help (name flags &rest args)
  "Print help message for current executable."
  (declare (ignore args flags))
  (format *error-output* "Usage: ~A ~A~%"
          name
          (or (cdr (assoc name +help+ :test #'string=))
              (concatenate 'string "Unknown executable: " name))))

(defun usage-error (name flags &rest args)
  "Print help and exit with a non-zero exit code."
  (format *error-output* "~A: usage error~%" name)
  (display-help name args flags)
  (uiop:quit 100))

(defun main ()
  "Dispatch to correct main function based on arguments and UIOP:ARGV0."
  (config:init-from-env)
  (multiple-value-bind (flags args)
      (partition-by (lambda (x) (starts-with #\- x))
                    (uiop:command-line-arguments))

    (let ((prog-name (pathname-name (pathname (uiop:argv0))))
          (help-requested-p (find-if (lambda (x)
                                       (member x '("-h" "--help" "--usage")
                                               :test #'string=))
                                     flags)))
      (apply
       (if help-requested-p
           #'display-help
           (cond
             ((and (string= prog-name "mnote-html")
                   (null flags))
              #'mnote-html)
             ((and (string= prog-name "mblog")
                   (null flags)
                   (= 2 (length args)))
              #'mblog)
             (t #'usage-error)))
       (append (list prog-name flags)
               args)))))
