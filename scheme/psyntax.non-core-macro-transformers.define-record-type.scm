;;;Copyright (c) 2010-2015 Marco Maggi <marco.maggi-ipsu@poste.it>
;;;Copyright (c) 2006, 2007 Abdulaziz Ghuloum and Kent Dybvig
;;;
;;;Permission is hereby  granted, free of charge,  to any person obtaining  a copy of
;;;this software and associated documentation files  (the "Software"), to deal in the
;;;Software  without restriction,  including without  limitation the  rights to  use,
;;;copy, modify,  merge, publish, distribute,  sublicense, and/or sell copies  of the
;;;Software,  and to  permit persons  to whom  the Software  is furnished  to do  so,
;;;subject to the following conditions:
;;;
;;;The above  copyright notice and  this permission notice  shall be included  in all
;;;copies or substantial portions of the Software.
;;;
;;;THE  SOFTWARE IS  PROVIDED  "AS IS",  WITHOUT  WARRANTY OF  ANY  KIND, EXPRESS  OR
;;;IMPLIED, INCLUDING BUT  NOT LIMITED TO THE WARRANTIES  OF MERCHANTABILITY, FITNESS
;;;FOR A  PARTICULAR PURPOSE AND NONINFRINGEMENT.   IN NO EVENT SHALL  THE AUTHORS OR
;;;COPYRIGHT HOLDERS BE LIABLE FOR ANY  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
;;;AN ACTION OF  CONTRACT, TORT OR OTHERWISE,  ARISING FROM, OUT OF  OR IN CONNECTION
;;;WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


