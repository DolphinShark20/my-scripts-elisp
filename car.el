;;; CAR --- "Compile And Run", simple script that compiles, then runs C code in a neat format.
;;; Commentary:
;;; Short snippet of elisp code to improve my ability to write Lisp and serve as a useful function.
;;; Code:

(require 'comint)

(defun compile-c-file ()
  "Compiles the current C file."
  (interactive)
  (if (eq major-mode 'c-ts-mode)
      (progn
	(let (
	      (buffer-c (buffer-name (current-buffer)))
	      )
	  (save-buffer)
	  (compile (concat "gcc -O0 -g -o " (file-name-sans-extension buffer-c) " " buffer-c))
	  )
	)
    (message "This does not seem to be a C buffer!")
    )
  )
(global-set-key (kbd "C-c C--") 'compile-c-file)

(defun compile-and-run-hook (comp_buf_obj comp_out_str)
  "Use COMP_BUF_OBJ and COMP_OUT_STR to run Windows executable of compilation."
  (when (and
	 (string-match "finished" comp_out_str)
	 (not (string-match "error" comp_out_str))
	 )
    (with-temp-buffer
      (insert-buffer-substring comp_buf_obj)
      (goto-char (point-min))
      (re-search-forward "\\b\\(\\w+\\)\\.c\\b")
      (let* (
	     (output (match-string 1))
	     (buf-c (concat output ".c"))
	     )
	(select-window (get-buffer-window comp_buf_obj))
	(split-window-below nil (get-buffer-window comp_buf_obj))
	(other-window 1)
	(shell)
	(goto-char (point-max))
	(insert (concat output ".exe"))
	(comint-send-input)
	(select-window (get-buffer-window buf-c))
	))
    )
  )
(add-hook 'compilation-finish-functions 'compile-and-run-hook)

(provide 'car)
;;; car.el ends here
