;;; mude.el --- MUD Emacs. An Emacs MUD client. (Pronounced: "Muddy"!)
;;; Commentary:
;;; Honestly, just wanted to give it a go!
;;; I'll use 'open-network-stream' primarily to communicate with the server.
;;; I'm quite new to TCP communications, telnet, and everything, so I'll have to study other scripts that do similar things.
;;; Code:
(defvar mud-process nil)

(defun m-close ()
  "Closes the current MUD session."
  (if (eq mud-process nil)
      (message "There's no current MUD session!")
    (progn
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
	)
    (setq mud-process net-proc)
    (with-current-buffer "MUD!"
      (read-only-mode 1)
      )
    (split-window-right)
    (set-window-buffer (next-window) "MUD!")
  )
)

(provide 'mude)
;;; mude.el ends here
