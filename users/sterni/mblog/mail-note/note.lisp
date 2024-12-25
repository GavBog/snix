;; SPDX-License-Identifier: GPL-3.0-only
;; SPDX-FileCopyrightText: Copyright (C) 2022-2024 by sterni

(in-package :mail-note)
(declaim (optimize (safety 3)))

;;; util

(defun html-escape-stream (in out)
  "Escape characters read from stream IN and write them to
  stream OUT escaped using WHO:ESCAPE-STRING-MINIMAL."
  (let ((buf (make-string *general-buffer-size*)))
    (loop for len = (read-sequence buf in)
          while (> len 0)
          do (write-string (who:escape-string-minimal (subseq buf 0 len)) out))))

(defun cid-header-value (cid)
  "Takes a Content-ID as present in Mail Notes' <object> tags and properly
  surrounds them with angle brackets for a MIME header"
  (concatenate 'string "<" cid ">"))

(defun find-mime-message-date (message)
  (when-let ((date-string (car (mime:mime-message-header-values "Date" message))))
    (date-time-parser:parse-date-time date-string)))

;;; main implementation

(defun mail-note-mime-subtype-p (x)
  (member x '("plain" "html") :test #'string-equal))

(deftype mail-note-mime-subtype ()
  '(satisfies mail-note-mime-subtype-p))

(defclass mail-note (mime:mime-message)
  ((text-part
    :type mime:mime-text
    :initarg :text-part
    :reader mail-note-text-part)
   (subject
    :type string
    :initarg :subject
    :reader mail-note-subject)
   (uuid
    :type string
    :initarg :uuid
    :reader mail-note-uuid)
   (time
    :type integer
    :initarg :time
    :reader mail-note-time)
   (mime-subtype
    :type mail-note-mime-subtype
    :initarg :mime-subtype
    :reader mail-note-mime-subtype))
  (:documentation
   "Representation of a Mail Note, e.g. created using Apple's Notes App via the IMAP backend"))

(defun mail-note-p (msg)
  "Checks X-Uniform-Type-Identifier of a MIME:MIME-MESSAGE
  to determine if a given mime message claims to be an (Apple) Mail Note."
  (when-let (uniform-id (car (mime:mime-message-header-values
                              "X-Uniform-Type-Identifier"
                              msg)))
    (string-equal uniform-id "com.apple.mail-note")))

(defun make-mail-note (msg)
  (check-type msg mime-message)

  (unless (mail-note-p msg)
    (error "Passed message is not a Mail Note according to headers"))

  (let ((text-part (mime:find-mime-text-part msg))
        (subject (car (mime:mime-message-header-values "Subject" msg :decode t)))
        (uuid (when-let ((val (car (mime:mime-message-header-values
                                    "X-Universally-Unique-Identifier"
                                    msg))))
                (string-downcase val)))
        (time (find-mime-message-date msg)))
    ;; The idea here is that we don't need to check a lot manually, instead
    ;; the type annotation are going to do this for us (with sufficient safety?)
    (change-class msg 'mail-note
                  :text-part text-part
                  :subject subject
                  :uuid uuid
                  :time time
                  :mime-subtype (mime:mime-subtype text-part))))

(defgeneric mail-note-html-fragment (note out)
  (:documentation
   "Takes an MAIL-NOTE and writes its text content as HTML to
   the OUT stream. The <object> tags are resolved to <img> which
   refer to the respective attachment's filename as a relative path,
   but extraction of the attachments must be done separately. The
   surrounding <html> and <body> tags are stripped and <head>
   discarded completely, so only a fragment which can be included
   in custom templates remains."))

(defmethod mail-note-html-fragment ((note mail-note) (out stream))
  (let ((text (mail-note-text-part note)))
    (cond
      ;; notemap creates text/plain notes we need to handle properly.
      ;; Additionally we *could* check X-Mailer which notemap sets
      ((string-equal (mail-note-mime-subtype note) "plain")
       (html-escape-stream (mime:mime-body-stream text) out))
      ;; Notes.app creates text/html parts
      ((string-equal (mail-note-mime-subtype note) "html")
       (closure-html:parse
        (mime:mime-body-stream text)
        (make-instance
         'mail-note-transformer
         :cid-lookup
         (lambda (cid)
           (when-let* ((part (mime:find-mime-part-by-id note (cid-header-value cid)))
                       (file (mime:mime-part-file-name part)))
             file))
         :next-handler
         (closure-html:make-character-stream-sink out))))
      (t (error "Internal error: unexpected MIME subtype")))))
