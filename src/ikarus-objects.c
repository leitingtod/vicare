/*
  Part of: Vicare
  Contents: utilities for built in object manipulation
  Date: Tue Nov	 8, 2011

  Abstract



  Copyright (C) 2011, 2012, 2013, 2014, 2015 Marco Maggi <marco.maggi-ipsu@poste.it>

  This program is  free software: you can redistribute	it and/or modify
  it under the	terms of the GNU General Public	 License as published by
  the Free Software Foundation, either	version 3 of the License, or (at
  your option) any later version.

  This program	is distributed in the  hope that it will  be useful, but
  WITHOUT   ANY	 WARRANTY;   without  even   the  implied   warranty  of
  MERCHANTABILITY  or FITNESS  FOR A  PARTICULAR PURPOSE.   See	 the GNU
  General Public License for more details.

  You  should have received  a copy  of the  GNU General  Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/


/** --------------------------------------------------------------------
 ** Headers.
 ** ----------------------------------------------------------------- */

#include "internals.h"
#include <gmp.h>
#include <ctype.h>	/* for "isxdigit()" */


/** --------------------------------------------------------------------
 ** Special objects.
 ** ----------------------------------------------------------------- */

ikptr_t
ikrt_bwp_object (ikpcb_t * pcb)
{
  return IK_BWP_OBJECT;
}
ikptr_t
ikrt_unbound_object (ikpcb_t * pcb)
{
  return IK_UNBOUND_OBJECT;
}


/** --------------------------------------------------------------------
 ** Scheme pairs utilities.
 ** ----------------------------------------------------------------- */

ikptr_t
ika_pair_alloc (ikpcb_t * pcb)
{
  ikptr_t	s_pair = IKA_PAIR_ALLOC(pcb);
  IK_CAR(s_pair) = IK_VOID_OBJECT;
  IK_CDR(s_pair) = IK_VOID_OBJECT;
  return s_pair;
}
ikptr_t
iku_pair_alloc (ikpcb_t * pcb)
{
  ikptr_t	s_pair = IKU_PAIR_ALLOC(pcb);
  IK_CAR(s_pair) = IK_VOID_OBJECT;
  IK_CDR(s_pair) = IK_VOID_OBJECT;
  return s_pair;
}
ikuword_t
ik_list_length (ikptr_t s_list)
/* Return the  length of the list  S_LIST.  Do *not*  check for circular
   lists. */
{
  ikuword_t	length;
  for (length = 0; pair_tag == IK_TAGOF(s_list); ++length) {
    if (LONG_MAX != length)
      s_list = IK_REF(s_list, off_cdr);
    else
      ik_abort("size of list exceeds LONG_MAX");
  }
  return length;
}

/* ------------------------------------------------------------------ */

void
ik_list_to_argv (ikptr_t s_list, char **argv)
/* Given a  reference S_LIST  to a list	 of bytevectors, fill  ARGV with
   pointers to the data areas, setting the last element of ARGV to NULL.
   The array referenced by ARGV must be wide enough to hold all the data
   from S_LIST plus the terminating NULL. */
{
  int	 i;
  ikptr_t	 bv;
  for (i=0; pair_tag == IK_TAGOF(s_list); s_list=IK_CDR(s_list), ++i) {
    bv	    = IK_CAR(s_list);
    argv[i] = IK_BYTEVECTOR_DATA_CHARP(bv);
  }
  argv[i] = NULL;
}
void
ik_list_to_argv_and_argc (ikptr_t s_list, char **argv, long *argc)
/* Given a  reference S_LIST  to a list	 of bytevectors: fill  ARGV with
   pointers to the data areas, setting the last element of ARGV to NULL;
   fill ARGC with the lengths  of the bytevectors.  The array referenced
   by ARGV must be wide enough to hold all the data from S_LIST plus the
   terminating NULL; the array referenced by ARGC must be wide enough to
   hold all the lengths. */
{
  int	 i;
  ikptr_t	 bv;
  for (i=0; pair_tag == IK_TAGOF(s_list); s_list=IK_CDR(s_list), ++i) {
    bv	    = IK_CAR(s_list);
    argv[i] = IK_BYTEVECTOR_DATA_CHARP(bv);
    argc[i] = IK_BYTEVECTOR_LENGTH(bv);
  }
  argv[i] = NULL;
}

/* ------------------------------------------------------------------ */

ikptr_t
ika_list_from_argv (ikpcb_t * pcb, char ** argv)
/* Given a  pointer ARGV  to a NULL-terminated	array of  ASCIIZ strings
   build and return  a list of bytevectors holding a  copy of the ASCIIZ
   strings.  Make use of "pcb->root8,9".  */
{
  if (! argv[0])
    return IK_NULL_OBJECT;
  else {
    ikptr_t	s_list, s_pair;
    s_list = s_pair = ika_pair_alloc(pcb);
    pcb->root9 = &s_list;
    pcb->root8 = &s_pair;
    {
      int		i;
      for (i=0; argv[i];) {
	IK_ASS(IK_CAR(s_pair), ika_bytevector_from_cstring(pcb, argv[i]));
	IK_SIGNAL_DIRT_IN_PAGE_OF_POINTER(pcb, IK_CAR_PTR(s_pair));
	if (argv[++i]) {
	  IK_ASS(IK_CDR(s_pair), ika_pair_alloc(pcb));
	  IK_SIGNAL_DIRT_IN_PAGE_OF_POINTER(pcb, IK_CDR_PTR(s_pair));
	  s_pair = IK_CDR(s_pair);
	} else {
	  IK_CDR(s_pair) = IK_NULL_OBJECT;
	  break;
	}
      }
    }
    pcb->root8 = NULL;
    pcb->root9 = NULL;
    return s_list;
  }
}
ikptr_t
ika_list_from_argv_and_argc (ikpcb_t * pcb, char ** argv, long argc)
/* Given  a pointer  ARGV to  an array	of ASCIIZ  strings  holding ARGC
   pointers: build  and return a list  of bytevectors holding  a copy of
   the ASCIIZ strings.	Make use of "pcb->root8,9".  */
{
  if (! argc)
    return IK_NULL_OBJECT;
  else {
    ikptr_t	s_list, s_pair;
    s_list = s_pair = ika_pair_alloc(pcb);
    pcb->root9 = &s_list;
    pcb->root8 = &s_pair;
    {
      for (long i=0; i<argc;) {
	IK_ASS(IK_CAR(s_pair), ika_bytevector_from_cstring(pcb, argv[i]));
	IK_SIGNAL_DIRT_IN_PAGE_OF_POINTER(pcb, IK_CAR_PTR(s_pair));
	if (++i < argc) {
	  IK_ASS(IK_CDR(s_pair), ika_pair_alloc(pcb));
	  IK_SIGNAL_DIRT_IN_PAGE_OF_POINTER(pcb, IK_CDR_PTR(s_pair));
	  s_pair = IK_CDR(s_pair);
	} else {
	  IK_CDR(s_pair) = IK_NULL_OBJECT;
	  break;
	}
      }
    }
    pcb->root8 = NULL;
    pcb->root9 = NULL;
    return s_list;
  }
}


/** --------------------------------------------------------------------
 ** Scheme bytevector utilities.
 ** ----------------------------------------------------------------- */

ikptr_t
ika_bytevector_alloc (ikpcb_t * pcb, ikuword_t requested_number_of_bytes)
{
  ikuword_t   aligned_size;
  ikptr_t	 s_bv;
  assert(requested_number_of_bytes <= most_positive_fixnum);
  aligned_size = IK_ALIGN(disp_bytevector_data + requested_number_of_bytes + 1);
  s_bv	       = ik_safe_alloc(pcb, aligned_size) | bytevector_tag;
  IK_REF(s_bv, off_bytevector_length) = IK_FIX(requested_number_of_bytes);
  IK_BYTEVECTOR_DATA_CHARP(s_bv)[requested_number_of_bytes] = '\0';
  return s_bv;
}
ikptr_t
ika_bytevector_from_cstring (ikpcb_t * pcb, const char * cstr)
{
  if (cstr) {
    ikptr_t	s_bv;
    char *	data;
    size_t	len = strlen(cstr);
    if (len > most_positive_fixnum)
      len = most_positive_fixnum;
    s_bv = ika_bytevector_alloc(pcb, len);
    data = IK_BYTEVECTOR_DATA_CHARP(s_bv);
    memcpy(data, cstr, len);
    return s_bv;
  } else {
    return ika_bytevector_alloc(pcb, 0);
  }
}
ikptr_t
ika_bytevector_from_cstring_len (ikpcb_t * pcb, const char * cstr, size_t len)
{
  if (len > most_positive_fixnum)
    len = most_positive_fixnum;
  ikptr_t	    s_bv = ika_bytevector_alloc(pcb, len);
  char *    data = IK_BYTEVECTOR_DATA_CHARP(s_bv);
  memcpy(data, cstr, len);
  return s_bv;
}
ikptr_t
ika_bytevector_from_memory_block (ikpcb_t * pcb, const void * memory, size_t len)
{
  if (len > most_positive_fixnum)
    len = most_positive_fixnum;
  ikptr_t	    s_bv = ika_bytevector_alloc(pcb, len);
  void *    data = IK_BYTEVECTOR_DATA_VOIDP(s_bv);
  memcpy(data, memory, len);
  return s_bv;
}
ikptr_t
ikrt_bytevector_copy (ikptr_t s_dst, ikptr_t s_dst_start,
		      ikptr_t s_src, ikptr_t s_src_start,
		      ikptr_t s_count)
{
  ikuword_t	src_start = IK_UNFIX(s_src_start);
  ikuword_t	dst_start = IK_UNFIX(s_dst_start);
  size_t	count     = (size_t)IK_UNFIX(s_count);
  uint8_t *	dst = IK_BYTEVECTOR_DATA_UINT8P(s_dst) + dst_start;
  uint8_t *	src = IK_BYTEVECTOR_DATA_UINT8P(s_src) + src_start;
  memcpy(dst, src, count);
  return IK_VOID_OBJECT;
}
ikptr_t
ika_bytevector_from_utf16z (ikpcb_t * pcb, const void * _data)
/* Build and return  a new bytevector from a memory  block referencing a
   UTF-16 string terminated with two  consecutive zeros starting at even
   offset.  If the  the end of the  string is not found  before the byte
   index reaches the maximum fixnum: return the false object. */
{
  const uint8_t *	data = _data;
  int			i;
  /* Search the end of  the UTF-16 string: it is a sequence  of two 0 at
     even offset. */
  for (i=0; data[i] || data[1+i]; i+=2)
    if (most_positive_fixnum <= i)
      return IK_FALSE_OBJECT;
  return (most_positive_fixnum <= i)? IK_FALSE_OBJECT : \
    ika_bytevector_from_memory_block(pcb, data, i);
}


