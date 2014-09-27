;;; -*- coding: utf-8-unix -*-
;;;
;;;Part of: Vicare Scheme
;;;Contents: tests for the compiler internals
;;;Date: Mon Jul 28, 2014
;;;
;;;Abstract
;;;
;;;
;;;
;;;Copyright (C) 2014 Marco Maggi <marco.maggi-ipsu@poste.it>
;;;
;;;This program is free software: you can  redistribute it and/or modify it under the
;;;terms  of  the GNU  General  Public  License as  published  by  the Free  Software
;;;Foundation,  either version  3  of the  License,  or (at  your  option) any  later
;;;version.
;;;
;;;This program is  distributed in the hope  that it will be useful,  but WITHOUT ANY
;;;WARRANTY; without  even the implied warranty  of MERCHANTABILITY or FITNESS  FOR A
;;;PARTICULAR PURPOSE.  See the GNU General Public License for more details.
;;;
;;;You should have received a copy of  the GNU General Public License along with this
;;;program.  If not, see <http://www.gnu.org/licenses/>.
;;;


#!vicare
(import (vicare)
  (vicare checks)
  (only (vicare libraries)
	uninstall-library)
  (prefix (vicare compiler)
	  compiler.))

(check-set-mode! 'report-failed)
(check-display "*** testing Vicare compiler internals\n")

(compiler.optimize-level 2)
(compiler.source-optimizer-passes-count 2)
;;(compiler.cp0-effort-limit 50)
;;(compiler.cp0-size-limit   8)


;;;; helpers

(define (gensyms->symbols sexp)
  (cond ((pair? sexp)
	 (cons (gensyms->symbols (car sexp))
	       (gensyms->symbols (cdr sexp))))
	((vector? sexp)
	 (vector-map gensyms->symbols sexp))
	((gensym? sexp)
	 (string->symbol (symbol->string sexp)))
	(else sexp)))

;;; --------------------------------------------------------------------
;;; expansion helpers

(define-constant THE-ENVIRONMENT
  (environment '(vicare)
	       '(vicare system $fx)
	       ;;We  import this  library for  $SYMBOL-STRING, which  is a  primitive
	       ;;operation bot not a primitive function.
	       '(vicare system $symbols)
	       ;;We import this library to  inspect how imported bindings are handled
	       ;;by the compiler.
	       '(libtest compiler-internals)
	       ;;This is to build annotated forms and test debug-calls.
	       '(only (vicare)
		      get-annotated-datum)))

(define (%expand standard-language-form)
  (receive (code libs)
      (expand-form-to-core-language standard-language-form THE-ENVIRONMENT)
    code))

(define (%expand-library standard-language-form)
  (cdr (assq 'invoke-code (expand-library->sexp standard-language-form))))

(define (%make-annotated-form form)
  (let* ((form.str (receive (port extract)
		       (open-string-output-port)
		     (unwind-protect
			 (begin
			   (display form port)
			   (extract))
		       (close-port port))))
	 (port     (open-string-input-port form.str)))
    (unwind-protect
	(get-annotated-datum port)
      (close-port port))))


(parametrise ((check-test-name		'expansion))

  (define-syntax-rule (doit* ?standard-language-form ?expected-result)
    (check
	(%expand (quasiquote ?standard-language-form))
      => (quasiquote ?expected-result)))

  (define-syntax-rule (libdoit* ?standard-language-form ?expected-result)
    (check
	(gensyms->symbols (%expand-library (quasiquote ?standard-language-form)))
      => (quasiquote ?expected-result)))

;;; --------------------------------------------------------------------

  (doit* (fx+ 1 2)
	 (annotated-call (fx+ 1 2)
			 (primitive fx+) '1 '2))

  (doit* ($symbol-string 'ciao)
	 (annotated-call ($symbol-string 'ciao)
			 (primitive $symbol-string) 'ciao))

;;; --------------------------------------------------------------------

  (libdoit* (library (expansion-demo-1)
	      (export a b)
	      (import (rnrs)
		(libtest compiler-internals))
	      (define a
		(a-func 1 2))
	      (define (b)
		1))
	    (library-letrec* ((a a (annotated-call (a-func 1 2) a-func (quote 1) (quote 2)))
			      (b b (annotated-case-lambda b (() (quote 1)))))
	      (quote #!void)))

  #t)


(parametrise ((check-test-name		'recordisation))

  (define (%recordise core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-syntax-rule (doit ?core-language-form ?expected-result)
    (check
	(%recordise (quasiquote ?core-language-form))
      => (quasiquote ?expected-result)))

  (define-syntax-rule (doit* ?standard-language-form ?expected-result)
    (doit ,(%expand (quasiquote ?standard-language-form)) ?expected-result))

  (define-syntax-rule (libdoit* ?standard-language-form ?expected-result)
    (doit ,(%expand-library (quasiquote ?standard-language-form)) ?expected-result))

;;; --------------------------------------------------------------------
;;; primitive function calls and primitive operation calls

  (doit* (fx+ 1 2)
	 (funcall (primref fx+) (constant 1) (constant 2)))
  (doit ((primitive fx+) '1 '2)
	(funcall (primref fx+) (constant 1) (constant 2)))
  (doit (annotated-call (fx+ 1 2)
			(primitive fx+) '1 '2)
	(funcall (primref fx+) (constant 1) (constant 2)))

  (doit* ($symbol-string 'ciao)
	 (funcall (primref $symbol-string) (constant ciao)))
  (doit ((primitive $symbol-string) 'ciao)
	(funcall (primref $symbol-string) (constant ciao)))

;;; --------------------------------------------------------------------
;;; let bindings

  (doit* (let ((a '1))
	   (let ((a '2))
	     (let ((a '3))
	       a)))
	 (bind ((a_0 (constant 1)))
	   (bind ((a_1 (constant 2)))
	     (bind ((a_2 (constant 3)))
	       a_2))))

  (doit* (let ((a '1))
	   (let ((a a))
	     (let ((a a))
	       a)))
	 (bind ((a_0 (constant 1)))
	   (bind ((a_1 a_0))
	     (bind ((a_2 a_1))
	       a_2))))

;;; --------------------------------------------------------------------
;;; sequences

  (doit* (begin '1 '2 '3)
	 (seq (constant 1) (constant 2) (constant 3)))

;;; --------------------------------------------------------------------
;;; libraries

  ;;This is the (libtest compiler-internals) library.
  (libdoit* (library (recordize-demo-0)
	      (export a-func a-thunk a-const)
	      (import (rnrs (6)))
	      (define (a-func a b)
		(+ a b))
	      (define (a-thunk)
		"ciao")
	      (define a-const 123))
	    (rec*bind ((a-func_0  (lambda (a_0 b_0) (funcall (primref +) a_0 b_0)))
		       (a-thunk_0 (lambda () (constant "ciao")))
		       (a-const_0 (constant 123)))
	      (constant #!void)))

  ;;How reference imported bindings are recordised.
  (libdoit* (library (recordize-demo-1)
	      (export)
	      (import (rnrs)
		(libtest compiler-internals))
	      (list a-const
		    (a-thunk)
		    (a-func 1 2)))
	    (rec*bind ()
	      (funcall (primref list)
		(funcall (primref top-level-value) (constant a-const))
		(funcall (funcall (primref top-level-value) (constant a-thunk)))
		(funcall (funcall (primref top-level-value) (constant a-func))
		  (constant 1) (constant 2)))))

  ;;Record type definition.
  (libdoit* (library (recordize-demo-2)
	      (export make-a a?)
	      (import (rnrs))
	      (define-record-type a))
	    (rec*bind ((a-rtd_0      (funcall (primref make-record-type-descriptor)
				       (constant a) (constant #f) (constant #f)
				       (constant #f) (constant #f) (constant #())))
		       (a-protocol_0 (constant #f))
		       (a-rcd_0      (funcall (primref make-record-constructor-descriptor)
				       a-rtd_0 (constant #f) a-protocol_0))
		       (a?_0         (funcall (primref record-predicate) a-rtd_0))
		       (make-a_0     (funcall (primref record-constructor) a-rcd_0))
		       (a-first-field-offset_0
			(funcall (primref $struct-ref) a-rtd_0 (constant 3))))
	      (constant #!void)))

;;; --------------------------------------------------------------------
;;; debug calls, no annotation

  (parametrise ((compiler.generate-debug-calls #t))

    (doit* (list '1 '2)
	   (funcall (primref debug-call) (constant (#f . (list '1 '2)))
		    (primref list) (constant 1) (constant 2)))

    (doit* ((lambda (x y) (list x y)) '1 '2)
	   (funcall (primref debug-call)
	     (constant (#f . ((lambda (x y) (list x y)) '1 '2)))
	     (lambda (x_0 y_0)
	       (funcall (primref debug-call)
		 (constant (#f . (list x y)))
		 (primref list)
		 x_0 y_0))
	     (constant 1) (constant 2)))

    (doit* ((lambda (x) x) '1)
	   (funcall (primref debug-call)
	     (constant (#f . ((lambda (x) x) '1)))
	     (lambda (x_0) x_0)
	     (constant 1)))

    (doit* (let ((x '1)
		 (y '2))
	     (list x y))
	   (bind ((x_0 (constant 1))
		  (y_0 (constant 2)))
	     (funcall (primref debug-call) (constant (#f . (list x y)))
		      (primref list) x_0 y_0)))

    (doit* (let ((f (lambda (x) x)))
	     (f '1))
	   (bind ((f_0 (lambda (x_0) x_0)))
	     (funcall (primref debug-call) (constant (#f . (f '1)))
		      f_0 (constant 1))))

    #f)

;;; --------------------------------------------------------------------
;;; debug calls, annotation

;;;The format of the annotation is:
;;;
;;;   (constant (?annotation-source . ?source-form))
;;;
;;;where ?ANNOTATION-SOURCE has one of the formats:
;;;
;;;   #f
;;;   (?port-identifier . ?first-character-offset)
;;;

  (parametrise ((compiler.generate-debug-calls #t))

    (doit* ,(%make-annotated-form '(list 1 2))
	   (funcall (primref debug-call)
	     (constant (("*string-input-port*" . 0) . (list 1 2)))
	     (primref list)
	     (constant 1) (constant 2)))

    (doit* ,(%make-annotated-form '((lambda (x) x) 1))
	   (funcall (primref debug-call)
	     (constant (("*string-input-port*" . 0) . ((lambda (x) x) 1)))
	     (lambda (x_0) x_0)
	     (constant 1)))

    (doit* ,(%make-annotated-form '(let ((x '1)
                           		 (y '2))
                           	     (list x y)))
	   (bind ((x_0 (constant 1))
		  (y_0 (constant 2)))
	     (funcall (primref debug-call)
	       (constant (("*string-input-port*" . 21) . (list x y)))
	       (primref list)
	       x_0 y_0)))

    (doit* ,(%make-annotated-form '(let ((f (lambda (x) x)))
				     (f '1)))
	   (bind ((f_0 (lambda (x_0) x_0)))
	     (funcall (primref debug-call)
	       (constant (("*string-input-port*". 26) . (f '1)))
	       f_0
	       (constant 1))))

    (doit* ,(%make-annotated-form '((let ((f (lambda (x) x)))
				      f)
				    1))
	   (funcall (primref debug-call)
	     (constant (("*string-input-port*" . 0) . ((let ((f (lambda (x) x))) f) 1)))
	     (bind ((f_0 (lambda (x_0) x_0))) f_0)
	     (constant 1)))

    #f)

  #t)


(parametrise ((check-test-name		'direct-calls-optimisation))

  (define (%optimize-direct-calls core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (D (compiler.optimize-direct-calls D))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-syntax-rule (doit ?core-language-form ?expected-result)
    (check
	(%optimize-direct-calls (quasiquote ?core-language-form))
      => (quasiquote ?expected-result)))

  (define-syntax-rule (doit* ?standard-language-form ?expected-result)
    (doit ,(%expand (quasiquote ?standard-language-form)) ?expected-result))

  (define-syntax-rule (libdoit* ?standard-language-form ?expected-result)
    (doit ,(%expand-library (quasiquote ?standard-language-form)) ?expected-result))

;;; --------------------------------------------------------------------
;;; simple demos

  (doit* (fx+ 1 2)
	 (funcall (primref fx+) (constant 1) (constant 2)))

;;; --------------------------------------------------------------------
;;; CLAMBDA integration

  (doit* ((lambda (x) x) '1)
	 (bind ((x_0 (constant 1)))
	   x_0))

  (doit* ((case-lambda
	   ((x y) y)
	   ((x) x)
	   (args args))
	  '1)
	 (bind ((x_0 (constant 1)))
	   x_0))

;;; --------------------------------------------------------------------
;;; binding forms integration

  (doit* ((let ((x '1))
	    (lambda (y) (list x y)))
	  '2)
	 (bind ((x_0 (constant 1)))
	   (bind ((y_0 (constant 2)))
	     (funcall (primref list) x_0 y_0))))

  ;;CLAMBDA body
  (doit ((let ((x '1))
	   (lambda (y) ((primitive list) x y)))
	 '2)
	(bind ((x_0 (constant 1)))
	  (bind ((y_0 (constant 2)))
	    (funcall (primref list) x_0 y_0))))

  ;;CLAMBDA body
  (doit ((letrec ((x '1))
	   (lambda (y) ((primitive list) x y)))
	 '2)
	(recbind ((x_0 (constant 1)))
	  (bind ((y_0 (constant 2)))
	    (funcall (primref list) x_0 y_0))))

  ;;CLAMBDA body
  (doit ((letrec* ((x '1))
	   (lambda (y) ((primitive list) x y)))
	 '2)
	(rec*bind ((x_0 (constant 1)))
	  (bind ((y_0 (constant 2)))
	    (funcall (primref list) x_0 y_0))))

  ;;prelex body
  (doit ((let ((f (lambda (y) y)))
	   f)
	 '1)
	(bind ((f_0 (lambda (y_0) y_0)))
	  (funcall f_0 (constant 1))))

  ;;prelex body
  (doit ((letrec ((f (lambda (y) y)))
	   f)
	 '1)
	(recbind ((f_0 (lambda (y_0) y_0)))
	  (funcall f_0 (constant 1))))

  ;;prelex body
  (doit ((letrec* ((f (lambda (y) y)))
	   f)
	 '1)
	(rec*bind ((f_0 (lambda (y_0) y_0)))
	  (funcall f_0 (constant 1))))

  ;;multiple expressions body
  (doit ((let ((x '1))
	   (begin
	     ((primitive display) '1)
	     (lambda (y) ((primitive list) x y))))
	 '2)
	(bind ((x_0 (constant 1)))
	  (bind ((tmp_0 (seq
			  (funcall (primref display) (constant 1))
			  (lambda (y_0)
			    (funcall (primref list) x_0 y_0)))))
	    (funcall tmp_0 (constant 2)))))

;;; --------------------------------------------------------------------
;;; call-with-values

  ;;No possible integration.
  (doit* (call-with-values
	     (lambda ()
	       (values (read) (read)))
	   (lambda (x y)
	     (list x y)))
	 (funcall (primref call-with-values)
	   (lambda ()
	     (funcall (primref values) (funcall (primref read)) (funcall (primref read))))
	   (lambda (x_0 y_0)
	     (funcall (primref list) x_0 y_0))))

  ;;Consumer is a CLAMBDA with single argument.
  (doit* (call-with-values
	     (lambda ()
	       (read))
	   (lambda (x)
	     (list x)))
	 (bind ((x_0 (bind ()
		       (funcall (primref read)))))
	   (funcall (primref list) x_0)))

;;; --------------------------------------------------------------------
;;; special cases

  (doit* (cond ((read)
		=> (lambda (Y)
		     (write Y)))
	       (else
		(read)))
	 (bind ((t_0 (funcall (primref read))))
	   (conditional t_0
	       (bind ((Y_0 t_0))
		 (funcall (primref write) Y_0))
	     (funcall (primref read)))))

;;; --------------------------------------------------------------------
;;; debugging calls

  (parametrise ((compiler.generate-debug-calls #t))

    (doit* ,(%make-annotated-form '((lambda (x) x) '1))
	   (bind ((x_0 (constant 1)))
	     x_0))

    (doit* ,(%make-annotated-form '((let ((f (lambda (y) y)))
				      f)
				    1))
	   (bind ((f_0 (lambda (y_0) y_0)))
	     (funcall (primref debug-call)
	       (constant (("*string-input-port*" . 0) . ((let ((f (lambda (y) y))) f) 1)))
	       f_0 (constant 1))))

    #f)

  #t)


(parametrise ((check-test-name	'basic-optimize-letrec))

;;;We test the "basic"  here because it is very simple and does  not need many tests.
;;;We do the "waddell" and "scc" tests below.

  (define (%optimize-letrec core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (D (compiler.optimize-direct-calls D))
	   (D (compiler.optimize-letrec D))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-auxiliary-syntaxes basic waddell scc)

  (define-syntax doit
    (syntax-rules ()
      ((_ ?core-language-form ?expected-result/basic)
       (check
	   (parametrise ((compiler.current-letrec-pass 'basic))
	     (%optimize-letrec (quasiquote ?core-language-form)))
	 => (quasiquote ?expected-result/basic)))
      ))

  (define-syntax doit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result/basic)
       (doit ,(%expand (quasiquote ?standard-language-form)) ?expected-result/basic))
      ))

  (define-syntax libdoit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result/basic)
       (doit ,(%expand-library (quasiquote ?standard-language-form)) ?expected-result/basic))
      ))

;;; --------------------------------------------------------------------

  (doit (letrec ((a '1))
	  '#f)
	(bind ((a_0 (constant #!void)))
	  (bind ((a_1 (constant 1)))
	    (seq
	      (assign a_0 a_1)
	      (constant #f)))))

  (doit (letrec* ((a '1))
	  '#f)
	(bind ((a_0 (constant #!void)))
	  (seq
	    (assign a_0 (constant 1))
	    (constant #f))))

  (doit (letrec ((a (lambda () (quote 1))))
	  a)
	(bind ((a_0 (constant #!void)))
	  (bind ((a_1 (lambda () (constant 1))))
	    (seq
	      (assign a_0 a_1)
	      a_0))))

  (doit* (letrec ((a (lambda () (quote 1)))
		  (b (lambda () (quote 2))))
	   (list (a) (b)))
	 (bind ((a_0 (constant #!void))
		(b_0 (constant #!void)))
	   (bind ((a_1 (lambda () (constant 1)))
		  (b_1 (lambda () (constant 2))))
	     (seq
	       (assign a_0 a_1)
	       (assign b_0 b_1)
	       (funcall (primref list) (funcall a_0) (funcall b_0))))))

;;; --------------------------------------------------------------------

  (doit (letrec* ((a (quote 1)))
	  a)
	(bind ((a_0 (constant #!void)))
	  (seq
	    (assign a_0 (constant 1))
	    a_0)))

  (doit (letrec* ((a (lambda () (quote 1))))
	  a)
	(bind ((a_0 (constant #!void)))
	  (seq
	    (assign a_0 (lambda () (constant 1)))
	    a_0)))

  (doit* (letrec* ((a (lambda () (quote 1)))
		   (b (lambda () (quote 2))))
	   (list (a) (b)))
	 (bind ((a_0 (constant #!void))
		(b_0 (constant #!void)))
	   (seq
	     (assign a_0 (lambda () (constant 1)))
	     (assign b_0 (lambda () (constant 2)))
	     (funcall (primref list) (funcall a_0) (funcall b_0)))))

;;; --------------------------------------------------------------------
;;; special

  (libdoit* (library (optimize-letrec-basic-demo)
	      (export a b c)
	      (import (rnrs))
	      (define (a) 1)
	      (define (b) (a) 2)
	      (define (c) (b) 3))
	    (bind ((a_0 (constant #!void))
		   (b_0 (constant #!void))
		   (c_0 (constant #!void)))
	      (seq
		(assign-init a_0 (lambda () (constant 1)))
		(assign-init b_0 (lambda () (seq (funcall a_0) (constant 2))))
		(assign-init c_0 (lambda () (seq (funcall b_0) (constant 3))))
		(constant #!void))))

;;; --------------------------------------------------------------------
;;; nested binding forms: nested RHS

  ;;nested LET RHS
  (doit (letrec* ((a (lambda () '1))
		  (c (let ((b '2))
		       ((primitive +) a b)))
		  (d (lambda () '4)))
	  ((primitive list) a c d))
	(bind ((a_0 (constant #!void))
	       (b_0 (constant #!void))
	       (b_1 (constant #!void))
	       (c_0 (constant #!void))
	       (d_0 (constant #!void)))
	  (seq
	    (assign a_0 (lambda () (constant 1)))
	    (assign b_0 (constant 2))
	    (assign b_1 b_0)
	    (assign c_0 (funcall (primref +) a_0 b_1))
	    (assign d_0 (lambda () (constant 4)))
	    (funcall (primref list) a_0 c_0 d_0))))

  ;;nested LETREC RHS
  (doit (letrec* ((a (lambda () '1))
		  (c (letrec ((b '2))
		       ((primitive +) a b)))
		  (d (lambda () '4)))
	  ((primitive list) a c d))
	(bind ((a_0 (constant #!void))
	       (b_0 (constant #!void))
	       (b_1 (constant #!void))
	       (c_0 (constant #!void))
	       (d_0 (constant #!void)))
	  (seq
	    (assign a_0 (lambda () (constant 1)))
	    (assign b_0 (constant 2))
	    (assign b_1 b_0)
	    (assign c_0 (funcall (primref +) a_0 b_1))
	    (assign d_0 (lambda () (constant 4)))
	    (funcall (primref list) a_0 c_0 d_0))))

  ;;nested LETREC* RHS
  (doit (letrec* ((a (lambda () '1))
		  (c (letrec* ((b '2))
		       ((primitive +) a b)))
		  (d (lambda () '4)))
	  ((primitive list) a c d))
	(bind ((a_0 (constant #!void))
	       (b_0 (constant #!void))
	       (b_1 (constant #!void))
	       (c_0 (constant #!void))
	       (d_0 (constant #!void)))
	  (seq
	    (assign a_0 (lambda () (constant 1)))
	    (assign b_0 (constant 2))
	    (assign b_1 b_0)
	    (assign c_0 (funcall (primref +) a_0 b_1))
	    (assign d_0 (lambda () (constant 4)))
	    (funcall (primref list) a_0 c_0 d_0))))

  ;;preparatory exapmle for the double nested LETREC* and LET RHS below
  (doit (letrec* ((d '3)
		  (e (let ((g '5))
		       ((primitive list) d g)))
		  (f '4))
	  ((primitive list) d e f))
	(bind ((d_0 (constant #!void))
	       (g_0 (constant #!void))
	       (g_1 (constant #!void))
	       (e_0 (constant #!void))
	       (f_0 (constant #!void)))
	  (seq
	    (assign d_0 (constant 3))
	    (assign g_0 (constant 5))
	    (assign g_1 g_0)
	    (assign e_0 (funcall (primref list) d_0 g_1))
	    (assign f_0 (constant 4))
	    (funcall (primref list) d_0 e_0 f_0))))

  ;;double nested LETREC* and LET RHS
  (doit (letrec* ((a (lambda () '1))
		  (b (letrec* ((d '3)
			       (e (let ((g '5))
				    ((primitive list) d g)))
			       (f '4))
		       ((primitive list) d e f)))
		  (c (lambda () '2)))
	  ((primitive list) a b c))
	(bind ((a_0 (constant #!void))
	         (d_0 (constant #!void))
	         (g_0 (constant #!void))
	         (g_1 (constant #!void))
	         (e_0 (constant #!void))
	         (f_0 (constant #!void))
	       (d_1 (constant #!void))
	       (g_2 (constant #!void))
	       (g_3 (constant #!void))
	       (e_1 (constant #!void))
	       (f_1 (constant #!void))
	       (b_0 (constant #!void))
	       (c_0 (constant #!void)))
	  (seq (assign a_0 (lambda () (constant 1)))
	       (assign d_0 (constant 3)) (assign g_0 (constant 5))
	       (assign g_1 g_2)
	       (assign e_0 (funcall (primref list) d_1 g_3))
	       (assign f_0 (constant 4)) (assign d_1 d_0)
	       (assign g_2 g_0) (assign g_3 g_1) (assign e_1 e_0)
	       (assign f_1 f_0)
	       (assign b_0 (funcall (primref list) d_1 e_1 f_1))
	       (assign c_0 (lambda () (constant 2)))
	       (funcall (primref list) a_0 b_0 c_0))))

;;; --------------------------------------------------------------------
;;; nested binding forms: nested body

  ;;nested LET body
  (doit (letrec* ((a (lambda () '1)))
	  (let ((b (lambda () '2)))
	    ((primitive list) a b)))
	(bind ((a_0 (constant #!void))
	       (b_0 (constant #!void)))
	  (seq
	    (assign a_0 (lambda () (constant 1)))
	    (assign b_0 (lambda () (constant 2)))
	    (funcall (primref list) a_0 b_0))))

  ;;nested LETREC body
  (doit (letrec* ((a (lambda () '1)))
	  (letrec ((b (lambda () '2)))
	    ((primitive list) a b)))
	(bind ((a_0 (constant #!void))
	       (b_0 (constant #!void)))
	  (seq
	    (assign a_0 (lambda () (constant 1)))
	    (assign b_0 (lambda () (constant 2)))
	    (funcall (primref list) a_0 b_0))))

  ;;nested LETREC* body
  (doit (letrec* ((a (lambda () '1)))
	  (letrec* ((b (lambda () '2)))
	    ((primitive list) a b)))
	(bind ((a_0 (constant #!void))
	       (b_0 (constant #!void)))
	  (seq
	    (assign a_0 (lambda () (constant 1)))
	    (assign b_0 (lambda () (constant 2)))
	    (funcall (primref list) a_0 b_0))))

  ;;double nested LETREC* body
  (doit (letrec* ((a (lambda () '1)))
	  (letrec* ((b (lambda () '2)))
	    (letrec* ((c (lambda () '3)))
	      ((primitive list) a b c))))
	(bind ((a_0 (constant #!void))
	       (b_0 (constant #!void))
	       (c_0 (constant #!void)))
	  (seq
	    (assign a_0 (lambda () (constant 1)))
	    (assign b_0 (lambda () (constant 2)))
	    (assign c_0 (lambda () (constant 3)))
	    (funcall (primref list) a_0 b_0 c_0))))

  #t)


(parametrise ((check-test-name	'optimize-letrec))

;;;Test the "waddell" and  "scc" transformations here, side by side,  to make it easy
;;;to  compare  the results.   Every  test  that is  interesting  for  "scc" is  also
;;;interesting for "waddell".

  (define (%optimize-letrec core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (D (compiler.optimize-direct-calls D))
	   (D (compiler.optimize-letrec D))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-auxiliary-syntaxes waddell scc)

  (define-syntax doit
    (syntax-rules (waddell scc)
      ((_ ?core-language-form
	  (waddell	?expected-result/waddell)
	  (scc		?expected-result/scc))
       (begin
	 (check
	     (parametrise ((compiler.current-letrec-pass 'waddell))
	       (%optimize-letrec (quasiquote ?core-language-form)))
	   => (quasiquote ?expected-result/waddell))
	 (check
	     (parametrise ((compiler.current-letrec-pass 'scc))
	       (%optimize-letrec (quasiquote ?core-language-form)))
	   => (quasiquote ?expected-result/scc))
	 ))
      ))

  (define-syntax doit*
    (syntax-rules (waddell scc)
      ((_ ?standard-language-form
	  (waddell	?expected-result/waddell)
	  (scc		?expected-result/scc))
       ;;We want the ?STANDARD-LANGUAGE-FORM to appear  in the output of CHECK when a
       ;;test fails.
       (doit ,(%expand (quasiquote ?standard-language-form))
	     (waddell		?expected-result/waddell)
	     (scc		?expected-result/scc)))
      ))

;;; --------------------------------------------------------------------
;;; single bindings, simple RHS expressions

  ;;Single, unused binding.
  ;;
  (doit (letrec ((a '1))
	  '#f)
	(waddell
	 (bind ((a_0 (constant 1))) ;simple
	   (constant #f)))
	(scc
	 (bind ((a_0 (constant 1)))
	   (constant #f))))

  (doit (letrec* ((a '1))
	  '#f)
	(waddell
	 (bind ((a_0 (constant 1))) ;simple
	   (constant #f)))
	(scc
	 (bind ((a_0 (constant 1)))
	   (constant #f))))

  ;;Single, referenced, unassigned binding.
  ;;
  (doit (letrec ((a '1))
	  a)
	(waddell
	 (bind ((a_0 (constant 1))) ;simple
	   a_0))
	(scc
	 (bind ((a_0 (constant 1)))
	   a_0)))

  (doit (letrec* ((a '1))
	  a)
	(waddell
	 (bind ((a_0 (constant 1))) ;simple
	   a_0))
	(scc
	 (bind ((a_0 (constant 1)))
	   a_0)))

  (doit* (letrec ((a '1))
	   (let ((a a))
	     a))
	 (waddell
	  (bind ((a_0 (constant 1)))
	    (bind ((a_1 a_0))
	      a_1)))
	 (scc
	  (bind ((a_0 (constant 1)))
	    (bind ((a_1 a_0))
	      a_1))))

  (doit* (letrec* ((a '1))
	   (let ((a a))
	     a))
	 (waddell
	  (bind ((a_0 (constant #!void))
		 (a_1 (constant #!void)))
	    (seq
	      (assign a_0 (constant 1))
	      (assign a_1 a_0)
	      a_1)))
	 (scc
	  (bind ((a_0 (constant 1)))
	    (bind ((a_1 a_0))
	      a_1))))

  ;;Single, unreferenced, assigned binding.
  ;;
  (doit (letrec ((a '1))
	  (begin
	    (set! a (quote 2))
	    '#f))
	(waddell
	 (bind ((a_0 (constant #!void))) ;complex
	   (bind ((a_1 (constant 1)))	 ;tmp
	     (seq
	       (assign a_0 a_1)
	       (assign a_0 (constant 2))
	       (constant #f)))))
	(scc
	 (bind ((a_0 (constant 1)))
	   (seq
	     (assign a_0 (constant 2))
	     (constant #f)))))
  (doit (letrec* ((a '1))
	  (begin
	    (set! a (quote 2))
	    '#f))
	(waddell
	 (bind ((a_0 (constant #!void))) ;complex
	   (seq
	     (assign a_0 (constant 1))
	     (assign a_0 (constant 2))
	     (constant #f))))
	(scc
	 (bind ((a_0 (constant 1)))
	   (seq
	     (assign a_0 (constant 2))
	     (constant #f)))))


  ;;Single, referenced, assigned binding.
  ;;
  (doit (letrec ((a '1))
	  (begin
	    (set! a (quote 2))
	    a))
	(waddell
	 (bind ((a_0 (constant #!void))) ;complex
	   (bind ((a_1 (constant 1)))    ;tmp
	     (seq
	       (assign a_0 a_1)
	       (assign a_0 (constant 2))
	       a_0))))
	(scc
	 (bind ((a_0 (constant 1))) ;complex
	   (seq
	     (assign a_0 (constant 2))
	     a_0))))
  (doit (letrec* ((a '1))
	  (begin
	    (set! a (quote 2))
	    a))
	(waddell
	 (bind ((a_0 (constant #!void))) ;complex
	   (seq
	     (assign a_0 (constant 1))
	     (assign a_0 (constant 2))
	     a_0)))
	(scc
	 (bind ((a_0 (constant 1))) ;complex
	   (seq
	     (assign a_0 (constant 2))
	     a_0))))

;;; --------------------------------------------------------------------
;;; single bindings, lambda RHS expressions


  ;;Single, unreferenced, unassigned,  lambda binding is classified  as "fixable", so
  ;;it ends in a FIX form.
  ;;
  (doit (letrec ((a (lambda () '1)))
	  '#f)
	(waddell
	 (fix ((a_0 (lambda () (constant 1))))
	   (constant #f)))
	(scc
	 (fix ((a_0 (lambda () (constant 1))))
	   (constant #f))))
  (doit (letrec* ((a (lambda () '1)))
	  '#f)
	(waddell
	 (fix ((a_0 (lambda () (constant 1))))
	   (constant #f)))
	(scc
	 (fix ((a_0 (lambda () (constant 1))))
	   (constant #f))))


  ;;Single, referenced, unassigned,  lambda binding is classified as  "fixable", so it
  ;;ends in a FIX form.
  ;;
  (doit (letrec ((a (lambda () '1)))
	  a)
	(waddell
	 (fix ((a_0 (lambda () (constant 1))))
	   a_0))
	(scc
	 (fix ((a_0 (lambda () (constant 1))))
	   a_0)))
  (doit (letrec* ((a (lambda () '1)))
	  a)
	(waddell
	 (fix ((a_0 (lambda () (constant 1))))
	   a_0))
	(scc
	 (fix ((a_0 (lambda () (constant 1))))
	   a_0)))

  ;;Single, unreferenced, assigned, lambda binding is classified as "complex".
  ;;
  (doit (letrec ((a (lambda () '1)))
	  (begin
	    (set! a '1)
	    '#f))
	(waddell
	 (bind ((a_0 (constant #!void)))
	   (bind ((a_1 (lambda () (constant 1))))
	     (seq
	       (assign a_0 a_1)
	       (assign a_0 (constant 1))
	       (constant #f)))))
	(scc
	 (bind ((a_0 (lambda () (constant 1))))
	   (seq
	     (assign a_0 (constant 1))
	     (constant #f)))))
  (doit (letrec* ((a (lambda () '1)))
	  (begin
	    (set! a '1)
	    '#f))
	(waddell
	 (bind ((a_0 (constant #!void)))
	   (seq
	     (assign a_0 (lambda () (constant 1)))
	     (assign a_0 (constant 1))
	     (constant #f))))
	(scc
	 (bind ((a_0 (lambda () (constant 1))))
	   (seq
	     (assign a_0 (constant 1))
	     (constant #f)))))

  ;;Single, referenced, assigned, lambda binding is classified as "complex".
  ;;
  (doit (letrec ((a (lambda () '1)))
	  (begin
	    (set! a '1)
	    a))
	(waddell
	 (bind ((a_0 (constant #!void)))
	   (bind ((a_1 (lambda () (constant 1))))
	     (seq
	       (assign a_0 a_1)
	       (assign a_0 (constant 1))
	       a_0))))
	(scc
	 (bind ((a_0 (lambda () (constant 1))))
	   (seq
	     (assign a_0 (constant 1))
	     a_0))))
  (doit (letrec* ((a (lambda () '1)))
	  (begin
	    (set! a '1)
	    a))
	(waddell
	 (bind ((a_0 (constant #!void)))
	   (seq
	     (assign a_0 (lambda () (constant 1)))
	     (assign a_0 (constant 1))
	     a_0)))
	(scc
	 (bind ((a_0 (lambda () (constant 1))))
	   (seq
	     (assign a_0 (constant 1))
	     a_0))))

;;; --------------------------------------------------------------------
;;; multiple simple RHS expressions

  ;;Multiple referenced, unassigned bindings.
  ;;
  (doit* (letrec ((a '1)
		  (b '2))
	   (list a b))
	 (waddell
	  (bind ((a_0 (constant 1))
		 (b_0 (constant 2)))
	    (funcall (primref list) a_0 b_0)))
	 (scc
	  (bind ((a_0 (constant 1)))
	    (bind ((b_0 (constant 2)))
	      (funcall (primref list) a_0 b_0)))))
  (doit* (letrec* ((a '1)
		   (b '2))
	   (list a b))
	 (waddell
	  (bind ((a_0 (constant 1))
		 (b_0 (constant 2)))
	    (funcall (primref list) a_0 b_0)))
	 (scc
	  (bind ((a_0 (constant 1)))
	    (bind ((b_0 (constant 2)))
	      (funcall (primref list) a_0 b_0)))))

;;; --------------------------------------------------------------------
;;; multiple lambda RHS expressions

  ;;Multiple unreferenced, unassigned lambda bindings are classified as "fixable", so
  ;;they end in the same FIX form.
  ;;
  (doit (letrec ((a (lambda () '1))
		 (b (lambda () '2)))
	  '#f)
	(waddell
	 (fix ((a_0 (lambda () (constant 1)))
	       (b_0 (lambda () (constant 2))))
	   (constant #f)))
	(scc
	 (fix ((a_0 (lambda () (constant 1)))
	       (b_0 (lambda () (constant 2))))
	   (constant #f))))
  (doit (letrec* ((a (lambda () '1))
		  (b (lambda () '2)))
	  '#f)
	(waddell
	 (fix ((a_0 (lambda () (constant 1)))
	       (b_0 (lambda () (constant 2))))
	   (constant #f)))
	(scc
	 (fix ((a_0 (lambda () (constant 1)))
	       (b_0 (lambda () (constant 2))))
	   (constant #f))))

  ;;Multiple referenced, unassigned  lambda bindings are classified  as "fixable", so
  ;;they end in the same FIX form.
  ;;
  (doit (letrec ((a (lambda () (b)))
		 (b (lambda () (a))))
	  '#f)
	(waddell
	 (fix ((a_0 (lambda () (funcall b_0)))
	       (b_0 (lambda () (funcall a_0))))
	   (constant #f)))
	(scc
	 (fix ((b_0 (lambda () (funcall a_0)))
	       (a_0 (lambda () (funcall b_0))))
	   (constant #f))))
  (doit (letrec ((a (lambda () (b)))
		 (b (lambda () (a))))
	  a)
	(waddell
	 (fix ((a_0 (lambda () (funcall b_0)))
	       (b_0 (lambda () (funcall a_0))))
	   a_0))
	(scc
	 (fix ((b_0 (lambda () (funcall a_0)))
	       (a_0 (lambda () (funcall b_0))))
	   a_0)))
  (doit* (letrec ((a (lambda () (b)))
		  (b (lambda () (a))))
	   (list a b))
	 (waddell
	  (fix ((a_0 (lambda () (funcall b_0)))
		(b_0 (lambda () (funcall a_0))))
	    (funcall (primref list) a_0 b_0)))
	 (scc
	  (fix ((b_0 (lambda () (funcall a_0)))
		(a_0 (lambda () (funcall b_0))))
	    (funcall (primref list) a_0 b_0))))
  (doit (letrec* ((a (lambda () (b)))
		  (b (lambda () (a))))
	  '#f)
	(waddell
	 (fix ((a_0 (lambda () (funcall b_0)))
	       (b_0 (lambda () (funcall a_0))))
	   (constant #f)))
	(scc
	 (fix ((b_0 (lambda () (funcall a_0)))
	       (a_0 (lambda () (funcall b_0))))
	   (constant #f))))
  (doit (letrec* ((a (lambda () (b)))
		  (b (lambda () (a))))
	  a)
	(waddell
	 (fix ((a_0 (lambda () (funcall b_0)))
	       (b_0 (lambda () (funcall a_0))))
	   a_0))
	(scc
	 (fix ((b_0 (lambda () (funcall a_0)))
	       (a_0 (lambda () (funcall b_0))))
	   a_0)))
  (doit* (letrec* ((a (lambda () (b)))
		   (b (lambda () (a))))
	   (list a b))
	 (waddell
	  (fix ((a_0 (lambda () (funcall b_0)))
		(b_0 (lambda () (funcall a_0))))
	    (funcall (primref list) a_0 b_0)))
	 (scc
	  (fix ((b_0 (lambda () (funcall a_0)))
		(a_0 (lambda () (funcall b_0))))
	    (funcall (primref list) a_0 b_0))))

  ;;Here the  binding B is assigned,  even though in the  body of a LAMBDA;  for this
  ;;reason it cannot be classified as "fixable", rather it is classified as "complex".
  ;;
  (doit (letrec ((a (lambda () (b)))
		 (b (lambda () (set! a '123))))
	  '#f)
	(waddell
	 (bind ((a_0 (constant #!void)))		   ;complex
	   (fix ((b_0 (lambda () (assign a_0 (constant 123))))) ;lambda
	     (bind ((a_1 (lambda () (funcall b_0))))		   ;tmp
	       (seq
		 (assign a_0 a_1)
		 (constant #f))))))
	(scc
	 (bind ((a_0 (constant #!void)))		   ;complex
	   (fix ((b_0 (lambda () (assign a_0 (constant 123))))) ;lambda
	     (seq
	       (assign a_0 (lambda () (funcall b_0)))
	       (constant #f))))))


;;; --------------------------------------------------------------------
;;; misc RHS expressions

  ;;Weird case number 1.
  (doit (letrec* ((b (lambda () a))
		  (a (b)))
	  '#!void)
	(waddell
	 (bind ((a_0 (constant #!void)))
	   (fix ((b_0 (lambda () a_0)))
	     (seq
	       (assign a_0 (funcall b_0))
	       (constant #!void)))))
	(scc
	 (bind ((a_0 (constant #!void)))
	   (fix ((b_0 (lambda () a_0)))
	     (seq
	       (assign a_0 (funcall b_0))
	       (constant #!void))))))

  ;;Weird case number 2.
  (doit (letrec* ((b (lambda () ((primitive list) a)))
		  (a (b)))
	  '#!void)
	(waddell
	 (bind ((a_0 (constant #!void)))
	   (fix ((b_0 (lambda () (funcall (primref list) a_0))))
	     (seq
	       (assign a_0 (funcall b_0))
	       (constant #!void)))))
	(scc
	 (bind ((a_0 (constant #!void)))
	   (fix ((b_0 (lambda () (funcall (primref list) a_0))))
	     (seq
	       (assign a_0 (funcall b_0))
	       (constant #!void))))))

  ;;With waddell: the binding C is not "simple"  because it is assigned in the RHS of
  ;;D.
  ;;
  (doit* (letrec* ((a (lambda (x)
			(when x
			  (a '#f))))
		   (b '123)
		   (c '456)
		   (d (begin
			(set! c '789)
			'9)))
	   a)
	 (waddell
	  (bind ((b_0 (constant 123)))
	    (bind ((c_0 (constant #!void))
		   (d_0 (constant #!void)))
	      (fix ((a_0 (lambda (x_0)
			   (conditional x_0
			       (funcall a_0 (constant #f))
			     (constant #!void)))))
		(seq
		  (assign c_0 (constant 456))
		  (assign d_0 (seq
				(assign c_0 (constant 789))
				(constant 9)))
		  a_0)))))
	 (scc
	  (fix ((a_0 (lambda (x_0)
		       (conditional x_0
			   (funcall a_0 (constant #f))
			 (constant #!void)))))
	    (bind ((b_0 (constant 123)))
	      (bind ((c_0 (constant 456)))
		(bind ((d_0 (seq
			      (assign c_0 (constant 789))
			      (constant 9))))
		  a_0))))))

  ;;The binding  A is  referenced in  a RHS, so  it cannot  be "simple"  according to
  ;;waddell.
  ;;
  (doit* (letrec* ((a '1)
		   (b a))
	   b)
	 (waddell
	  (bind ((a_0 (constant #!void))
		 (b_0 (constant #!void)))
	    (seq
	      (assign a_0 (constant 1))
	      (assign b_0 a_0)
	      b_0)))
	 (scc
	  (bind ((a_0 (constant 1)))
	    (bind ((b_0 a_0))
	      b_0))))

  ;;waddell: here the binding D is initialised  by a LAMBDA RHS expression, but later
  ;;it is  assigned; for  this reason  D cannot  end into  a FIX  form, rather  it is
  ;;classified as "complex".
  ;;
  (doit* (letrec ((a '123)
		  (d (lambda () '123)))
	   (set! d '123)
	   a)
	 (waddell
	  (bind ((a_0 (constant 123)))
	    (bind ((d_0 (constant #!void)))
	      (bind ((d_1 (lambda () (constant 123))))
		(seq
		  (assign d_0 d_1)
		  (assign d_0 (constant 123))
		  a_0)))))
	 (scc
	  (bind ((a_0 (constant 123)))
	    (bind ((d_0 (lambda () (constant 123))))
	      (seq
		(assign d_0 (constant 123))
		a_0)))))
  (doit* (letrec* ((a '123)
		   (d (lambda () '123)))
	   (set! d '123)
	   a)
	 (waddell
	  (bind ((a_0 (constant 123)))
	    (bind ((d_0 (constant #!void)))
	      (seq
		(assign d_0 (lambda () (constant 123)))
		(assign d_0 (constant 123))
		a_0))))
	 (scc
	  (bind ((a_0 (constant 123)))
	    (bind ((d_0 (lambda () (constant 123))))
	      (seq
		(assign d_0 (constant 123))
		a_0)))))

;;; --------------------------------------------------------------------
;;; special cases

  ;;References and assignments of LETREC and LETREC* bindings in LAMBDA bodies do not
  ;;make the binding "complex".

  ;;Binding referenced in lambda RHS.
  (doit (letrec ((a '1)
                 (b (lambda () a)))
          '#f)
	(waddell
	 (bind ((a_0 (constant #!void)))
	   (fix ((b_0 (lambda () a_0)))
	     (bind ((a_1 (constant 1)))
	       (seq
		 (assign a_0 a_1)
		 (constant #f))))))
	(scc
	 (bind ((a_0 (constant 1)))
	   (fix ((b_0 (lambda () a_0)))
	     (constant #f)))))
  (doit (letrec* ((a '1)
		  (b (lambda () a)))
          '#f)
	(waddell
	 (bind ((a_0 (constant #!void)))
	   (fix ((b_0 (lambda () a_0)))
	     (seq
	       (assign a_0 (constant 1))
	       (constant #f)))))
	(scc
	 (bind ((a_0 (constant 1)))
	   (fix ((b_0 (lambda () a_0)))
	     (constant #f)))))

  ;;Binding assigned in lambda RHS.
  (doit (letrec ((a '1)
                 (b (lambda () (set! a '2))))
          '#f)
	(waddell
	 (bind ((a_0 (constant #!void)))
	   (fix ((b_0 (lambda () (assign a_0 (constant 2)))))
	     (bind ((a_1 (constant 1)))
	       (seq
		 (assign a_0 a_1)
		 (constant #f))))))
	(scc
	 (bind ((a_0 (constant 1)))
	   (fix ((b_0 (lambda () (assign a_0 (constant 2)))))
	     (constant #f)))))

  (doit* (letrec ((a '1))
	   (let ((b (lambda () a)))
	     '#f))
	 (waddell
	  (bind ((a_0 (constant 1)))
	    (bind ((b_0 (lambda () a_0)))
	      (constant #f))))
	 (scc
	  (bind ((a_0 (constant 1)))
	    (bind ((b_0 (lambda () a_0)))
	      (constant #f)))))


  ;;waddell does not  distinguish between an assignment in the  RHS and an assignment
  ;;in the body.
  (doit* (letrec ((a '1))
	   (let ((b (lambda () (set! a '2))))
	     '#f))
	 (waddell
	  (bind ((a_0 (constant #!void)))
	    (bind ((a_1 (constant 1)))
	      (seq
		(assign a_0 a_1)
		(bind ((b_0 (lambda () (assign a_0 (constant 2)))))
		  (constant #f))))))
	 (scc
	  (bind ((a_0 (constant 1)))
	    (bind ((b_0 (lambda () (assign a_0 (constant 2)))))
	      (constant #f)))))

  (doit (letrec* ((a '1)
                  (b (lambda () a))
                  (c (b)))
          '#f)
        (waddell
	 (bind ((a_0 (constant #!void))	 ;complex
		(c_0 (constant #!void))) ;complex
	   (fix ((b_0 (lambda () a_0)))
	     (seq
	       (assign a_0 (constant 1))
	       (assign c_0 (funcall b_0))
	       (constant #f)))))
        (scc
	 (bind ((a_0 (constant 1)))
	   (fix ((b_0 (lambda () a_0)))
	     (bind ((c_0 (funcall b_0)))
	       (constant #f))))))

;;; --------------------------------------------------------------------
;;; special cases

  ;;RHS with side effects.
  (doit* (letrec* ((a '1)
		   (b (write a)))
	   a)
	 (waddell
	  (bind ((a_0 (constant #!void))
		 (b_0 (constant #!void)))
	    (seq
	      (assign a_0 (constant 1))
	      (assign b_0 (funcall (primref write) a_0))
	      a_0)))
	 (scc
	  (bind ((a_0 (constant 1)))
	    (bind ((b_0 (funcall (primref write) a_0)))
	      a_0))))

  ;;Function  call in  RHS expression  that does  not make  the enclosing  expression
  ;;"complex".
  (doit* (letrec* ((a '1)
		   (b ($fx+ '1 '2)))
	   a)
	 (waddell
	  (bind ((a_0 (constant 1))
		 (b_0 (funcall (primref $fx+) (constant 1) (constant 2))))
	    a_0))
	 (scc
	  (bind ((a_0 (constant 1)))
	    (bind ((b_0 (funcall (primref $fx+) (constant 1) (constant 2))))
	      a_0))))

  ;;Nested RHS LETREC.
  (doit (letrec* ((a '1)
		  (b (letrec* ((d (lambda () '4)))
		       (d)))
		  (c '2))
  	  b)
  	(waddell
  	 (bind ((a_0 (constant 1))
  		(c_0 (constant 2)))
	   (bind ((d_0 (constant #!void))
		  (b_0 (constant #!void)))
	     (fix ((d_1 (lambda () (constant 4))))
	       (seq
		 (assign d_0 d_1)
		 (assign b_0 (funcall d_0))
		 b_0)))))
  	(scc
  	 (bind ((a_0 (constant 1)))
  	   (fix ((d_0 (lambda () (constant 4))))
	     (bind ((d_1 d_0))
	       (bind ((b_0 (funcall d_1)))
		 (bind ((c_0 (constant 2)))
		   b_0)))))))

;;; --------------------------------------------------------------------
;;; libraries

  ;;This test will install the library!!!
  (check
      (parametrise ((compiler.current-letrec-pass 'waddell))
	(let* ((form1 '(library (optimize-letrec-waddell-demo-1)
			 (export a b c)
			 (import (rnrs))
			 (define (a) 1)
			 (define (b) (a) 2)
			 (define (c) (b) 3)))
	       (form2 (%expand-library form1)))
	  (%optimize-letrec form2)))
    => '(fix ((a_0 (lambda () (constant 1)))
	      (b_0 (lambda () (seq (funcall a_0) (constant 2))))
	      (c_0 (lambda () (seq (funcall b_0) (constant 3)))))
	  (constant #!void)))

  ;;This test will install the library!!!
  (check
      (parametrise ((compiler.current-letrec-pass 'scc))
	(let* ((form1 '(library (optimize-letrec-scc-demo-1)
			 (export a b c)
			 (import (rnrs))
			 (define (a) 1)
			 (define (b) (a) 2)
			 (define (c) (b) 3)))
	       (form2 (%expand-library form1)))
	  (%optimize-letrec form2)))
    => '(fix ((a_0 (lambda () (constant 1)))
	      (b_0 (lambda () (seq (funcall a_0) (constant 2))))
	      (c_0 (lambda () (seq (funcall b_0) (constant 3)))))
	  (constant #!void)))

  ;;Record type definition.
  (check
      (parametrise ((compiler.current-letrec-pass 'scc))
	(let* ((form1 '(library (optimize-letrec-scc-demo-2)
			 (export make-a a?)
			 (import (rnrs))
			 (define-record-type a)))
	       (form2 (%expand-library form1)))
	  (%optimize-letrec form2)))
    => '(bind ((a-rtd_0 (funcall (primref make-record-type-descriptor)
			  (constant a) (constant #f) (constant #f)
			  (constant #f) (constant #f) (constant #()))))
	  (bind ((a-protocol_0 (constant #f)))
	    (bind ((a-rcd_0 (funcall (primref make-record-constructor-descriptor)
			      a-rtd_0 (constant #f) a-protocol_0)))
	      (bind ((a?_0 (funcall (primref record-predicate) a-rtd_0)))
		(bind ((make-a_0 (funcall (primref record-constructor) a-rcd_0)))
		  (bind ((a-first-field-offset_0 (funcall (primref $struct-ref) a-rtd_0 (constant 3))))
		    (constant #!void))))))))

  #t)


(parametrise ((check-test-name	'rewrite-references-and-assignments))

  (define (%rewrite-references-and-assignments core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (D (compiler.optimize-direct-calls D))
	   (D (compiler.optimize-letrec D))
	   (D (compiler.source-optimize D))
	   (D (compiler.rewrite-references-and-assignments D))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-syntax doit
    (syntax-rules ()
      ((_ ?core-language-form ?expected-result)
       (check
	   (%rewrite-references-and-assignments (quasiquote ?core-language-form))
	 => (quasiquote ?expected-result)))
      ))

  (define-syntax doit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result)
       ;;We want the ?STANDARD-LANGUAGE-FORM to appear  in the output of CHECK when a
       ;;test fails.
       (doit ,(%expand (quasiquote ?standard-language-form))
	     ?expected-result))
      ))

;;; --------------------------------------------------------------------
;;; read-only bindings

  ;;Weird case  number 1.   Originally read-only bindings  that are  transformed into
  ;;read-write  bindings by  the SCC  letrec optimiser,  but then  retransformed into
  ;;read-only by the source optimiser.
  (doit (letrec* ((b (lambda () a))
		  (a (b)))
	  '#!void)
	(constant #!void))

;;; --------------------------------------------------------------------
;;; read-write bindings

  (doit* (let ((a '1))
	   (set! a '2)
	   a)
	 (bind ((a_0 (constant 1)))
	   (bind ((a_1 (funcall (primref vector) a_0)))
	     (seq
	       (funcall (primref $vector-set!) a_1 (constant 0) (constant 2))
	       (funcall (primref $vector-ref)  a_1 (constant 0))))))

  (doit* (let ((a '1)
	       (b '2))
	   (set! a '3)
	   (set! b '4)
	   (list a b))
	 (bind ((a_0 (constant 1))
		(b_0 (constant 2)))
	   (bind ((a_1 (funcall (primref vector) a_0))
		  (b_1 (funcall (primref vector) b_0)))
	     (seq
	       (funcall (primref $vector-set!) a_1 (constant 0) (constant 3))
	       (funcall (primref $vector-set!) b_1 (constant 0) (constant 4))
	       (funcall (primref list)
		 (funcall (primref $vector-ref) a_1 (constant 0))
		 (funcall (primref $vector-ref) b_1 (constant 0)))))))

  ;;Lambda form
  (doit* (lambda (a)
	   (display a)
	   (set! a 1)
	   a)
	 (lambda (a_0)
	   (bind ((a_1 (funcall (primref vector) a_0)))
	     (seq
	       (funcall (primref display)
		 (funcall (primref $vector-ref) a_1 (constant 0)))
	       (funcall (primref $vector-set!) a_1 (constant 0) (constant 1))
	       (funcall (primref $vector-ref)  a_1 (constant 0))))))

;;; --------------------------------------------------------------------
;;; LIBRARY-LETREC* forms

  ;;Simple unassigned bindings.
  (doit (library-letrec* ((a.lex a.loc '1)
			  (b.lex b.loc '2))
	  ((primitive display) a.lex b.lex))
	(bind ((a.lex_0 (constant 1)))
	  (bind ((b.lex_0 (constant 2)))
	    (funcall (primref display) (constant 1) (constant 2)))))

  ;;Simple assigned bindings.
  (doit (library-letrec* ((a.lex a.loc '1)
			  (b.lex b.loc '2))
	  (begin
	    (set! a.lex '11)
	    (set! b.lex '22)
	    ((primitive display) a.lex b.lex)))
	(bind ((a.lex_0 (constant 1)))
	  (bind ((b.lex_0 (constant 2)))
	    (seq
	      (funcall (primref $set-symbol-value!)
		(constant a.loc)
		(constant 11))
	      (funcall (primref $set-symbol-value!)
		(constant b.loc)
		(constant 22))
	      (funcall (primref display)
		(funcall (primref $symbol-value) (constant a.loc))
		(funcall (primref $symbol-value) (constant b.loc)))))))

  ;;Recursive top level binding with single init assignment.
  (doit (library-letrec* ((b.lex b.loc (lambda () a.lex))
			  (a.lex a.loc (b.lex)))
	  '#!void)
	(bind ((a.lex_0 (constant #!void)))
	  (fix ((b.lex_0 (lambda ()
			   (funcall (primref $symbol-value)
			     (constant a.loc)))))
	    (constant #!void))))

  ;;Recursive top level binding with assignment.
  (doit (library-letrec* ((a.lex a.loc (lambda () a.lex))
			  (b.lex b.loc (lambda () (set! a.lex '123))))
	  '#!void)
	(bind ((a.lex_0 (constant #!void)))
	  (seq
	    (funcall (primref $set-symbol-value!)
	      (constant a.loc)
	      (lambda ()
		(funcall (primref $symbol-value)
		  (constant a.loc))))
	    (fix ((b.lex_0 (lambda ()
			     (seq
			       (funcall (primref $set-symbol-value!)
				 (constant a.loc)
				 (constant 123))
			       (constant #!void)))))
	      (constant #!void)))))

  ;;All bindings in FIX.
  (doit (library-letrec*
	    ((a.lex a.loc (lambda () '1))
	     (b.lex a.loc (lambda () '2)))
	  ((primitive display) (a.lex)))
	(fix ((a.lex_0 (lambda () (constant 1)))
	      (b.lex_0 (lambda () (constant 2))))
	  (funcall (primref display) (constant 1))))

;;; --------------------------------------------------------------------
;;; libraries

;;;These tests will install the libraries!!!

  ;;All the bindings end in a FIX structure.
  (check
      (let* ((form1 '(library (rewrite-references-and-assignments-demo-1)
		       (export a b c)
		       (import (rnrs))
		       (define (a) 1)
		       (define (b) (read))
		       (define (c) (b))))
	     (form2 (%expand-library form1)))
	(%rewrite-references-and-assignments form2))
    => `(fix ((a_0 (lambda () (constant 1)))
	      (b_0 (lambda () (funcall (primref read))))
	      (c_0 (lambda () (funcall (primref read)))))
	  (constant ,(void))))

  (check
      (let* ((form1 '(library (rewrite-references-and-assignments-demo-2)
		       (export a b)
		       (import (rnrs)
			 (libtest compiler-internals))
		       (define a
			 (a-func 1 2))
		       (define (b)
			 1)))
	     (form2 (%expand-library form1)))
	(%rewrite-references-and-assignments form2))
    => '(bind ((a_0 (funcall (funcall (primref top-level-value) (constant a-func))
		      (constant 1)
		      (constant 2))))
	  (fix ((b_0 (lambda () (constant 1))))
	    (constant #!void))))

  ;;Record type definition.
  (check
      (let* ((form1 '(library (rewrite-references-and-assignments-demo-3)
		       (export make-a a?)
		       (import (rnrs))
		       (define-record-type a)))
	     (form2 (%expand-library form1)))
	(%rewrite-references-and-assignments form2))
    => '(bind ((a-rtd_0 (funcall (primref make-record-type-descriptor)
			  (constant a) (constant #f) (constant #f)
			  (constant #f) (constant #f) (constant #()))))
	  (bind ((a-protocol_0 (constant #f)))
	    (bind ((a-rcd_0 (funcall (primref make-record-constructor-descriptor)
			      (funcall (primref $symbol-value) (constant a-rtd))
			      (constant #f) (constant #f))))
	      (bind ((a?_0 (funcall (primref record-predicate)
			     (funcall (primref $symbol-value) (constant a-rtd)))))
		(bind ((make-a_0 (funcall (primref record-constructor)
				   (funcall (primref $symbol-value) (constant a-rcd)))))
		  (bind ((a-first-field-offset_0 (funcall (primref $struct-ref)
						   (funcall (primref $symbol-value) (constant a-rtd))
						   (constant 3))))
		    (constant #!void))))))))

  #f)


(parametrise ((check-test-name	'core-type-inference))

  (define (%core-type-inference core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (D (compiler.optimize-direct-calls D))
	   (D (compiler.optimize-letrec D))
	   ;;By skipping source optimisation we  make it simpler to write inspectable
	   ;;test cases.
	   #;(D (compiler.source-optimize D))
	   (D (compiler.rewrite-references-and-assignments D))
	   (D (compiler.core-type-inference D))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-syntax doit
    (syntax-rules ()
      ((_ ?core-language-form ?expected-result)
       (check
	   (%core-type-inference (quasiquote ?core-language-form))
	 => (quasiquote ?expected-result)))
      ))

  (define-syntax doit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result)
       ;;We want the ?STANDARD-LANGUAGE-FORM to appear  in the output of CHECK when a
       ;;test fails.
       (doit ,(%expand (quasiquote ?standard-language-form))
	     ?expected-result))
      ))

;;; --------------------------------------------------------------------
;;; fixnum type

  (doit (let ((f (lambda (x) x)))
	  (f '1))
	(bind ((f_0 (lambda (x_0) x_0)))
	  (funcall (known f_0
			  (T:procedure T:non-false T:nonimmediate T:object))
	    (known (constant 1)
		   (T:fixnum T:positive T:non-false T:exact T:number T:immediate T:object)))))

  (doit (let ((f (lambda (x) x)))
	  (f '"1"))
	(bind ((f_0 (lambda (x_0) x_0)))
	  (funcall (known f_0
			  (T:procedure T:non-false T:nonimmediate T:object))
	    (known (constant "1")
		   (T:string T:non-false T:nonimmediate T:object)))))

;;; --------------------------------------------------------------------
;;; vector type

  (doit* (vector-length '#(1 2))
	 (funcall (primref vector-length)
	   (known (constant #(1 2))
		  (T:vector T:non-false T:nonimmediate T:object))))

;;; --------------------------------------------------------------------
;;; inference of type after successful variable test

  (doit* (let ((x (read)))
	   (if x
	       (display x)
	     (display x)))
	 (bind ((x_0 (funcall (primref read))))
	   (conditional x_0
	       (funcall (primref display)
		 (known x_0 (T:non-false T:object)))
	     (funcall (primref display)
	       (known x_0 (T:false T:boolean T:immediate T:object))))))

;;; --------------------------------------------------------------------
;;; return value type descriptors

  ;;Test for NOT return value type descriptor.
  (doit (let ((x ((primitive not) ((primitive read)))))
	  ((primitive display) x))
	(bind ((x_0 (funcall (primref not)
		      (funcall (primref read)))))
	  (funcall (primref display)
	    (known x_0 (T:boolean T:immediate T:object)))))

;;; inference of type after successful type predicate application

  (doit* (let ((x (read)))
	   (if (fixnum? x)
	       (display x)
	     (display x)))
	 (bind ((x_0 (funcall (primref read))))
	   (conditional (funcall (primref fixnum?) x_0)
	       (funcall (primref display)
		 (known x_0 (T:fixnum T:non-false T:exact T:number T:immediate T:object)))
	     (funcall (primref display)
	       x_0))))

  ;;Miscellaneous predicates.
  (doit* (let ((x (read)))
	   (cond ((fixnum? x)
		  (display x))
		 ((string? x)
		  (display x))
		 (else
		  (display x))))
	 (bind ((x_0 (funcall (primref read))))
	   (conditional (funcall (primref fixnum?) x_0)
	       (funcall (primref display)
		 (known x_0 (T:fixnum T:non-false T:exact T:number T:immediate T:object)))
	     (conditional (funcall (primref string?) x_0)
		 (funcall (primref display)
		   (known x_0 (T:string T:non-false T:nonimmediate T:object)))
	       (funcall (primref display)
		 x_0)))))

  ;;Test for NULL?, PAIR? and LIST?.
  (doit* (let ((x (read)))
	   (cond ((null? x)
		  (display x))
		 ((pair? x)
		  (display x))
		 ((list? x)
		  (display x))
		 (else
		  (display x))))
	 (bind ((x_0 (funcall (primref read))))
	   (conditional (funcall (primref null?) x_0)
	       (funcall (primref display)
		 (known x_0 (T:null T:non-false T:immediate T:object)))
	     (conditional (funcall (primref pair?) x_0)
		 (funcall (primref display)
		   (known x_0 (T:pair T:non-false T:nonimmediate T:object)))
	       (conditional (funcall (primref list?) x_0)
		   (funcall (primref display)
		     (known x_0 (T:pair T:non-false T:nonimmediate T:object)))
		 (funcall (primref display) x_0))))))

  ;;Test for NOT in conditional's test position.
  (doit* (let ((x (read)))
	   (if (not x)
	       (display x)
	     (display x)))
	 (bind ((x_0 (funcall (primref read))))
	   (conditional (funcall (primref not) x_0)
	       (funcall (primref display)
		 (known x_0 (T:false T:boolean T:immediate T:object)))
	     (funcall (primref display)
	       (known x_0 (T:non-false T:object))))))

  ;;Test for numbers.
  (doit* (let ((x (read)))
	   (cond ((fixnum? x)
		  (display x))
		 ((flonum? x)
		  (display x))
		 ((bignum? x)
		  (display x))
		 ((ratnum? x)
		  (display x))
		 ((compnum? x)
		  (display x))
		 ((cflonum? x)
		  (display x))
		 ((number? x)
		  (display x))
		 ((complex? x)
		  (display x))
		 ((real? x)
		  (display x))
		 ((rational? x)
		  (display x))
		 ((exact? x)
		  (display x))
		 ((inexact? x)
		  (display x))
		 (else
		  (display x))))
	 (bind ((x_0 (funcall (primref read))))
	   (conditional (funcall (primref fixnum?) x_0)
	       (funcall (primref display)
		 (known x_0 (T:fixnum T:non-false T:exact T:number T:immediate T:object)))
	     (conditional (funcall (primref flonum?) x_0)
		 (funcall (primref display)
		   (known x_0 (T:flonum T:non-false T:nonimmediate T:inexact T:number T:object)))
	       (conditional (funcall (primref bignum?) x_0)
		   (funcall (primref display)
		     (known x_0 (T:other-number T:non-false T:nonimmediate T:number T:object)))
		 (conditional (funcall (primref ratnum?) x_0)
		     (funcall (primref display)
		       (known x_0 (T:other-number T:non-false T:nonimmediate T:number T:object)))
		   (conditional (funcall (primref compnum?) x_0)
		       (funcall (primref display)
			 (known x_0 (T:other-number T:non-false T:nonimmediate T:number T:object)))
		     (conditional (funcall (primref cflonum?) x_0)
			 (funcall (primref display)
			   (known x_0 (T:other-number T:non-false T:nonimmediate T:number T:object)))
		       (conditional (funcall (primref number?) x_0)
			   (funcall (primref display)
			     (known x_0 (T:non-false T:number T:object)))
			 (conditional (funcall (primref complex?) x_0)
			     (funcall (primref display)
			       (known x_0 (T:other-number T:non-false T:nonimmediate T:number T:object)))
			   (conditional (funcall (primref real?) x_0)
			       (funcall (primref display)
				 (known x_0 (T:non-false T:number T:object)))
			     (conditional (funcall (primref rational?) x_0)
				 (funcall (primref display)
				   (known x_0 (T:non-false T:number T:object)))
			       (conditional (funcall (primref exact?) x_0)
				   (funcall (primref display)
				     (known x_0 (T:non-false T:exact T:number T:object)))
				 (conditional (funcall (primref inexact?) x_0)
				     (funcall (primref display)
				       (known x_0 (T:non-false T:nonimmediate T:inexact T:number T:object)))
				   (funcall (primref display) x_0)))))))))))))))

  ;;Test for AND syntax type propagation.  AND expands to IF.
  (doit* (let ((x (read)))
	   (and (pair? x)
		(car   x)))
	 (bind ((x_0 (funcall (primref read))))
	   (conditional (funcall (primref pair?) x_0)
	       (seq
		 (constant #f)
		 (funcall (primref car)
		   (known x_0 (T:pair T:non-false T:nonimmediate T:object))))
	     (constant #f))))

;;; --------------------------------------------------------------------
;;; propagation of type after successful primitive argument validation

  ;;The following tests are related.  We  test what happens when a variable reference
  ;;is used as operand for CDR; the primitive CDR accepts a pair as operand.
  (begin
    ;;Here  the variable  X  is of  known  type from  the start:  it  is tagged  with
    ;;"T:pair".
    (doit* (let ((f (lambda (y) y))
		 (x '(1 . 2)))
	     (f (cdr x)))
	   (bind ((f_0 (lambda (y_0) y_0))
		  (x_0 (constant (1 . 2))))
	     (funcall (known f_0 (T:procedure T:non-false T:nonimmediate T:object))
	       (funcall (primref cdr)
		 (known x_0 (T:pair T:non-false T:nonimmediate T:object))))))

    ;;Here the variable X is of unknown type: it is left untagged.
    (doit* (let ((f (lambda (y) y))
		 (x (read)))
	     (f (cdr x)))
	   (bind ((f_0 (lambda (y_0) y_0))
		  (x_0 (funcall (primref read))))
	     (funcall (known f_0 (T:procedure T:non-false T:nonimmediate T:object))
	       (funcall (primref cdr) x_0))))

    ;;Here the variable X is of unknown type  when its binding is created: it is left
    ;;untagged.   But, after  being  used  as argument  for  CDR  without raising  an
    ;;exception: it is known that its type  is "T:pair"; so the second reference to X
    ;;is tagged with "T:pair".
    ;;
    ;;We know  that a "wrong  operand type" exception  is non-continuable; so  if CDR
    ;;raises an exception because X is not a pair: the control flow cannot come back.
    (doit* (let ((f (lambda (y) y))
		 (x (read)))
	     (f (cdr x))
	     (f x))
	   (bind ((f_0 (lambda (y_0) y_0))
		  (x_0 (funcall (primref read))))
	     (seq
	       (funcall (known f_0 (T:procedure T:non-false T:nonimmediate T:object))
		 (funcall (primref cdr) x_0))
	       (funcall (known f_0 (T:procedure T:non-false T:nonimmediate T:object))
		 (known x_0 (T:pair T:non-false T:nonimmediate T:object))))))

    #| end of BEGIN |# )

  #t)


(parametrise ((check-test-name	'sanitise-bindings))

  (define (%sanitize-bindings core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (D (compiler.optimize-direct-calls D))
	   (D (compiler.optimize-letrec D))
	   (D (compiler.source-optimize D))
	   (D (compiler.rewrite-references-and-assignments D))
	   (D (compiler.sanitize-bindings D))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-syntax doit
    (syntax-rules ()
      ((_ ?core-language-form ?expected-result)
       (check
	   (%sanitize-bindings (quasiquote ?core-language-form))
	 => (quasiquote ?expected-result)))
      ))

  (define-syntax doit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result)
       ;;We want the ?STANDARD-LANGUAGE-FORM to appear  in the output of CHECK when a
       ;;test fails.
       (doit ,(%expand (quasiquote ?standard-language-form))
	     ?expected-result))
      ))

;;; --------------------------------------------------------------------

  (doit (lambda () '1)
	(fix ((tmp_0 (lambda () (constant 1))))
	  tmp_0))

  (doit (let ((a (lambda () '1)))
	  a)
	(fix ((a_0 (lambda () (constant 1))))
	  a_0))

  (doit (let ((a (lambda () '1))
	      (b ((primitive read))))
	  ((primitive list) a b))
	(bind ((b_0 (funcall (primref read))))
	  (fix ((a_0 (lambda () (constant 1))))
	    (funcall (primref list) a_0 b_0))))

  (doit (let ((a (lambda () '1)))
	  (begin
	    (set! a '2)
	    a))
	(fix ((a_0 (lambda () (constant 1))))
	  (bind ((a_1 (funcall (primref vector) a_0)))
	    (seq
	      (funcall (primref $vector-set!) a_1 (constant 0) (constant 2))
	      (funcall (primref $vector-ref)  a_1 (constant 0))))))

  #t)


(parametrise ((check-test-name						'optimise-direct-jumps)
	      (compiler.enabled-function-application-integration?	#f)
	      (compiler.descriptive-labels				#t))

  (define (%optimise-direct-jumps core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (D (compiler.optimize-direct-calls D))
	   (D (compiler.optimize-letrec D))
	   (D (compiler.source-optimize D))
	   (D (compiler.rewrite-references-and-assignments D))
	   (D (compiler.sanitize-bindings D))
	   (D (compiler.optimize-for-direct-jumps D))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-syntax doit
    (syntax-rules ()
      ((_ ?core-language-form ?expected-result)
       (check
	   (%optimise-direct-jumps (quasiquote ?core-language-form))
	 => (quasiquote ?expected-result)))
      ))

  (define-syntax doit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result)
       ;;We want the ?STANDARD-LANGUAGE-FORM to appear  in the output of CHECK when a
       ;;test fails.
       (doit ,(%expand (quasiquote ?standard-language-form))
	     ?expected-result))
      ))

  (define-syntax libdoit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result/basic)
       (doit ,(%expand-library (quasiquote ?standard-language-form)) ?expected-result/basic))
      ))

;;; --------------------------------------------------------------------

  (doit (let ((f (case-lambda
		  ((a)   '1)
		  ((a b) '2))))
	  ((primitive list) (f '1) (f '1 '2)))
	(fix ((f_0 (case-lambda
		    ((a_0)     (constant 1))
		    ((a_1 b_0) (constant 2)))))
	  (funcall (primref list)
	    (jmpcall asmlabel:f:clambda:case-1 f_0 (constant 1))
	    (jmpcall asmlabel:f:clambda:case-2 f_0 (constant 1) (constant 2)))))

  ;;The same as above but expanded.
  (doit* (let ((f (case-lambda
		   ((a)   1)
		   ((a b) 2))))
	   (list (f 1) (f 1 2)))
	 (fix ((lex.f_0 (case-lambda
			 ((lex.a_0)         (constant 1))
			 ((lex.a_1 lex.b_0) (constant 2)))))
	   (funcall (primref list)
	     (jmpcall asmlabel:lex.f:clambda:case-1 lex.f_0 (constant 1))
	     (jmpcall asmlabel:lex.f:clambda:case-2 lex.f_0 (constant 1) (constant 2)))))

  ;;Recursive function.
  (doit (letrec ((f (case-lambda
		     (()	(f '1))
		     ((a)	a))))
	  ((primitive list) (f) (f '2)))
	(fix ((f_0 (case-lambda
		    (()
		     (jmpcall asmlabel:f:clambda:case-1 f_0 (constant 1)))
		    ((a_0)
		     a_0))))
	  (funcall (primref list)
	    (jmpcall asmlabel:f:clambda:case-0 f_0)
	    (jmpcall asmlabel:f:clambda:case-1 f_0 (constant 2)))))

  #t)


(parametrise ((check-test-name	'insert-global-assignments))

  (define (%insert-global-assignments core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (D (compiler.optimize-direct-calls D))
	   (D (compiler.optimize-letrec D))
	   (D (compiler.source-optimize D))
	   (D (compiler.rewrite-references-and-assignments D))
	   (D (compiler.sanitize-bindings D))
	   (D (compiler.optimize-for-direct-jumps D))
	   (D (compiler.insert-global-assignments D))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-syntax doit
    (syntax-rules ()
      ((_ ?core-language-form ?expected-result)
       (check
	   (%insert-global-assignments (quasiquote ?core-language-form))
	 => (quasiquote ?expected-result)))
      ))

  (define-syntax doit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result)
       ;;We want the ?STANDARD-LANGUAGE-FORM to appear  in the output of CHECK when a
       ;;test fails.
       (doit ,(%expand (quasiquote ?standard-language-form))
	     ?expected-result))
      ))

  (define-syntax libdoit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result/basic)
       (doit ,(%expand-library (quasiquote ?standard-language-form)) ?expected-result/basic))
      ))

;;; --------------------------------------------------------------------

  (doit (library-letrec*
	    ((a.lex a.loc (lambda () '1))
	     (b.lex b.loc (lambda () '2))
	     (c.lex c.loc (lambda () '3))
	     (d.lex d.loc '4))
	  (quote #!void))
	(fix ((a.lex_0 (lambda () (constant 1)))
	      (b.lex_0 (lambda () (constant 2)))
	      (c.lex_0 (lambda () (constant 3))))
	  (seq
	    (funcall (primref $set-symbol-value/proc!) (constant a.loc) a.lex_0)
	    (funcall (primref $init-symbol-value!)     (constant b.loc) b.lex_0)
	    (funcall (primref $init-symbol-value!)     (constant c.loc) c.lex_0)
	    (bind ((d.lex_0 (constant 4)))
	      (seq
		(funcall (primref $init-symbol-value!) (constant d.loc) d.lex_0)
		(constant #!void))))))

;;; --------------------------------------------------------------------
;;; libraries

  (libdoit* (library (insert-global-assignments-demo-1)
	      (export a b c d)
	      (import (rnrs))
	      (define (a) '1)
	      (define (b) '2)
	      (define (c) '3)
	      (define d '4))
	    (fix ((a_0 (lambda () (constant 1)))
		  (b_0 (lambda () (constant 2)))
		  (c_0 (lambda () (constant 3))))
	      (seq
		(funcall (primref $set-symbol-value/proc!) (constant a) a_0)
		(funcall (primref $init-symbol-value!)     (constant b) b_0)
		(funcall (primref $init-symbol-value!)     (constant c) c_0)
		(bind ((d_0 (constant 4)))
		  (seq
		    (funcall (primref $init-symbol-value!) (constant d) d_0)
		    (constant #!void))))))
  #t)


(parametrise ((check-test-name						'closure-makers)
	      (compiler.enabled-function-application-integration?	#f)
	      (compiler.descriptive-labels				#t))

;;;Function  application integration  is disabled  here to  make it  easier to  write
;;;meaningful code for debugging and inspection.

  (define (%introduce-closure-makers core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (D (compiler.optimize-direct-calls D))
	   (D (compiler.optimize-letrec D))
	   (D (compiler.source-optimize D))
	   (D (compiler.rewrite-references-and-assignments D))
	   (D (compiler.sanitize-bindings D))
	   (D (compiler.optimize-for-direct-jumps D))
	   (D (compiler.insert-global-assignments D))
	   (D (compiler.introduce-vars D))
	   (D (compiler.introduce-closure-makers D))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-syntax doit
    (syntax-rules ()
      ((_ ?core-language-form ?expected-result)
       (check
	   (%introduce-closure-makers (quasiquote ?core-language-form))
	 => (quasiquote ?expected-result)))
      ))

  (define-syntax doit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result)
       ;;We want the ?STANDARD-LANGUAGE-FORM to appear  in the output of CHECK when a
       ;;test fails.
       (doit ,(%expand (quasiquote ?standard-language-form))
	     ?expected-result))
      ))

  (define-syntax libdoit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result/basic)
       (doit ,(%expand-library (quasiquote ?standard-language-form)) ?expected-result/basic))
      ))

;;; --------------------------------------------------------------------

  ;;LAMBDA combinator.
  (doit (lambda () '1)
	(fix ((tmp_0 (closure-maker (lambda () (constant 1))
				    no-freevars)))
	  tmp_0))

  ;;CASE-LAMBDA combinator.
  (doit (case-lambda
	 (() '1)
	 ((a) a))
	(fix ((tmp_0 (closure-maker (case-lambda
				     (()    (constant 1))
				     ((a_0) a_0))
				    no-freevars)))
	  tmp_0))

  ;;LAMBDA closure.
  (doit (let ((a ((primitive read))))
	  (lambda () a))
	(bind ((a_0 (funcall (primref read))))
	  (fix ((tmp_0 (closure-maker (lambda () a_0)
				      (freevars: a_0))))
	    tmp_0)))

  ;;Recursive LAMBDA combinator.
  (doit (letrec ((f (lambda () (f))))
	  f)
	(fix ((f_0 (closure-maker (lambda () (jmpcall asmlabel:f:clambda:case-0 f_0))
				  (freevars: f_0))))
	  f_0))

;;; --------------------------------------------------------------------
;;; special cases

  ;;This  is to  verify that  the substitution  of the  synonym A  with F  is already
  ;;happened here.
  (doit (let ((f (lambda () '1)))
	  (let ((a f))
	    (let ((g (lambda () (a))))
	      g)))
	(fix ((f_0 (closure-maker (lambda () (constant 1)) no-freevars)))
	  (fix ((g_0 (closure-maker (lambda () (jmpcall asmlabel:f:clambda:case-0 f_0))
				    (freevars: f_0))))
	    g_0)))

;;; --------------------------------------------------------------------
;;; libraries

  (doit (library-letrec*
	    ((a a.loc (lambda () '1))
	     (b b.loc (lambda () '2))
	     (c c.loc (lambda () '3))
	     (d d.loc '4))
	  (quote #!void))
	(fix ((a_0 (closure-maker (lambda () (constant 1)) no-freevars))
	      (b_0 (closure-maker (lambda () (constant 2)) no-freevars))
	      (c_0 (closure-maker (lambda () (constant 3)) no-freevars)))
	  (seq
	    (funcall (primref $set-symbol-value/proc!) (constant a.loc) a_0)
	    (funcall (primref $init-symbol-value!)     (constant b.loc) b_0)
	    (funcall (primref $init-symbol-value!)     (constant c.loc) c_0)
	    (bind ((d_0 (constant 4)))
	      (seq
		(funcall (primref $init-symbol-value!) (constant d.loc) d_0)
		(constant #!void))))))

  #t)


(parametrise ((check-test-name						'clambda-lifting)
	      (compiler.enabled-function-application-integration?	#f)
	      (compiler.descriptive-labels				#t))

;;;Function  application integration  is disabled  here to  make it  easier to  write
;;;meaningful code for debugging and inspection.

  (define (%lift-codes core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (D (compiler.optimize-direct-calls D))
	   (D (compiler.optimize-letrec D))
	   (D (compiler.source-optimize D))
	   (D (compiler.rewrite-references-and-assignments D))
	   (D (compiler.sanitize-bindings D))
	   (D (compiler.optimize-for-direct-jumps D))
	   (D (compiler.insert-global-assignments D))
	   (D (compiler.introduce-vars D))
	   (D (compiler.introduce-closure-makers D))
	   (D (compiler.optimize-combinator-calls/lift-clambdas D))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-syntax doit
    (syntax-rules ()
      ((_ ?core-language-form ?expected-result)
       (check
	   (%lift-codes (quasiquote ?core-language-form))
	 => (quasiquote ?expected-result)))
      ))

  (define-syntax doit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result)
       ;;We want the ?STANDARD-LANGUAGE-FORM to appear  in the output of CHECK when a
       ;;test fails.
       (doit ,(%expand (quasiquote ?standard-language-form))
	     ?expected-result))
      ))

  (define-syntax libdoit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result/basic)
       (doit ,(%expand-library (quasiquote ?standard-language-form)) ?expected-result/basic))
      ))

;;; --------------------------------------------------------------------
;;; combinator functions

  (doit (lambda () ((primitive read)))
	(codes
	 ((lambda (label: asmlabel:anonymous:clambda) () (funcall (primref read))))
	 (closure-maker (code-loc asmlabel:anonymous:clambda)
			no-freevars)))

  (doit (let ((f (lambda () '1)))
	  (f))
	(codes
	 ((lambda (label: asmlabel:f:clambda) () (constant 1)))
	 (jmpcall asmlabel:f:clambda:case-0
		  (closure-maker (code-loc asmlabel:f:clambda) no-freevars))))

  (doit (let ((f (lambda () '1))
	      (g (lambda () '2)))
	  ((primitive list) (f) (g)))
	(codes
	 ((lambda (label: asmlabel:g:clambda) () (constant 2))
	  (lambda (label: asmlabel:f:clambda) () (constant 1)))
	 (funcall (primref list)
	   (jmpcall asmlabel:f:clambda:case-0
		    (closure-maker (code-loc asmlabel:f:clambda) no-freevars))
	   (jmpcall asmlabel:g:clambda:case-0
		    (closure-maker (code-loc asmlabel:g:clambda) no-freevars)))))

  ;;Single function, multiple closures.
  (doit (let ((f (lambda () '1)))
	  ((primitive list) (f) (f)))
	(codes
	 ((lambda (label: asmlabel:f:clambda) () (constant 1)))
	 (funcall (primref list)
	   (jmpcall asmlabel:f:clambda:case-0
		    (closure-maker (code-loc asmlabel:f:clambda)
				   no-freevars))
	   (jmpcall asmlabel:f:clambda:case-0
		    (closure-maker (code-loc asmlabel:f:clambda)
				   no-freevars)))))

  ;;Cycle of combinators.
  (doit (letrec* ((a (lambda () (d)))
		  (b (lambda () (a)))
		  (c (lambda () (b)))
		  (d (lambda () (c))))
	  ((primitive list) (a) (b) (c) (d)))
	(codes
	 ((lambda (label: asmlabel:a:clambda) ()
	     (jmpcall asmlabel:d:clambda:case-0 (closure-maker (code-loc asmlabel:d:clambda) no-freevars)))
	  (lambda (label: asmlabel:d:clambda) ()
	     (jmpcall asmlabel:c:clambda:case-0 (closure-maker (code-loc asmlabel:c:clambda) no-freevars)))
	  (lambda (label: asmlabel:c:clambda) ()
	     (jmpcall asmlabel:b:clambda:case-0 (closure-maker (code-loc asmlabel:b:clambda) no-freevars)))
	  (lambda (label: asmlabel:b:clambda) ()
	     (jmpcall asmlabel:a:clambda:case-0 (closure-maker (code-loc asmlabel:a:clambda) no-freevars))))
	 (funcall (primref list)
	   (jmpcall asmlabel:a:clambda:case-0 (closure-maker (code-loc asmlabel:a:clambda) no-freevars))
	   (jmpcall asmlabel:b:clambda:case-0 (closure-maker (code-loc asmlabel:b:clambda) no-freevars))
	   (jmpcall asmlabel:c:clambda:case-0 (closure-maker (code-loc asmlabel:c:clambda) no-freevars))
	   (jmpcall asmlabel:d:clambda:case-0 (closure-maker (code-loc asmlabel:d:clambda) no-freevars)))))

;;; --------------------------------------------------------------------
;;; non-combinators

  ;;Single function, single call.
  (doit (let ((a ((primitive read))))
	  (lambda () a))
	(codes
	 ((lambda (label: asmlabel:anonymous:clambda) () a_0))
	 (bind ((a_0 (funcall (primref read))))
	   (fix ((tmp_0 (closure-maker (code-loc asmlabel:anonymous:clambda)
				       (freevars: a_0))))
	     tmp_0))))

  ;;Single function, 2 calls.
  (doit (let ((a ((primitive read))))
	  (let ((f (lambda () a)))
	    ((primitive list) (f) (f))))
	(codes
	 ((lambda (label: asmlabel:f:clambda) () a_0))
	 (bind ((a_0 (funcall (primref read))))
	   (fix ((f_0 (closure-maker (code-loc asmlabel:f:clambda)
				     (freevars: a_0))))
	     (funcall (primref list)
	       (jmpcall asmlabel:f:clambda:case-0 f_0)
	       (jmpcall asmlabel:f:clambda:case-0 f_0))))))

  ;;Recursive combinator.
  (doit (letrec ((f (lambda () (f))))
	  f)
	(codes
	 ((lambda (label: asmlabel:f:clambda) ()
	     (jmpcall asmlabel:f:clambda:case-0
		      (closure-maker (code-loc asmlabel:f:clambda)
				     no-freevars))))
	 (closure-maker (code-loc asmlabel:f:clambda) no-freevars)))

  ;;Cycle of non-combinators.
  (doit (let ((v ((primitive read))))
	  (letrec* ((a (lambda (x) (d v)))
		    (b (lambda (x) (a v)))
		    (c (lambda (x) (b v)))
		    (d (lambda (x) (c v))))
	    ((primitive list) (a '1) (b '2) (c '3) (d '4))))
	(codes
	 ((lambda (label: asmlabel:a:clambda) (x_0)
	     (jmpcall asmlabel:d:clambda:case-1 d_0 v_0))
	  (lambda (label: asmlabel:d:clambda) (x_1)
	     (jmpcall asmlabel:c:clambda:case-1 c_0 v_0))
	  (lambda (label: asmlabel:c:clambda) (x_2)
	     (jmpcall asmlabel:b:clambda:case-1 b_0 v_0))
	  (lambda (label: asmlabel:b:clambda) (x_3)
	     (jmpcall asmlabel:a:clambda:case-1 a_0 v_0)))
	 (bind ((v_0 (funcall (primref read))))
	   (fix ((a_0 (closure-maker (code-loc asmlabel:a:clambda) (freevars: d_0 v_0)))
		 (d_0 (closure-maker (code-loc asmlabel:d:clambda) (freevars: c_0 v_0)))
		 (c_0 (closure-maker (code-loc asmlabel:c:clambda) (freevars: b_0 v_0)))
		 (b_0 (closure-maker (code-loc asmlabel:b:clambda) (freevars: a_0 v_0))))
	     (funcall (primref list)
	       (jmpcall asmlabel:a:clambda:case-1 a_0 (constant 1))
	       (jmpcall asmlabel:b:clambda:case-1 b_0 (constant 2))
	       (jmpcall asmlabel:c:clambda:case-1 c_0 (constant 3))
	       (jmpcall asmlabel:d:clambda:case-1 d_0 (constant 4)))))))

  ;;Cycle of non-combinators induced by a single explicit free variable.
  (doit (let ((v ((primitive read))))
	  (letrec* ((a (lambda (x) (d x)))
		    (b (lambda (x) (a x)))
		    (c (lambda (x) (b x)))
		    (d (lambda (x) (c v))))
	    ((primitive list) (a '1) (b '2) (c '3) (d '4))))
	(codes
	 ((lambda (label: asmlabel:a:clambda) (x_0)
	     (jmpcall asmlabel:d:clambda:case-1 d_0 x_0))
	  (lambda (label: asmlabel:d:clambda) (x_1)
	     (jmpcall asmlabel:c:clambda:case-1 c_0 v_0))
	  (lambda (label: asmlabel:c:clambda) (x_2)
	     (jmpcall asmlabel:b:clambda:case-1 b_0 x_2))
	  (lambda (label: asmlabel:b:clambda) (x_3)
	     (jmpcall asmlabel:a:clambda:case-1 a_0 x_3)))
	 (bind ((v_0 (funcall (primref read))))
	   (fix ((a_0 (closure-maker (code-loc asmlabel:a:clambda) (freevars: d_0)))
		 (d_0 (closure-maker (code-loc asmlabel:d:clambda) (freevars: c_0 v_0)))
		 (c_0 (closure-maker (code-loc asmlabel:c:clambda) (freevars: b_0)))
		 (b_0 (closure-maker (code-loc asmlabel:b:clambda) (freevars: a_0))))
	     (funcall (primref list)
	       (jmpcall asmlabel:a:clambda:case-1 a_0 (constant 1))
	       (jmpcall asmlabel:b:clambda:case-1 b_0 (constant 2))
	       (jmpcall asmlabel:c:clambda:case-1 c_0 (constant 3))
	       (jmpcall asmlabel:d:clambda:case-1 d_0 (constant 4)))))))

;;; --------------------------------------------------------------------
;;; binding reference substitutions

  ;;Variable synonym substitution.  This does not happen at this compiler pass: it is
  ;;performed earlier.
  (doit (let ((a ((primitive read))))
	  (let ((b a))
	    b))
	(codes
	 ()
	 (bind ((a_0 (funcall (primref read))))
	   a_0)))

  ;;Variable synonym substitution.
  (doit (let ((f (lambda () '1)))
	  (let ((a f))
	    (let ((g (lambda () (a))))
	      g)))
	(codes
	 ((lambda (label: asmlabel:g:clambda) ()
	     (jmpcall asmlabel:f:clambda:case-0
		      (closure-maker (code-loc asmlabel:f:clambda)
				     no-freevars)))
	  (lambda (label: asmlabel:f:clambda) () (constant 1)))
	 (closure-maker (code-loc asmlabel:g:clambda) no-freevars)))

  ;;The function A is a combinator (no free vars); as a consequence the function B is
  ;;also a combinator.
  (doit (letrec* ((a (lambda () '1))
		  (b (lambda () (a))))
	  b)
	(codes ((lambda (label: asmlabel:b:clambda) ()
		   (jmpcall asmlabel:a:clambda:case-0 (closure-maker (code-loc asmlabel:a:clambda) no-freevars)))
		(lambda (label: asmlabel:a:clambda) () (constant 1)))
	       (closure-maker (code-loc asmlabel:b:clambda) no-freevars)))

  ;;The function  A is a closure  upon D, as a  consequence the function B  is also a
  ;;closure.
  (doit (let ((d ((primitive read))))
	  (letrec* ((a (lambda () d))
		    (b (lambda () (a))))
	    b))
	(codes
	 ((lambda (label: asmlabel:b:clambda) () (jmpcall asmlabel:a:clambda:case-0 a_0))
	  (lambda (label: asmlabel:a:clambda) () d_0))
	 (bind ((d_0 (funcall (primref read))))
	   (fix ((b_0 (closure-maker (code-loc asmlabel:b:clambda) (freevars: a_0)))
		 (a_0 (closure-maker (code-loc asmlabel:a:clambda) (freevars: d_0))))
	     b_0))))

  ;;Recursive non-combinator.
  (doit (let ((a ((primitive read))))
	  (letrec ((f (lambda (x) (f a))))
	    (f '1)))
	(codes
	 ((lambda (label: asmlabel:f:clambda) (x_0)
	     (jmpcall asmlabel:f:clambda:case-1 f_0 a_0)))
	 (bind ((a_0 (funcall (primref read))))
	   (fix ((f_0 (closure-maker (code-loc asmlabel:f:clambda)
				     (freevars: a_0))))
	     (jmpcall asmlabel:f:clambda:case-1 f_0 (constant 1))))))

  (doit (letrec ((f (case-lambda
		     (()	(f '1))
		     ((a)	a))))
	  ((primitive list) (f) (f '2)))
	(codes ((case-lambda (label: asmlabel:f:clambda)
			     (()
			      (jmpcall asmlabel:f:clambda:case-1
				       (closure-maker (code-loc asmlabel:f:clambda) no-freevars)
				       (constant 1)))
			     ((a_0)
			      a_0)))
	       (funcall (primref list)
		 (jmpcall asmlabel:f:clambda:case-0 (closure-maker (code-loc asmlabel:f:clambda) no-freevars))
		 (jmpcall asmlabel:f:clambda:case-1 (closure-maker (code-loc asmlabel:f:clambda) no-freevars) (constant 2)))))

;;; --------------------------------------------------------------------
;;; special cases

  (doit (let ((a (lambda () '1)))
	  ((primitive eq?) a a))
	(codes
	 ((lambda (label: asmlabel:a:clambda) () (constant 1)))
	 (funcall (primref eq?)
	   (closure-maker (code-loc asmlabel:a:clambda) no-freevars)
	   (closure-maker (code-loc asmlabel:a:clambda) no-freevars))))

;;; --------------------------------------------------------------------
;;; LIBRARY-LETREC* forms

  (doit (library-letrec*
	    ((a a.loc (lambda () '1))
	     (b b.loc (lambda () '2))
	     (c c.loc (lambda () '3))
	     (d d.loc '4))
	  (quote #!void))
	(codes
	 ((lambda (label: asmlabel:c:clambda) () (constant 3))
	  (lambda (label: asmlabel:b:clambda) () (constant 2))
	  (lambda (label: asmlabel:a:clambda) () (constant 1)))
	 (seq
	   (funcall (primref $set-symbol-value/proc!)
	     (constant a.loc)
	     (closure-maker (code-loc asmlabel:a:clambda) no-freevars))
	   (funcall (primref $init-symbol-value!)
	     (constant b.loc)
	     (closure-maker (code-loc asmlabel:b:clambda) no-freevars))
	   (funcall (primref $init-symbol-value!)
	     (constant c.loc)
	     (closure-maker (code-loc asmlabel:c:clambda) no-freevars))
	   (bind ((d_0 (constant 4)))
	     (seq
	       (funcall (primref $init-symbol-value!)
		 (constant d.loc) d_0)
	       (constant #!void))))))

  (libdoit* (library (clambda-lifting-demo-0)
	      (export a b c d)
	      (import (rnrs))
	      (define (a) '1)
	      (define (b) '2)
	      (define (c) '3)
	      (define d 4))
	    (codes
	     ((lambda (label: asmlabel:lex.c:clambda) () (constant 3))
	      (lambda (label: asmlabel:lex.b:clambda) () (constant 2))
	      (lambda (label: asmlabel:lex.a:clambda) () (constant 1)))
	     (seq
	       (funcall (primref $set-symbol-value/proc!)
		 (constant lex.a)
		 (closure-maker (code-loc asmlabel:lex.a:clambda) no-freevars))
	       (funcall (primref $init-symbol-value!) (constant lex.b)
			(closure-maker (code-loc asmlabel:lex.b:clambda) no-freevars))
	       (funcall (primref $init-symbol-value!) (constant lex.c)
			(closure-maker (code-loc asmlabel:lex.c:clambda) no-freevars))
	       (bind ((lex.d_0 (constant 4)))
		 (seq
		   (funcall (primref $init-symbol-value!) (constant lex.d) lex.d_0)
		   (constant #!void))))))

  #t)


(parametrise ((check-test-name						'introduce-primcalls)
	      (compiler.enabled-function-application-integration?	#f)
	      (compiler.descriptive-labels				#t))

;;;Function  application integration  is disabled  here to  make it  easier to  write
;;;meaningful code for debugging and inspection.

  (define (%introduce-primcalls core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (D (compiler.optimize-direct-calls D))
	   (D (compiler.optimize-letrec D))
	   (D (compiler.source-optimize D))
	   (D (compiler.rewrite-references-and-assignments D))
	   (D (compiler.sanitize-bindings D))
	   (D (compiler.optimize-for-direct-jumps D))
	   (D (compiler.insert-global-assignments D))
	   (D (compiler.introduce-vars D))
	   (D (compiler.introduce-closure-makers D))
	   (D (compiler.optimize-combinator-calls/lift-clambdas D))
	   (D (compiler.introduce-primcalls D))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-syntax doit
    (syntax-rules ()
      ((_ ?core-language-form ?expected-result)
       (check
	   (%introduce-primcalls (quasiquote ?core-language-form))
	 => (quasiquote ?expected-result)))
      ))

  (define-syntax doit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result)
       ;;We want the ?STANDARD-LANGUAGE-FORM to appear  in the output of CHECK when a
       ;;test fails.
       (doit ,(%expand (quasiquote ?standard-language-form))
	     ?expected-result))
      ))

  (define-syntax libdoit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result/basic)
       (doit ,(%expand-library (quasiquote ?standard-language-form)) ?expected-result/basic))
      ))

;;; --------------------------------------------------------------------

  (doit ((primitive list) '1 '2)
	(codes
	 ()
	 (primcall list (constant 1) (constant 2))))

#t)


(parametrise ((check-test-name						'rewrite-freevar-refs)
	      (compiler.enabled-function-application-integration?	#f)
	      (compiler.descriptive-labels				#t))

;;;Function  application integration  is disabled  here to  make it  easier to  write
;;;meaningful code for debugging and inspection.

  (define (%rewrite-freevar-refs core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (D (compiler.optimize-direct-calls D))
	   (D (compiler.optimize-letrec D))
	   (D (compiler.source-optimize D))
	   (D (compiler.rewrite-references-and-assignments D))
	   (D (compiler.sanitize-bindings D))
	   (D (compiler.optimize-for-direct-jumps D))
	   (D (compiler.insert-global-assignments D))
	   (D (compiler.introduce-vars D))
	   (D (compiler.introduce-closure-makers D))
	   (D (compiler.optimize-combinator-calls/lift-clambdas D))
	   (D (compiler.introduce-primcalls D))
	   (D (compiler.rewrite-freevar-references D))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-syntax doit
    (syntax-rules ()
      ((_ ?core-language-form ?expected-result)
       (check
	   (%rewrite-freevar-refs (quasiquote ?core-language-form))
	 => (quasiquote ?expected-result)))
      ))

  (define-syntax doit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result)
       ;;We want the ?STANDARD-LANGUAGE-FORM to appear  in the output of CHECK when a
       ;;test fails.
       (doit ,(%expand (quasiquote ?standard-language-form))
	     ?expected-result))
      ))

  (define-syntax libdoit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result/basic)
       (doit ,(%expand-library (quasiquote ?standard-language-form)) ?expected-result/basic))
      ))

;;; --------------------------------------------------------------------

  (doit (let ((a ((primitive read))))
	  (lambda () a))
	(codes
	 ((lambda (label: asmlabel:anonymous:clambda) (cp_0)
	     (primcall $cpref cp_0 (constant 0))))
	 (bind ((a_0 (funcall (primref read))))
	   (fix ((tmp_0 (closure-maker (code-loc asmlabel:anonymous:clambda)
				       (freevars: a_0))))
	     tmp_0))))

  (doit (let ((a ((primitive read)))
	      (b ((primitive read))))
	  (lambda () ((primitive list) a b)))
	(codes
	 ((lambda (label: asmlabel:anonymous:clambda) (cp_0)
	     (primcall list
	       (primcall $cpref cp_0 (constant 1))
	       (primcall $cpref cp_0 (constant 0)))))
	 (bind ((a_0 (funcall (primref read)))
		(b_0 (funcall (primref read))))
	   (fix ((tmp_0 (closure-maker (code-loc asmlabel:anonymous:clambda)
				       (freevars: b_0 a_0))))
	     tmp_0))))

  ;;Assigned free variable.
  (doit (let ((a ((primitive read))))
	  (lambda ()
	    (begin
	      (set! a '1)
	      a)))
	(codes
	 ((lambda (label: asmlabel:anonymous:clambda) (cp_0)
	     (seq
	       (primcall $vector-set!
			 (primcall $cpref cp_0 (constant 0)) (constant 0)
			 (constant 1))
	       (primcall $vector-ref
			 (primcall $cpref cp_0 (constant 0)) (constant 0)))))
	 (bind ((a_0 (funcall (primref read))))
	   (bind ((a_1 (primcall vector a_0)))
	     (fix ((tmp_0 (closure-maker (code-loc asmlabel:anonymous:clambda)
					 (freevars: a_1))))
	       tmp_0)))))

;;; --------------------------------------------------------------------

  (doit (let ((f (lambda () '1)))
	  f)
	(codes
	 ((lambda (label: asmlabel:f:clambda) (cp_0) (constant 1)))
	 (fix ((tmp_0 (closure-maker (code-loc asmlabel:f:clambda) no-freevars)))
	   tmp_0)))

  (doit (let ((f (lambda () '1)))
	  (f))
	(codes
	 ((lambda (label: asmlabel:f:clambda) (cp_0) (constant 1)))
	 (jmpcall asmlabel:f:clambda:case-0
		  (fix ((tmp_0 (closure-maker (code-loc asmlabel:f:clambda) no-freevars)))
		    tmp_0))))

  #t)


(parametrise ((check-test-name						'engine-checks)
	      (compiler.enabled-function-application-integration?	#f)
	      (compiler.descriptive-labels				#t))

;;;Function  application integration  is disabled  here to  make it  easier to  write
;;;meaningful code for debugging and inspection.

  (define (%insert-engine-checks core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (D (compiler.optimize-direct-calls D))
	   (D (compiler.optimize-letrec D))
	   (D (compiler.source-optimize D))
	   (D (compiler.rewrite-references-and-assignments D))
	   (D (compiler.sanitize-bindings D))
	   (D (compiler.optimize-for-direct-jumps D))
	   (D (compiler.insert-global-assignments D))
	   (D (compiler.introduce-vars D))
	   (D (compiler.introduce-closure-makers D))
	   (D (compiler.optimize-combinator-calls/lift-clambdas D))
	   (D (compiler.introduce-primcalls D))
	   (D (compiler.rewrite-freevar-references D))
	   (D (compiler.insert-engine-checks D))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-syntax doit
    (syntax-rules ()
      ((_ ?core-language-form ?expected-result)
       (check
	   (%insert-engine-checks (quasiquote ?core-language-form))
	 => (quasiquote ?expected-result)))
      ))

  (define-syntax doit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result)
       ;;We want the ?STANDARD-LANGUAGE-FORM to appear  in the output of CHECK when a
       ;;test fails.
       (doit ,(%expand (quasiquote ?standard-language-form))
	     ?expected-result))
      ))

  (define-syntax libdoit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result/basic)
       (doit ,(%expand-library (quasiquote ?standard-language-form)) ?expected-result/basic))
      ))

;;; --------------------------------------------------------------------

  (doit (letrec ((f (lambda () (primitive read)))
		 (g (lambda () (f))))
	  (g))
	(codes
	 ((lambda (label: asmlabel:g:clambda) (cp_0)
	     (seq (primcall $do-event)
		  (jmpcall asmlabel:f:clambda:case-0
			   (fix ((tmp_0 (closure-maker (code-loc asmlabel:f:clambda) no-freevars)))
			     tmp_0))))
	  (lambda (label: asmlabel:f:clambda) (cp_1)
	     (primref read)))
	 (seq (primcall $do-event)
	      (jmpcall asmlabel:g:clambda:case-0
		       (fix ((tmp_1 (closure-maker (code-loc asmlabel:g:clambda) no-freevars)))
			 tmp_1)))))

  #t)


(parametrise ((check-test-name						'stack-overflow-checks)
	      (compiler.enabled-function-application-integration?	#f)
	      (compiler.descriptive-labels				#t))

;;;Function  application integration  is disabled  here to  make it  easier to  write
;;;meaningful code for debugging and inspection.

  (define (%stack-overflow-checks core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (D (compiler.optimize-direct-calls D))
	   (D (compiler.optimize-letrec D))
	   (D (compiler.source-optimize D))
	   (D (compiler.rewrite-references-and-assignments D))
	   (D (compiler.sanitize-bindings D))
	   (D (compiler.optimize-for-direct-jumps D))
	   (D (compiler.insert-global-assignments D))
	   (D (compiler.introduce-vars D))
	   (D (compiler.introduce-closure-makers D))
	   (D (compiler.optimize-combinator-calls/lift-clambdas D))
	   (D (compiler.introduce-primcalls D))
	   (D (compiler.rewrite-freevar-references D))
	   (D (compiler.insert-engine-checks D))
	   (D (compiler.insert-stack-overflow-check D))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-syntax doit
    (syntax-rules ()
      ((_ ?core-language-form ?expected-result)
       (check
	   (%stack-overflow-checks (quasiquote ?core-language-form))
	 => (quasiquote ?expected-result)))
      ))

  (define-syntax doit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result)
       ;;We want the ?STANDARD-LANGUAGE-FORM to appear  in the output of CHECK when a
       ;;test fails.
       (doit ,(%expand (quasiquote ?standard-language-form))
	     ?expected-result))
      ))

  (define-syntax libdoit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result/basic)
       (doit ,(%expand-library (quasiquote ?standard-language-form)) ?expected-result/basic))
      ))

;;; --------------------------------------------------------------------

  (doit (letrec ((f (lambda () (primitive read)))
		 (g (lambda () (f))))
	  (g))
	(codes
	 ((lambda (label: asmlabel:g:clambda) (cp_0)
	     (seq (primcall $do-event)
		  (jmpcall asmlabel:f:clambda:case-0
			   (fix ((tmp_0 (closure-maker (code-loc asmlabel:f:clambda) no-freevars)))
			     tmp_0))))
	  (lambda (label: asmlabel:f:clambda) (cp_1)
	     (primref read)))
	 (seq (primcall $do-event)
	      (jmpcall asmlabel:g:clambda:case-0
		       (fix ((tmp_1 (closure-maker (code-loc asmlabel:g:clambda) no-freevars)))
			 tmp_1)))))

  #t)


(parametrise ((check-test-name			'specify-representation)
	      (compiler.descriptive-labels	#t))

;;;NOTE There is a separate file for testing this compiler pass!!!

  (define (%specify-representation core-language-form)
    (let* ((D (compiler.recordize core-language-form))
	   (D (compiler.optimize-direct-calls D))
	   (D (compiler.optimize-letrec D))
	   ;;Source  optimisation  is  skipped  here  to  make  it  easier  to  write
	   ;;meaningful code for debugging and inspection.
	   #;(D (compiler.source-optimize D))
	   (D (compiler.rewrite-references-and-assignments D))
	   (D (compiler.sanitize-bindings D))
	   (D (compiler.optimize-for-direct-jumps D))
	   (D (compiler.insert-global-assignments D))
	   (D (compiler.introduce-vars D))
	   (D (compiler.introduce-closure-makers D))
	   (D (compiler.optimize-combinator-calls/lift-clambdas D))
	   (D (compiler.introduce-primcalls D))
	   (D (compiler.rewrite-freevar-references D))
	   (D (compiler.insert-engine-checks D))
	   (D (compiler.insert-stack-overflow-check D))
	   (D (compiler.specify-representation D))
	   (S (compiler.unparse-recordized-code/sexp D)))
      S))

  (define-syntax doit
    (syntax-rules ()
      ((_ ?core-language-form ?expected-result)
       (check
	   (%specify-representation (quasiquote ?core-language-form))
	 => (quasiquote ?expected-result)))
      ))

  (define-syntax doit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result)
       ;;We want the ?STANDARD-LANGUAGE-FORM to appear  in the output of CHECK when a
       ;;test fails.
       (doit ,(%expand (quasiquote ?standard-language-form))
	     ?expected-result))
      ))

  (define-syntax libdoit*
    (syntax-rules ()
      ((_ ?standard-language-form ?expected-result/basic)
       (doit ,(%expand-library (quasiquote ?standard-language-form)) ?expected-result/basic))
      ))

;;; --------------------------------------------------------------------

  ;;The  arguments of  +  are known  fixnums:  first attempt  a  sub between  fixnums
  ;;yielding  a fixnum;  if  an overflow  occurs,  resort to  a call  to  the full  +
  ;;primitive function.  The  primitive function + is accessed by  retrieving it from
  ;;its loc gensym.
  ;;
  ;;19 is  the offset of the  VALUE slot in the  loc gensym, taking into  account the
  ;;type tag in the tagged pointer.
  ;;
  ;;8 and 16 are, respectively, the machine word representations of the fixnums 1 and
  ;;2 on 64-bit platforms.
  (doit ((primitive +) '1 '2)
	(codes
	 ()
	 (shortcut
	     (seq
	       (primcall nop)
	       (primcall int+/overflow (constant 8) (constant 16)))
	   (funcall (primcall mref (constant (object +)) (constant 19))
	     (constant 8) (constant 16)))))

  ;;Notice how the return value of the SHORTCUT becomes the operand of DISPLAY.
  (doit* (display (+ 1 2))
	 (codes
	  ()
	  (funcall (primcall mref (constant (object display)) (constant 19))
	    (shortcut
		(seq
		  (primcall nop)
		  (primcall int+/overflow (constant 8) (constant 16)))
	      (funcall (primcall mref (constant (object +)) (constant 19))
		(constant 8) (constant 16))))))

  #t)


;;;; done

(check-report)

;;; end of file
;; Local Variables:
;; eval: (put 'bind			'scheme-indent-function 1)
;; eval: (put 'fix			'scheme-indent-function 1)
;; eval: (put 'recbind			'scheme-indent-function 1)
;; eval: (put 'rec*bind			'scheme-indent-function 1)
;; eval: (put 'seq			'scheme-indent-function 0)
;; eval: (put 'conditional		'scheme-indent-function 2)
;; eval: (put 'funcall			'scheme-indent-function 1)
;; eval: (put 'library-letrec*		'scheme-indent-function 1)
;; eval: (put 'shortcut			'scheme-indent-function 1)
;; End:
