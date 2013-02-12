/* ==========================================
    CMock Project - Automatic Mock Generation for C
    Copyright (c) 2007 Mike Karlesky, Mark VanderVoord, Greg Williams
    [Released under MIT License. Please refer to license.txt for details]
========================================== */

#ifndef CMOCK_FRAMEWORK_H
#define CMOCK_FRAMEWORK_H

//should be big enough to index full range of CMOCK_MEM_MAX
#ifndef CMOCK_MEM_INDEX_TYPE
#define CMOCK_MEM_INDEX_TYPE  unsigned int
#endif

#define CMOCK_GUTS_NONE (0)

#ifndef NULL
#define NULL (void*)0
#endif

#define CHAR_TO_MAGIC(a,b,c,d) (((a)<<24) | ((b) << 16) | ((c) << 8) | (d))
/* M = 0x31323334 - "1234"
 *  MAGIC_TO_CHAR(M,0) = "1"
 */    
#define MAGIC_TO_CHAR(m,i)  (((m) >> ((3-(i)) * 8)) & 0xFF)
#define MAGIC_EQ(m,s)  (m == (((s[0])<<24) | ((s[1]) << 16) | ((s[2]) << 8) | (s[3])))

//-------------------------------------------------------
// Memory API
//-------------------------------------------------------
CMOCK_MEM_INDEX_TYPE  CMock_Guts_MemNew(CMOCK_MEM_INDEX_TYPE size);
CMOCK_MEM_INDEX_TYPE  CMock_Guts_MemChain(CMOCK_MEM_INDEX_TYPE root_index, CMOCK_MEM_INDEX_TYPE obj_index);
CMOCK_MEM_INDEX_TYPE  CMock_Guts_MemNext(CMOCK_MEM_INDEX_TYPE previous_item_index);

void*                 CMock_Guts_GetAddressFor(CMOCK_MEM_INDEX_TYPE index);

CMOCK_MEM_INDEX_TYPE  CMock_Guts_MemBytesFree(void);
CMOCK_MEM_INDEX_TYPE  CMock_Guts_MemBytesUsed(void);
void                  CMock_Guts_MemFreeAll(void);

#endif //CMOCK_FRAMEWORK
