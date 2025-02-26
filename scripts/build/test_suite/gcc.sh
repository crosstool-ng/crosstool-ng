# This file adds the functions to build the GCC test suite
# Copyright 2010 DoréDevelopment
# Created by Martin Lund <mgl@doredevelopment.dk>
# Licensed under the GPL v2. See COPYING in the root of this package

do_test_suite_gcc_get() { :; }
do_test_suite_gcc_extract() { :; }
do_test_suite_gcc_build() { :; }

# Overide functions depending on configuration
if [ "${CT_TEST_SUITE_GCC}" = "y" ]; then

do_test_suite_gcc_build() {
 
    CT_DoStep INFO "Installing GCC test suite"

    CT_DoExecLog ALL mkdir -p "${CT_TEST_SUITE_DIR}/gcc"
    CT_DoExecLog ALL cp -av "${CT_LIB_DIR}/contrib/gcc-test-suite/default.cfg"      \
                            "${CT_LIB_DIR}/contrib/gcc-test-suite/Makefile"         \
                            "${CT_LIB_DIR}/contrib/gcc-test-suite/README"           \
                            "${CT_SRC_DIR}/gcc/gcc/testsuite"  \
                            "${CT_TEST_SUITE_DIR}/gcc"

    DG_QEMU_ARGS=`echo "${CT_TEST_SUITE_GCC_QEMU_ARGS}" | sed 's/@SYSROOT@/$(SYSROOT)/'`

    CT_DoExecLog ALL sed -i -r \
		 -e "s/@@DG_TARGET@@/${CT_TARGET}/g"     \
		 -e "s/@@DG_SSH@@/${CT_TEST_SUITE_GCC_SSH}/g" \
		 -e "s/@@DG_QEMU@@/${CT_TEST_SUITE_GCC_QEMU}/g" \
		 -e "s/@@DG_TARGET_HOSTNAME@@/${CT_TEST_SUITE_GCC_TARGET_HOSTNAME}/g" \
		 -e "s/@@DG_TARGET_USERNAME@@/${CT_TEST_SUITE_GCC_TARGET_USERNAME}/g" \
		 -e "s/@@DG_QEMU_PROGRAM@@/${CT_TEST_SUITE_GCC_QEMU_PROGRAM}/g" \
		 -e "s/@@DG_QEMU_ARGS@@/${DG_QEMU_ARGS}/g" \
			 "${CT_TEST_SUITE_DIR}/gcc/default.cfg"

    CT_EndStep
}

fi # CT_TEST_SUITE_GCC
