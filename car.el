;;; CAR --- "Compile And Run", simple script that compiles, then runs C code in a neat format.
;;; Commentary:
;;; Short snippet of elisp code to improve my ability to write Lisp and serve as a useful function.
;;; Code:

;;; UNINTENDED ISSUE: If you use 'compile-and-run-hook' by compiling a different C source file in a different directory, the shell that was initially created
;;; (and that will be used to try and execute [newsource].exe) will still be within the directory of the original C source file. This'll cause it to try and run
;;; the new executible created from [newsource].c within the directory that [originalsource].c and [originalsource].exe lived in.
;;; This can be easily fixed by adding a check to see which directory we're currently in vs. what the shell is in.
;;; FIXED: Simply changes directory to the current one. Little messier than before, but it's not a problem.

(require 'comint)

(defvar cur-exec-dir nil)

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
	(setq cur-exec-dir (file-name-directory (buffer-file-name (current-buffer))))
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
	(if (not (and (string-match "*shell*" (buffer-name (window-buffer (next-window))))))
	    (split-window-below nil (get-buffer-window comp_buf_obj))
	  )
	(other-window 1)
	(shell)
	(goto-char (point-max))
	(insert (concat "cd " cur-exec-dir))
	(comint-send-input)
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
