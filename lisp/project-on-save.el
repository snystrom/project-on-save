;;; project-on-save-command.el --- Run commands in project directory on save -*- lexical-binding: t; -*-

;;; Commentary:
;; A minor mode that allows registering commands to run in the project
;; directory whenever a buffer is saved.

;;; Code:

(require 'projectile)

(defgroup project-on-save-command nil
  "Run commands in project directory on save."
  :group 'convenience
  :prefix "project-on-save-command-")

(defcustom project-on-save-command-timeout 10
  "Timeout in seconds for running save commands."
  :type 'integer
  :group 'project-on-save-command)

(defcustom project-on-save-command-show-output t
  "Whether to show command output in a buffer."
  :type 'boolean
  :group 'project-on-save-command)

(defcustom project-on-save-command-run-synchronously nil
  "Whether to run commands synchronously and reload buffer from disk when complete.
Useful for formatters that modify the current file."
  :type 'boolean
  :group 'project-on-save-command)

(defvar-local project-on-save-command--registered-command nil
  "The command registered for this buffer.")

(defvar-local project-on-save-command--project-root nil
  "Cached project root for this buffer.")

(defun project-on-save-command--get-project-root ()
  "Get the project root directory, caching it for performance."
  (or project-on-save-command--project-root
      (setq project-on-save-command--project-root
            (projectile-project-root))))

(defun project-on-save-command--run-command (command)
  "Run COMMAND in the project directory."
  (when-let ((project-root (project-on-save-command--get-project-root)))
    (let ((default-directory project-root)
          (process-name (format "*project-on-save: %s*" (file-name-nondirectory project-root)))
          (current-buffer (current-buffer))
          (current-file (buffer-file-name)))
      (if project-on-save-command-run-synchronously
          ;; Run synchronously and reload buffer
          (progn
            (when project-on-save-command-show-output
              (message "Running: %s..." command))
            (let ((result (shell-command command)))
              (when project-on-save-command-show-output
                (message "Command finished with exit code: %d" result))
              ;; Reload the current buffer from disk if it's a file buffer
              (when (and current-file
                         (file-exists-p current-file)
                         (buffer-live-p current-buffer))
                (with-current-buffer current-buffer
                  (let ((point (point))
                        (window-start (window-start)))
                    (message "Reloading buffer: %s" (buffer-name))
                    (revert-buffer t t t)
                    ;; Restore cursor position and window position
                    (goto-char point)
                    (set-window-start (selected-window) window-start)
                    (message "Buffer reloaded"))))))
        ;; Run asynchronously
        (if project-on-save-command-show-output
            (let ((buffer (get-buffer-create process-name)))
              (with-current-buffer buffer
                (erase-buffer)
                (insert (format "Running: %s\nIn: %s\n\n" command project-root)))
              (start-process-shell-command
               process-name buffer command))
          ;; Run silently
          (start-process-shell-command
           process-name nil command))))))

(defun project-on-save-command--after-save-hook ()
  "Hook function to run registered command after save."
  (when project-on-save-command--registered-command
    (project-on-save-command--run-command project-on-save-command--registered-command)))

(defun project-on-save-command-register (command)
  "Register COMMAND to run on save in the current buffer's project directory."
  (interactive "sCommand to run on save: ")
  (setq project-on-save-command--registered-command command)
  (message "Registered command: %s" command))

(defun project-on-save-command-unregister ()
  "Unregister the save command for the current buffer."
  (interactive)
  (setq project-on-save-command--registered-command nil)
  (message "Unregistered save command"))

(defun project-on-save-command-show-registered ()
  "Show the currently registered command."
  (interactive)
  (if project-on-save-command--registered-command
      (message "Registered command: %s" project-on-save-command--registered-command)
    (message "No command registered")))

;;;###autoload
(define-minor-mode project-on-save-command-mode
  "Minor mode to run commands in project directory on save."
  :lighter " OnSave"
  :group 'project-on-save-command
  (if project-on-save-command-mode
      (progn
        ;; Cache the project root when enabling the mode
        (project-on-save-command--get-project-root)
        (add-hook 'after-save-hook #'project-on-save-command--after-save-hook nil t))
    (remove-hook 'after-save-hook #'project-on-save-command--after-save-hook t)
    ;; Clear cached data when disabling
    (setq project-on-save-command--project-root nil)))

;;;###autoload
(define-globalized-minor-mode global-project-on-save-command-mode
  project-on-save-command-mode
  (lambda () (project-on-save-command-mode 1))
  :group 'project-on-save-command)

(provide 'project-on-save-command)
;;; project-on-save-command.el ends here
