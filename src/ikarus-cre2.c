/*
  Part of: Vicare
  Contents: built in binding to CRE2
  Date: Fri Jan  6, 2012

  Abstract

	Built in  binding to the CRE2  library: a C wrapper  for the RE2
	regular expressions library from Google.

  Copyright (C) 2012 Marco Maggi <marco.maggi-ipsu@poste.it>

  This program is  free software: you can redistribute  it and/or modify
  it under the  terms of the GNU General Public  License as published by
  the Free Software Foundation, either  version 3 of the License, or (at
  your option) any later version.

  This program  is distributed in the  hope that it will  be useful, but
  WITHOUT   ANY  WARRANTY;   without  even   the  implied   warranty  of
  MERCHANTABILITY  or FITNESS  FOR A  PARTICULAR PURPOSE.   See  the GNU
  General Public License for more details.

  You  should have received  a copy  of the  GNU General  Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/


/** --------------------------------------------------------------------
 ** Headers.
 ** ----------------------------------------------------------------- */

#include "ikarus.h"

#if (1 == ENABLE_CRE2)
#  include <cre2.h>
#else

static IK_UNUSED void
feature_failure_ (const char * funcname)
{
  fprintf(stderr, "Vicare error: called CRE2 specific function, %s\n", funcname);
  exit(EXIT_FAILURE);
}
#define feature_failure(FN)     { feature_failure_(FN); return void_object; }

#endif


/** --------------------------------------------------------------------
 ** Version functions.
 ** ----------------------------------------------------------------- */

ikptr
ikrt_cre2_enabled (void)
{
#if (1 == ENABLE_CRE2)
  return true_object;
#else
  return false_object;
#endif
}
ikptr
ikrt_cre2_version_interface_current (void)
{
#if (1 == ENABLE_CRE2)
  return IK_FIX(cre2_version_interface_current());
#else
  feature_failure(__func__);
#endif
}
ikptr
ikrt_cre2_version_interface_revision (void)
{
#if (1 == ENABLE_CRE2)
  return IK_FIX(cre2_version_interface_revision());
#else
  feature_failure(__func__);
#endif
}
ikptr
ikrt_cre2_version_interface_age (void)
{
#if (1 == ENABLE_CRE2)
  return IK_FIX(cre2_version_interface_age());
#else
  feature_failure(__func__);
#endif
}


/** --------------------------------------------------------------------
 ** Precompiled regular expression objects.
 ** ----------------------------------------------------------------- */

ikptr
ikrt_cre2_new (ikptr s_pattern, ikptr s_options, ikpcb * pcb)
/* Build a new precompiled regular expression object.  S_PATTERN must be
   a bytevector holding the regexp pattern.  S_OPTIONS must be a pointer
   to a "cre2_options_t" value or false if the regexp must be built with
   the default options.

   If  successful:  return  a  pointer  object  referencing  the  regexp
   structure.  If  an error occurs allocating memory:  return false.  If
   an error  occurs building the  object: return a  pair whose car  is a
   fixnum  representing the  error code  and whose  cdr is  a bytevector
   representing the error string in ASCII encoding.
*/
{
#if (1 == ENABLE_CRE2)
  const char *		pattern;
  int			pattern_len;
  cre2_regexp_t *	rex;
  cre2_options_t *	options;
  pattern     = IK_BYTEVECTOR_DATA_CHARP(s_pattern);
  pattern_len = IK_BYTEVECTOR_LENGTH(s_pattern);
  options     = (false_object == s_options)? NULL : IK_POINTER_DATA_VOIDP(s_options);
  rex         = cre2_new(pattern, pattern_len, options);
  if (NULL == rex)
    return false_object; /* error allocating memory */
  else {
    int  errcode = cre2_error_code(rex);
    if (errcode) {
      ikptr	s_pair = IK_PAIR_ALLOC(pcb);
      pcb->root0 = &s_pair;
      {
	IK_CAR(s_pair) = IK_FIX(errcode);
	IK_CDR(s_pair) = ik_bytevector_from_cstring(pcb, cre2_error_string(rex));
      }
      pcb->root0 = NULL;
      cre2_delete(rex);
      return s_pair;
    } else
      return ik_pointer_alloc((unsigned long)rex, pcb);
  }
#else
  return feature_failure(__func__);
#endif
}
ikptr
ikrt_cre2_delete (ikptr s_rex)
/* Finalise  a precompiled regular  expression releasing  the associated
   resources.   Finalisation  takes place  only  if  S_REX references  a
   non-NULL  pointer.  After the  context has  been finalised:  S_REX is
   mutated to reference a NULL pointer. */
{
#if (1 == ENABLE_CRE2)
  cre2_regexp_t *	rex;
  rex = IK_POINTER_DATA_VOIDP(s_rex);
  if (rex) {
    cre2_delete(rex);
    ref(s_rex, off_pointer_data) = 0;
  }
  return void_object;
#else
  return feature_failure(__func__);
#endif
}


/** --------------------------------------------------------------------
 ** Configuration options.
 ** ----------------------------------------------------------------- */

