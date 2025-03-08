;;; mude.el --- MUD Emacs. An Emacs MUD client. (Pronounced: "Muddy"!)
;;; Commentary:
;;; Honestly, just wanted to give it a go!
;;; I'll use 'open-network-stream' primarily to communicate with the server.
;;; I'm quite new to TCP communications, telnet, and everything, so I'll have to study other scripts that do similar things.
;;; Code:
(require 'ansi-color)
(require 'password-cache)

; General Global Variables
(defvar mud-net-process nil)
(defvar mud-input-buffer nil)
(defvar mud-proc-buf-name "MUD!")

;; Persistent list containing data to use for quick reconnecting
(defcustom last-world nil
  "List of information about the last MUD connected to through mude."
  :type '(list
	 (string :tag "Last Host") ; Last used hostname
	 (integer :tag "Last Port") ; The last used port
	 )
  :group 'mude
  )

;; Persistent settings for how the external game options should be like (autoscrolling, size of game buffer, "cinematic" mode, etc)
(defcustom mude-settings '(0 nil t 0)
  "Persistent settings for how the external game options should be like.

Display Width - Adjusts the window width to integer value, if nil makes no adjustments.

Cinematic Mode - Switches the input-display buffers from the default (side-by-side)
                 to stacked atop eachother.

Autoscroll - Turns auto-scrolling on, which adjusts the output to occupy the entire screen,
             leaving no whitespace

Autoscroll Padding - Adjusts how many whitespace lines the user wants below their display's output.
"
  :type '(list
	  (integer :tag "Display Widening" :value 0)
	  (boolean :tag "Cinematic Mode" :value nil)
	  (boolean :tag "Autoscroll" :value t)
	  (integer :tag "Autoscroll Padding" :value 0)
	  )
  :group 'mude
  )

					; Misc Functions
(defun set-mude-settings ()
  "Set the user settings contained in 'mude-settings'."
  (interactive)
  (let (
	(usr-widen (string-to-number (read-from-minibuffer "Additional game display width: ")))
	(usr-cine (read-from-minibuffer "Do you want to turn on Cinematic Mode? (\"y\" for yes, other for no): "))
	(usr-as (read-from-minibuffer "Do you want to turn on autoscroll? (\"y\" for yes, other for no): "))
	(usr-as-pad (string-to-number (read-from-minibuffer "How many lines of padding do you want for autoscroll? (\"nil\" for none, non-negative integer otherwise): ")))
	)
    (if (<= usr-widen 0)
	(setq usr-widen 0)
      )
    (if (or
	 ;;; Not a very refined check, but eh, if you're inputting "maybe", you may as well get matched as true.
	 (string-match-p "[yY]" usr-cine)
	 (string-match-p "[tT]" usr-cine)
	 )
	(setq usr-cine t)
      (setq usr-cine nil)
      )
    (if (or
	 (string-match-p "[yY]" usr-as)
	 (string-match-p "[tT]" usr-as)
	 )
	(setq usr-as t)
      (setq usr-as nil)
      )
    (if (not (or
	 (integerp usr-as-pad)
	 (>= usr-as-pad 0)
	 ))
	(setq usr-as-pad nil)
	)
    (setq mude-settings (list usr-widen usr-cine usr-as usr-as-pad))
    (customize-save-variable 'mude-settings mude-settings)
    )
  )

(defun display-buffer-scroll (choice)
  "Use CHOICE to determine whether to scroll the display buffer up or down."
  (with-selected-window (get-buffer-window (process-buffer mud-net-process))
      (if (eq choice 0)
	  (scroll-up-command)
	(scroll-down-command)
	)
      )
  )

(defvar garbage-char-list '()
  "Variety of character(s) to filter for in the output of the process."
  )

;;; This is set up just so it's easier to add more.
(setq garbage-char-list '(
			  ""
			  "ý"
			  "ÿ "
			  "ÿÿ"
			  "ÿÿÿ"
			  "ÿù"
			  )
      )

(defsubst cleanup-garbage-characters ()
  "Clean up garbage characters left from coding system."
  (mapc (lambda (gc)
	    (replace-string-in-region gc "" (point-min) (point-max))
	    )
	  garbage-char-list)
  )
					; Settings functions
(defun adjust-mud-display-window-size ()
  "Adjusts the width of the display window, or the height if in cinematic mode."
  (if (/= (nth 0 mude-settings) 0)
      (let (
	    (disp-window (get-buffer-window (process-buffer mud-net-process)))
	    (window-increase (nth 0 mude-settings))
	    (cinematic-setting (nth 1 mude-settings))
	    )
	(window-resize disp-window window-increase (not cinematic-setting))
	)
    )
  )

