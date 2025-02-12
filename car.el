;;; CAR --- "Compile And Run", simple script that compiles, then runs C code in a neat format.
;;; Commentary:
;;; Short snippet of elisp code to improve my ability to write Lisp and serve as a useful function.
;;; Code:

(require 'comint)

(defun car-exec ()
  "Compile and run C code that is within the current buffer."
  (interactive)
  (if (eq major-mode 'c-ts-mode)
    (progn
      (save-buffer)
      (let (
	    (justname (file-name-sans-extension (file-name-nondirectory (buffer-file-name))))
	    (orig-buf-name (buffer-name (current-buffer)))
	    )
	(compile (concat "gcc -O0 -g -o " justname " " justname ".c"))
	(add-hook 'compilation-finish-functions
		  (lambda (buf_obj out_str)
		    (when (and
			   (string-match "finished" out_str)
			   (not (string-match "error" out_str))
			   )
		      (select-window buf_obj)
		      (shell)
		      (goto-char (point-max))
		      (insert (concat justname ".exe"))
		      (comint-send-input)
		      (select-window (get-buffer-window orig-buf-name))
		      ))
		  )
	)
      )
    (message "This isn't a buffer containing only C code.")))

(provide 'car)
;;; car.el ends here
