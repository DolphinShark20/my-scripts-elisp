;;; mude.el --- MUD Emacs. An Emacs MUD client. (Pronounced: "Muddy"!)
;;; Commentary:
;;; Honestly, just wanted to give it a go!
;;; I'll use 'open-network-stream' primarily to communicate with the server.
;;; I'm quite new to TCP communications, telnet, and everything, so I'll have to study other scripts that do similar things.
;;; Code:
(require 'comint)

;;; General Global Variables
(defvar mud-net-process nil)
(defvar mud-input-buffer nil)

;;; INPUT MODE SET UP
(defun mud-send-input-line ()
  "Sends input from input buffer's active line to active MUD connection stored at 'mud-net-process'."
  (interactive)
  (let* (
	(eol (point))
	(sol (line-beginning-position))
	(input-line (concat (buffer-substring eol sol) "\n"))
	)
    (process-send-string mud-net-process input-line)
    (newline)
    )
  )

(defvar mud-input-mode-map
  (let (
	(binds (make-sparse-keymap))
	)
    (set-keymap-parent binds text-mode-map)
    (define-key binds (kbd "<RET>") 'mud-send-input-line)
    binds
    )
  )

(defun mud-input-mode ()
  "Major mode for the buffer that will provide an input to the MUD network process."
  (setq major-mode 'mud-input-mode)
  (setq mode-name "MUD-IN")
  (use-local-map mud-input-mode-map)
  )

(defvar mud-display-mode-map
  (let (
	(binds (make-sparse-keymap))
	)
;;;    (define-key binds (kbd "s") 'scroll-down-command)
;;;    (define-key binds (kbd "w") 'scroll-up-command)
    (set-keymap-parent binds comint-mode-map)
    binds
    )
  "Key bindings that will be used for 'mud-display-mode'.
By default, exactly the same as comint mode."
  )

(defun mud-display-mode ()
  "Major mode for the buffer that will display the MUDs output."
  (setq major-mode 'mud-display-mode)
  (setq mode-name "MUD-OUT")
  (use-local-map mud-display-mode-map)
  )

;;; Persistent list containing data to use for quick reconnecting
(defcustom last-world nil
  "List of information about the last MUD connected to through mude."
  :type '(list
	 (string :tag "Last Host") ; Last used hostname
	 (integer :tag "Last Port") ; The last used port
	 )
  :group 'mude
  )

;;; FUNCTIONS TO SET UP GAME BUFFERS
(defun setup-mud-input-buffer ()
  "Set up the input buffer to interact with the MUD network process."
  (let (
	(mud-in-buf (get-buffer-create "*MUD Input!*"))
	)
    (setq mud-input-buffer mud-in-buf)
    (pop-to-buffer mud-in-buf)
    (with-current-buffer mud-in-buf
      (mud-input-mode)
      )
    )
  )

(defun setup-mud-display-buffer (mud-proc)
  "Set up the display buffer for MUD-PROC."
  (set-process-filter mud-proc 'mud-network-process-filter)
  (setq mud-net-process mud-proc)
  (let (
	(mud-proc-buf (process-buffer mud-proc))
	)
    (with-current-buffer mud-proc-buf
      (mud-display-mode)
      )
    (pop-to-buffer mud-proc-buf)
    )
  )

;;; Filter functions
(defun mud-network-process-filter (net-proc str-out)
  "Filter function for the NET-PROC proccess that serves STR-OUT to display."
  (with-current-buffer (process-buffer net-proc)
    (goto-char (point-max))
    (insert str-out)
    )
  (with-selected-window (get-buffer-window (process-buffer mud-net-process))
		       (goto-char (point-max))
		       )
  )

;;; CORE FUNCTIONS
(defun mude-nl ()
  "Main function for the MUD client."
  (interactive)
  (let* (
	(input-host (read-from-minibuffer "Hostname: "))
	(input-port (read-from-minibuffer "Port: "))
	(net-proc (open-network-stream "MUD-PROCESS" "*MUD!*" input-host input-port))
	)
    (setq mud-net-process net-proc)
        
    (setq last-world (list input-host input-port))
    (customize-save-variable 'last-world last-world)
    
    (setup-mud-display-buffer net-proc)
    (setup-mud-input-buffer)
    )
  )

(defun mude-re ()
  "Reconnect to last-joined MUD world."
  (interactive)
  ;;; Annoying hack --- didn't want to bring in cl-return to handle mid-function breaking if user opts "N", so I put this in instead.
  (let (
	(pass t)
	)
    (if (and
	 (get-buffer "*MUD!*")
	 (get-buffer "*MUD Input!*")
	 )
	(if (string-equal-ignore-case (read-from-minibuffer "MUD session/buffers may still be open! Close them and reconnect (Y) or halt reconnection (N/ANYKEY); [Y/N]: ") "Y")
	    (mude-close)
	  (setq pass nil)
	  )
      )
    (if pass
	(let* (
	       (last-host (car last-world))
	       (last-port (nth 1 last-world))
	       (net-proc (open-network-stream "MUD-PROCESS" "*MUD!*" last-host last-port))
	       )
	  (setup-mud-display-buffer net-proc)
	  (setup-mud-input-buffer)
	  )
      )
    )
  )

(defun mude-close ()
  "Closes the current MUD session and its relevant buffers/windows."
  (interactive)
  ;;; Since killing the buffer kills the associated process, may as well just /only/ kill the buffer.
  (let* (
	(mud-out-buf (process-buffer mud-net-process))
	(mud-out-window (get-buffer-window mud-out-buf))
	(mud-in-buf mud-input-buffer)
	)
    
    (if mud-out-buf
	(kill-buffer mud-out-buf)
      )
    (if mud-in-buf
	(kill-buffer mud-in-buf)
      )
    (if mud-out-window
	(delete-window mud-out-window)
      )
    (message "Active MUD processes/buffers/windows have been closed! (If there were any)")
    )
  )

(provide 'mude)
;;; mude.el ends here
