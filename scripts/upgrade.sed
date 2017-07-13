# After 1.23.0, generated config options were standardized to upper case
s/\<CT_ARCH_(alpha|arm|avr|m68k|microblaze|mips|msp430|nios2|powerpc|s390|sh|sparc|x86|xtensa)\>/CT_ARCH_\U\1/g
s/\<CT_BINUTILS_binutils\>/CT_BINUTILS_BINUTILS/g
s/\<CT_CC_gcc\>/CT_CC_GCC/g
s/\<CT_COMP_TOOLS_(autoconf|automake|libtool|m4|make)\>/CT_COMP_TOOLS_\U\1/g
s/\<CT_DEBUG_(duma|gdb|ltrace|strace)\>/CT_DEBUG_\U\1/g
s/\<CT_KERNEL_(bare_metal|linux|windows)\>/CT_KERNEL_\U\1/g
s/\<CT_LIBC_(avr_libc|bionic|glibc|mingw|musl|newlib|none|uClibc)\>/CT_LIBC_\U\1/g

# Also after 1.23.0, package versions were brought to the same format
s/\<CT_LIBC_BIONIC_V_([0-9a-z]+)\>/CT_ANDROID_NDK_V_R\U\1/g
s/\<CT_ANDROID_NDK_V_R15BETA1\>/CT_ANDROID_NDK_V_R15B/g
s/\<CT_LIBC_AVR_LIBC_V_/CT_AVR_LIBC_V_/g
s/\<CT_CC_GCC_V_/CT_GCC_V_/g
s/\<CT_LIBC_GLIBC_V_/CT_GLIBC_V_/g
s/\<CT_KERNEL_V_/CT_LINUX_V_/g
s/\<CT_WINAPI_V_/CT_MINGW_W64_V_V/g
s/\<CT_LIBC_MUSL_V_/CT_MUSL_V_/g
s/\<CT_LIBC_NEWLIB_V_/CT_NEWLIB_V_/g
s/\<CT_LIBC_UCLIBC_NG_V_/CT_UCLIBC_NG_V_/g

# Special cases that need manual intervention (require setting of supporting options)
s/\<CT_LIBC_UCLIBC_V_.*/# [&] not handled by upgrade script, use menuconfig./w/dev/stderr
s/\<CT_[A-Za-z0-9_]*_SHOW_LINARO.*/# [&] not handled by upgrade script, use menuconfig./w/dev/stderr
s/\<CT_[A-Za-z0-9_]*_CUSTOM_LOCATION.*/# [&] not handled by upgrade script, use menuconfig./w/dev/stderr
