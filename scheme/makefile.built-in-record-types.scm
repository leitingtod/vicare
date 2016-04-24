;; -*- coding: utf-8-unix -*-
;;
;;Part of: Vicare Scheme
;;Contents: table of built-in record types and condition object types
;;Date: Tue Dec 22, 2015
;;
;;Abstract
;;
;;
;;
;;Copyright (C) 2015, 2016 Marco Maggi <marco.maggi-ipsu@poste.it>
;;
;;This program is free  software: you can redistribute it and/or  modify it under the
;;terms  of  the  GNU General  Public  License  as  published  by the  Free  Software
;;Foundation, either version 3 of the License, or (at your option) any later version.
;;
;;This program  is distributed in the  hope that it  will be useful, but  WITHOUT ANY
;;WARRANTY; without  even the implied  warranty of  MERCHANTABILITY or FITNESS  FOR A
;;PARTICULAR PURPOSE.  See the GNU General Public License for more details.
;;
;;You should have received  a copy of the GNU General Public  License along with this
;;program.  If not, see <http://www.gnu.org/licenses/>.
;;


;;;; syntaxes

(define-syntax (define-built-in-record-type stx)
  (define (%false-or-id? obj)
    (or (identifier? obj)
	(not (syntax->datum obj))))
  (syntax-case stx (methods)
    ((?kwd ?type-name ?parent-name ?constructor ?predicate)
     (and (identifier? #'?type-name)
	  (%false-or-id? #'?parent-name)
	  (%false-or-id? #'?constructor)
	  (identifier? #'?predicate))
     #'(?kwd ?type-name ?parent-name ?constructor ?predicate (methods)))

    ((_    ?type-name ?parent-name ?constructor ?predicate (methods (?field-name ?accessor-name) ...))
     (and (identifier? #'?type-name)
	  (%false-or-id? #'?parent-name)
	  (%false-or-id? #'?constructor)
	  (identifier? #'?predicate))
     (let ((type-name.str (symbol->string (syntax->datum #'?type-name))))
       (define (mkid . str*)
	 (datum->syntax #'?type-name (string->symbol (apply string-append str*))))
       (with-syntax
	   ((TYPE-RTD (mkid type-name.str "-rtd"))
	    (TYPE-RCD (mkid type-name.str "-rcd")))
	 #'(set-cons! VICARE-CORE-BUILT-IN-RECORD-TYPES-SYNTACTIC-BINDING-DESCRIPTORS
		      (quote (?type-name
			      ($core-record-type-name
			       . (?type-name TYPE-RTD TYPE-RCD ?parent-name ?constructor ?predicate
					     ((?field-name . ?accessor-name) ...)))))))))
    ))


;;;; built-in record types

(define-built-in-record-type <library>
    <record>
  make-library library?
  (methods
   (uid				library-uid)
   (name			library-name)
   (imp-lib*			library-imp-lib*)
   (vis-lib*			library-vis-lib*)
   (inv-lib*			library-inv-lib*)
   (export-subst		library-export-subst)
   (global-env			library-global-env)
   (typed-locs			library-typed-locs)
   (visit-state			library-visit-state)
   (invoke-state		library-invoke-state)
   (visit-code			library-visit-code)
   (invoke-code			library-invoke-code)
   (guard-code			library-guard-code)
   (guard-lib*			library-guard-lib*)
   (visible?			library-visible?)
   (source-file-name		library-source-file-name)
   (option*			library-option*)
   (foreign-library*		library-foreign-library*)))

;;; --------------------------------------------------------------------

(define-built-in-record-type <lexical-environment>
    <record>
  #f environment?)

(define-built-in-record-type <interaction-lexical-environment>
    <lexical-environment>
  new-interaction-environment interaction-lexical-environment?)

(define-built-in-record-type <non-interaction-lexical-environment>
    <lexical-environment>
  environment non-interaction-lexical-environment?)

;;; --------------------------------------------------------------------

(define-built-in-record-type <object-type-spec>
    <record>
  #f object-type-spec?
  (methods
   (name				object-type-spec.name)
   (parent-ots				object-type-spec.parent-ots)
   (constructor-stx			object-type-spec.constructor-stx)
   (destructor-stx			object-type-spec.destructor-stx)
   (type-predicate-stx			object-type-spec.type-predicate-stx)
   (equality-predicate-id		object-type-spec.equality-predicate-id)
   (comparison-procedure-id		object-type-spec.comparison-procedure-id)
   (hash-function-id			object-type-spec.hash-function-id)
   (applicable-hash-function-id		object-type-spec.applicable-hash-function-id)
   (safe-accessor-stx			object-type-spec.safe-accessor-stx)
   (safe-mutator-stx			object-type-spec.safe-mutator-stx)
   (applicable-method-stx		object-type-spec.applicable-method-stx)
   (single-value-validator-lambda-stx	object-type-spec.single-value-validator-lambda-stx)
   (list-validator-lambda-stx		object-type-spec.list-validator-lambda-stx)
   (procedure?				object-type-spec.procedure?)
   (list-sub-type?			object-type-spec.list-sub-type?)
   (vector-sub-type?			object-type-spec.vector-sub-type?)))

(define-built-in-record-type <scheme-type-spec>
    <object-type-spec>
  make-scheme-type-spec scheme-type-spec?
  (methods
   (type-descriptor-id		scheme-type-spec.type-descriptor-id)))

(define-built-in-record-type <closure-type-spec>
    <object-type-spec>
  make-closure-type-spec closure-type-spec?
  (methods
   (signature			closure-type-spec.signature)))

(define-built-in-record-type <struct-type-spec>
    <object-type-spec>
  make-struct-type-spec struct-type-spec?
  (methods
   (std				struct-type-spec.std)))

(define-built-in-record-type <record-type-spec>
    <object-type-spec>
  make-record-type-spec record-type-spec?
  (methods
   (rtd-id				record-type-spec.rtd-id)
   (rcd-id				record-type-spec.rcd-id)
   (super-protocol-id		record-type-spec.super-protocol-id)))

(define-built-in-record-type <compound-condition-type-spec>
    <objct-type-spec>
  make-compound-condition-type-spec compound-condition-type-spec?
  (methods
   (component-ots*	compound-condition-type-spec.component-ots*)))

;;; --------------------------------------------------------------------

(define-built-in-record-type <union-type-spec>
    <object-type-spec>
  make-union-type-spec union-type-spec?
  (methods
   (component-ots*		union-type-spec.component-ots*)))

(define-built-in-record-type <intersection-type-spec>
    <object-type-spec>
  make-intersection-type-spec intersection-type-spec?
  (methods
   (component-ots*		intersection-type-spec.component-ots*)))

(define-built-in-record-type <complement-type-spec>
    <object-type-spec>
  make-complement-type-spec complement-type-spec?
  (methods
   (item-ots			complement-type-spec.item-ots)))

(define-built-in-record-type <ancestor-of-type-spec>
    <object-type-spec>
  make-ancestor-of-type-spec ancestor-of-type-spec?
  (methods
   (item-ots			ancestor-of-type-spec.item-ots)
   (component-ots*		ancestor-of-type-spec.component-ots*)))

;;; --------------------------------------------------------------------

(define-built-in-record-type <pair-type-spec>
    <object-type-spec>
  make-pair-type-spec pair-type-spec?
  (methods
   (car-ots			pair-type-spec.car-ots)
   (cdr-ots			pair-type-spec.cdr-ots)))

(define-built-in-record-type <pair-of-type-spec>
    <object-type-spec>
  make-pair-of-type-spec pair-of-type-spec?
  (methods
   (item-ots			pair-of-type-spec.item-ots)))

(define-built-in-record-type <list-type-spec>
    <object-type-spec>
  make-list-type-spec list-type-spec?
  (methods
   (item-ots*		list-type-spec.item-ots*)))

(define-built-in-record-type <list-of-type-spec>
    <object-type-spec>
  make-list-of-type-spec list-of-type-spec?
  (methods
   (item-ots			list-of-type-spec.item-ots)))

(define-built-in-record-type <vector-type-spec>
    <object-type-spec>
  make-vector-type-spec vector-type-spec?
  (methods
   (item-ots*		vector-type-spec.item-ots*)))

(define-built-in-record-type <vector-of-type-spec>
    <object-type-spec>
  make-vector-of-type-spec vector-of-type-spec?
  (methods
   (item-ots			vector-of-type-spec.item-ots)))

(define-built-in-record-type <hashtable-type-spec>
    <hashtable>
  make-hashtable-type-spec hashtable-type-spec?
  (methods
   (key-ots			hashtable-type-spec.key-ots)
   (value-ots			hashtable-type-spec.value-ots)))

(define-built-in-record-type <alist-type-spec>
    <list>
  make-alist-type-spec alist-type-spec?
  (methods
   (key-ots			alist-type-spec.key-ots)
   (value-ots			alist-type-spec.value-ots)))

(define-built-in-record-type <enumeration-type-spec>
    <object-type-spec>
  make-enumeration-type-spec enumeration-type-spec?
  (methods
   (symbol*			enumeration-type-spec.symbol*)
   (member?			enumeration-type-spec.member?)))

;;; --------------------------------------------------------------------

(define-built-in-record-type <type-signature>
    <record>
  make-type-signature type-signature?
  (methods
   (object-type-specs			type-signature.object-type-specs)
   (syntax-object			type-signature.syntax-object)
   (=					type-signature=?)
   (fully-untyped?			type-signature.fully-untyped?)
   (partially-untyped?			type-signature.partially-untyped?)
   (untyped?				type-signature.untyped?)
   (empty?				type-signature.empty?)
   (super-and-sub?			type-signature.super-and-sub?)
   (compatible-super-and-sub?		type-signature.compatible-super-and-sub?)
   (single-type?			type-signature.single-type?)
   (single-top-tag?			type-signature.single-top-tag?)
   (single-type-or-fully-untyped?	type-signature.single-type-or-fully-untyped?)
   (no-return?				type-signature.no-return?)
   (match-arguments-against-operands	type-signature.match-arguments-against-operands)
   (min-count				type-signature.min-count)
   (max-count				type-signature.max-count)
   (min-and-max-counts			type-signature.min-and-max-counts)
   (common-ancestor			type-signature.common-ancestor)
   (union				type-signature.union)))

;;; --------------------------------------------------------------------

(define-built-in-record-type <stx>
    <record>
  #f stx?
  (methods
   (expr			stx-expr)
   (mark*			stx-mark*)
   (rib*			stx-rib*)
   (annotated-expr*		stx-annotated-expr*)))

(define-built-in-record-type <syntactic-identifier>
    <stx>
  #f syntactic-identifier?
  (methods
   (string			identifier->string)
   (label			syntactic-identifier->label)))

(define-built-in-record-type <syntax-clause-spec>
    <record>
  make-syntax-clause-spec syntax-clause-spec?
  (methods
   (keyword				syntax-clause-spec-keyword)
   (min-number-of-occurrences	syntax-clause-spec-min-number-of-occurrences)
   (max-number-of-occurrences	syntax-clause-spec-max-number-of-occurrences)
   (min-number-of-arguments		syntax-clause-spec-min-number-of-arguments)
   (max-number-of-arguments		syntax-clause-spec-max-number-of-arguments)
   (mutually-inclusive		syntax-clause-spec-mutually-inclusive)
   (mutually-exclusive		syntax-clause-spec-mutually-exclusive)
   (custom-data			syntax-clause-spec-custom-data)))

;;; end of file
;; Local Variables:
;; mode: vicare
;; End:
