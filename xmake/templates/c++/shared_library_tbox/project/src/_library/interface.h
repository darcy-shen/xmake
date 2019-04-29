#ifndef INTERFACE_H
#define INTERFACE_H

/* //////////////////////////////////////////////////////////////////////////////////////
 * includes
 */
#include "tbox/tbox.h"

/* //////////////////////////////////////////////////////////////////////////////////////
 * extern
 */
__tb_extern_c_enter__


/*! calculate add(a, b) 
 *
 * @param a     the first argument
 * @param b     the second argument
 *
 * @return      the result
 */
__tb_export__ tb_int_t add(tb_int_t a, tb_int_t b);

/* //////////////////////////////////////////////////////////////////////////////////////
 * extern
 */
__tb_extern_c_leave__

#endif
