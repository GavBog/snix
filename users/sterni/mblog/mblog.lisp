;; SPDX-License-Identifier: GPL-3.0-only
;; SPDX-FileCopyrightText: Copyright (C) 2022-2024 by sterni
;; SPDX-FileCopyrightText: Copyright (C) 2006-2010 by Walter C. Pelissero

(in-package :mblog)

;; util

;; Taken from SCLF, written by Walter C. Pelissero
(defun pathname-as-directory (pathname)
  "Converts PATHNAME to directory form and return it."
  (setf pathname (pathname pathname))
  (if (pathname-name pathname)
      (make-pathname :directory (append (or (pathname-directory pathname)
                                            '(:relative))
                                        (list (file-namestring pathname)))
                     :name nil
                     :type nil
                     :defaults pathname)
      pathname))

(defmacro with-overwrite-file ((&rest args) &body body)
  "Like WITH-OPEN-FILE, but creates/supersedes the given file for writing."
  `(with-open-file (,@args :direction :output
                           :if-exists :supersede
                           :if-does-not-exist :create)
     ,@body))

;; CSS

(defvar *style* "
header, main {
  width: 100%;
  max-width: 800px;
}

main img {
  max-width: 100%;
}

a:link, a:visited {
  color: blue;
}
")

;; Templating

(eval-when (:compile-toplevel :load-toplevel)
  (setf (who:html-mode) :html5))

(defmacro render-page ((stream title &key root) &body body)
  "Surround BODY with standard mblog document skeleton and render it to STREAM
  using CL-WHO. If :ROOT is T, assume that the page is the top level index page.
  Otherwise it is assumed to be one level below the index page."
  `(who:with-html-output (,stream nil :prologue t)
    (:html
     (:head
      (:meta :charset "utf-8")
      (:meta :viewport "width=device-width")
      (:title (who:esc ,title))
      (:link :rel "stylesheet"
             :type "text/css"
             :href ,(concatenate 'string (if root "" "../") "style.css")))
     (:body
      (:header
       (:nav
        (:a :href ,(who:escape-string (if root "" "..")) "index")))
      (:main ,@body)))))

;; Build Logic

(defun build-note-page (note note-dir)
  "Convert NOTE to HTML and write it to index.html in NOTE-DIR alongside any
  extra attachments NOTE contains."
  (with-overwrite-file (html-stream (merge-pathnames "index.html" note-dir))
    (render-page (html-stream (mail-note-subject note))
      (:article
       (mail-note-html-fragment note html-stream))))

  (mime:do-parts (part note)
    (unless (string= (mime:mime-id part)
                     (mime:mime-id (mail-note-text-part note)))
      (let ((attachment-in (mime:mime-body-stream part))
            (attachment-dst (merge-pathnames
                             (mime:mime-part-file-name part)
                             note-dir)))

        (format *error-output* "Writing attachment ~A~%" attachment-dst)

        (with-overwrite-file (attachment-out attachment-dst
                              :element-type
                              (stream-element-type attachment-in))
          (redirect-stream attachment-in attachment-out
                           :buffer-size *general-buffer-size*)))))

  (values))

(defun build-index-page (notes-list destination)
  "Write an overview page linking all notes in NOTE-LIST in the given order to
  DESTINATION. The notes are assumed to be in a sibling directory named like the
  each note's UUID."
  (with-overwrite-file (listing-stream destination)
    (render-page (listing-stream "mblog" :root t)
      (:h1 "mblog")
      (:table
       (dolist (note notes-list)
         (who:htm
          (:tr
           (:td (:a :href (who:escape-string (mail-note-uuid note))
                    (who:esc (mail-note-subject note))))
           (:td (who:esc
                 (klatre:format-dottime
                  (universal-to-timestamp (mail-note-time note)))))))))))
  (values))

(defun build-mblog (notes-dir html-dir)
  "Take MIME messages from maildir NOTES-DIR and build a complete mblog in HTML-DIR."
  (setf notes-dir (pathname-as-directory notes-dir))
  (setf html-dir (pathname-as-directory html-dir))

  ;; TODO(sterni): avoid rewriting if nothing was updated
  ;; TODO(sterni): clean up deleted things
  ;; TODO(sterni): atom feed

  (let ((all-notes '()))
    (dolist (message-path (maildir:list notes-dir))
      (let* ((note (make-mail-note (mime:mime-message message-path)))
             (note-dir  (merge-pathnames (make-pathname
                                          :directory
                                          `(:relative ,(mail-note-uuid note)))
                                         html-dir)))

        (format *error-output* "Writing note message ~A to ~A~%"
                message-path note-dir)
        (ensure-directories-exist note-dir)
        (build-note-page note note-dir)
        (push note all-notes)))

    ;; reverse sort the entries by time for the index page
    (setf all-notes (sort all-notes #'> :key #'mail-note-time))

    (build-index-page all-notes (merge-pathnames "index.html" html-dir))

    (with-overwrite-file (css-stream (merge-pathnames "style.css" html-dir))
      (write-string *style* css-stream))

    (values)))