(defun mud-autoscroll (buf)
  "Positions BUF to properly display all information it can."
  (if (nth 2 mude-settings)
      (with-current-buffer buf
	(let (
	      (w-start (line-number-at-pos (window-start)))
	      (w-height (window-body-height))
	      (w-end nil)
	      (w-scroll-amount nil)
	      (as-padding (nth 3 mude-settings))
	      )
	  (save-excursion
	    (goto-char (point-max))
	    (setq w-end (line-number-at-pos))
	    )
	  (setq w-scroll-amount (- (- (+ w-height w-start) w-end) (+ 1 as-padding)))
	  (scroll-down-line w-scroll-amount)
	  )
	)
    )
  )

; INPUT MODE SET UP
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
    (define-key binds (kbd "C-c q") 'mude-close)
    (define-key binds (kbd "<RET>") 'mud-send-input-line)
    (define-key binds (kbd "C-c C-w") (lambda ()
					(interactive)
					(display-buffer-scroll 1)
					)
		)
    (define-key binds (kbd "C-c C-s") (lambda ()
					(interactive)
					(display-buffer-scroll 0)
					)
		)
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
    (set-keymap-parent binds text-mode-map)
    binds
    )
  "Key bindings that will be used for 'mud-display-mode'.
By default, exactly the same as 'text-mode'."
  )

(defun mud-display-mode ()
  "Major mode for the buffer that will display the MUDs output."
  (setq major-mode 'mud-display-mode)
  (setq mode-name "MUD-OUT")
  (use-local-map mud-display-mode-map)
  )

; FUNCTIONS TO SET UP GAME BUFFERS
(defun setup-mud-input-buffer ()
  "Set up the input buffer to interact with the MUD network process."
  (let (
	(mud-in-buf (get-buffer-create "*MUD Input!*"))
	(cinematic-setting (nth 1 mude-settings))
	)
    (setq mud-input-buffer mud-in-buf)
    (with-current-buffer mud-in-buf
      (mud-input-mode)
      )
    
    (if cinematic-setting
	(progn
	  (select-window (split-window-below))
	  (switch-to-buffer mud-in-buf)
	  )
      (pop-to-buffer mud-in-buf)
      )
    )
  )

(defun setup-mud-display-buffer (mud-proc)
  "Set up the display buffer for MUD-PROC."
  (set-process-filter mud-proc 'mud-output-filter)
  (setq mud-net-process mud-proc)
  (let (
	(mud-proc-buf (process-buffer mud-proc))
	(cine-setting (nth 1 mude-settings))
	)
    (with-current-buffer mud-proc-buf
      (mud-display-mode)
      )
    (if cine-setting
	(switch-to-buffer mud-proc-buf)
      (pop-to-buffer mud-proc-buf)
    )
    (adjust-mud-display-window-size)
    )
  )

					; Filter functions
(defun mud-password-check (proc-str)
  "Check whether PROC-STR has a password prompt, then opens secure input."
  (if (string-match-p "\\b\\w*password\\:" proc-str)
      (let (
	    (pass-result (password-read "MUD Password: "))
	    )
	(process-send-string mud-net-process (concat pass-result "\n"))
	)
    )
  )

(defun mud-output-filter (net-proc str-out)
  "Filter function for the NET-PROC process that serves STR-OUT to display."
  (let* (
	(net-proc-buf (process-buffer net-proc))
	(net-proc-buf-window (get-buffer-window net-proc-buf))
	)
    (with-current-buffer net-proc-buf
      (let (
	    (sor (point-max))
	    (eor nil)
	    (str-out-final nil)
	    )
	(with-temp-buffer
	  (insert str-out)
	  (goto-char (point-min))
	  (cleanup-garbage-characters)
	  (setq str-out-final (buffer-substring (point-min) (point-max)))
	  )
	(goto-char sor)
	(insert (concat "\n" str-out-final))
	(setq eor (point))
	(ansi-color-apply-on-region sor eor)
	)
      )
    ;;; This may not be needed
    (with-selected-window net-proc-buf-window
      (mud-autoscroll net-proc-buf)
      )
    (mud-password-check str-out)
    )
  )

; CORE FUNCTIONS
(defun mude-nl ()
  "Main function for the MUD client."
  (interactive)
  (let* (
	(input-host (read-from-minibuffer "Hostname: "))
	(input-port (read-from-minibuffer "Port: "))
	(connection-cons (cons input-host input-port))
	(net-proc (open-network-stream "MUD-PROCESS" mud-proc-buf-name input-host input-port))
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
  (let (
	(pass t)
	)
    (if (and
	 (get-buffer mud-proc-buf-name)
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
	       (net-proc (open-network-stream "MUD-PROCESS" mud-proc-buf-name last-host last-port))
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
