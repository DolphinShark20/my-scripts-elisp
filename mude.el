;;; mude.el --- MUD Emacs. An Emacs MUD client. (Pronounced: "Muddy"!)
;;; Commentary:
;;; Honestly, just wanted to give it a go!
;;; I'll use 'open-network-stream' primarily to communicate with the server.
;;; I'm quite new to TCP communications, telnet, and everything, so I'll have to study other scripts that do similar things.
;;; Code:
(defvar mud-process nil)

(defcustom mud-worlds nil
  "List of lists that contain MUD world info (alias for world, host, port)
This list can be changed using a built in function."
  :type '(repeat
	  (vector :tag "MUD World"
	   (string :tag "Alias")
	   (string :tag "Hostname")
	   (string :tag "Port")
	   (string :tag "Character" :value nil)
	   (string :tag "Password" :value nil)
	   )
	  )
  :group 'mude
  )

(defun m-alias ()
  "Create a preset MUD world with an alias that can be easily accessed."
  (interactive)
  (let (
	(alias (read-from-minibuffer "Alias: "))
	(host (read-from-minibuffer "Host: "))
	(port (read-from-minibuffer "Port: "))
	(auto-log-status (read-from-minibuffer "Would you like to add an auto-login character (y/[anything else]): "))
	(char-name nil)
	(pass nil)
	)
    (if (string-equal auto-log-status "y")
	(progn
	  (setq char-name (read-from-minibuffer "Character Name: "))
	  (setq pass (read-from-minibuffer "Password (which is stored plainly in the init file): "))
	  )
      )
    (setq mud-worlds (append mud-worlds (vector alias host port char-name pass)))
    (customize-save-variable 'mud-worlds mud-worlds)
    (message "MUD world '%s' has been added to the saved MUD lists!" alias)
  )
)

(defun m-close ()
  "Closes the current MUD session."
  (interactive)
  (if (eq mud-process nil)
      (message "There's no current MUD session!")
    (progn
      (let (
	    (mud-window (get-buffer-window "MUD!"))
	    )
      (if mud-window
	  (delete-window mud-window)
	)
      )
      (delete-process mud-process)
      (message "Current MUD process has been ended!")
      )
    )
  )


(defun mude ()
  "Main function for the MUD client."
  (interactive)
  (let* (
	(input-host (read-from-minibuffer "Hostname: "))
	(input-port (read-from-minibuffer "Port: "))
	(net-proc (open-network-stream "MUD-PROCESS" "MUD!" input-host input-port))
	(m-window (split-window-right))
	)
    (setq mud-process net-proc)
    (with-current-buffer "MUD!"
      (read-only-mode 1)
      )
    (set-window-buffer m-window "MUD!")
    )
  )

(provide 'mude)
;;; mude.el ends here
