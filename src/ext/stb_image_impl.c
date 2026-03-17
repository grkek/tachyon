/* stb_image wrapper for Tachyon
 * We vendor a minimal C file that includes stb_image implementation.
 * Build: cc -c -O2 stb_image_impl.c -o stb_image_impl.o
 */

#define STB_IMAGE_IMPLEMENTATION
#define STBI_NO_STDIO  // We'll use memory loading
#undef STBI_NO_STDIO   // Actually we need file loading too
#include "stb_image.h"