ikptr
ikrt_cre2_opt_new (ikpcb * pcb)
/* Build a new configuration options object.

   If  successful:  return  a  pointer object  referencing  the  options
   structure.  If an error occurs allocating memory: return false. */
{
#if (1 == ENABLE_CRE2)
  cre2_options_t *	opt;
  opt = cre2_opt_new();
  if (opt) {
    cre2_opt_set_encoding(opt, CRE2_UTF8);
    return ik_pointer_alloc((unsigned long)opt, pcb);
  } else
    return false_object; /* error allocating memory */
#else
  return feature_failure(__func__);
#endif
}
ikptr
ikrt_cre2_opt_delete (ikptr s_opt)
/* Finalise  a  configuration options  object  releasing the  associated
   resources.   Finalisation  takes place  only  if  S_OPT references  a
   non-NULL  pointer.  After the  context has  been finalised:  S_OPT is
   mutated to reference a NULL pointer. */
{
#if (1 == ENABLE_CRE2)
  cre2_options_t *	opt;
  opt = IK_POINTER_DATA_VOIDP(s_opt);
  if (opt) {
    cre2_opt_delete(opt);
    ref(s_opt, off_pointer_data) = 0;
  }
  return void_object;
#else
  return feature_failure(__func__);
#endif
}

#define DEFINE_OPTION_SETTER_AND_GETTER(NAME)				\
  ikptr									\
  ikrt_cre2_opt_set_##NAME (ikptr s_opt, ikptr s_bool)			\
  {									\
    cre2_options_t *	opt;						\
    opt = IK_POINTER_DATA_VOIDP(s_opt);					\
    cre2_opt_set_##NAME(opt, (false_object == s_bool)? 0 : 1);		\
    return void_object;							\
  }									\
  ikptr									\
  ikrt_cre2_opt_##NAME (ikptr s_opt)					\
  {									\
    cre2_options_t *	opt;						\
    opt = IK_POINTER_DATA_VOIDP(s_opt);					\
    return (cre2_opt_##NAME(opt))? true_object : false_object;		\
  }

DEFINE_OPTION_SETTER_AND_GETTER(posix_syntax)
DEFINE_OPTION_SETTER_AND_GETTER(longest_match)
DEFINE_OPTION_SETTER_AND_GETTER(log_errors)
DEFINE_OPTION_SETTER_AND_GETTER(literal)
DEFINE_OPTION_SETTER_AND_GETTER(never_nl)
DEFINE_OPTION_SETTER_AND_GETTER(case_sensitive)
DEFINE_OPTION_SETTER_AND_GETTER(perl_classes)
DEFINE_OPTION_SETTER_AND_GETTER(word_boundary)
DEFINE_OPTION_SETTER_AND_GETTER(one_line)

ikptr
ikrt_cre2_opt_set_max_mem (ikptr s_opt, ikptr s_dim)
{
  cre2_options_t *	opt;
  long			dim;
  opt = IK_POINTER_DATA_VOIDP(s_opt);
  dim = ik_integer_to_long(s_dim);
  cre2_opt_set_max_mem(opt, (int)dim);
  return void_object;
}
ikptr
ikrt_cre2_opt_max_mem (ikptr s_opt, ikpcb * pcb)
{
  cre2_options_t *	opt;
  long			dim;
  opt = IK_POINTER_DATA_VOIDP(s_opt);
  dim = (long)cre2_opt_max_mem(opt);
  return ik_integer_from_long(dim, pcb);
}


/** --------------------------------------------------------------------
 ** Matching.
 ** ----------------------------------------------------------------- */

ikptr
ikrt_cre2_match (ikptr s_rex, ikptr s_text, ikptr s_start, ikptr s_end,
		 ikptr s_anchor, ikptr s_nmatch, ikpcb * pcb)
/*

   If  successful:  return  a  pointer object  referencing  the  options
   structure.  If an error occurs allocating memory: return false. */
{
#if (1 == ENABLE_CRE2)
  cre2_regexp_t *	rex;
  const char *		text_data;
  int			text_len;
  int			start, end, anchor;
  int			nmatch, ngroups, nitems;
  int			retval;
  rex		= IK_POINTER_DATA_VOIDP(s_rex);
  text_data	= IK_BYTEVECTOR_DATA_CHARP(s_text);
  text_len	= IK_BYTEVECTOR_LENGTH(s_text);
  start		= IK_UNFIX(s_start);
  end		= IK_UNFIX(s_end);
  anchor	= IK_UNFIX(s_anchor);
  nmatch	= IK_UNFIX(s_nmatch);
  ngroups	= 1 + cre2_num_capturing_groups(rex);
  nitems	= (nmatch > ngroups)? ngroups : nmatch;
  switch (anchor) {
  case 0: anchor = CRE2_UNANCHORED;	break;
  case 1: anchor = CRE2_ANCHOR_START;	break;
  case 2: anchor = CRE2_ANCHOR_BOTH;	break;
  default: /* should never happen */
    anchor = CRE2_UNANCHORED;
  }
  cre2_string_t		strings[nitems];
  memset(strings, '\0', nitems * sizeof(cre2_string_t));
  retval = cre2_match(rex, text_data, text_len, start, end, anchor, strings, nitems);
  if (retval) {
    cre2_range_t	ranges[nitems];
    ikptr		s_match;
    int			i;
    cre2_strings_to_ranges(text_data, ranges, strings, nitems);
    s_match = ik_vector_alloc(pcb, nitems);
    pcb->root0 = &s_match;
    {
      for (i=0; i<nitems; ++i) {
	IK_ITEM(s_match, i) = IK_PAIR_ALLOC(pcb);
	IK_CAR(IK_ITEM(s_match, i)) = IK_FIX(ranges[i].start);
	IK_CDR(IK_ITEM(s_match, i)) = IK_FIX(ranges[i].past);
      }
    }
    pcb->root0 = NULL;
    return s_match;
  } else
    return false_object; /* no match */
#else
  return feature_failure(__func__);
#endif
}


/** --------------------------------------------------------------------
 ** Done.
 ** ----------------------------------------------------------------- */


/* end of file */