/** --------------------------------------------------------------------
 ** Scheme bytevector conversion to ASCII HEX.
 ** ----------------------------------------------------------------- */

ikptr_t
ikrt_bytevector_to_hex (ikptr_t s_in, ikpcb_t * pcb)
{
  static const char table[] = "0123456789ABCDEF";
  uint8_t *	in	= IK_BYTEVECTOR_DATA_UINT8P(s_in);
  ikuword_t	in_len	= IK_BYTEVECTOR_LENGTH(s_in);
  ikptr_t		s_ou;
  char *	ou;
  ikuword_t	ou_len;
  uint8_t	byte;
  ikuword_t	i;
  if ((IK_GREATEST_FIXNUM / 2) > in_len) {
    pcb->root0 = &s_in;
    {
      ou_len = in_len * 2;
      s_ou   = ika_bytevector_alloc(pcb, ou_len);
      ou     = IK_BYTEVECTOR_DATA_CHARP(s_ou);
      for (byte=in[i = 0]; i<in_len; byte=in[++i]) {
	*ou++ = table[byte >> 4];
	*ou++ = table[byte & 15];
      }
    }
    pcb->root0 = NULL;
    return s_ou;
  } else
    return IK_FALSE;
}
ikptr_t
ikrt_bytevector_from_hex (ikptr_t s_in, ikpcb_t * pcb)
{
  char *	in	= IK_BYTEVECTOR_DATA_CHARP(s_in);
  ikuword_t	in_len	= IK_BYTEVECTOR_LENGTH(s_in);
  ikptr_t		s_ou;
  uint8_t *	ou;
  ikuword_t	ou_len;
  ikuword_t	i;
  pcb->root0 = &s_in;
  {
    ou_len = in_len / 2;
    s_ou   = ika_bytevector_alloc(pcb, ou_len);
    ou     = IK_BYTEVECTOR_DATA_UINT8P(s_ou);
    for (i=0; i<in_len; ++i) {
      char	value;
      if (isxdigit(in[i])) {
	char	ch = in[i] - '0';
	if (ch > 9)  { ch += ('0' - 'A') + 10; }
	if (ch > 16) { ch += ('A' - 'a');      }
	value = (ch & 0xf) << 4;
      } else {
	s_ou = IK_FALSE;
	goto error;
      }
      if (isxdigit(in[++i])) {
	char	ch = in[i] - '0';
	if (ch > 9)  { ch += ('0' - 'A') + 10; }
	if (ch > 16) { ch += ('A' - 'a');      }
	*ou++ = value | (ch & 0xf);
      } else {
	s_ou = IK_FALSE;
	goto error;
      }
    }
  }
  error:
  pcb->root0 = NULL;
  return s_ou;
}


/** --------------------------------------------------------------------
 ** Scheme bytevector conversion to ASCII Base64.
 ** ----------------------------------------------------------------- */

ikptr_t
ikrt_bytevector_to_base64 (ikptr_t s_in, ikpcb_t * pcb)
{
  /* The following is the encoding table  for Base64 as specified by RFC
     4648. */
  static const uint8_t table[] = {
    'A', 'B', 'C',   'D', 'E', 'F',   'G', 'H', 'I',   'J',    /*  0 -  9 */
    'K', 'L', 'M',   'N', 'O', 'P',   'Q', 'R', 'S',   'T',    /* 10 - 19 */
    'U', 'V', 'W',   'X', 'Y', 'Z',   'a', 'b', 'c',   'd',    /* 20 - 29 */
    'e', 'f', 'g',   'h', 'i', 'j',   'k', 'l', 'm',   'n',    /* 30 - 31 */
    'o', 'p', 'q',   'r', 's', 't',   'u', 'v', 'w',   'x',    /* 40 - 49 */
    'y', 'z', '0',   '1', '2', '3',   '4', '5', '6',   '7',    /* 50 - 59 */
    '8', '9', '+',   '/'                                       /* 60 - 63 */
  };
  uint8_t *	in	= IK_BYTEVECTOR_DATA_UINT8P(s_in);
  ikuword_t		in_len	= IK_BYTEVECTOR_LENGTH(s_in);
  ikptr_t		s_ou;
  uint8_t *	ou;
  ikuword_t		ou_len;
  ikuword_t		i, j, left;
  { /* Avoid overflowing.  Every 6 bits of  input binary data, 8 bits of
       output ASCII  characters; every 3  bytes of input binary  data, 4
       bytes of  output ASCII characters;  padding with '=' is  added at
       the end if needed.

       NOTE I subtract 16 from  IK_GREATEST_FIXNUM to be safe, because I
       am ignorant  about exact integers arithmetic.   (Marco Maggi; Sun
       Mar 10, 2013) */
    ikuword_t	number_of_groups = in_len / 3 + ((in_len % 3)? 1 : 0);
    if (((IK_GREATEST_FIXNUM-16) / 4) < number_of_groups)
      return IK_FALSE;
  }
  pcb->root0 = &s_in;
  {
    ou_len = (in_len / 3) * 4 + ((in_len % 3)? 4 : 0);
    s_ou   = ika_bytevector_alloc(pcb, ou_len);
    ou     = IK_BYTEVECTOR_DATA_UINT8P(s_ou);
    for (i=0, j=0; i<in_len; i+=3) {
      left = in_len - i;
      if (left >= 3) {
	/*
	 *     in[i+0]  in[i+1]  in[i+2]
	 *
	 *    |76543210|76543210|76543210|
	 *    |--------+--------+--------|
	 *    |543210  |        |        | ou[j+0]
	 *    |      54|3210    |        | ou[j+1]
	 *    |        |    5432|10      | ou[j+2]
	 *    |        |        |  543210| ou[j+3]
	 */
	ou[j++] = table[63 & ((in[i]   >> 2))];
	ou[j++] = table[63 & ((in[i]   << 4) | (in[i+1] >> 4))];
	ou[j++] = table[63 & ((in[i+1] << 2) | (in[i+2] >> 6))];
	ou[j++] = table[63 & ((in[i+1] << 6) | (in[i+2]))];
      } else {
	switch (left) {
	case 2:
	  /*
	   *     in[i+0]  in[i+1]
	   *
	   *    |76543210|76543210|
	   *    |--------+--------+
	   *    |543210  |        |    ou[j+0]
	   *    |      54|3210    |    ou[j+1]
	   *    |        |    5432|10  ou[j+2]
	   */
	  ou[j++] = table[63 & ((in[i]   >> 2))];
	  ou[j++] = table[63 & ((in[i]   << 4) | (in[i+1] >> 4))];
	  ou[j++] = table[63 & ((in[i+1] << 2))];
	  ou[j++] = '=';
	  break;

	case 1:
	  /*
	   *     in[i+0]
	   *
	   *    |76543210|
	   *    |--------+
	   *    |543210  |      ou[j+0]
	   *    |      54|3210  ou[j+1]
	   */
	  ou[j++] = table[63 & ((in[i] >> 2))];
	  ou[j++] = table[63 & ((in[i] << 4))];
	  ou[j++] = '=';
	  ou[j++] = '=';
	  break;

	default: /* case 0: */
	  break;
	}
      }
    }
  }
  pcb->root0 = NULL;
  return s_ou;
}
ikptr_t
ikrt_bytevector_from_base64 (ikptr_t s_in, ikpcb_t * pcb)
{
  /* Decoding tables  for Base64  as specified  by RFC  4648: disallowed
     input  characters  have  a  value  of  0xFF;  only  128  chars,  as
     everything above 127 (0x80) is disallowed. */
  static const uint8_t table[128] = {
    0xFF, 0xFF, 0xFF,   0xFF, 0xFF, 0xFF,   0xFF, 0xFF, 0xFF,   0,	/*   0,   9 */
    0xFF, 0xFF, 0xFF,   0xFF, 0xFF, 0xFF,   0xFF, 0xFF, 0xFF,   0,	/*  10,  19 */
    0xFF, 0xFF, 0xFF,   0xFF, 0xFF, 0xFF,   0xFF, 0xFF, 0xFF,   0,	/*  20,  29 */
    0xFF, 0xFF, 0xFF,   0xFF, 0xFF, 0xFF,   0xFF, 0xFF, 0xFF,   0,	/*  30,  39 */
    0xFF, 0xFF, 0xFF,   62,   0xFF, 0xFF,   0xFF, 63,   52,     53,	/*  40,  49 */
    54,   55,   56,     57,   58,   59,     60,   61,   0xFF,   0xFF,   /*  50,  59 */
    0xFF, 0xFF, 0xFF,   0xFF, 0xFF, 0,      1,    2,    3,      4,	/*  60,  69 */
    5,    6,    7,      8,    9,    10,     11,   12,   13,     14,	/*  70,  79 */
    15,   16,   17,     18,   19,   20,     21,   22,   23,     24,	/*  80,  89 */
    25,   0xFF, 0xFF,   0xFF, 0xFF, 0xFF,   0xFF, 26,   27,     28,	/*  90,  99 */
    29,   30,   31,     32,   33,   34,     35,   36,   37,     38,	/* 100, 109 */
    39,   40,   41,     42,   43,   44,     45,   46,   47,     48,	/* 110, 119 */
    49,   50,   51,     0xFF, 0xFF, 0xFF,   0xFF, 0xFF			/* 120, 127 */
  };
  uint8_t *	in	= IK_BYTEVECTOR_DATA_VOIDP(s_in);
  ikuword_t		in_len	= IK_BYTEVECTOR_LENGTH(s_in);
  ikptr_t		s_ou;
  uint8_t *	ou;
  ikuword_t		ou_len;
  ikuword_t		i, j;
  /* Check for invalid input size. */
  if (in_len % 4) {
    s_ou = IK_FALSE;
    goto error;
  }
  /* Compute the output size. */
  ou_len = 3 * (in_len / 4);
  if ('=' == in[in_len-1]) {
    if ('=' == in[in_len-2]) {
      ou_len -= 2;	/* two bytes of padding */
    } else {
      --ou_len;	/* one byte of padding */
    }
  }
  pcb->root0 = &s_in;
  {
    s_ou = ika_bytevector_alloc(pcb, ou_len);
    ou   = IK_BYTEVECTOR_DATA_UINT8P(s_ou);
    for (i=0, j=0; i<in_len; ) {
      /* Determine the number of characters to decode: 4, 3 or 2. */
      int	left = 4;
      if ('=' == in[i+3]) --left; /* At least one pad character. */
      if ('=' == in[i+2]) --left; /* Two pad characters. */
      switch (left) {
      case 4:  /* Full group, no pad characters. */
	{
	  uint8_t	A = in[i++];
	  uint8_t	B = in[i++];
	  uint8_t	C = in[i++];
	  uint8_t	D = in[i++];
	  /* Check that all the input  characters have integer value below
	     128. */
	  if ((A >= 128) || (B >= 128) || (C >= 128) || (D >= 128)) {
	    s_ou = IK_FALSE;
	    goto error;
	  }
	  A = table[A];
	  B = table[B];
	  C = table[C];
	  D = table[D];
	  /* Check that all the input  characters are in the range allowed
	     for Base64. */
	  if ((0xFF == A) || (0xFF == B) || (0xFF == C) || (0xFF == D)) {
	    s_ou = IK_FALSE;
	    goto error;
	  }
	  /*
	   *  in[i+0]  in[i+1]  in[i+2]  in[i+3]
	   *
	   * |76543210|76543210|76543210|76543210|
	   * |--------+--------+--------+--------|
	   * |  765432|  10    |        |        | ou[j+0]
	   * |        |    7654|  3210  |        | ou[j+1]
	   * |        |        |      76|  543210| ou[j+2]
	   */
	  ou[j++] = (0xFF & (A << 2)) | (0xFF & (B >> 4));
	  ou[j++] = (0xFF & (B << 4)) | (0xFF & (C >> 2));
	  ou[j++] = (0xFF & (C << 6)) | (0xFF & (D));
	}
	break;

      case 3: /* Not full group, one pad character. */
	{
	  uint8_t	A = in[i++];
	  uint8_t	B = in[i++];
	  uint8_t	C = in[i++];
	  ++i;
	  /* Check that all the input  characters have integer value below
	     128. */
	  if ((A >= 128) || (B >= 128) || (C >= 128)) {
	    s_ou = IK_FALSE;
	    goto error;
	  }
	  A = table[A];
	  B = table[B];
	  C = table[C];
	  /* Check that all the input  characters are in the range allowed
	     for Base64. */
	  if ((0xFF == A) || (0xFF == B) || (0xFF == C)) {
	    s_ou = IK_FALSE;
	    goto error;
	  }
	  /*
	   *  in[i+0]  in[i+1]  in[i+2]
	   *
	   * |76543210|76543210|76543210|
	   * |--------+--------+--------+
	   * |  765432|  10    |        |  ou[j+0]
	   * |        |    7654|  3210  |  ou[j+1]
	   */
	  ou[j++] = (A << 2) | (B >> 4);
	  ou[j++] = (B << 4) | (C >> 2);
	}
	break;

      case 2: /* Not full group, two pad characters. */
	{
	  uint8_t	A = in[i++];
	  uint8_t	B = in[i++];
	  i += 2;
	  /* Check that all the input  characters have integer value below
	     128. */
	  if ((A >= 128) || (B >= 128)) {
	    s_ou = IK_FALSE;
	    goto error;
	  }
	  A = table[A];
	  B = table[B];
	  /* Check that all the input  characters are in the range allowed
	     for Base64. */
	  if ((0xFF == A) || (0xFF == B)) {
	    s_ou = IK_FALSE;
	    goto error;
	  }
	  /*
	   *  in[i+0]  in[i+1]
	   *
	   * |76543210|76543210|
	   * |--------+--------+
	   * |  765432|  10    |  ou[j]
	   */
	  ou[j++] = (A << 2) | (B >> 4);
	}
	break;

      case 1: /* This is impossible. */
	break;

      default: /* case 0: */
	break;
      }
    }
  }
 error:
  pcb->root0 = NULL;
  return s_ou;
}


