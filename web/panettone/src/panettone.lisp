(in-package :panettone)
(declaim (optimize (safety 3)))

(defvar *cheddar-url* "http://localhost:4238")

(defgeneric render-markdown (markdown)
  (:documentation
   "Render the argument, or the elements of the argument, as markdown, and return
   the same structure"))

(defun request-markdown-from-cheddar (input)
  "Send the CL value INPUT encoded as JSON to cheddar's
  markdown endpoint and return the decoded response."
  (let ((s (drakma:http-request
            (concatenate 'string
                         *cheddar-url*
                         "/markdown")
            :accept "application/json"
            :method :post
            :content-type "application/json"
            :external-format-out :utf-8
            :content (json:encode-json-to-string input)
            :want-stream t)))
    (setf (flexi-streams:flexi-stream-external-format s) :utf-8)
    (cl-json:decode-json s)))

(defmethod render-markdown ((markdown string))
  (cdr (assoc :markdown
              (request-markdown-from-cheddar
               `((markdown . ,markdown))))))

(defmethod render-markdown ((markdown hash-table))
  (alist-hash-table
   (request-markdown-from-cheddar markdown)))

(defun markdownify-comment-bodies (comments)
  "Convert the bodies of the given list of comments to markdown in-place using
  Cheddar, and return nothing"
  (let ((in (make-hash-table))
        (comment-table (make-hash-table)))
    (dolist (comment comments)
      (when (typep comment 'model:issue-comment)
        (setf (gethash (id comment) in) (body comment))
        (setf (gethash (id comment) comment-table) comment)))
    (let ((res (render-markdown in)))
      (iter (for (comment-id markdown-body) in-hashtable res)
        (let ((comment-id (parse-integer (symbol-name comment-id))))
          (setf (slot-value (gethash comment-id comment-table)
                            'model:body)
                markdown-body)))))
  (values))

;;;
;;; Views
;;;

(defvar *title* "Panettone")

(eval-when (:compile-toplevel :load-toplevel)
  (setf (who:html-mode) :html5))

(defun render/nav ()
  (who:with-html-output (*standard-output*)
    (:nav
     (if (find (car (split "\\?" (hunchentoot:request-uri*) :limit 2))
               (list "/" "/issues/closed")
               :test #'string=)
         (who:htm (:span :class "placeholder"))
         (who:htm (:a :href "/" "All Issues")))
     (if *user*
         (who:htm
          (:div :class "nav-group"
           (:a :href "/settings" "Settings")
           (:form :class "form-link log-out"
                  :method "post"
                  :action "/logout"
                  (:input :type "submit" :value "Log Out"))))
         (who:htm
          (:a :href
              (format nil
                      "/auth?original-uri=~A"
                      (drakma:url-encode (hunchentoot:request-uri*)
                                         :utf-8))
              "Log In"))))))

(defun author (object)
  (find-user-by-dn (author-dn object)))

(defun displayname-if-known (user)
  (or (when user (displayname user))
      "unknown"))

(defmacro render ((&key
                     (footer t)
                     (header t))
                  &body body)
  `(who:with-html-output-to-string (*standard-output* nil :prologue t)
     (:html
      :lang "en"
      (:head
       (:title (who:esc *title*))
       (:link :rel "stylesheet" :type "text/css" :href "/main.css")
       (:meta :name "viewport"
              :content "width=device-width,initial-scale=1"))
      (:body
       (:div
        :class "content"
        (when ,header
          (who:htm
           (render/nav)))
        ,@body
        (when ,footer
          (who:htm
           (:footer
            (render/nav)))))))))

(defun form-button (&key
                      class
                      input-class
                      href
                      label
                      (method "post"))
  (who:with-html-output (*standard-output*)
    (:form :class class
           :method method
           :action href
           (:input :type "submit"
                   :class input-class
                   :value label))))

(defun render/alert (message)
  "Render an alert box for MESSAGE, if non-null"
  (check-type message (or null string))
  (who:with-html-output (*standard-output*)
    (when message
      (who:htm (:div :class "alert" (who:esc message))))))

(defun render/settings ()
  (let ((settings (model:settings-for-user (dn *user*))))
    (render ()
      (:div
       :class "settings-page"
       (:header
        (:h1 "Settings"))
       (:form
        :method :post :action "/settings"
        (:div
         (:label :class "checkbox"
          (:input :type "checkbox"
                  :name "enable-email-notifications"
                  :id "enable-email-notifications"
                  :checked (model:enable-email-notifications-p
                            settings))
          "Enable Email Notifications"))
        (:div :class "form-group"
         (:input :type "submit"
                 :value "Save Settings")))))))

(defun created-by-at (issue)
  (check-type issue model:issue)
  (who:with-html-output (*standard-output*)
    (:span :class "created-by-at"
           "Opened by "
           (:span :class "username"
                  (who:esc (displayname-if-known
                             (author issue))))
           " at "
           (:span :class "timestamp"
                  (who:esc
                   (format-dottime (created-at issue)))))))

(defun render/issue-list (&key issues)
  (who:with-html-output (*standard-output*)
    (:ol
     :class "issue-list"
     (dolist (issue issues)
       (let ((issue-id (model:id issue)))
         (who:htm
          (:li
           (:a :href (format nil "/issues/~A" issue-id)
               (:p
                (:span :class "issue-subject"
                       (render-inline-markdown (subject issue))))
               (:span :class "issue-number"
                      (who:esc (format nil "#~A" issue-id)))
               " - "
               (created-by-at issue)
               (let ((num-comments (length (model:issue-comments issue))))
                 (unless (zerop num-comments)
                   (who:htm
                    (:span :class "comment-count"
                           " - "
                           (who:esc
                            (format nil "~A comment~:p" num-comments))))))))))))))

(defun render/issue-search (&key search)
  (who:with-html-output (*standard-output*)
    (:form
     :method "get"
     :class "issue-search"
     (:input :type "search"
             :name "search"
             :title "Issue search query"
             :value search)
     (:input
      :type "submit"
      :value "Search Issues"
      :class "sr-only"))))

(defun render/index (&key issues search)
  (render ()
    (:header
     (:h1 "Issues")
     (when *user*
       (who:htm
        (:a
         :class "new-issue"
         :href "/issues/new" "New Issue"))))
    (:main
     (:div
      :class "issue-links"
      (:a :href "/issues/closed" "View closed issues")
      (render/issue-search :search search))
     (render/issue-list :issues issues))))

(defun render/closed-issues (&key issues search)
  (render ()
    (:header
     (:h1 "Closed issues"))
    (:main
     (:div
      :class "issue-links"
      (:a :href "/" "View open isues")
      (render/issue-search :search search))
     (render/issue-list :issues issues))))

(defun render/issue-form (&optional issue message)
  (let ((editing (and issue (id issue))))
    (render ()
      (:header
       (:h1
        (who:esc
         (if editing "Edit Issue" "New Issue"))))
      (:main
       (render/alert message)
       (:form :method "post"
              :action (if editing
                          (format nil "/issues/~A"
                                  (id issue))
                          "/issues")
              :class "issue-form"
              (:div
               (:input :type "text"
                       :id "subject"
                       :name "subject"
                       :placeholder "Subject"
                       :value (when editing
                                (who:escape-string
                                  (subject issue)))))

              (:div
               (:textarea :name "body"
                          :placeholder "Description"
                          :rows 10
                          (who:esc
                           (when editing
                             (body issue)))))

              (:input :type "submit"
                      :value
                      (if editing
                          "Save Issue"
                          "Create Issue")))))))

(defun render/new-comment (issue-id)
  (who:with-html-output (*standard-output*)
    (:form
     :class "new-comment"
     :method "post"
     :action (format nil "/issues/~A/comments" issue-id)
     (:div
      (:textarea :name "body"
                 :placeholder "Leave a comment"
                 :rows 5))
     (:input :type "submit"
             :value "Comment"))))

(defgeneric render/issue-history-item (item))

(defmethod render/issue-history-item ((comment model:issue-comment))
  (let ((fragment (format nil "comment-~A" (id comment))))
    (who:with-html-output (*standard-output*)
      (:li
       :class "comment"
       :id fragment
       (:p (who:str (body comment)))
       (:p
        :class "comment-info"
        (:span :class "username"
               (who:esc
                 (displayname-if-known (author comment)))
               " at "
               (:a :href (concatenate 'string "#" fragment)
                   (who:esc (format-dottime (created-at comment))))))))))

(defmethod render/issue-history-item ((event model:issue-event))
  (let ((user (find-user-by-dn (acting-user-dn event)))
        (fragment (format nil "event-~A" (id event))))
    (who:with-html-output (*standard-output*)
      (:li
       :class "event"
       :id fragment
       (who:esc (displayname-if-known user))
       (switch ((field event) :test #'string=)
         ("STATUS"
          (who:htm
           (who:esc
            (switch ((new-value event) :test #'string=)
              ("OPEN" " reopened ")
              ("CLOSED" " closed ")))
           " this issue "))
         ("BODY" (who:htm " updated the body of this issue"))
         (t
          (who:htm
           " changed the "
           (who:esc (string-downcase (field event)))
           " of this issue from \""
           (who:esc (previous-value event))
           "\" to \""
           (who:esc (new-value event))
           "\"")))
       " at "
       (who:esc (format-dottime (created-at event)))))))

(defun render/issue (issue)
  (check-type issue model:issue)
  (let ((issue-id (id issue))
        (issue-status (status issue)))
    (render ()
      (:header
       (:h1 (render-inline-markdown (subject issue)))
       (:div :class "issue-number"
             (who:esc (format nil "#~A" issue-id))))
      (:main
       (:div
        :class "issue-info"
        (created-by-at issue)

        (when *user*
          (who:htm
           (when (string= (author-dn issue)
                          (dn *user*))
             (who:htm
              (:a :class "edit-issue"
                  :href (format nil "/issues/~A/edit"
                                issue-id)
                  "Edit")))
           (form-button
            :class "set-issue-status"
            :href (format nil "/issues/~A/~A"
                          issue-id
                          (case issue-status
                            (:open "close")
                            (:closed "open")))
            :input-class (case issue-status
                           (:open "close-issue")
                           (:closed "open-issue"))
            :label (case issue-status
                     (:open "Close")
                     (:closed "Reopen"))))))
       (:p (who:str (render-markdown (body issue))))
       (let* ((comments (model:issue-comments issue))
              (events (model:issue-events issue))
              (history (merge 'list
                              comments
                              events
                              #'local-time:timestamp<
                              :key #'created-at)))
         (markdownify-comment-bodies comments)
         (when (or history *user*)
           (who:htm
            (:ol
             :class "issue-history"
             (dolist (item history)
               (render/issue-history-item item))
             (when *user*
               (render/new-comment (id issue)))))))))))

(defun render/not-found (entity-type)
  (render ()
    (:h1 (who:esc entity-type) " Not Found")))

;;;
;;; HTTP handlers
;;;

(defun send-email-for-issue
    (issue-id &key subject (message ""))
  "Send an email notification to all subscribers to the given issue with the
given subject an body (in a thread, to avoid blocking)"
  (let ((current-user *user*))
    (bordeaux-threads:make-thread
     (lambda ()
       (pomo:with-connection *pg-spec*
         (dolist (user-dn (model:issue-subscribers issue-id))
           (when (not (equal (dn current-user) user-dn))
             (email:notify-user
              user-dn
              :subject subject
              :message message))))))))

(defun link-to-issue (issue-id)
  (format nil "https://b.tvl.fyi/issues/~A" issue-id))

(defun @auth-optional (next)
  (let ((*user* (hunchentoot:session-value 'user)))
    (funcall next)))

(defun @auth (next)
  (if-let ((*user* (hunchentoot:session-value 'user)))
    (funcall next)
    (hunchentoot:redirect
     (format nil "/auth?original-uri=~A"
             (drakma:url-encode
              (hunchentoot:request-uri*)
              :utf-8)))))

(defun @db (next)
  "Decorator for handlers that use the database, wrapped in a transaction."
  (pomo:with-connection *pg-spec*
    (pomo:with-transaction ()
      (catch
          ;; 'hunchentoot:handler-done is unexported, but is used by functions
          ;; like hunchentoot:redirect to nonlocally abort the request handler -
          ;; this doesn't mean an error occurred, so we need to catch it here to
          ;; make the transaction still get committed
          (intern "HANDLER-DONE" "HUNCHENTOOT")
        (funcall next)))))

(defun @handle-issue-not-found (next)
  (handler-case (funcall next)
    (model:issue-not-found (err)
      (render/not-found
       (format nil "Issue #~A" (model:not-found-id err))))))

(defroute auth-handler ("/auth" :method :get :decorators (@auth-optional)) ()
  (if-let ((code (hunchentoot:get-parameter "code")))
    (let ((user (fetch-token code)))
      (setf (hunchentoot:session-value 'user) user)
      (hunchentoot:redirect (or (hunchentoot:session-value 'original-uri) "/")))

    (progn
      (when-let ((original-uri (hunchentoot:get-parameter "original-uri")))
        (setf (hunchentoot:session-value 'original-uri) original-uri))
      (hunchentoot:redirect (authn:auth-url)))))

(defroute logout ("/logout" :method :post) ()
  (hunchentoot:delete-session-value 'user)
  (hunchentoot:redirect "/"))

(defroute index ("/" :decorators (@auth-optional @db)) (&get search)
  (let ((issues (model:list-issues :status :open
                                   :search search)))
    (render/index :issues issues
                  :search search)))

(defroute settings ("/settings" :method :get :decorators (@auth @db)) ()
  (render/settings))

(defroute save-settings ("/settings" :method :post :decorators (@auth @db))
    (&post enable-email-notifications)
  (let ((settings (model:settings-for-user (dn *user*))))
    (model:update-user-settings
     settings
     'model:enable-email-notifications enable-email-notifications)
    (render/settings)))

(defroute handle-closed-issues
    ("/issues/closed" :decorators (@auth-optional @db))
    (&get search)
  (let ((issues (model:list-issues :status :closed
                                   :search search)))
    (render/closed-issues :issues issues
                          :search search)))

(defroute new-issue ("/issues/new" :decorators (@auth)) ()
  (render/issue-form))

(defroute handle-create-issue
    ("/issues" :method :post :decorators (@auth @db))
    (&post subject body)
  (if (string= subject "")
      (render/issue-form
       (make-instance 'model:issue :subject subject :body body)
       "Subject is required")
      (let ((issue
              (model:create-issue :subject subject
                                  :body body
                                  :author-dn (dn *user*))))
        (send-irc-notification
         (format nil
                 "b/~A: \"~A\" opened by ~A - https://b.tvl.fyi/issues/~A"
                 (id issue)
                 subject
                 (irc:noping (cn *user*))
                 (id issue))
         :channel (or (uiop:getenvp "ISSUECHANNEL")
                      "#tvl"))
        (hunchentoot:redirect
         (format nil "/issues/~A" (id issue))))))

(defroute show-issue
    ("/issues/:id" :decorators (@auth-optional @handle-issue-not-found @db))
    (&path (id 'integer))
  (let* ((issue (model:get-issue id))
         (*title* (format nil "~A | Panettone"
                          (subject issue))))
    (render/issue issue)))

(defroute edit-issue
    ("/issues/:id/edit" :decorators (@auth @handle-issue-not-found @db))
    (&path (id 'integer))
  (let* ((issue (model:get-issue id))
         (*title* "Edit Issue | Panettone"))
    (render/issue-form issue)))

(defroute update-issue
    ("/issues/:id" :decorators (@auth @handle-issue-not-found @db)
                   ;; NOTE: this should be a put, but we're all HTML forms
                   ;; right now and those don't support PUT
                   :method :post)
    (&path (id 'integer) &post subject body)
  (let ((issue (model:get-issue id)))
    ;; only the original author can edit an issue
    (if (string-equal (author-dn issue)
                      (dn *user*))
        (progn
          (model:update-issue issue
                              'model:subject subject
                              'model:body body)
          (hunchentoot:redirect (format nil "/issues/~A" id)))
        (render/not-found "Issue"))))

(defroute handle-create-comment
    ("/issues/:id/comments"
     :decorators (@auth @handle-issue-not-found @db)
     :method :post)
    (&path (id 'integer) &post body)
  (flet ((redirect-to-issue ()
           (hunchentoot:redirect (format nil "/issues/~A" id))))
    (cond
      ((string= body "")
       (redirect-to-issue))
      (:else
       (model:create-issue-comment
        :issue-id id
        :body body
        :author-dn (dn *user*))

       (let ((issue (model:get-issue id)))
         (send-email-for-issue
          id
          :subject (format nil "~A commented on b/~A: \"~A\""
                           (displayname *user*)
                           id
                           (subject issue))
          :message (format nil "~A~%~%~A"
                           body
                           (link-to-issue id))))
       (redirect-to-issue)))))

(defroute close-issue
    ("/issues/:id/close" :decorators (@auth @handle-issue-not-found @db)
                         :method :post)
    (&path (id 'integer))
  (model:set-issue-status id :closed)
  (let ((issue (model:get-issue id)))
    (send-irc-notification
     (format nil
             "b/~A: \"~A\" closed by ~A - ~A"
             id
             (subject issue)
             (irc:noping (cn *user*))
             (link-to-issue id))
     :channel (or (uiop:getenvp "ISSUECHANNEL")
                  "#tvl"))
    (send-email-for-issue
     id
     :subject (format nil "b/~A: \"~A\" closed by ~A"
                      id
                      (subject issue)
                      (displayname *user*))
     :message (link-to-issue id)))
  (hunchentoot:redirect (format nil "/issues/~A" id)))

(defroute open-issue
    ("/issues/:id/open" :decorators (@auth @db)
                        :method :post)
    (&path (id 'integer))
  (model:set-issue-status id :open)
  (let ((issue (model:get-issue id)))
    (send-irc-notification
     (format nil
             "b/~A: \"~A\" reopened by ~A - ~A"
             id
             (subject issue)
             (irc:noping (cn *user*))
             (link-to-issue id))
     :channel (or (uiop:getenvp "ISSUECHANNEL")
                  "#tvl"))
    (send-email-for-issue
     id
     :subject (format nil "b/~A: \"~A\" reopened by ~A"
                      id
                      (subject issue)
                      (displayname *user*))
     :message (link-to-issue id)))
  (hunchentoot:redirect (format nil "/issues/~A" id)))

(defroute styles ("/main.css") ()
  (setf (hunchentoot:content-type*) "text/css")
  (apply #'lass:compile-and-write panettone.css:styles))

(defvar *acceptor* nil
  "Hunchentoot acceptor for Panettone's web server.")

(defun migrate-db ()
  "Migrate the database to the latest version of the schema"
  (pomo:with-connection *pg-spec*
    (model:migrate)))

(define-build-time-var *static-dir* "static/"
    "Directory to serve static files from")

(defun start-panettone (&key port session-secret)
  (authn:initialise-oauth2)
  (model:prepare-db-connections)
  (migrate-db)

  (when session-secret
    (setq hunchentoot:*session-secret* session-secret))

  (setq hunchentoot:*session-max-time* (* 60 60 24 90))

  (setq *acceptor*
        (make-instance 'easy-routes:easy-routes-acceptor :port port))

  (push
   (hunchentoot:create-folder-dispatcher-and-handler
    "/static/"
    (util:->dir *static-dir*))
   hunchentoot:*dispatch-table*)

  (hunchentoot:start *acceptor*))

(defun main ()
  (let ((port (integer-env "PANETTONE_PORT" :default 6161))
        (cheddar-url (uiop:getenvp "CHEDDAR_URL"))
        (session-secret (uiop:getenvp "SESSION_SECRET")))
    (when cheddar-url (setq *cheddar-url* cheddar-url))
    (setq hunchentoot:*show-lisp-backtraces-p* nil)
    (setq hunchentoot:*log-lisp-backtraces-p* nil)

    (start-panettone :port port
                     :session-secret session-secret)

    (format t "launched panettone on port ~A~%" port)

    (sb-thread:join-thread
     (find-if (lambda (th)
                (string= (sb-thread:thread-name th)
                         (format nil "hunchentoot-listener-*:~A" port)))
              (sb-thread:list-all-threads)))))

(comment
 (setq hunchentoot:*catch-errors-p* nil)
 ;; to setup an ssh tunnel to cheddar+irccat for development:
 ;; ssh -N -L 4238:localhost:4238 -L 4722:localhost:4722 nevsky.tvl.fyi
 (start-panettone :port 6161
                  :session-secret "session-secret")
 )
