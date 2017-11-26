/**
 * The contents of this file are copied directly from /usr/include/dlfcn.h
 */

#ifndef SHIM_H
#define SHIM_H

#ifdef __linux__
/* Structure containing information about object searched using
   `dladdr'.  */
typedef struct
{
  const char *dli_fname;        /* File name of defining object.  */
  void *dli_fbase;              /* Load address of that object.  */
  const char *dli_sname;        /* Name of nearest symbol.  */
  void *dli_saddr;              /* Exact value of nearest symbol.  */
} Dl_info;

typedef Dl_info dl_info;

/* Fill in *INFO with the following information about ADDRESS.
   Returns 0 iff no shared object's segments contain that address.  */
int dladdr (const void *__address, Dl_info *__info);
#endif // defined(__linux__)

#endif // defined(SHIM_H)