/** --------------------------------------------------------------------
 ** Scheme vector utilities.
 ** ----------------------------------------------------------------- */

int
ik_is_vector (ikptr_t s_vec)
{
  return (vector_tag == (s_vec & vector_mask)) && IK_IS_FIXNUM(IK_REF(s_vec, off_vector_length));
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_make_vector1 (ikptr_t s_len, ikpcb_t* pcb)
/* This  is   the  core   implementation  of  the   primitive  operation
   MAKE-VECTOR, */
{
  iksword_t intlen = (iksword_t)s_len;
  if (IK_IS_FIXNUM(s_len) && (intlen >= 0)) {
    ikptr_t s = ik_safe_alloc(pcb, IK_ALIGN(s_len + disp_vector_data));
    IK_REF(s, 0) = s_len;
    /* "ik_safe_alloc()" returns uninitialised  invalid memory; but such
       memory is on  the Scheme heap, which is not  a garbage collection
       root.   This   means  we  can  freely   leave  uninitialised  the
       additional memory reserved when  converting the requested size to
       the aligned  size, because the  garbage collector will  never see
       it. */
    memset((char*)(ikuword_t)(s+disp_vector_data), 0, s_len);
    return s | vector_tag;
  } else
    return 0;
}

/* ------------------------------------------------------------------ */

ikptr_t
ika_vector_alloc_no_init (ikpcb_t * pcb, ikuword_t number_of_items)
{
  ikptr_t s_len      = IK_FIX(number_of_items);
  /* Do not ask me why, but IK_ALIGN is needed here. */
  ikuword_t	align_size = IK_ALIGN(disp_vector_data + s_len);
  ikptr_t	s_vec	   = ik_safe_alloc(pcb, align_size) | vector_tag;
  IK_REF(s_vec, off_vector_length) = s_len;
  /* "ik_safe_alloc()"  returns uninitialised  invalid memory;  but such
     memory is  on the Scheme  heap, which  is not a  garbage collection
     root.  This means we can  freely leave uninitialised the additional
     memory reserved when  converting the requested size  to the aligned
     size, because the garbage collector will never see it. */
  return s_vec;
}
ikptr_t
iku_vector_alloc_no_init (ikpcb_t * pcb, ikuword_t number_of_items)
{
  ikptr_t s_len      = IK_FIX(number_of_items);
  /* Do not ask me why, but IK_ALIGN is needed here. */
  ikuword_t	align_size = IK_ALIGN(disp_vector_data + s_len);
  ikptr_t	s_vec	   = ik_unsafe_alloc(pcb, align_size) | vector_tag;
  IK_REF(s_vec, off_vector_length) = s_len;
  /* "ik_unsafe_alloc()" returns uninitialised  invalid memory; but such
     memory is  on the Scheme  heap, which  is not a  garbage collection
     root.  This means we can  freely leave uninitialised the additional
     memory reserved when  converting the requested size  to the aligned
     size, because the garbage collector will never see it. */
  return s_vec;
}

/* ------------------------------------------------------------------ */

ikptr_t
ika_vector_alloc_and_init (ikpcb_t * pcb, ikuword_t number_of_items)
{
  ikptr_t s_len      = IK_FIX(number_of_items);
  /* Do not ask me why, but IK_ALIGN is needed here. */
  ikuword_t	align_size = IK_ALIGN(disp_vector_data + s_len);
  ikptr_t	s_vec	   = ik_safe_alloc(pcb, align_size) | vector_tag;
  IK_REF(s_vec, off_vector_length) = s_len;
  /* Set the data area to zero.  Remember that the machine word 0 is the
     fixnum zero.  We avoid setting to zero the additional word, if any,
     reserved by  "ik_safe_alloc()" when  converting from  the requested
     size to the aligned size; such word is on the Scheme heap, which is
     not a garbage  collector root, so the garbage  collector will never
     see it. */
  memset((char*)(ikuword_t)(s_vec + off_vector_data), 0, s_len);
  return s_vec;
}
ikptr_t
iku_vector_alloc_and_init (ikpcb_t * pcb, ikuword_t number_of_items)
{
  ikptr_t s_len      = IK_FIX(number_of_items);
  /* Do not ask me why, but IK_ALIGN is needed here. */
  ikuword_t	align_size = IK_ALIGN(disp_vector_data + s_len);
  ikptr_t	s_vec	   = ik_unsafe_alloc(pcb, align_size) | vector_tag;
  IK_REF(s_vec, off_vector_length) = s_len;
  /* Set the data area to zero.  Remember that the machine word 0 is the
     fixnum zero.  We avoid setting to zero the additional word, if any,
     reserved by  "ik_safe_alloc()" when  converting from  the requested
     size to the aligned size; such word is on the Scheme heap, which is
     not a garbage  collector root, so the garbage  collector will never
     see it. */
  memset((char*)(ikuword_t)(s_vec + off_vector_data), 0, s_len);
  return s_vec;
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_vector_clean (ikptr_t s_vec)
{
  ikptr_t	s_len = IK_VECTOR_LENGTH_FX(s_vec);
  memset((char*)(ikuword_t)(s_vec + off_vector_data), 0, s_len);
  return s_vec;
}


/** --------------------------------------------------------------------
 ** Scheme struct utilities.
 ** ----------------------------------------------------------------- */

ikptr_t
ikrt_make_struct (ikptr_t s_std, ikpcb_t* pcb)
{
  return ika_struct_alloc_and_init(pcb, s_std);
}

int
ik_is_struct (ikptr_t R)
{
  return ((record_tag == (record_mask & R)) &&
	  (record_tag == (record_mask & IK_STRUCT_STD(R))));
}
ikptr_t
ika_struct_alloc_no_init (ikpcb_t * pcb, ikptr_t s_std)
/* Allocate  and return  a new  structure instance  using S_STD  as type
   descriptor.   All the  fields are  left uninitialised.   Make use  of
   "pcb->root9". */
{
  ikuword_t	num_of_fields = IK_UNFIX(IK_STD_LENGTH(s_std));
  ikuword_t	align_size    = IK_ALIGN(disp_record_data + num_of_fields * wordsize);
  ikptr_t	s_stru;
  pcb->root9 = &s_std;
  {
    s_stru = ik_safe_alloc(pcb, align_size) | record_tag;
    /* The  struct is  allocated on  the Scheme  heap's nursery,  so the
       struct will be  scanned at the next garbage  collection; There is
       no need to signal dirt. */
    IK_STRUCT_STD(s_stru) = s_std;
    /* "ik_safe_alloc()" returns uninitialised  invalid memory; but such
       memory is  on the Scheme heap's  nursery, which is not  a garbage
       collection root.   This means  we can freely  leave uninitialised
       the additional memory reserved when converting the requested size
       to the aligned size, because the garbage collector will never see
       it. */
  }
  pcb->root9 = NULL;
  return s_stru;
}
ikptr_t
ika_struct_alloc_and_init (ikpcb_t * pcb, ikptr_t s_std)
/* Allocate  and return  a new  structure instance  using S_STD  as type
   descriptor.  All the fields are initialised to the fixnum zero.  Make
   use of "pcb->root9". */
{
  ikptr_t	s_num_of_fields = IK_STD_LENGTH(s_std);
  ikuword_t	align_size      = IK_ALIGN(disp_record_data + s_num_of_fields);
  ikptr_t	s_stru;
  pcb->root9 = &s_std;
  {
    s_stru = ik_safe_alloc(pcb, align_size) | record_tag;
    /* The  struct is  allocated on  the Scheme  heap's nursery,  so the
       struct will be  scanned at the next garbage  collection; There is
       no need to signal dirt. */
    IK_STRUCT_STD(s_stru) = s_std;
    /* Set the  reserved data  area to zero;  remember that  the machine
       word 0 is the fixnum zero.

         We avoid setting to zero  the additional word, if any, reserved
       by "ik_safe_alloc()"  when converting from the  requested size to
       the  aligned size;  such word  is on  the Scheme  heap's nursery,
       which is not  a garbage collector root, so  the garbage collector
       will never see it. */
    memset(IK_STRUCT_FIELDS_VOIDP(s_stru), 0, s_num_of_fields);
  }
  pcb->root9 = NULL;
  return s_stru;
}


/** --------------------------------------------------------------------
 ** Scheme string utilities.
 ** ----------------------------------------------------------------- */

ikptr_t
ika_string_alloc (ikpcb_t * pcb, ikuword_t number_of_chars)
{
  ikuword_t	align_size;
  ikptr_t s_str;
  /* Do not ask me why, but IK_ALIGN is needed here. */
  align_size = IK_ALIGN(disp_string_data + number_of_chars * sizeof(ikchar_t));
  s_str	     = ik_safe_alloc(pcb, align_size) | string_tag;
  IK_STRING_LENGTH_FX(s_str) = IK_FIX(number_of_chars);
  return s_str;
}
ikptr_t
iku_string_alloc (ikpcb_t * pcb, ikuword_t number_of_chars)
{
  ikuword_t	align_size;
  ikptr_t s_str;
  /* Do not ask me why, but IK_ALIGN is needed here. */
  align_size = IK_ALIGN(disp_string_data + number_of_chars * sizeof(ikchar_t));
  s_str	     = ik_unsafe_alloc(pcb, align_size) | string_tag;
  IK_STRING_LENGTH_FX(s_str) = IK_FIX(number_of_chars);
  return s_str;
}

/* ------------------------------------------------------------------ */

ikptr_t
ika_string_from_cstring (ikpcb_t * pcb, const char * cstr)
{
  ikuword_t	clen  = strlen(cstr);
  ikptr_t	s_str = ika_string_alloc(pcb, clen);
  ikuword_t	i;
  for (i=0; i<clen; ++i) {
    IK_CHAR32(s_str, i) = IK_CHAR32_FROM_INTEGER(IK_UNICODE_FROM_ASCII(cstr[i]));
  }
  return s_str;
}
ikptr_t
iku_string_from_cstring (ikpcb_t * pcb, const char * cstr)
{
  ikuword_t	clen  = strlen(cstr);
  ikptr_t	s_str = iku_string_alloc(pcb, clen);
  ikuword_t	i;
  for (i=0; i<clen; ++i) {
    IK_CHAR32(s_str, i) = IK_CHAR32_FROM_INTEGER(IK_UNICODE_FROM_ASCII(cstr[i]));
  }
  return s_str;
}


/** --------------------------------------------------------------------
 ** Symbols.
 ** ----------------------------------------------------------------- */

int
ik_is_symbol (ikptr_t obj)
{
  return ((vector_tag == (vector_mask & obj)) &&
	  (symbol_tag == (symbol_mask & IK_REF(obj, off_symbol_record_tag))));
}


/** --------------------------------------------------------------------
 ** Scheme objects from C numbers.
 ** ----------------------------------------------------------------- */

ikptr_t
ika_integer_from_int (ikpcb_t * pcb, int N)
{
  return ika_integer_from_long(pcb, (long)N);
}
ikptr_t
ika_integer_from_long (ikpcb_t * pcb, long N)
{
  ikptr_t	s_fx = IK_FIX(N);
  if (IK_UNFIX(s_fx) == N)
    return s_fx;
  else {
#undef NUMBER_OF_WORDS
#define NUMBER_OF_WORDS		1
    /* wordsize == sizeof(long) */
    ikptr_t s_bn = ik_safe_alloc(pcb, IK_ALIGN(wordsize + disp_bignum_data)) | vector_tag;
    if (N > 0) { /* positive bignum */
      IK_REF(s_bn, off_bignum_tag)	 =
	(ikptr_t)(bignum_tag | (NUMBER_OF_WORDS << bignum_nlimbs_shift));
      IK_REF(s_bn, off_bignum_data) = (ikptr_t)+N;
    } else { /* zero or negative bignum */
      IK_REF(s_bn, off_bignum_tag)	 =
	(ikptr_t)(bignum_tag | (NUMBER_OF_WORDS << bignum_nlimbs_shift) | (1 << bignum_sign_shift));
      IK_REF(s_bn, off_bignum_data) = (ikptr_t)-N;
    }
    return s_bn;
  }
}
ikptr_t
ika_integer_from_llong (ikpcb_t * pcb, ik_llong N)
{
  /* If it  is in the range  of "long", use the	 appropriate function to
     allocate memory only for a "long" in the data area. */
  if (((ik_llong)(long) N) == N)
    return ika_integer_from_long(pcb, (long)N);
  else {
#undef NUMBER_OF_WORDS
#define NUMBER_OF_WORDS		sizeof(ik_llong) / sizeof(mp_limb_t)
    int	  align_size = IK_ALIGN(disp_bignum_data + sizeof(ik_llong));
    ikptr_t s_bn	     = ik_safe_alloc(pcb, align_size) | vector_tag;
    if (N > 0){
      IK_REF(s_bn, off_bignum_tag) =
	(ikptr_t)(bignum_tag | (NUMBER_OF_WORDS << bignum_nlimbs_shift));
      *((ik_llong*)(s_bn + off_bignum_data)) = +N;
    } else {
      IK_REF(s_bn, off_bignum_tag) =
	(ikptr_t)(bignum_tag | (NUMBER_OF_WORDS << bignum_nlimbs_shift) | (1 << bignum_sign_shift));
      *((ik_llong*)(s_bn + off_bignum_data)) = -N;
    }
    return s_bn;
  }
}
ikptr_t
ika_integer_from_uint (ikpcb_t * pcb, ik_uint N)
{
  return ika_integer_from_ulong(pcb, (ik_ulong)N);
}
ikptr_t
ika_integer_from_ulong (ikpcb_t * pcb, ik_ulong N)
{
  if ((iksword_t)N <= most_positive_fixnum) {
    return IK_FIX(N);
  } else {
    /* wordsize == sizeof(unsigned long) */
    ikptr_t	s_bn = ik_safe_alloc(pcb, IK_ALIGN(disp_bignum_data + wordsize)) | vector_tag;
    IK_REF(s_bn, off_bignum_tag)  = (ikuword_t)(bignum_tag | (1 << bignum_nlimbs_shift));
    IK_REF(s_bn, off_bignum_data) = (ikuword_t)N;
    return s_bn;
  }
}
ikptr_t
ika_integer_from_ullong (ikpcb_t * pcb, ik_ullong N)
{
  /* If	 it is	in the	range of  "unsigned long",  use	 the appropriate
     function to allocate memory only for an "unsigned long" in the data
     area. */
  if (((ik_ullong)((ik_ulong) N)) == N)
    return ika_integer_from_ulong(pcb, N);
  else {
#undef NUMBER_OF_WORDS
#define NUMBER_OF_WORDS		sizeof(ik_ullong) / sizeof(mp_limb_t)
    ikuword_t	align_size	= IK_ALIGN(disp_bignum_data + sizeof(ik_ullong));
    ikptr_t	bn		= ik_safe_alloc(pcb, align_size);
    bcopy((uint8_t*)(&N), (uint8_t*)(bn+disp_bignum_data), sizeof(ik_ullong));
    /* "ik_normalize_bignum()" wants an *untagged* pointer as argument. */
    return ik_normalize_bignum(NUMBER_OF_WORDS, 0, bn);
  }
}

/* ------------------------------------------------------------------ */

ikptr_t
ika_integer_from_sint8	(ikpcb_t* pcb, int8_t N)
/* According to R6RS  fixnums have at least 24 bits,  so we just convert
   it to fixnum. */
{
  return IK_FIX(N);
}
ikptr_t
ika_integer_from_uint8	(ikpcb_t* pcb, uint8_t N)
/* According to R6RS  fixnums have at least 24 bits,  so we just convert
   it to fixnum. */
{
  return IK_FIX(N);
}

/* ------------------------------------------------------------------ */

ikptr_t
ika_integer_from_sint16	(ikpcb_t* pcb, int16_t N)
/* According to R6RS  fixnums have at least 24 bits,  so we just convert
   it to fixnum. */
{
  return IK_FIX(N);
}
ikptr_t
ika_integer_from_uint16	(ikpcb_t* pcb, uint16_t N)
{
  return IK_FIX(N);
}

/* ------------------------------------------------------------------ */

ikptr_t
ika_integer_from_sint32	(ikpcb_t* pcb, int32_t N)
{
  ikptr_t	s_fx = IK_FIX(N);
  if (IK_UNFIX(s_fx) == N)
    return s_fx;
  else {
    switch (sizeof(int32_t)) {
    case sizeof(int):
      return ika_integer_from_int   (pcb, (int)N);
#if 0 /* duplicate case value */
    case sizeof(long):
      return ika_integer_from_long  (pcb, (long)N);
#endif
    case sizeof(ik_llong):
      return ika_integer_from_llong (pcb, (ik_llong)N);
    default:
      ik_abort("unexpected integers size");
      return IK_VOID_OBJECT;
    }
  }
}
ikptr_t
ika_integer_from_uint32	(ikpcb_t* pcb, uint32_t N)
{
  uint64_t	mxn = most_positive_fixnum;
  if (N <= mxn) {
    return IK_FIX(N);
  } else {
    switch (sizeof(uint32_t)) {
    case sizeof(ik_uint):
      return ika_integer_from_uint   (pcb, (ik_uint)N);
#if 0 /* duplicate case value */
    case sizeof(ik_ulong):
      return ika_integer_from_ulong  (pcb, (ik_ulong)N);
#endif
    case sizeof(ik_ullong):
      return ika_integer_from_ullong (pcb, (ik_ullong)N);
    default:
      ik_abort("unexpected integers size");
      return IK_VOID_OBJECT;
    }
  }
}

/* ------------------------------------------------------------------ */

ikptr_t
ika_integer_from_sint64	(ikpcb_t* pcb, int64_t N)
{
  ikptr_t	s_fx = IK_FIX(N);
  if (IK_UNFIX(s_fx) == N)
    return s_fx;
  else {
    switch (sizeof(int64_t)) {
    case sizeof(int):
      return ika_integer_from_int   (pcb, (int)N);
#if 0 /* duplicate case value */
    case sizeof(long):
      return ika_integer_from_long  (pcb, (long)N);
#endif
    case sizeof(ik_llong):
      return ika_integer_from_llong (pcb, (ik_llong)N);
    default:
      ik_abort("unexpected integers size");
      return IK_VOID_OBJECT;
    }
  }
}
ikptr_t
ika_integer_from_uint64	(ikpcb_t* pcb, uint64_t N)
{
  uint64_t	mxn = most_positive_fixnum;
  if (N <= mxn) {
    return IK_FIX(N);
  } else {
    switch (sizeof(uint64_t)) {
    case sizeof(ik_uint):
      return ika_integer_from_uint   (pcb, (ik_uint)N);
#if 0 /* duplicate case value */
    case sizeof(ik_ulong):
      return ika_integer_from_ulong  (pcb, (ik_ulong)N);
#endif
    case sizeof(ik_ullong):
      return ika_integer_from_ullong (pcb, (ik_ullong)N);
    default:
      ik_abort("unexpected integers size");
      return IK_VOID_OBJECT;
    }
  }
}

/* ------------------------------------------------------------------ */

ikptr_t
ika_integer_from_off_t (ikpcb_t * pcb, off_t N)
{
  switch (sizeof(off_t)) {
  case sizeof(int64_t):
    return ika_integer_from_sint64(pcb, (int64_t)N);
  case sizeof(int32_t):
    return ika_integer_from_sint32(pcb, (int32_t)N);
  default:
    ik_abort("unexpected off_t size %d", sizeof(off_t));
    return IK_VOID_OBJECT;
  }
}
ikptr_t
ika_integer_from_ssize_t (ikpcb_t * pcb, ssize_t N)
{
  switch (sizeof(ssize_t)) {
  case sizeof(int64_t):
    return ika_integer_from_sint64(pcb, (int64_t)N);
  case sizeof(int32_t):
    return ika_integer_from_sint32(pcb, (int32_t)N);
  default:
    ik_abort("unexpected ssize_t size %d", sizeof(ssize_t));
    return IK_VOID_OBJECT;
  }
}
ikptr_t
ika_integer_from_size_t (ikpcb_t * pcb, size_t N)
{
  switch (sizeof(size_t)) {
  case sizeof(uint64_t):
    return ika_integer_from_uint64(pcb, (uint64_t)N);
  case sizeof(int32_t):
    return ika_integer_from_uint32(pcb, (uint32_t)N);
  default:
    ik_abort("unexpected size_t size %d", sizeof(size_t));
    return IK_VOID_OBJECT;
  }
}
ikptr_t
ika_integer_from_ptrdiff_t (ikpcb_t * pcb, ptrdiff_t N)
{
  switch (sizeof(ptrdiff_t)) {
  case sizeof(int64_t):
    return ika_integer_from_sint64(pcb, (int64_t)N);
  case sizeof(int32_t):
    return ika_integer_from_sint32(pcb, (int32_t)N);
  default:
    ik_abort("unexpected ptrdiff_t size %d", sizeof(ptrdiff_t));
    return IK_VOID_OBJECT;
  }
}

/* ------------------------------------------------------------------ */

ikptr_t
ika_integer_from_sword (ikpcb_t* pcb, iksword_t N)
{
  switch (sizeof(iksword_t)) {
  case sizeof(int64_t):
    return ika_integer_from_sint64(pcb, (int64_t)N);
  case sizeof(int32_t):
    return ika_integer_from_sint32(pcb, (int32_t)N);
  /* case sizeof(signed long): */
  /*   return ika_integer_from_long(pcb, (signed long)N); */
  default:
    ik_abort("unexpected iksword_t size %d", sizeof(iksword_t));
    return IK_VOID_OBJECT;
  }
}
ikptr_t
ika_integer_from_uword (ikpcb_t* pcb, ikuword_t N)
{
  switch (sizeof(ikuword_t)) {
  case sizeof(uint64_t):
    return ika_integer_from_uint64(pcb, (int64_t)N);
  case sizeof(uint32_t):
    return ika_integer_from_uint32(pcb, (int32_t)N);
  /* case sizeof(unsigned long): */
  /*   return ika_integer_from_ulong(pcb, (unsigned long)N); */
  default:
    ik_abort("unexpected ikuword_t size %d", sizeof(ikuword_t));
    return IK_VOID_OBJECT;
  }
}

/* ------------------------------------------------------------------ */

ikptr_t
ika_flonum_from_double (ikpcb_t* pcb, double N)
{
  ikptr_t x = ik_safe_alloc(pcb, flonum_size) | vector_tag;
  IK_FLONUM_TAG(x)  = flonum_tag;
  IK_FLONUM_DATA(x) = N;
  return x;
}
ikptr_t
ika_cflonum_from_doubles (ikpcb_t* pcb, double re, double im)
{
  ikptr_t	x = ik_safe_alloc(pcb, cflonum_size) | vector_tag;
  IK_CFLONUM_TAG(x) = cflonum_tag;
  pcb->root9 = &x;
  {
    IK_ASS(IK_CFLONUM_REAL(x), ika_flonum_from_double(pcb, re));
    IK_SIGNAL_DIRT_IN_PAGE_OF_POINTER(pcb, IK_CFLONUM_REAL_PTR(x));

    IK_ASS(IK_CFLONUM_IMAG(x), ika_flonum_from_double(pcb, im));
    IK_SIGNAL_DIRT_IN_PAGE_OF_POINTER(pcb, IK_CFLONUM_IMAG_PTR(x));
  }
  pcb->root9 = NULL;
  return x;
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_integer_from_machine_word (ikptr_t s_word, ikpcb_t * pcb)
{
#ifdef IK_32BIT_PLATFORM
  uint32_t	word	= (uint32_t) s_word;
  ikptr_t		s_int	= ika_integer_from_uint32(pcb, word);
#else
  uint64_t	word	= (uint64_t) s_word;
  ikptr_t		s_int	= ika_integer_from_uint64(pcb, word);
#endif
  return s_int;
}


/** --------------------------------------------------------------------
 ** Scheme objects to C numbers.
 ** ----------------------------------------------------------------- */

int
ik_integer_to_int (ikptr_t x)
{
  if (IK_IS_FIXNUM(x))
    return (int)IK_UNFIX(x);
  else if (x == IK_VOID_OBJECT)
    return 0;
  else {
    if (IK_BNFST_NEGATIVE(IK_REF(x, -vector_tag)))
      return (int)(-IK_REF(x, off_bignum_data));
    else
      return (int)(+IK_REF(x, off_bignum_data));
  }
}
long
ik_integer_to_long (ikptr_t x)
{
  if (IK_IS_FIXNUM(x))
    return IK_UNFIX(x);
  else if (x == IK_VOID_OBJECT)
    return 0;
  else {
    if (IK_BNFST_NEGATIVE(IK_REF(x, -vector_tag)))
      return (long)(-IK_REF(x, off_bignum_data));
    else
      return (long)(+IK_REF(x, off_bignum_data));
  }
}
ik_uint
ik_integer_to_uint (ikptr_t x)
{
  if (IK_IS_FIXNUM(x))
    return IK_UNFIX(x);
  else if (x == IK_VOID_OBJECT)
    return 0;
  else {
    assert(! IK_BNFST_NEGATIVE(IK_REF(x, -vector_tag)));
    return (ik_uint)(IK_REF(x, off_bignum_data));
  }
}
ik_ulong
ik_integer_to_ulong (ikptr_t x)
{
  if (IK_IS_FIXNUM(x))
    return IK_UNFIX(x);
  else if (x == IK_VOID_OBJECT)
    return 0;
  else {
    assert(! IK_BNFST_NEGATIVE(IK_REF(x, -vector_tag)));
    return (ik_ulong)(IK_REF(x, off_bignum_data));
  }
}
ik_llong
ik_integer_to_llong (ikptr_t x)
{
  if (IK_IS_FIXNUM(x))
    return IK_UNFIX(x);
  else if (x == IK_VOID_OBJECT)
    return 0;
  else {
    ikptr_t fst		   = IK_REF(x, -vector_tag);
    ikptr_t pos_one_limb_tag = (ikptr_t)(bignum_tag	      | (1 << bignum_nlimbs_shift));
    ikptr_t neg_one_limb_tag = (ikptr_t)(pos_one_limb_tag | (1 << bignum_sign_shift));
    if (fst == pos_one_limb_tag)
      return (ik_ulong)IK_REF(x, off_bignum_data);
    else if (fst == neg_one_limb_tag)
      return -(signed long)IK_REF(x, off_bignum_data);
    else if (IK_BNFST_NEGATIVE(fst))
      return -(*((ik_llong*)(x+off_bignum_data)));
    else
      return *((ik_llong*)(x+off_bignum_data));

  }
}
ik_ullong
ik_integer_to_ullong (ikptr_t x)
{
  if (IK_IS_FIXNUM(x))
    return (ik_ullong)IK_UNFIX(x);
  else if (x == IK_VOID_OBJECT)
    return 0;
  else {
    ik_ullong *	 memory = (ik_ullong *)(x + off_bignum_data);
    assert(! IK_BNFST_NEGATIVE(IK_REF(x, -vector_tag)));
    return *memory;
  }
}

/* ------------------------------------------------------------------ */

uint8_t
ik_integer_to_uint8 (ikptr_t x)
/* According to R6RS fixnums must have at  least 24 bits, so X must be a
   fixnum for this function to work. */
{
  assert(IK_IS_FIXNUM(x));
  iksword_t	X = IK_UNFIX(x);
  return ((0 <= X) && (X <= UINT8_MAX))? ((uint8_t)X) : IK_FALSE;
}
int8_t
ik_integer_to_sint8 (ikptr_t x)
/* According to R6RS fixnums must have at  least 24 bits, so X must be a
   fixnum for this function to work. */
{
  assert(IK_IS_FIXNUM(x));
  iksword_t	X = IK_UNFIX(x);
  return ((INT8_MIN <= X) && (X <= INT8_MAX))? ((int8_t)X) : IK_FALSE;
}

/* ------------------------------------------------------------------ */

uint16_t
ik_integer_to_uint16 (ikptr_t x)
/* According to R6RS fixnums must have at  least 24 bits, so X must be a
   fixnum for this function to work. */
{
  assert(IK_IS_FIXNUM(x));
  iksword_t	X = IK_UNFIX(x);
  return ((0 <= X) && (X <= UINT16_MAX))? ((uint16_t)X) : IK_FALSE;
}
int16_t
ik_integer_to_sint16 (ikptr_t x)
/* According to R6RS fixnums must have at  least 24 bits, so X must be a
   fixnum for this function to work. */
{
  assert(IK_IS_FIXNUM(x));
  iksword_t	X = IK_UNFIX(x);
  return ((INT16_MIN <= X) && (X <= INT16_MAX))? ((int16_t)X) : IK_FALSE;
}

/* ------------------------------------------------------------------ */

uint32_t
ik_integer_to_uint32 (ikptr_t x)
{
  if (IK_IS_FIXNUM(x)) {
    iksword_t	X = IK_UNFIX(x);
    return ((0 <= X) && (X <= UINT32_MAX))? ((uint32_t)X) : IK_FALSE_OBJECT;
  } else {
    uint32_t *	memory = (void *)(((uint8_t *)x) + off_bignum_data);
    return (IK_BNFST_NEGATIVE(IK_REF(x, -vector_tag)))? -(*memory) : (*memory);
  }
}
int32_t
ik_integer_to_sint32 (ikptr_t x)
{
  if (IK_IS_FIXNUM(x)) {
    iksword_t	X = IK_UNFIX(x);
    return ((INT32_MIN <= X) && (X <= INT32_MAX))? ((int32_t)X) : IK_FALSE_OBJECT;
  } else {
    int32_t *  memory = (void *)(((uint8_t *)x) + off_bignum_data);
    return (IK_BNFST_NEGATIVE(IK_REF(x, -vector_tag)))? -(*memory) : (*memory);
  }
}

/* ------------------------------------------------------------------ */

uint64_t
ik_integer_to_uint64 (ikptr_t x)
{
  if (IK_IS_FIXNUM(x)) {
    iksword_t	X = IK_UNFIX(x);
    return ((0 <= X) && (X <= UINT64_MAX))? ((uint64_t)X) : IK_FALSE_OBJECT;
  } else {
    uint64_t *	memory = (void *)(((uint8_t *)x) + off_bignum_data);
    return (IK_BNFST_NEGATIVE(IK_REF(x, -vector_tag)))? -(*memory) : (*memory);
  }
}
int64_t
ik_integer_to_sint64 (ikptr_t x)
{
  if (IK_IS_FIXNUM(x)) {
    iksword_t	X = IK_UNFIX(x);
    return ((INT64_MIN <= X) && (X <= INT64_MAX))? ((int64_t)X) : IK_FALSE_OBJECT;
  } else {
    int64_t *  memory = (void *)(((uint8_t *)x) + off_bignum_data);
    return (IK_BNFST_NEGATIVE(IK_REF(x, -vector_tag)))? -(*memory) : (*memory);
  }
}

/* ------------------------------------------------------------------ */

off_t
ik_integer_to_off_t (ikptr_t x)
{
  switch (sizeof(off_t)) {
  case sizeof(int64_t):
    return (off_t)ik_integer_to_sint64(x);
  case sizeof(int32_t):
    return (off_t)ik_integer_to_sint32(x);
  default:
    ik_abort("unexpected off_t size %d", sizeof(off_t));
    return IK_VOID_OBJECT;
  }
}
size_t
ik_integer_to_size_t (ikptr_t x)
{
  if (sizeof(size_t) == sizeof(uint32_t))
    return (size_t)ik_integer_to_uint32(x);
  else
    return (size_t)ik_integer_to_uint64(x);
}
ssize_t
ik_integer_to_ssize_t (ikptr_t x)
{
  if (sizeof(ssize_t) == sizeof(int32_t))
    return (ssize_t)ik_integer_to_sint32(x);
  else
    return (ssize_t)ik_integer_to_sint64(x);
}
ptrdiff_t
ik_integer_to_ptrdiff_t (ikptr_t x)
{
  switch (sizeof(ptrdiff_t)) {
  case sizeof(int32_t):
    return (ptrdiff_t)ik_integer_to_sint32(x);
  case sizeof(int64_t):
    return (ptrdiff_t)ik_integer_to_sint64(x);
  default:
    ik_abort("unexpected ptrdiff_t size %d", sizeof(ptrdiff_t));
    return IK_VOID_OBJECT;
  }
}

/* ------------------------------------------------------------------ */

iksword_t
ika_integer_to_sword (ikpcb_t* pcb, ikptr_t X)
{
  switch (sizeof(iksword_t)) {
  case sizeof(int64_t):
    return (iksword_t)ik_integer_to_sint64(X);
  case sizeof(int32_t):
    return (iksword_t)ik_integer_to_sint32(X);
  /* case sizeof(signed long): */
  /*   return (iksword_t)ik_integer_to_long(X); */
  default:
    ik_abort("unexpected iksword_t size %d", sizeof(iksword_t));
    return IK_VOID_OBJECT;
  }
}
ikuword_t
ika_integer_to_uword (ikpcb_t* pcb, ikptr_t X)
{
  switch (sizeof(ikuword_t)) {
  case sizeof(uint64_t):
    return (ikuword_t)ik_integer_to_uint64(X);
  case sizeof(uint32_t):
    return (ikuword_t)ik_integer_to_uint32(X);
  /* case sizeof(signed long): */
  /*   return (ikuword_t)ik_integer_to_ulong(X); */
  default:
    ik_abort("unexpected iksword_t size %d", sizeof(ikuword_t));
    return IK_VOID_OBJECT;
  }
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_integer_to_machine_word (ikptr_t s_int, ikpcb_t * pcb)
{
#ifdef IK_32BIT_PLATFORM
  uint32_t	word = ik_integer_to_uint32(s_int);
#else
  uint64_t	word = ik_integer_to_uint64(s_int);
#endif
  return (ikptr_t)word;
}


/** --------------------------------------------------------------------
 ** Ratnum objects.
 ** ----------------------------------------------------------------- */

int
ik_is_ratnum (ikptr_t X)
{
  return ((vector_tag == IK_TAGOF(X)) &&
	  (ratnum_tag == IK_RATNUM_TAG(X)));
}
ikptr_t
ika_ratnum_alloc_no_init (ikpcb_t * pcb)
{
  ikptr_t	s_rn = ik_safe_alloc(pcb, ratnum_size) | vector_tag;
  IK_RATNUM_TAG(s_rn) = ratnum_tag;
  return s_rn;
}
ikptr_t
ika_ratnum_alloc_and_init (ikpcb_t * pcb)
{
  ikptr_t	s_rn = ik_safe_alloc(pcb, ratnum_size) | vector_tag;
  IK_RATNUM_TAG(s_rn) = ratnum_tag;
  memset((void *)(((ikuword_t)s_rn) + off_ratnum_num), 0, 3 * wordsize);
  return s_rn;
}


/** --------------------------------------------------------------------
 ** Compnum objects.
 ** ----------------------------------------------------------------- */

int
ik_is_compnum (ikptr_t X)
{
  return ((vector_tag  == IK_TAGOF(X)) &&
	  (compnum_tag == IK_COMPNUM_TAG(X)));
}
ikptr_t
ika_compnum_alloc_no_init (ikpcb_t * pcb)
{
  ikptr_t	s_cn = ik_safe_alloc(pcb, compnum_size) | vector_tag;
  IK_COMPNUM_TAG(s_cn) = compnum_tag;
  return s_cn;
}
ikptr_t
ika_compnum_alloc_and_init (ikpcb_t * pcb)
{
  ikptr_t	s_cn = ik_safe_alloc(pcb, compnum_size) | vector_tag;
  IK_COMPNUM_TAG(s_cn) = compnum_tag;
  memset((void *)(((ikuword_t)s_cn) + off_compnum_real), 0, compnum_size);
  return s_cn;
}


/** --------------------------------------------------------------------
 ** Code objects.
 ** ----------------------------------------------------------------- */

ikptr_t
ik_stack_frame_top_to_code_object (ikptr_t top)
/* Given a pointer  to the top of  a stack frame: return  a reference to
   the code object containing the return point. */
{
  /* A Scheme stack frame looks like this:
   *
   *
   *       high memory
   *   |                |
   *   |----------------|
   *   | return address | <- uplevel top
   *   |----------------|         --
   *   | Scheme object  |         .
   *   |----------------|         .
   *   | Scheme object  |         . framesize
   *   |----------------|         .
   *   | return address | <- top  .
   *   |----------------|         --
   *   |                |
   *      low memory
   *
   * through TOP we  retrieve the return address, which is  a pointer to
   * the label SINGLE-VALUE-RP in the following assembly code:
   *
   *     ;; low memory
   *
   *     jmp L0
   *     livemask-bytes	;array of bytes			|
   *     framesize	;data word, a "ikuword_t"	| call
   *     rp_offset	;data word, a fixnum		| table
   *     multi-value-rp	;data word, assembly label	|
   *     pad-bytes
   *   L0:
   *     call function-address
   *   single-value-rp:		;single value return point
   *     ... instructions...
   *   multi-value-rp:		;multi value return point
   *     ... instructions...
   *
   *     ;; high memory
   */
  ikptr_t	single_value_rp	= IK_REF(top, 0);
  /* Through the return  address we retrieve the field  RP_OFFSET in the
   * call table, which  contains the offset of that very  field from the
   * beginning of the code.
   *
   *    metadata              binary code
   *   |........|.......................................|
   *
   *                          call table  single-value-rp
   *                          |........|  v
   *   |--------|-------------+-+-+----+--+-------------| code object
   *            |...............|^
   *              field_offset   |
   *                    |        |
   *                     --------
   */
  iksword_t	field_offset	= IK_UNFIX(IK_CALLTABLE_OFFSET(single_value_rp));
  /* Then we  compute the offset  of the label SINGLE-VALUE-RP  from the
   * beginning of the code object's entry point.
   *
   *    metadata              binary code
   *   |........|.......................................|
   *
   *                          call table  single-value-rp
   *                          |........|  v
   *   |--------|-------------+--------+--+-------------| code object
   *            |.........................|
   *                     rp_offset
   *
   *
   * NOTE The preprocessor symbol "disp_call_table_offset" is a negative
   * integer.
   */
  iksword_t	rp_offset	= field_offset - disp_call_table_offset;
  /* Then we compute the address of  the entry point in the code object:
     the address of the first byte of executable code. */
  ikptr_t	code_entry	= single_value_rp - rp_offset;
  /* Finally we compute the tagged pointer to the code object. */
  ikptr_t s_code		= code_entry - off_code_data;
  return s_code;
}


/** --------------------------------------------------------------------
 ** General C buffers.
 ** ----------------------------------------------------------------- */

size_t
ik_generalised_c_buffer_len (ikptr_t s_buffer, ikptr_t s_buffer_len)
/* Return the number of bytes in a generalised C buffer object.

   S_BUFFER must  be a  bytevector, pointer object,  memory-block struct
   instance.

   When  S_BUFFER is  a pointer  object: S_BUFFER_LEN  must be  an exact
   integer representing the number of  bytes available in the referenced
   memory block.  Otherwise S_BUFFER_LEN is ignored.  */
{
  if (IK_IS_POINTER(s_buffer)) {
    return ik_integer_to_size_t(s_buffer_len);
  } else if (IK_IS_BYTEVECTOR(s_buffer)) {
    return IK_BYTEVECTOR_LENGTH(s_buffer);
  } else { /* it is a memory-block */
    return IK_MBLOCK_SIZE(s_buffer);
  }
}


/** --------------------------------------------------------------------
 ** Miscellanous functions.
 ** ----------------------------------------------------------------- */

ikptr_t
ikrt_general_copy (ikptr_t s_dst, ikptr_t s_dst_start,
		   ikptr_t s_src, ikptr_t s_src_start,
		   ikptr_t s_count, ikpcb_t * pcb)
/* General binary  data copy function.   It copies data from  raw memory
   block  or Scheme  bytevector Scheme  string  to raw  memory block  or
   Scheme bytevector or Scheme string. */
{
  ikuword_t	src_start = IK_UNFIX(s_src_start);
  ikuword_t	dst_start = IK_UNFIX(s_dst_start);
  size_t	count     = (size_t)IK_UNFIX(s_count);
  uint8_t *	dst = NULL;
  uint8_t *	src = NULL;
  if (IK_IS_BYTEVECTOR(s_src)) {
    src = IK_BYTEVECTOR_DATA_UINT8P(s_src) + src_start;
  } else if (ikrt_is_pointer(s_src)) {
    src = IK_POINTER_DATA_UINT8P(s_src) + src_start;
  } else if (IK_IS_STRING(s_src)) {
    src_start <<= 2; /* multiply by 4 */
    src = IK_STRING_DATA_VOIDP(s_src);
  } else
    ik_abort("%s: invalid src value, %lu", __func__, (ik_ulong)s_src);

  if (IK_IS_BYTEVECTOR(s_dst)) {
    dst = IK_BYTEVECTOR_DATA_UINT8P(s_dst) + dst_start;
  } else if (ikrt_is_pointer(s_dst)) {
    dst = IK_POINTER_DATA_UINT8P(s_dst) + dst_start;
  } else if (IK_IS_STRING(s_dst)) {
    dst_start <<= 2; /* multiply by 4 */
    dst = IK_STRING_DATA_VOIDP(s_dst);
  } else
    ik_abort("%s: invalid dst value, %lu", __func__, (ik_ulong)s_dst);

  memcpy(dst, src, count);
  return IK_VOID_OBJECT;
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_debug_flonum_to_bytevector (ikptr_t s_flonum, ikpcb_t * pcb)
{
  ikptr_t		s_bv;
  uint8_t *	src;
  uint8_t *	dst;
  pcb->root0 = &s_flonum;
  {
    s_bv = ika_bytevector_alloc(pcb, flonum_size);
    src  = (uint8_t *)(s_flonum - vector_tag);
    dst  = IK_BYTEVECTOR_DATA_VOIDP(s_bv);
    memcpy(dst, src, flonum_size);
  }
  pcb->root0 = NULL;
  return s_bv;
}
ikptr_t
ikrt_debug_flonum_from_bytevector (ikptr_t s_bv, ikpcb_t * pcb)
{
  if (flonum_size == IK_BYTEVECTOR_LENGTH(s_bv)) {
    ikptr_t	s_flonum;
    uint8_t *	src;
    uint8_t *	dst;
    pcb->root0 = &s_bv;
    {
      s_flonum = ika_flonum_from_double(pcb, 0.0);
      src      = IK_BYTEVECTOR_DATA_UINT8P(s_bv);
      dst      = (uint8_t *)(s_flonum - vector_tag);
      memcpy(dst, src, flonum_size);
    }
    pcb->root0 = NULL;
    return s_flonum;
  } else
    return IK_FALSE;
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_debug_bignum_to_bytevector (ikptr_t s_bignum, ikpcb_t * pcb)
{
  ikptr_t		first_word = IK_REF(s_bignum, -vector_tag);
  ikuword_t	limb_count = IK_BNFST_LIMB_COUNT(first_word);
  ikuword_t	bv_size    = IK_BIGNUM_ALLOC_SIZE(limb_count);
  ikptr_t		s_bv;
  uint8_t *	src;
  uint8_t *	dst;
  /* fprintf(stderr, "limb count: %ld, bv size: %ld\n", limb_count, bv_size); */
  pcb->root0 = &s_bignum;
  {
    s_bv = ika_bytevector_alloc(pcb, bv_size);
    src  = (uint8_t *)(s_bignum - vector_tag);
    dst  = IK_BYTEVECTOR_DATA_VOIDP(s_bv);
    memcpy(dst, src, bv_size);
  }
  pcb->root0 = NULL;
  return s_bv;
}
ikptr_t
ikrt_debug_bignum_from_bytevector (ikptr_t s_bv, ikpcb_t * pcb)
{
  ikptr_t		s_bignum;
  uint8_t *	src;
  uint8_t *	dst;
  pcb->root0 = &s_bv;
  {
    ikuword_t	bv_size    = IK_BYTEVECTOR_LENGTH(s_bv);
    ikuword_t	limb_count = (bv_size - disp_bignum_data) / wordsize;
    s_bignum = IKA_BIGNUM_ALLOC(pcb, limb_count);
    src      = IK_BYTEVECTOR_DATA_UINT8P(s_bv);
    dst      = (uint8_t *)(s_bignum - vector_tag);
    memcpy(dst, src, bv_size);
  }
  pcb->root0 = NULL;
  return s_bignum;
}


/** --------------------------------------------------------------------
 ** Garbage collection avoidance.
 ** ----------------------------------------------------------------- */

static ik_gc_avoidance_collection_t *
ik_allocate_avoidance_collection (void)
{
  ik_gc_avoidance_collection_t *	collection;
  int	i;
  collection = calloc(1, sizeof(ik_gc_avoidance_collection_t));
  if (NULL == collection) {
    ik_abort("not enough memory to allocate a garbage collection avoidance list");
  }
  for (i=0; i<IK_GC_AVOIDANCE_ARRAY_LEN; ++i)
    collection->slots[i] = IK_VOID;
  return collection;
}
ikptr_t
ik_register_to_avoid_collecting (ikptr_t s_obj, ikpcb_t * pcb)
{
  if (IK_VOID == s_obj) {
    return ika_pointer_alloc(pcb, (ikuword_t)NULL);
  } else {
    ik_gc_avoidance_collection_t *	collection = pcb->not_to_be_collected;
    ikptr_t *				slot = NULL;
    { /* If no collections are present: allocate a new one and store it in
	 the PCB. */
      if (NULL == collection)
	pcb->not_to_be_collected = collection = ik_allocate_avoidance_collection();
    }
    { /* At  least  one  collection  is   present.   Search  the  list  of
	 collections for the first with a free slot in its array. */
      while (collection) {
	int	i;
	for (i=0; i<IK_GC_AVOIDANCE_ARRAY_LEN; ++i) {
	  if (IK_VOID == collection->slots[i]) {
	    slot = &collection->slots[i];
	    goto out;
	  }
	}
	collection = collection->next;
      }
    }
  out:
    /* If no collection has a free slot: allocate a new one and push it on
       the PCB. */
    {
      if (NULL == slot) {
	collection		= ik_allocate_avoidance_collection();
	collection->next	= pcb->not_to_be_collected;
	pcb->not_to_be_collected= collection;
	slot = &(collection->slots[0]);
      }
    }
    /* Now SLOT references a free slot. */
    *slot = s_obj;
    return ika_pointer_alloc(pcb, (ikuword_t)slot);
  }
}
ikptr_t
ik_forget_to_avoid_collecting (ikptr_t s_ptr, ikpcb_t * pcb)
{
  ikptr_t *	P = IK_POINTER_DATA_VOIDP(s_ptr);
  if (P) {
    ikptr_t	s_obj = *P;
    *P = IK_VOID;
    return s_obj;
  } else
    return IK_VOID;
}
ikptr_t
ik_retrieve_to_avoid_collecting (ikptr_t s_ptr, ikpcb_t * pcb)
{
  ikptr_t *	P = IK_POINTER_DATA_VOIDP(s_ptr);
  return (P)? *P : IK_VOID;
}
ikptr_t
ik_replace_to_avoid_collecting (ikptr_t s_ptr, ikptr_t s_new_obj, ikpcb_t * pcb)
{
  ikptr_t *	P = IK_POINTER_DATA_VOIDP(s_ptr);
  if (P) {
    ikptr_t	s_old_obj = *P;
    *P = s_new_obj;
    return s_old_obj;
  } else
    return IK_VOID;
}
ikptr_t
ik_collection_avoidance_list (ikpcb_t * pcb)
{
  ik_gc_avoidance_collection_t *	collection = pcb->not_to_be_collected;
  ikptr_t		s_list		= IK_NULL;
  ikptr_t		s_spine		= IK_NULL;
  if (NULL == collection)
    return IK_NULL;
  else {
    pcb->root0 = &s_list;
    pcb->root1 = &s_spine;
    {
      while (collection) {
	for (ikuword_t i=0; i<IK_GC_AVOIDANCE_ARRAY_LEN; ++i) {
	  /* fprintf(stderr, "%d=%ld ", i, collection->slots[i]); */
	  if (IK_VOID != collection->slots[i]) {
	    if (IK_NULL == s_spine) {
	      s_spine = ika_pair_alloc(pcb);
	    } else {
	      IK_ASS(IK_CDR(s_spine), ika_pair_alloc(pcb));
	      IK_SIGNAL_DIRT_IN_PAGE_OF_POINTER(pcb, IK_CDR_PTR(s_spine));
	      s_spine = IK_CDR(s_spine);
	    }
	    IK_CAR(s_spine) = collection->slots[i];
	    IK_SIGNAL_DIRT_IN_PAGE_OF_POINTER(pcb, IK_CAR_PTR(s_spine));
	    if (IK_NULL == s_list)
	      s_list = s_spine;
	  }
	}
	collection = collection->next;
      }
      if (IK_NULL != s_spine)
	IK_CDR(s_spine) = IK_NULL;
    }
    pcb->root1 = NULL;
    pcb->root0 = NULL;
    return s_list;
  }
}
ikptr_t
ik_purge_collection_avoidance_list (ikpcb_t * pcb)
{
  ik_gc_avoidance_collection_t *	collection = pcb->not_to_be_collected;
  while (collection) {
    int		i;
    for (i=0; i<IK_GC_AVOIDANCE_ARRAY_LEN; ++i)
      collection->slots[i] = IK_VOID;
    collection = collection->next;
  }
  return IK_VOID;
}

#if 0
/* The following  are the old versions,  when the "not to  be collected"
   list was an actual Scheme list. */
ikptr_t
ik_register_to_avoid_collecting (ikptr_t s_obj, ikpcb_t * pcb)
{
  switch (s_obj) {
  case IK_FALSE:     /* Avoid registering constants. */
  case IK_TRUE:
  case IK_NULL:
  case IK_EOF:
  case IK_VOID:
  case IK_BWP:
  case IK_UNBOUND:
    return s_obj;
  default:
    if (IK_IS_FIXNUM(s_obj)) {    /* Avoid registering fixnums. */
      return s_obj;
    } else {
      pcb->root0 = &s_obj;
      {
	ikptr_t	s_pair = ika_pair_alloc(pcb);
	IK_CAR(s_pair) = s_obj;
	IK_SIGNAL_DIRT_IN_PAGE_OF_POINTER(pcb, IK_CAR_PTR(s_pair));
	IK_CDR(s_pair) = pcb->not_to_be_collected;
	pcb->not_to_be_collected = s_pair;
      }
      pcb->root0 = NULL;
      return s_obj;
    }
  }
}
ikptr_t
ik_forget_to_avoid_collecting (ikptr_t s_obj, ikpcb_t * pcb)
{
  switch (s_obj) {
  case IK_FALSE:     /* Avoid searching for constants. */
  case IK_TRUE:
  case IK_NULL:
  case IK_EOF:
  case IK_VOID:
  case IK_BWP:
  case IK_UNBOUND:
    return IK_FALSE;
  default:
    if (IK_IS_FIXNUM(s_obj)) {    /* Avoid searching for fixnums. */
      return IK_FALSE;
    } else {
      ikptr_t s_pair = pcb->not_to_be_collected;
      /*
       *  |------------| pcb
       *       |
       *        ---> NULL = s_pair
       */
      if (IK_NULL == s_pair) {
	return IK_FALSE_OBJECT;
      } else
	/* Before:
	 *
	 *  |------------| pcb
	 *       |
	 *        --->|---|---| s_pair
	 *              |   |
	 *             OBJ   --->|---|---| CDR
	 *
	 * after:
	 *
	 *  |------------| pcb                |---|---| s_pair
	 *       |                              |
	 *        --->|---|---| CDR            OBJ
	 */
	if (IK_CAR(s_pair) == s_obj) {
	  pcb->not_to_be_collected = IK_CDR(s_pair);
	  return s_obj;
	} else {
	  ikptr_t	s_prev = s_pair;
	  while (IK_NULL != s_pair) {
	    /* Before:
	     *
	     *  |---|---| s_prev
	     *        |
	     *         --->|---|---| s_pair
	     *               |   |
	     *              OBJ   --->|---|---| CDR
	     *
	     * after:
	     *
	     *  |---|---| s_prev               |---|---| s_pair
	     *        |                          |
	     *         --->|---|---| CDR        OBJ
	     */
	    if (IK_CAR(s_pair) == s_obj) {
	      IK_CDR(s_prev) = IK_CDR(s_pair);
	      return s_obj;
	    } else {
	      s_prev = s_pair;
	      s_pair = IK_CDR(s_prev);
	    }
	  }
	  return IK_FALSE_OBJECT;
	}
    }
  }
}
ikptr_t
ik_collection_avoidance_list (ikpcb_t * pcb)
{
  return pcb->not_to_be_collected;
}
ikptr_t
ik_purge_collection_avoidance_list (ikpcb_t * pcb)
{
  pcb->not_to_be_collected = IK_NULL;
  return IK_VOID;
}
#endif

/* end of file */
