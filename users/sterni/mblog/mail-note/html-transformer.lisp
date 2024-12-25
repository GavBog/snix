;; SPDX-License-Identifier: GPL-3.0-only
;; SPDX-FileCopyrightText: Copyright (C) 2022, 2024 by sterni

(in-package :mail-note)
(declaim (optimize (safety 3)))

;; Throw away these tags and all of their children
(defparameter +discard-tags-with-children+ '("HEAD"))
;; Only “strip” these tags and leave their content as is
(defparameter +discard-tags-only+ '("BODY" "HTML"))

;; This is basically the same as cxml's PROXY-HANDLER.
;; Couldn't be bothered to make a BROADCAST-HANDLER because I
;; only need to pass through to one handler. It accepts every
;; event and passes it on to NEXT-HANDLER. This is useful for
;; subclassing mostly where an event can be modified or passed
;; on as is via CALL-NEXT-METHOD.
(defclass hax-proxy-handler (hax:default-handler)
  ((next-handler
    :initarg :next-handler
    :accessor proxy-next-handler)))

;; Define the trivial handlers which just call themselves for NEXT-HANDLER
(macrolet ((def-proxy-handler (name (&rest args))
             `(defmethod ,name ((h hax-proxy-handler) ,@args)
                (,name (proxy-next-handler h) ,@args))))
  (def-proxy-handler hax:start-document (name p-id s-id))
  (def-proxy-handler hax:end-document ())
  (def-proxy-handler hax:start-element (name attrs))
  (def-proxy-handler hax:end-element (name))
  (def-proxy-handler hax:characters (data))
  (def-proxy-handler hax:unescaped (data))
  (def-proxy-handler hax:comment (data)))

(defclass mail-note-transformer (hax-proxy-handler)
  ((cid-lookup
    :initarg :cid-lookup
    :initform (lambda (cid) nil)
    :accessor transformer-cid-lookup)
   (discard-until
    :initarg :discard-until
    :initform nil
    :accessor transformer-discard-until)
   (depth
    :initarg :depth
    :initform 0
    :accessor transformer-depth))
  (:documentation
   "HAX handler that strips unnecessary tags from the HTML of a com.apple.mail-note
   and resolves references to attachments to IMG tags."))

;; Define the “boring” handlers which just call the next method (i. e. the next
;; handler) unless discard-until is not nil in which case the event is dropped.
(macrolet ((def-filter-handler (name (&rest args))
             `(defmethod ,name ((h mail-note-transformer) ,@args)
                (when (not (transformer-discard-until h))
                  (call-next-method)))))
  (def-filter-handler hax:start-document (name p-id s-id))
  (def-filter-handler hax:end-document ())
  (def-filter-handler hax:characters (data))
  (def-filter-handler hax:unescaped (data))
  (def-filter-handler hax:comment (data)))

(defun parse-content-id (attrlist)
  (when-let (data (find-if (lambda (x)
                             (string-equal (hax:attribute-name x) "DATA"))
                           attrlist))
    (multiple-value-bind (starts-with-cid-p suffix)
        (starts-with-subseq "cid:" (hax:attribute-value data)
                            :return-suffix t :test #'char=)
      (if starts-with-cid-p suffix data))))

(defmethod hax:start-element ((handler mail-note-transformer) name attrs)
  (with-accessors ((discard-until transformer-discard-until)
                   (next-handler proxy-next-handler)
                   (cid-lookup transformer-cid-lookup)
                   (depth transformer-depth))
      handler

    (cond
      ;; If we are discarding, any started element is dropped,
      ;; since the end-condition only is reached via END-ELEMENT.
      (discard-until nil)
      ;; If we are not discarding any outer elements, we can set
      ;; up a new discard condition if we encounter an appropriate
      ;; element.
      ((member name +discard-tags-with-children+ :test #'string-equal)
       (setf discard-until (cons name depth)))
      ;; Only drop this event, must be mirrored in END-ELEMENT to
      ;; avoid invalidly nested HTML.
      ((member name +discard-tags-only+ :test #'string-equal) nil)
      ;; If we encounter an object tag, we drop it and its contents,
      ;; but only after inspecting its attributes and emitting new
      ;; events representing an img tag which includes the respective
      ;; attachment via its filename.
      ((string-equal name "OBJECT")
       (progn
         (setf discard-until (cons "OBJECT" depth))
         ;; TODO(sterni): check type and only resolve images, raise error
         ;; otherwise. We should only encounter images anyways, since
         ;; other types are only supported for iCloud which doesn't seem
         ;; to use IMAP for sync these days.
         (when-let* ((cid (parse-content-id attrs))
                     (file (apply cid-lookup (list cid)))
                     (src (hax:make-attribute "SRC" file)))
           (hax:start-element next-handler "IMG" (list src))
           (hax:end-element next-handler "IMG"))))
      ;; In all other cases, we use HAX-PROXY-HANDLER to pass the event on.
      (t (call-next-method)))
    (setf depth (1+ depth))))

(defmethod hax:end-element ((handler mail-note-transformer) name)
  (with-accessors ((discard-until transformer-discard-until)
                   (depth transformer-depth))
      handler

    (setf depth (1- depth))
    (cond
      ;; If we are discarding and encounter the same tag again at the same
      ;; depth, we can stop, but still have to discard the current tag.
      ((and discard-until
            (string-equal (car discard-until) name)
            (= (cdr discard-until) depth))
       (setf discard-until nil))
      ;; In all other cases, we drop properly.
      (discard-until nil)
      ;; Mirrored tag stripping as in START-ELEMENT
      ((member name +discard-tags-only+ :test #'string-equal) nil)
      ;; In all other cases, we use HAX-PROXY-HANDLER to pass the event on.
      (t (call-next-method)))))