(module (define-record-type-macro)
  ;;Transformer function used to expand R6RS's DEFINE-RECORD-TYPE macros
  ;;from the  top-level built  in environment.   Expand the  contents of
  ;;INPUT-FORM.STX; return a syntax object that must be further expanded.
  ;;
  (define-constant __module_who__ 'define-record-type)


;;;; helpers

(define (%named-gensym/suffix foo suffix)
  (gensym (string-append (symbol->string (syntax->datum foo)) suffix)))

(define (%named-gensym/prefix foo prefix)
  (gensym (string-append prefix (symbol->string (syntax->datum foo)))))


(define (define-record-type-macro input-form.stx)
  (syntax-match input-form.stx ()
    ((_ ?namespec ?clause* ...)
     (begin
       (%verify-clauses input-form.stx ?clause*)
       (%do-define-record input-form.stx ?namespec ?clause*)))
    ))


(define (%do-define-record input-form.stx namespec clause*)
  (case-define synner
    ((message)
     (synner message #f))
    ((message subform)
     (syntax-violation __module_who__ message input-form.stx subform)))

  (define-values (foo make-foo foo?)
    (%parse-full-name-spec namespec))
  (define foo-rtd			(%named-gensym/suffix foo "-rtd"))
  (define foo-rcd			(%named-gensym/suffix foo "-rcd"))
  (define parent-rtd			(%named-gensym/suffix foo "-parent-rtd"))
  (define foo-constructor-protocol	(%named-gensym/suffix foo "-constructor-protocol"))
  (define foo-destructor		(%named-gensym/prefix foo "destroy-"))
  (define foo-custom-printer		(%named-gensym/suffix foo "-custom-printer"))
  (define-values
    (x*
		;A list of identifiers representing all the field names.
     idx*
		;A list  of fixnums  representing all the  field indexes
		;(zero-based).
     foo-x*
		;A list  of identifiers  representing the  safe accessor
		;names.
     unsafe-foo-x*
		;A list of identifiers  representing the unsafe accessor
		;names.
     mutable-x*
		;A list  of identifiers  representing the  mutable field
		;names.
     set-foo-idx*
		;A  list  of  fixnums  representing  the  mutable  field
		;indexes (zero-based).
     foo-x-set!*
		;A list of identifiers representing the mutator names.
     unsafe-foo-x-set!*
		;A list  of identifiers representing the  unsafe mutator
		;names.
     immutable-x*
		;A list of identifiers  representing the immutable field
		;names.
     tag*
		;A list of tag identifiers representing the field tags.
     mutable-tag*
		;A list of tag identifiers representing the mutable field tags.
     immutable-tag*
		;A list of tag identifiers representing the immutable field tags.
     )
    (%parse-field-specs foo (%get-fields clause*) synner))

  ;;Code  for  parent record-type  descriptor  and  parent record-type  constructor
  ;;descriptor retrieval.
  ;;
  ;;FOO-PARENT: an identifier representing the parent type, or false if there is no
  ;;parent or the parent is specified through the procedural layer.
  ;;
  ;;PARENT-RTD-CODE:  false or  a  symbolic expression  representing an  expression
  ;;which, expanded and  evaluated at run-time, will return  the parent record-type
  ;;descriptor.
  ;;
  ;;PARENT-RCD-CODE:  false or  a  symbolic expression  representing an  expression
  ;;which, expanded and  evaluated at run-time, will return  the parent record-type
  ;;default constructor descriptor.
  (define-values (foo-parent parent-rtd-code parent-rcd-code)
    (receive-and-return (foo-parent parent-rtd-code parent-rcd-code)
	(%make-parent-rtd+rcd-code clause* synner)
      ;;If a  parent record type  is specified and  its syntactic identifier  is an
      ;;imported syntactic binding: we want to  make sure that the imported library
      ;;is visited.
      (when foo-parent
	(visit-library-of-imported-syntactic-binding __module_who__ input-form.stx foo-parent (current-inferior-lexenv)))))

  ;;This can be  a symbol or false.  When  a symbol: the symbol is  the record type
  ;;UID, which will make this record  type non-generative.  When false: this record
  ;;type is generative.
  (define foo-uid
    (%get-uid foo clause* synner))

  ;;Code  to  build  at  run-time:  the  record-type  descriptor;  the  record-type
  ;;constructor descriptor; the record-type destructor function.
  (define foo-rtd-code
    (%make-rtd-code foo foo-uid clause* parent-rtd synner))
  (define foo-rcd-code
    (%make-rcd-code clause* foo-rtd foo-constructor-protocol parent-rcd-code))
  (define foo-destructor-code
    (%make-destructor-code clause* foo-destructor foo foo-rtd foo-parent parent-rtd parent-rtd-code synner))

  ;;Code for protocol.
  (define constructor-protocol-code
    (%get-constructor-protocol-code clause* synner))

  ;;Code for custom printer
  (define foo-custom-printer-code
    (%make-custom-printer-code clause* foo foo-rtd synner))

  ;;A  symbolic expression  representing  a  form which,  expanded  and evaluated  at
  ;;expand-time, returns the right-hand side of the record-type name's DEFINE-SYNTAX.
  ;;The value of the right-hand side is the syntactic binding's descriptor.
  (define foo-syntactic-binding-form
    (%make-type-name-syntactic-binding-form foo make-foo foo-destructor foo?
					    foo-parent foo-rtd foo-rcd
					    x* mutable-x*
					    foo-x* foo-x-set!*
					    unsafe-foo-x* unsafe-foo-x-set!*))
  (define tag-type-spec-form
    ;;The  tag-type-spec stuff  is used  to add  a tag  property to  the record  type
    ;;identifier.
    (%make-tag-type-spec-form foo make-foo foo? foo-parent
			      x* foo-x* unsafe-foo-x*
			      mutable-x* foo-x-set!* unsafe-foo-x-set!*
			      immutable-x* input-form.stx))

  (bless
   `(begin
      ;;Parent record-type descriptor.
      (define ,parent-rtd ,parent-rtd-code)
      ;;Record-type descriptor.
      (define ,foo-rtd ,foo-rtd-code)
      ;;Protocol function.
      (define ,foo-constructor-protocol ,constructor-protocol-code)
      ;;Record-constructor descriptor.
      (define ,foo-rcd ,foo-rcd-code)
      ;;Record destructor function.
      (define ,foo-destructor ,foo-destructor-code)
      ;;Record printer function.
      (define ,foo-custom-printer ,foo-custom-printer-code)
      ;;Syntactic binding for record-type name.
      (define-syntax ,foo
	,foo-syntactic-binding-form)
      (begin-for-syntax ,tag-type-spec-form)
      ;;Type predicate.
      (define (brace ,foo? <predicate>)
	(record-predicate ,foo-rtd))
      ;;Default constructor.
      (define ,make-foo
	(record-constructor ,foo-rcd))
      ;;We want the default constructor function to have a signature specifying the
      ;;record-type as return type.
      (begin-for-syntax
	(internal-body
	  (import (prefix (vicare expander tag-type-specs) typ.))
	  (define %constructor-signature
	    (typ.make-lambda-signature (typ.make-retvals-signature-single-value (syntax ,foo))
				       (typ.make-formals-signature (syntax <list>))))
	  (define %constructor-tag-id
	    (typ.fabricate-procedure-tag-identifier (quote ,make-foo) %constructor-signature))
	  (typ.override-identifier-tag! (syntax ,make-foo) %constructor-tag-id)))
      (module (,@foo-x*
	       ,@foo-x-set!*
	       ;;We want to  create the syntactic bindings of  unsafe accessors and
	       ;;mutators only when STRICT-R6RS mode is DISabled.
	       ,@(if (option.strict-r6rs)
		     '()
		   (append unsafe-foo-x* unsafe-foo-x-set!*)))
	,(%gen-unsafe-accessor+mutator-code foo foo-rtd foo-rcd
					    unsafe-foo-x*      x*         idx*
					    unsafe-foo-x-set!* mutable-x* set-foo-idx*
					    tag*)

	;;Safe record fields accessors.
	;;
	;;NOTE The  unsafe variant of  the field accessor  must be a  syntax object
	;;which, expanded  by itself and  evaluated, returns an  accessor function.
	;;We know that: when the compiler finds a form like:
	;;
	;;   ((lambda (record)
	;;      (unsafe-foo-x record))
	;;    the-record)
	;;
	;;it integrates the LAMBDA into:
	;;
	;;   (unsafe-foo-x the-record)
	;;
	;;(Marco Maggi; Wed Apr 23, 2014)
	,@(map (lambda (foo-x unsafe-foo-x field-tag)
		 `(begin
		    (internal-define (safe) ((brace ,foo-x ,field-tag) (brace record ,foo))
		      (,unsafe-foo-x record))
		    (begin-for-syntax
		      (set-identifier-unsafe-variant! (syntax ,foo-x)
			(syntax (lambda (record)
				  (,unsafe-foo-x record)))))))
	    foo-x* unsafe-foo-x* tag*)

	;;Safe record fields mutators (if any).
	;;
	;;NOTE The  unsafe variant  of the  field mutator must  be a  syntax object
	;;which, expanded by itself and  evaluated, returns a mutator function.  We
	;;know that: when the compiler finds a form like:
	;;
	;;   ((lambda (record new-value)
	;;      (unsafe-foo-x-set! record new-value))
	;;    the-record the-new-value)
	;;
	;;it integrates the LAMBDA into:
	;;
	;;   (unsafe-foo-x-set! the-record the-new-value)
	;;
	;;(Marco Maggi; Wed Apr 23, 2014)
	,@(map (lambda (foo-x-set! unsafe-foo-x-set! field-tag)
		 `(begin
		    (internal-define (safe) ((brace ,foo-x-set! <void>) (brace record ,foo) (brace new-value ,field-tag))
		      (,unsafe-foo-x-set! record new-value))
		    (begin-for-syntax
		      (set-identifier-unsafe-variant! (syntax ,foo-x-set!)
			(syntax (lambda (record new-value)
				  (,unsafe-foo-x-set! record new-value)))))))
	    foo-x-set!* unsafe-foo-x-set!* mutable-tag*)

	#| end of module: safe and unsafe accessors and mutators |# )
      )))


(define (%gen-unsafe-accessor+mutator-code foo foo-rtd foo-rcd
					   unsafe-foo-x*      x*         idx*
					   unsafe-foo-x-set!* mutable-x* set-foo-idx*
					   tag*)
  (define (%make-field-index-varname x.id)
    (string->symbol (string-append foo.str "-" (symbol->string (syntax->datum x.id)) "-index")))
  (define foo.str
    (symbol->string (syntax->datum foo)))
  (define foo-first-field-offset
    (%named-gensym/suffix foo "-first-field-offset"))
  `(module (,@unsafe-foo-x* ,@unsafe-foo-x-set!*)
     (define ,foo-first-field-offset
       ;;The field at index  3 in the RTD is: the index of  the first field of this
       ;;subtype in the  layout of instances; it  is the total number  of fields of
       ;;the parent type.
       ($struct-ref ,foo-rtd 3))

     ;;all fields indexes
     ,@(map (lambda (x idx)
	      (let ((the-index (%make-field-index-varname x)))
		`(define (brace ,the-index <fixnum>)
		   (fx+ ,idx ,foo-first-field-offset))))
	 x* idx*)

     ;;unsafe record fields accessors
     ,@(map (lambda (unsafe-foo-x x field.tag)
	      (let ((the-index (%make-field-index-varname x)))
		`(define-syntax-rule (,unsafe-foo-x ?x)
		   (tag-unsafe-cast ,field.tag ($struct-ref ?x ,the-index)))))
	 unsafe-foo-x* x* tag*)

     ;;unsafe record fields mutators
     ,@(map (lambda (unsafe-foo-x-set! x)
	      (let ((the-index (%make-field-index-varname x)))
		`(define-syntax-rule (,unsafe-foo-x-set! ?x ?v)
		   ($struct-set! ?x ,the-index ?v))))
	 unsafe-foo-x-set!* mutable-x*)
     #| end of module: unsafe accessors and mutators |# ))


(define (%parse-full-name-spec spec)
  ;;Given a syntax object representing  a full record-type name specification: return
  ;;the 3 syntactic  identifiers: the type name, the constructor  name, the predicate
  ;;name.
  ;;
  (syntax-match spec ()
    ((?foo ?make-foo ?foo?)
     (and (identifier? ?foo)
	  (identifier? ?make-foo)
	  (identifier? ?foo?))
     (values ?foo ?make-foo ?foo?))
    (?foo
     (identifier? ?foo)
     (values ?foo
	     (identifier-append ?foo "make-" (syntax->datum ?foo))
	     (identifier-append ?foo ?foo "?")))
    ))


(define (%get-uid foo clause* synner)
  (let ((clause (%get-clause 'nongenerative clause*)))
    (syntax-match clause ()
      ((_)
       (gensym (syntax->datum foo)))
      ((_ ?uid)
       (identifier? ?uid)
       (syntax->datum ?uid))
      ;;No matching clause found.  This record type will be non-generative.
      (#f
       #f)
      (_
       (synner "expected symbol or no argument in nongenerative clause" clause)))))


;;;; RTD and RCD code

(define (%make-rtd-code name foo-uid clause* parent-rtd-code synner)
  ;;Return a  sexp which,  when evaluated,  will return  a record-type
  ;;descriptor.
  ;;
  (define sealed?
    (let ((clause (%get-clause 'sealed clause*)))
      (syntax-match clause ()
	((_ #t)	#t)
	((_ #f)	#f)
	;;No matching clause found.
	(#f		#f)
	(_
	 (synner "invalid argument in SEALED clause" clause)))))
  (define opaque?
    (let ((clause (%get-clause 'opaque clause*)))
      (syntax-match clause ()
	((_ #t)	#t)
	((_ #f)	#f)
	;;No matching clause found.
	(#f		#f)
	(_
	 (synner "invalid argument in OPAQUE clause" clause)))))
  (define fields
    (let ((clause (%get-clause 'fields clause*)))
      (syntax-match clause ()
	((_ field-spec* ...)
	 `(quote ,(list->vector
		   (map (lambda (field-spec)
			  (syntax-match field-spec (mutable immutable brace)
			    ((mutable (brace ?name ?tag) . ?rest)
			     `(mutable ,?name))
			    ((mutable ?name . ?rest)
			     `(mutable ,?name))
			    ((immutable (brace ?name ?tag) . ?rest)
			     `(immutable ,?name))
			    ((immutable ?name . ?rest)
			     `(immutable ,?name))
			    ((brace ?name ?tag)
			     `(immutable ,?name))
			    (?name
			     `(immutable ,?name))))
		     field-spec*))))
	;;No matching clause found.
	(#f
	 (quote (quote #())))

	(_
	 (synner "invalid syntax in FIELDS clause" clause)))))
  `(make-record-type-descriptor (quote ,name) ,parent-rtd-code
				(quote ,foo-uid) ,sealed? ,opaque? ,fields))

;;; --------------------------------------------------------------------

(define (%make-rcd-code clause* foo-rtd foo-constructor-protocol parent-rcd-code)
  ;;Return a sexp  which, when evaluated, will  return the record-type
  ;;default constructor descriptor.
  ;;
  `(make-record-constructor-descriptor ,foo-rtd ,parent-rcd-code ,foo-constructor-protocol))

(define (%make-parent-rtd+rcd-code clause* synner)
  ;;Return 3 values:
  ;;
  ;;1. A syntactic identifier representing the parent type, or false if there is no
  ;;parent or the parent is specified through the procedural layer.
  ;;
  ;;2. False  of a symbolic  expression representing an expression  which, expanded
  ;;and evaluated at run-time, will return the parent's record-type descriptor.
  ;;
  ;;3.  False or  a symbolic expression representing an  expression which, expanded
  ;;and  evaluated  at  run-time,  will   return  the  parent  record-type  default
  ;;constructor descriptor.
  ;;
  (let ((parent-clause (%get-clause 'parent clause*)))
    (syntax-match parent-clause ()
      ;;If there  is a PARENT  clause insert code that  retrieves the RTD  from the
      ;;parent type name.
      ((_ ?name)
       (identifier? ?name)
       (values ?name
	       `(record-type-descriptor ,?name)
	       `(record-constructor-descriptor ,?name)))

      ;;If there is  no PARENT clause try to retrieve  the expression evaluating to
      ;;the RTD.
      (#f
       (let ((parent-rtd-clause (%get-clause 'parent-rtd clause*)))
	 (syntax-match parent-rtd-clause ()
	   ((_ ?rtd ?rcd)
	    (values #f ?rtd ?rcd))

	   ;;If neither  the PARENT  nor the PARENT-RTD  clauses are  present: just
	   ;;return false.
	   (#f
	    (values #f #f #f))

	   (_
	    (synner "invalid syntax in PARENT-RTD clause" parent-rtd-clause)))))

      (_
       (synner "invalid syntax in PARENT clause" parent-clause)))))


(define (%make-destructor-code clause* foo-destructor foo foo-rtd foo-parent parent-rtd parent-rtd-code synner)
  ;;Extract from the  CLAUSE* the DESTRUCTOR-PROTOCOL one and  return an expression
  ;;which, expanded and evaluated at run-time, will return the destructor function;
  ;;the expression will return false if there is no destructor.
  ;;
  ;;If FOO-PARENT is  not false: this record  type has a parent  specified with the
  ;;PARENT clause;  in this  case: PARENT-RTD  is an  expression evaluating  to the
  ;;parent's RTD.
  ;;
  ;;If PARENT-RTD-CODE is  not false: this record type has  a parent specified with
  ;;the PARENT-RTD clause; in this case:  PARENT-RTD is an expression evaluating to
  ;;the parent's RTD.
  ;;
  (let ((clause (%get-clause 'destructor-protocol clause*))
	(foo-destructor-protocol (%named-gensym/suffix foo "-destructor-protocol")))
    (syntax-match clause ()
      ((_ ?destructor-protocol-expr)
       ;;This record definition has a destructor protocol.
       `(let ((,foo-destructor-protocol ,?destructor-protocol-expr))
	  (unless (procedure? ,foo-destructor-protocol)
	    (assertion-violation (quote ,foo)
	      "expected closure object as result of evaluating the destructor protocol expression"
	      ,foo-destructor-protocol))
	  (receive-and-return (,foo-destructor)
	      ,(if (or foo-parent parent-rtd-code)
		   `(,foo-destructor-protocol (internal-applicable-record-type-destructor ,parent-rtd))
		 `(,foo-destructor-protocol))
	    (if (procedure? ,foo-destructor)
		(record-type-destructor-set! ,foo-rtd ,foo-destructor)
	      (assertion-violation (quote ,foo)
		"expected closure object as result of applying the destructor protocol function"
		,foo-destructor)))))

      ;;No  matching  clause  found.   This record  definition  has  no  destructor
      ;;protocol, but the parent (if any) might have one.
      ;;
      ;;*  If  the  parent  record-type  has  a  record  destructor:  the  parent's
      ;;destructor becomes this record-type's destructor.
      ;;
      ;;* If  the parent record-type  has no record destructor:  this record-type's
      ;;record destructor variable is set to false.
      ;;
      (#f
       (if (or foo-parent parent-rtd-code)
	   (let ((foo-parent-destructor (%named-gensym/suffix foo "-parent-destructor")))
	     `(cond ((record-type-destructor ,parent-rtd)
		     => (lambda (,foo-parent-destructor)
			  (record-type-destructor-set! ,foo-rtd ,foo-parent-destructor)
			  ,foo-parent-destructor))))
	 ;;Set to false this record-type record destructor variable.
	 #f))

      (_
       (synner "invalid syntax in DESTRUCTOR-PROTOCOL clause" clause)))))


(define (%get-constructor-protocol-code clause* synner)
  ;;Return  a  sexp  which,   when  evaluated,  returns  the  protocol
  ;;function.
  ;;
  (let ((clause (%get-clause 'protocol clause*)))
    (syntax-match clause ()
      ((_ ?expr)
       ?expr)

      ;;No matching clause found.
      (#f	#f)

      (_
       (synner "invalid syntax in PROTOCOL clause" clause)))))

(define (%get-fields clause*)
  ;;Return   a  list   of  syntax   objects  representing   the  field
  ;;specifications.
  ;;
  (syntax-match clause* (fields)
    (()
     '())
    (((fields ?field-spec* ...) . _)
     ?field-spec*)
    ((_ . ?rest)
     (%get-fields ?rest))))


(define (%parse-field-specs foo field-clause* synner)
  ;;Given the  arguments of the  fields specification clause  return 4
  ;;values:
  ;;
  ;;1..The list of identifiers representing all the field names.
  ;;
  ;;2..The  list  of  fixnums  representings all  the  field  relative
  ;;   indexes (zero-based).
  ;;
  ;;3..A list of identifiers representing the safe accessor names.
  ;;
  ;;4..A list of identifiers representing the unsafe accessor names.
  ;;
  ;;5..The list of identifiers representing the mutable field names.
  ;;
  ;;6..The list  of fixnums  representings the mutable  field relative
  ;;   indexes (zero-based).
  ;;
  ;;7..A list of identifiers representing the safe mutator names.
  ;;
  ;;8..A list of identifiers representing the unsafe mutator names.
  ;;
  ;;9..The list of identifiers representing the immutable field names.
  ;;
  ;;10.The list of identifiers representing the field tags.
  ;;
  ;;11.The list of identifiers representing the mutable field tags.
  ;;
  ;;12.The list of identifiers representing the immutable field tags.
  ;;
  ;;Here we assume that FIELD-CLAUSE* is null or a proper list.
  ;;
  (define (gen-safe-accessor-name x)
    (identifier-append  foo foo "-" x))
  (define (gen-unsafe-accessor-name x)
    (identifier-append  foo "$" foo "-" x))
  (define (gen-safe-mutator-name x)
    (identifier-append  foo foo "-" x "-set!"))
  (define (gen-unsafe-mutator-name x)
    (identifier-append  foo "$" foo "-" x "-set!"))
  (let loop ((field-clause*		field-clause*)
	     (i				0)
	     (field*			'())
	     (idx*			'())
	     (accessor*			'())
	     (unsafe-accessor*		'())
	     (mutable-field*		'())
	     (mutable-idx*		'())
	     (mutator*			'())
	     (unsafe-mutator*		'())
	     (immutable-field*		'())
	     (tag*			'())
	     (mutable-tag*		'())
	     (immutable-tag*		'()))
    (syntax-match field-clause* (mutable immutable)
      (()
       (values (reverse field*) (reverse idx*) (reverse accessor*) (reverse unsafe-accessor*)
	       (reverse mutable-field*) (reverse mutable-idx*) (reverse mutator*) (reverse unsafe-mutator*)
	       (reverse immutable-field*)
	       (reverse tag*)
	       (reverse mutable-tag*) (reverse immutable-tag*)))

      (((mutable   ?name ?accessor ?mutator) . ?rest)
       (and (identifier? ?accessor)
	    (identifier? ?mutator))
       (receive (field.id field.tag)
	   (parse-tagged-identifier-syntax ?name)
	 (loop ?rest (+ 1 i)
	       (cons field.id field*)		(cons i idx*)
	       (cons ?accessor accessor*)	(cons (gen-unsafe-accessor-name field.id) unsafe-accessor*)
	       (cons field.id mutable-field*)	(cons i mutable-idx*)
	       (cons ?mutator mutator*)	(cons (gen-unsafe-mutator-name  field.id) unsafe-mutator*)
	       immutable-field*
	       (cons field.tag tag*)
	       (cons field.tag mutable-tag*)	immutable-tag*)))

      (((immutable ?name ?accessor) . ?rest)
       (identifier? ?accessor)
       (receive (field.id field.tag)
	   (parse-tagged-identifier-syntax ?name)
	 (loop ?rest (+ 1 i)
	       (cons ?name field*)		(cons i idx*)
	       (cons ?accessor accessor*)	(cons (gen-unsafe-accessor-name ?name) unsafe-accessor*)
	       mutable-field*			mutable-idx*
	       mutator*			unsafe-mutator*
	       (cons ?name immutable-field*)
	       (cons field.tag tag*)
	       mutable-tag*			(cons field.tag immutable-tag*))))

      (((mutable   ?name) . ?rest)
       (receive (field.id field.tag)
	   (parse-tagged-identifier-syntax ?name)
	 (loop ?rest (+ 1 i)
	       (cons field.id field*)				(cons i idx*)
	       (cons (gen-safe-accessor-name   field.id)	accessor*)
	       (cons (gen-unsafe-accessor-name field.id)	unsafe-accessor*)
	       (cons field.id mutable-field*)			(cons i mutable-idx*)
	       (cons (gen-safe-mutator-name    field.id)	mutator*)
	       (cons (gen-unsafe-mutator-name  field.id)	unsafe-mutator*)
	       immutable-field*
	       (cons field.tag tag*)
	       (cons field.tag mutable-tag*)			immutable-tag*)))

      (((immutable ?name) . ?rest)
       (receive (field.id field.tag)
	   (parse-tagged-identifier-syntax ?name)
	 (loop ?rest (+ 1 i)
	       (cons field.id field*)				(cons i idx*)
	       (cons (gen-safe-accessor-name   field.id)	accessor*)
	       (cons (gen-unsafe-accessor-name field.id)	unsafe-accessor*)
	       mutable-field*					mutable-idx*
	       mutator*					unsafe-mutator*
	       (cons field.id immutable-field*)
	       (cons field.tag tag*)
	       mutable-tag*					(cons field.tag immutable-tag*))))

      ((?name . ?rest)
       (receive (field.id field.tag)
	   (parse-tagged-identifier-syntax ?name)
	 (loop ?rest (+ 1 i)
	       (cons field.id field*)				(cons i idx*)
	       (cons (gen-safe-accessor-name   field.id)	 accessor*)
	       (cons (gen-unsafe-accessor-name field.id)	unsafe-accessor*)
	       mutable-field*					mutable-idx*
	       mutator*					unsafe-mutator*
	       (cons field.id immutable-field*)
	       (cons field.tag tag*)
	       mutable-tag*					(cons field.tag immutable-tag*))))

      ((?spec . ?rest)
       (synner "invalid field specification in DEFINE-RECORD-TYPE syntax"
	       ?spec)))))


(define (%make-custom-printer-code clause* foo foo-rtd synner)
  (let ((clause (%get-clause 'custom-printer clause*)))
    (syntax-match clause ()
      ((_ ?expr)
       (let ((printer (%named-gensym/suffix foo "-custom-printer")))
	 `(receive-and-return (,printer)
	      ,?expr
	    (if (procedure? ,printer)
		(record-type-printer-set! ,foo-rtd ,printer)
	      (assertion-violation (quote ,foo)
		"expected closure object from evaluation of expression in CUSTOM-PRINTER clause"
		,printer)))))

      ;;No matching clause found.
      (#f	#f)

      (_
       (synner "invalid syntax in CUSTOM-PRINTER clause" clause)))))


(define (%make-type-name-syntactic-binding-form foo.id make-foo.id foo-destructor.sym foo?.id
						foo-parent.id foo-rtd.sym foo-rcd.sym
						x* mutable-x*
						foo-x* foo-x-set!*
						unsafe-foo-x* unsafe-foo-x-set!*)
  ;;Build and  return symbolic expression  representing a form which,  expanded and
  ;;evaluated at  expand-time, returns  the record-type name's  syntactic binding's
  ;;descriptor.
  ;;
  ;;FOO.ID must be the identifier bound to the type name.
  ;;
  ;;MAKE-FOO.ID must be the identifier bound to the default constructor function.
  ;;
  ;;FOO?.ID must be the identifier bound to the type predicate.
  ;;
  ;;FOO-PARENT.ID must be false or the identifier bound to the parent's type name.
  ;;
  ;;FOO-RTD.SYM must be a  gensym: it will become the name  of the identifier bound
  ;;to the record-type descriptor.
  ;;
  ;;FOO-RTD.SYM must be a  gensym: it will become the name  of the identifier bound
  ;;to the record-constructor descriptor.
  ;;
  ;;X* must be a list of identifiers whose names represent all the field names.
  ;;
  ;;MUTABLE-X* must be a list of  identifiers whose names represent all the mutable
  ;;field names.
  ;;
  ;;FOO-X*,  FOO-X-SET!*,  UNSAFE-FOO-X*,  UNSAFE-FOO-X-SET!*   must  be  lists  of
  ;;identifiers bound  to: the safe field  accessors; the safe field  mutators; the
  ;;unsafe field accessors; the unsafe field mutators.
  ;;
  (define (%make-alist field-name*.id operator*.id)
    ;;We  want  to   return  a  symbolic  expression   representing  the  following
    ;;expand-time expression:
    ;;
    ;;   (list (cons (quote ?field-sym0) (syntax ?operator0))
    ;;         (cons (quote ?field-sym)  (syntax ?operator))
    ;;         ...)
    ;;
    ;;which evaluates to an aslist whose keys  are field names and whose values are
    ;;syntactic identifiers bound to accessors or mutators.
    ;;
    (cons 'list (map (lambda (key.id operator.id)
		       (list 'cons `(quote ,(syntax->datum key.id)) `(syntax ,operator.id)))
		  field-name*.id operator*.id)))

  ;;A sexp which will be BLESSed in the  output code.  The sexp will evaluate to an
  ;;alist in which:  keys are symbols representing all the  field names; values are
  ;;identifiers bound to the safe accessors.
  (define foo-fields-safe-accessors.table
    (%make-alist x* foo-x*))

  ;;A sexp which will be BLESSed in the  output code.  The sexp will evaluate to an
  ;;alist in which:  keys are symbols representing mutable field  names; values are
  ;;identifiers bound to safe mutators.
  (define foo-fields-safe-mutators.table
    (%make-alist mutable-x* foo-x-set!*))

  ;;A sexp which will be BLESSed in the  output code.  The sexp will evaluate to an
  ;;alist in which:  keys are symbols representing all the  field names; values are
  ;;identifiers bound to the unsafe accessors.
  (define foo-fields-unsafe-accessors.table
    (if (option.strict-r6rs)
	'()
      (%make-alist x* unsafe-foo-x*)))

  ;;A sexp which will be BLESSed in the  output code.  The sexp will evaluate to an
  ;;alist in which:  keys are symbols representing mutable field  names; values are
  ;;identifiers bound to unsafe mutators.
  (define foo-fields-unsafe-mutators.table
    (if (option.strict-r6rs)
	'()
      (%make-alist mutable-x* unsafe-foo-x-set!*)))

  `(make-syntactic-binding-descriptor/record-type-name
    (make-r6rs-record-type-spec (syntax ,foo-rtd.sym) (syntax ,foo-rcd.sym)
				,(and foo-parent.id `(syntax ,foo-parent.id))
				(syntax ,make-foo.id) (syntax ,foo-destructor.sym)
				(syntax ,foo?.id)
				,foo-fields-safe-accessors.table
				,foo-fields-safe-mutators.table
				,foo-fields-unsafe-accessors.table
				,foo-fields-unsafe-mutators.table)))


(define (%make-tag-type-spec-form foo make-foo foo? foo-parent
				  x* foo-x* unsafe-foo-x*
				  mutable-x* foo-x-set!* unsafe-foo-x-set!*
				  immutable-x* input-form.stx)
  (define type.str
    (symbol->string (syntax->datum foo)))
  (define %constructor-maker
    (string->symbol (string-append type.str "-constructor-maker")))
  (define %accessor-maker
    (string->symbol (string-append type.str "-accessor-maker")))
  (define %mutator-maker
    (string->symbol (string-append type.str "-mutator-maker")))
  (define %getter-maker
    (string->symbol (string-append type.str "-getter-maker")))
  (define %setter-maker
    (string->symbol (string-append type.str "-setter-maker")))
  `(internal-body
     (import (vicare)
       (prefix (vicare expander tag-type-specs) typ.))

     (define (,%constructor-maker input-form.stx)
       (syntax ,make-foo))

     (define (,%accessor-maker field.sym input-form-stx)
       (case field.sym
	 ,@(map (lambda (field-name accessor-id)
		  `((,field-name)	(syntax ,accessor-id)))
	     x* foo-x*)
	 (else #f)))

     (define (,%mutator-maker field.sym input-form-stx)
       (case field.sym
	 ,@(map (lambda (field-name mutator-id)
		  `((,field-name)	(syntax ,mutator-id)))
	     mutable-x* foo-x-set!*)
	 ,@(map (lambda (field-name)
		  `((,field-name)
		    (syntax-violation ',foo
		      "requested mutator of immutable record field name"
		      input-form-stx field.sym)))
	     immutable-x*)
	 (else #f)))

     (define (,%getter-maker keys-stx input-form-stx)
       (syntax-case keys-stx ()
	 (([?field-id])
	  (identifier? #'?field-id)
	  (,%accessor-maker (syntax->datum #'?field-id) input-form-stx))
	 (else #f)))

     (define (,%setter-maker keys-stx input-form-stx)
       (syntax-case keys-stx ()
	 (([?field-id])
	  (identifier? #'?field-id)
	  (,%mutator-maker (syntax->datum #'?field-id) input-form-stx))
	 (else #f)))

     (define %caster-maker #f)
     (define %dispatcher   #f)

     (define parent-id
       ,(if foo-parent
	    `(syntax ,foo-parent)
	  '(typ.record-tag-id)))

     (define tag-type-spec
       (typ.make-tag-type-spec (syntax ,foo) parent-id (syntax ,foo?)
			       ,%constructor-maker
			       ,%accessor-maker ,%mutator-maker
			       ,%getter-maker   ,%setter-maker
			       %caster-maker    %dispatcher))

     (typ.set-identifier-tag-type-spec! (syntax ,foo) tag-type-spec)))


(module (%verify-clauses)

  (define (%verify-clauses input-form.stx cls*)
    (define-constant R6RS-VALID-KEYWORDS
      (map bless
	'(fields parent parent-rtd protocol sealed opaque nongenerative)))
    (define-constant EXTENDED-VALID-KEYWORDS
      (append R6RS-VALID-KEYWORDS
	      (map bless
		'(fields parent parent-rtd protocol sealed opaque destructor-protocol custom-printer))))
    (define-constant VALID-KEYWORDS
      (if (option.strict-r6rs)
	  R6RS-VALID-KEYWORDS
	EXTENDED-VALID-KEYWORDS))
    (let loop ((cls*  cls*)
	       (seen* '()))
      (unless (null? cls*)
	(syntax-match (car cls*) ()
	  ((?kwd . ?rest)
	   (cond ((or (not (identifier? ?kwd))
		      (not (%free-id-member? ?kwd VALID-KEYWORDS)))
		  (syntax-violation __module_who__
		    "not a valid DEFINE-RECORD-TYPE keyword"
		    input-form.stx ?kwd))
		 ((bound-id-member? ?kwd seen*)
		  (syntax-violation __module_who__
		    "invalid duplicate clause in DEFINE-RECORD-TYPE"
		    input-form.stx ?kwd))
		 (else
		  (loop (cdr cls*) (cons ?kwd seen*)))))
	  (?cls
	   (syntax-violation __module_who__
	     "malformed define-record-type clause"
	     input-form.stx ?cls))
	  ))))

  (define (%free-id-member? x ls)
    (and (pair? ls)
	 (or (~free-identifier=? x (car ls))
	     (%free-id-member? x (cdr ls)))))

  #| end of module: %VERIFY-CLAUSES |# )


(define (%get-clause sym clause*)
  ;;Given a symbol SYM representing the  name of a clause and a syntax
  ;;object  CLAUSE*  representing  the clauses:  search  the  selected
  ;;clause and return it as syntax object.  When no matching clause is
  ;;found: return false.
  ;;
  (let next ((id       (bless sym))
	     (clause*  clause*))
    (syntax-match clause* ()
      (()
       #f)
      (((?key . ?rest) . ?clause*)
       (if (~free-identifier=? id ?key)
	   `(,?key . ,?rest)
	 (next id ?clause*))))))


;;;; done

#| end of module: DEFINE-RECORD-TYPE-MACRO |# )


;;; end of file
;; Local Variables:
;; mode: vicare
;; End: