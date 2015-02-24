;;;
;;;Part of: Vicare Scheme
;;;Contents: demo for Scheme-flavored Common Lisp's restarts
;;;Date: Tue Feb 24, 2015
;;;
;;;Abstract
;;;
;;;
;;;
;;;Copyright (C) 2015 Marco Maggi <marco.maggi-ipsu@poste.it>
;;;
;;;This program is free software:  you can redistribute it and/or modify
;;;it under the terms of the  GNU General Public License as published by
;;;the Free Software Foundation, either version 3 of the License, or (at
;;;your option) any later version.
;;;
;;;This program is  distributed in the hope that it  will be useful, but
;;;WITHOUT  ANY   WARRANTY;  without   even  the  implied   warranty  of
;;;MERCHANTABILITY  or FITNESS FOR  A PARTICULAR  PURPOSE.  See  the GNU
;;;General Public License for more details.
;;;
;;;You should  have received  a copy of  the GNU General  Public License
;;;along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;;


#!vicare
(import (vicare)
  (vicare checks))

(check-set-mode! 'report-failed)
(check-display "*** testing Vicare: dynamic environment, Common Lisp's restarts\n")


;;;; implementation

(define-syntax handlers-case
  ;;Basically  behaves  like  R6RS's GUARD  syntax.   Install  condition
  ;;handlers and in case a  condition is signaled: terminate the dynamic
  ;;extent of the ?BODY forms.
  ;;
  ;;Every  ?CONDITION is  meant to  be  an identifier  usable as  second
  ;;argument to IS-A?, for example condition type identifiers.
  ;;
  ;;Every  ?HANDLER must  be  an expression  evaluating  to a  procedure
  ;;accepting a single  argument.  The return value  of ?HANDLER becomes
  ;;the return value of HANDLERS-CASE.
  ;;
  (syntax-rules ()
    ((_ () ?body0 ?body ...)
     (begin ?body0 ?body ...))
    ((_ ((?condition0 ?handler0) (?condition ?handler) ...)
	?body0 ?body ...)
     (guard (E ((is-a? E ?condition0) (?handler0 E))
	       ((is-a? E ?condition)  (?handler  E))
	       ...)
       ?body0 ?body ...))
    ))

(define-syntax handlers-bind
  ;;Not  quite  like   R6RS's  WITH-EXCEPTION-HANDLER  syntax.   Install
  ;;condition handlers and  in case a condition is  signaled: select one
  ;;of them in the dynamic extent of the ?BODY forms.
  ;;
  ;;Every  ?CONDITION is  meant to  be  an identifier  usable as  second
  ;;argument to IS-A?, for example condition type identifiers.
  ;;
  ;;Every  ?HANDLER must  be  an expression  evaluating  to a  procedure
  ;;accepting  a single  argument.  If  a ?HANDLER  accepts to  handle a
  ;;condition: it must perform a non-local exit, for example by invoking
  ;;a restart.  If a ?HANDLER returns: it means it refuses to handle the
  ;;condition and an upper level handler is searched.
  ;;
  (syntax-rules ()
    ((_ () ?body0 ?body ...)
     (begin ?body0 ?body ...))
    ((_ ((?condition ?handler) ...) ?body0 ?body ...)
     (with-exception-handler
	 (lambda (E)
	   (cond ((is-a? E ?condition) (?handler E))
		 ...)
	   ;;If we are here either no ?CONDITION matched E or a ?HANDLER
	   ;;returned.  Let's search for  another handler in the uplevel
	   ;;dynamic environment.
	   (raise-continuable E))
       (lambda () ?body0 ?body ...)))
    ))

(module (signal
	 restart-case
	 find-restart
	 invoke-restart)

  (module (installed-restart-point
	   installed-restart-point.signaled-object
	   installed-restart-point.restart-proc
	   installed-restart-point.restart-handlers
	   make-<restart-point>)

    (define-record-type <restart-point>
      (nongenerative)
      (fields (mutable signaled-object)
		;The object  signaled by  SIGNAL.  It is  meant to  be a
		;condition object.
	      (immutable restart-proc)
		;The escape procedure to be applied to the return values
		;of  a  restart  handler  to  jump  back  to  a  use  of
		;RESTART-CASE.
	      (immutable restart-handlers)
		;List  of alists  managed as  a stack  of alists.   Each
		;alist represents the restart  handlers installed by the
		;expansion of a single RESTART-CASE use.
	      #| end of FIELDS |# )
      (protocol
       (lambda (make-record)
	 (lambda (restart-proc handlers-alist)
	   (make-record #f restart-proc handlers-alist))))
      #| end of DEFINE-RECORD-TYPE |# )

    (define (default-restart-proc . args)
      (assertion-violation 'restart-proc
	"invalid call to restart procedure \
       outside RESTART-CASE environment"))

    (define installed-restart-point
      (make-parameter (make-<restart-point> default-restart-proc '())))

    (define-syntax installed-restart-point.signaled-object
      (syntax-rules ()
	((_)
	 (<restart-point>-signaled-object      (installed-restart-point)))
	((_ ?obj)
	 (<restart-point>-signaled-object-set! (installed-restart-point) ?obj))
	))

    (define-syntax-rule (installed-restart-point.restart-proc)
      (<restart-point>-restart-proc (installed-restart-point)))

    (define-syntax-rule (installed-restart-point.restart-handlers)
      (<restart-point>-restart-handlers (installed-restart-point)))

    #| end of module |# )

;;;

  (define* (signal {C condition?})
    ;;Signal a condition.
    ;;
    (installed-restart-point.signaled-object C)
    (raise-continuable C))

  (define-syntax restart-case
    ;;Every ?KEY  must be a symbol  representing the name of  a restart.
    ;;The same ?KEY can be used in nested uses of RESTART-CASE.
    ;;
    ;;Every ?HANDLER  must be  an expression  evaluating to  a procedure
    ;;accepting a single argument.  The return values of ?HANDLER become
    ;;the return values of RESTART-CASE.
    ;;
    (syntax-rules ()
      ((_ ?body)
       ?body)
      ((_ ?body (?key0 ?handler0) (?key ?handler) ...)
       (call/cc
	   (lambda (restart-proc)
	     (parametrise
		 ((installed-restart-point
		   (make-<restart-point> restart-proc
		     `(((?key0 . ,?handler0)
			(?key  . ,?handler)
			...)
		       . ,(installed-restart-point.restart-handlers)))))
	       ?body))))
      ))

  (define* (find-restart {key symbol?})
    ;;Search  the current  dynamic  environment for  the innest  restart
    ;;handler  associated to  KEY.  If  a handler  is found:  return its
    ;;procedure; otherwise return #f.
    ;;
    (exists (lambda (alist)
	      (cond ((assq key alist)
		     => cdr)
		    (else #f)))
      (installed-restart-point.restart-handlers)))

  (define (invoke-restart key/handler)
    ;;Given a symbol representing the  name of a restart handler: search
    ;;the  associated handler  in  the current  dynamic environment  and
    ;;apply it to the signaled condition object.
    ;;
    ;;Given a  procedure being the  restart handler itself: apply  it to
    ;;the signaled condition object
    ;;
    (define (%call-restart-handler handler)
      ((installed-restart-point.restart-proc) (handler (installed-restart-point.signaled-object))))
    (cond ((symbol? key/handler)
	   (cond ((find-restart key/handler)
		  => %call-restart-handler)
		 (else
		  (error __who__
		    "attempt to invoke non-existent restart"
		    key/handler))))
	  ((procedure? key/handler)
	   (%call-restart-handler key/handler))
	  (else
	   (procedure-argument-violation __who__
	     "expected restart name or procedure as argument"
	     key/handler))))

  #| end of module |# )


(parametrise ((check-test-name	'handlers-case))

  (check	;no condition
      (with-result
	(handlers-case
	    ((&error   (lambda (E)
			 (add-result 'error-handler)
			 1))
	     (&warning (lambda (E)
			 (add-result 'warning-handler)
			 2)))
	  (add-result 'body)
	  1))
    => '(1 (body)))

;;; --------------------------------------------------------------------

  (internal-body

    (define (doit C)
      (with-result
	(handlers-case
	    ((&error   (lambda (E)
			 (add-result 'error-handler)
			 1))
	     (&warning (lambda (E)
			 (add-result 'warning-handler)
			 2)))
	  (add-result 'body-begin)
	  (signal C)
	  (add-result 'body-normal-return))))

    (check
	(doit (make-error))
      => '(1 (body-begin error-handler)))

    (check
	(doit (make-warning))
      => '(2 (body-begin warning-handler)))

    #| end of body |# )

  (internal-body

    (define (doit C)
      (with-result
	(handlers-case
	    ((&error   (lambda (E)
			 (add-result 'error-handler)
			 1)))
	  (handlers-case
	      ((&warning (lambda (E)
			   (add-result 'warning-handler)
			   2)))
	    (add-result 'body-begin)
	    (signal C)
	    (add-result 'body-normal-return)))))

    (check
	(doit (make-error))
      => '(1 (body-begin error-handler)))

    (check
	(doit (make-warning))
      => '(2 (body-begin warning-handler)))

    #| end of body |# )

  #t)


(parametrise ((check-test-name	'handlers-bind))

  (check	;no condition
      (with-result
	(handlers-case
	    ((&error   (lambda (E)
			 (add-result 'error-handler)
			 1))
	     (&warning (lambda (E)
			 (add-result 'warning-handler)
			 2)))
	  (add-result 'body)
	  1))
    => '(1 (body)))

;;; --------------------------------------------------------------------

  (check	;escaping from handler
      (with-result
	(call/cc
	    (lambda (escape)
	      (handlers-bind
		  ((&error (lambda (E)
			     (add-result 'error-handler)
			     (escape 2))))
		(add-result 'body-begin)
		(raise (make-error))
		(add-result 'body-return)
		1))))
    => '(2 (body-begin error-handler)))

  (check	;returning from handler
      (with-result
	(call/cc
	    (lambda (escape)
	      (handlers-bind
		  ((&error (lambda (E)
			     (add-result 'outer-error-handler)
			     (escape 2))))
		(handlers-bind
		    ((&error (lambda (E)
			       ;;By  returning this  handler refuses  to
			       ;;handle this condition.
			       (add-result 'inner-error-handler))))
		  (add-result 'body-begin)
		  (raise (make-error))
		  (add-result 'body-return)
		  1)))))
    => '(2 (body-begin inner-error-handler outer-error-handler)))

  #t)


(parametrise ((check-test-name	'restarts))

  (check
      (find-restart 'alpha)
    => #f)

  (internal-body
    (define (restarts-outside/handlers-inside C)
      (with-result
	(restart-case
	    (handlers-bind
		((&error   (lambda (E)
			     (add-result 'error-handler-begin)
			     (invoke-restart 'alpha)
			     (add-result 'error-handler-return)))
		 (&warning (lambda (E)
			     (add-result 'warning-handler-begin)
			     (let ((handler (find-restart 'beta)))
			       (invoke-restart handler))
			     (add-result 'warning-handler-return))))
	      (signal C))
	  (alpha (lambda (E)
		   (add-result 'restart-alpha)
		   1))
	  (beta  (lambda (E)
		   (add-result 'restart-beta)
		   2)))))

    (check
	(restarts-outside/handlers-inside (make-error))
      => '(1 (error-handler-begin restart-alpha)))

    (check
	(restarts-outside/handlers-inside (make-warning))
      => '(2 (warning-handler-begin restart-beta)))

    #| end of body |# )

  (internal-body
    (define (restarts-inside/handlers-outside C)
      (with-result
	(handlers-bind
	    ((&error   (lambda (E)
			 (add-result 'error-handler-begin)
			 (invoke-restart 'alpha)
			 (add-result 'error-handler-return)))
	     (&warning (lambda (E)
			 (add-result 'warning-handler-begin)
			 (let ((handler (find-restart 'beta)))
			   (invoke-restart handler))
			 (add-result 'warning-handler-begin))))
	  (restart-case
	      (signal C)
	    (alpha (lambda (E)
		     (add-result 'restart-alpha)
		     1))
	    (beta  (lambda (E)
		     (add-result 'restart-beta)
		     2))))))

    (check
	(restarts-inside/handlers-outside (make-error))
      => '(1 (error-handler-begin restart-alpha)))

    (check
	(restarts-inside/handlers-outside (make-warning))
      => '(2 (warning-handler-begin restart-beta)))

    #| end of body |# )

  (internal-body
    (define (restarts-inside/nested-handlers C)
      (with-result
	(handlers-bind
	    ((&error   (lambda (E)
			 (add-result 'error-handler)
			 (invoke-restart 'alpha))))
	  (handlers-bind
	      ((&warning (lambda (E)
			   (add-result 'warning-handler)
			   (let ((handler (find-restart 'beta)))
			     (invoke-restart handler)))))
	    (restart-case
		(signal C)
	      (alpha (lambda (E)
		       (add-result 'restart-alpha)
		       1))
	      (beta  (lambda (E)
		       (add-result 'restart-beta)
		       2)))))))

    (check
	(restarts-inside/nested-handlers (make-error))
      => '(1 (error-handler restart-alpha)))

    (check
	(restarts-inside/nested-handlers (make-warning))
      => '(2 (warning-handler restart-beta)))

    #| end of LET |# )

  (internal-body
    (define (nested-restarts/handlers-outside C)
      (with-result
	(handlers-bind
	    ((&error   (lambda (E)
			 (add-result 'error-handler)
			 (invoke-restart 'alpha)))
	     (&warning (lambda (E)
			 (add-result 'warning-handler)
			 (let ((handler (find-restart 'beta)))
			   (invoke-restart handler)))))

	  (restart-case
	      (restart-case
		  (signal C)
		(alpha (lambda (E)
			 (add-result 'restart-alpha)
			 1)))
	    (beta  (lambda (E)
		     (add-result 'restart-beta)
		     2))))))

    (check
	(nested-restarts/handlers-outside (make-error))
      => '(1 (error-handler restart-alpha)))

    (check
	(nested-restarts/handlers-outside (make-warning))
      => '(2 (warning-handler restart-beta)))

    #| end of body |# )

  (check	;use value
      (restart-case
	  (handlers-bind
	      ((&message (lambda (E)
			   (add-result 'message-handler)
			   (invoke-restart 'use-value))))
	    (signal (make-message-condition "ciao")))
	(use-value (lambda (value)
		     (condition-message value))))
    => "ciao")

  (check	;normal return in handler
      (with-result
	(handlers-bind
	    ((&message (lambda (E)
			 (add-result 'outer-message-handler)
			 (invoke-restart 'use-value))))
	  (handlers-bind
	      ((&message (lambda (E)
			   ;;By returning  this handler refuses  to handle
			   ;;the condition.
			   (add-result 'inner-message-handler))))
	    (restart-case
		(begin
		  (add-result 'body-begin)
		  (signal (make-message-condition "ciao"))
		  (add-result 'body-return))
	      (use-value (lambda (value)
			   (add-result 'use-value-restart)
			   (condition-message value)))))))
    => '("ciao" (body-begin
		 inner-message-handler
		 outer-message-handler
		 use-value-restart)))

  #f)


;;;; done

(check-report)

;;; end of file
;; Local Variables:
;; fill-column: 72
;; coding: utf-8-unix
;; eval: (put 'handlers-case		'scheme-indent-function 1)
;; eval: (put 'handlers-bind		'scheme-indent-function 1)
;; eval: (put 'restart-case		'scheme-indent-function 1)
;; eval: (put 'make-<restart-point>	'scheme-indent-function 1)
;; End:
