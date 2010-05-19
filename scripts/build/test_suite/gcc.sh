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

    CT_DoExecLog ALL mkdir -p "${CT_TEST_SUITE_DIR}/gcc-test-suite/gcc-${CT_CC_VERSION}/gcc"
    CT_DoExecLog ALL cp "${CT_TOP_DIR}/contrib/gcc-test-suite/Makefile" \
                        "${CT_TEST_SUITE_DIR}/gcc-test-suite"
    CT_DoExecLog ALL cp "${CT_TOP_DIR}/contrib/gcc-test-suite/default.cfg" \
                        "${CT_TEST_SUITE_DIR}/gcc-test-suite"
    CT_DoExecLog ALL cp "${CT_TOP_DIR}/contrib/gcc-test-suite/README" \
                        "${CT_TEST_SUITE_DIR}/gcc-test-suite"
    CT_DoExecLog ALL cp -r "${CT_SRC_DIR}/gcc-${CT_CC_VERSION}/gcc/testsuite" \
                           "${CT_TEST_SUITE_DIR}/gcc-test-suite/gcc-${CT_CC_VERSION}/gcc"
    sed "s/DG_GCC_VERSION .*/DG_GCC_VERSION = ${CT_CC_VERSION}/g" \
        ${CT_TEST_SUITE_DIR}/gcc-test-suite/default.cfg > \
        ${CT_TEST_SUITE_DIR}/gcc-test-suite/default.cfg.tmp
    sed "s/DG_TARGET .*/DG_TARGET = ${CT_TARGET}/g" \
        ${CT_TEST_SUITE_DIR}/gcc-test-suite/default.cfg.tmp > \
        ${CT_TEST_SUITE_DIR}/gcc-test-suite/default.cfg
    CT_DoExecLog ALL rm -f "${CT_TEST_SUITE_DIR}/gcc-test-suite/default.cfg.tmp"
    CT_EndStep
}

fi # CT_TEST_SUITE_GCC
