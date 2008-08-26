# eglibc build functions (initially by Thomas JOURDAN).

do_print_filename() {
    [ "${CT_LIBC}" = "eglibc" ] || return 0
    echo "eglibc-${CT_LIBC_VERSION}"
    for addon in $(do_libc_add_ons_list " "); do
        # NPTL addon is not to be downloaded, in any case
        [ "${addon}" = "nptl" ] && continue || true
        echo "eglibc-${addon}-${CT_LIBC_VERSION}"
    done
}

# Download eglibc repository
do_eglibc_get() {
    CT_HasOrAbort svn

    case "${CT_LIBC_VERSION}" in
        trunk)  svn_url="svn://svn.eglibc.org/trunk";;
        *)      svn_url="svn://svn.eglibc.org/branches/eglibc-${CT_LIBC_VERSION}";;
    esac

    CT_MktempDir tmp_dir
    CT_Pushd "${tmp_dir}"

    case "${CT_EGLIBC_CHECKOUT}" in
        y)  svn_action="checkout";;
        *)  svn_action="export --force";;
    esac

    CT_DoSetProxy ${CT_PROXY_TYPE}
    CT_DoExecLog ALL svn ${svn_action} -r "${CT_EGLIBC_REVISION:-HEAD}" "${svn_url}" . 2>&1

    # Compress eglibc
    CT_DoExecLog ALL mv libc "${CT_LIBC_FILE}"
    CT_DoExecLog ALL tar cjf "${CT_TARBALLS_DIR}/${CT_LIBC_FILE}.tar.bz2" "${CT_LIBC_FILE}"

    # Compress linuxthreads, localedef and ports
    # Assign them the name the way ct-ng like it
    for addon in linuxthreads localedef ports; do
        CT_DoExecLog ALL tar cjf "${CT_TARBALLS_DIR}/${CT_LIBC}-${addon}-${CT_LIBC_VERSION}.tar.bz2" "${addon}"
    done

    CT_Popd

    # Remove source files
    CT_DoExecLog ALL rm -rf "${tmp_dir}"
}

# Download glibc
do_libc_get() {
    # eglibc is only available through subversion, there are no
    # snapshots available. Moreover, addons will be downloaded
    # simultaneously.

    # build filename
    eglibc="${CT_LIBC_FILE}.tar.bz2"
    eglibc_linuxthreads="${CT_LIBC}-linuxthreads-${CT_LIBC_VERSION}.tar.bz2"
    eglibc_localedef="${CT_LIBC}-localedef-${CT_LIBC_VERSION}.tar.bz2"
    eglibc_ports="${CT_LIBC}-ports-${CT_LIBC_VERSION}.tar.bz2"

    # Check if every tarballs are already present
    if [ -a "${CT_TARBALLS_DIR}/${eglibc}" ]              && \
       [ -a "${CT_TARBALLS_DIR}/${eglibc_linuxthreads}" ] && \
       [ -a "${CT_TARBALLS_DIR}/${eglibc_localedef}" ]    && \
       [ -a "${CT_TARBALLS_DIR}/${eglibc_ports}" ]; then
        CT_DoLog DEBUG "Already have 'eglibc-${CT_LIBC_VERSION}'"
        return 0
    fi

    if [ -a "${CT_LOCAL_TARBALLS_DIR}/${eglibc}" ]              && \
       [ -a "${CT_LOCAL_TARBALLS_DIR}/${eglibc_linuxthreads}" ] && \
       [ -a "${CT_LOCAL_TARBALLS_DIR}/${eglibc_localedef}" ]    && \
       [ -a "${CT_LOCAL_TARBALLS_DIR}/${eglibc_ports}" ]        && \
       [ "${CT_FORCE_DOWNLOAD}" != "y" ]; then
        CT_DoLog DEBUG "Got 'eglibc-${CT_LIBC_VERSION}' from local storage"
        for file in ${eglibc} ${eglibc_linuxthreads} ${eglibc_localedef} ${eglibc_ports}; do
            CT_DoExecLog ALL ln -s "${CT_LOCAL_TARBALLS_DIR}/${file}" "${CT_TARBALLS_DIR}/${file}"
        done
        return 0
    fi

    # Not found locally, try from the network
    CT_DoLog EXTRA "Retrieving 'eglibc-${CT_LIBC_VERSION}'"
    do_eglibc_get

    if [ "${CT_SAVE_TARBALLS}" = "y" ]; then
        CT_DoLog EXTRA "Saving 'eglibc-${CT_LIBC_VERSION}' to local storage"
        for file in ${eglibc} ${eglibc_linuxthreads} ${eglibc_localedef} ${eglibc_ports}; do
            CT_DoExecLog ALL mv -f "${CT_TARBALLS_DIR}/${file}" "${CT_LOCAL_TARBALLS_DIR}"
            CT_DoExecLog ALL ln -s "${CT_LOCAL_TARBALLS_DIR}/${file}" "${CT_TARBALLS_DIR}/${file}"
        done
    fi

    return 0
}

# Extract eglibc
do_libc_extract() {
    CT_ExtractAndPatch "${CT_LIBC_FILE}"

    # C library addons
    for addon in $(do_libc_add_ons_list " "); do
        # NPTL addon is not to be extracted, in any case
        [ "${addon}" = "nptl" ] && continue || true
        CT_ExtractAndPatch "${CT_LIBC}-${addon}-${CT_LIBC_VERSION}"
    done

    return 0
}

# There is nothing to do for eglibc check config
do_libc_check_config() {
    :
}

# This function installs the glibc headers needed to build the core compiler
do_libc_headers() {
    # Instead of doing two time the same actions, headers will
    # be installed with start files
    :
}

# Build and install start files
do_libc_start_files() {
    CT_DoStep INFO "Installing C library headers / start files"

    mkdir -p "${CT_BUILD_DIR}/build-libc-startfiles"
    cd "${CT_BUILD_DIR}/build-libc-startfiles"

    CT_DoLog EXTRA "Configuring C library"

    cross_cc=$(CT_Which "${CT_TARGET}-gcc")
    cross_cxx=$(CT_Which "${CT_TARGET}-g++")
    cross_ar=$(CT_Which "${CT_TARGET}-ar")
    cross_ranlib=$(CT_Which "${CT_TARGET}-ranlib")
    
    CT_DoLog DEBUG "Using gcc for target: '${cross_cc}'"
    CT_DoLog DEBUG "Using g++ for target: '${cross_cxx}'"
    CT_DoLog DEBUG "Using ar for target: '${cross_ar}'"
    CT_DoLog DEBUG "Using ranlib for target: '${cross_ranlib}'"

    BUILD_CC=${CT_CC_NATIVE}                    \
    CC=${cross_cc}                              \
    CXX=${cross_cxx}                            \
    AR=${cross_ar}                              \
    RANLIB=${cross_ranlib}                      \
    CT_DoExecLog ALL                            \
    "${CT_SRC_DIR}/${CT_LIBC_FILE}/configure"   \
        --prefix=/usr                           \
        --with-headers="${CT_HEADERS_DIR}"      \
        --build="${CT_UNIQ_BUILD}"              \
        --host="${CT_TARGET}"                   \
        --disable-profile                       \
        --without-gd                            \
        --without-cvs                           \
        --enable-add-ons

    CT_DoLog EXTRA "Installing C library headers"

    # use the 'install-headers' makefile target to install the
    # headers

    CT_DoExecLog ALL                    \
    make install-headers                \
         install_root=${CT_SYSROOT_DIR} \
         install-bootstrap-headers=yes

    CT_DoLog EXTRA "Installing C library start files"

    # there are a few object files needed to link shared libraries,
    # which we build and install by hand

    CT_DoExecLog ALL mkdir -p ${CT_SYSROOT_DIR}/usr/lib
    CT_DoExecLog ALL make csu/subdir_lib
    CT_DoExecLog ALL cp csu/crt1.o csu/crti.o csu/crtn.o \
        ${CT_SYSROOT_DIR}/usr/lib

    # Finally, 'libgcc_s.so' requires a 'libc.so' to link against.  
    # However, since we will never actually execute its code, 
    # it doesn't matter what it contains.  So, treating '/dev/null' 
    # as a C source file, we produce a dummy 'libc.so' in one step

    CT_DoExecLog ALL ${cross_cc} -nostdlib -nostartfiles -shared -x c /dev/null -o ${CT_SYSROOT_DIR}/usr/lib/libc.so

    CT_EndStep
}

# This function builds and install the full glibc
do_libc() {
    CT_DoStep INFO "Installing C library"

    mkdir -p "${CT_BUILD_DIR}/build-libc"
    cd "${CT_BUILD_DIR}/build-libc"

    CT_DoLog EXTRA "Configuring C library"

    # Add some default glibc config options if not given by user.
    # We don't need to be conditional on wether the user did set different
    # values, as they CT_LIBC_GLIBC_EXTRA_CONFIG is passed after extra_config

    extra_config="--enable-kernel=$(echo ${CT_KERNEL_VERSION} |sed -r -e 's/^([^.]+\.[^.]+\.[^.]+)(|\.[^.]+)$/\1/;')"

    case "${CT_THREADS}" in
        nptl)           extra_config="${extra_config} --with-__thread --with-tls";;
        linuxthreads)   extra_config="${extra_config} --with-__thread --without-tls --without-nptl";;
        none)           extra_config="${extra_config} --without-__thread --without-nptl"
                        case "${CT_LIBC_GLIBC_EXTRA_CONFIG}" in
                            *-tls*) ;;
                            *) extra_config="${extra_config} --without-tls";;
                        esac
                        ;;
    esac

    case "${CT_SHARED_LIBS}" in
        y) extra_config="${extra_config} --enable-shared";;
        *) extra_config="${extra_config} --disable-shared";;
    esac

    case "${CT_ARCH_FLOAT_HW},${CT_ARCH_FLOAT_SW}" in
        y,) extra_config="${extra_config} --with-fp";;
        ,y) extra_config="${extra_config} --without-fp";;
    esac

    case "$(do_libc_add_ons_list ,)" in
        "") ;;
        *)  extra_config="${extra_config} --enable-add-ons=$(do_libc_add_ons_list ,)";;
    esac

    extra_cc_args="${extra_cc_args} ${CT_ARCH_ENDIAN_OPT}"

    cross_cc=$(CT_Which "${CT_TARGET}-gcc")    

    CT_DoLog DEBUG "Using gcc for target:     '${cross_cc}'"
    CT_DoLog DEBUG "Configuring with addons : '$(do_libc_add_ons_list ,)'"
    CT_DoLog DEBUG "Extra config args passed: '${extra_config}'"
    CT_DoLog DEBUG "Extra CC args passed    : '${extra_cc_args}'"

    BUILD_CC=${CT_CC_NATIVE}                                        \
    CFLAGS="${CT_TARGET_CFLAGS} ${CT_LIBC_GLIBC_EXTRA_CFLAGS} -O"   \
    CC="${CT_TARGET}-gcc ${CT_LIBC_EXTRA_CC_ARGS} ${extra_cc_args}" \
    AR=${CT_TARGET}-ar                                              \
    RANLIB=${CT_TARGET}-ranlib                                      \
    CT_DoExecLog ALL                                                \
    "${CT_SRC_DIR}/${CT_LIBC_FILE}/configure"                       \
        --prefix=/usr                                               \
        --with-headers="${CT_HEADERS_DIR}"                          \
        --build=${CT_UNIQ_BUILD}                                    \
        --host=${CT_TARGET}                                         \
        --disable-profile                                           \
        --without-gd                                                \
        --without-cvs                                               \
        ${extra_config}                                             \
        ${CT_LIBC_GLIBC_EXTRA_CONFIG}
    
    CT_DoLog EXTRA "Building C library"

    CT_DoExecLog ALL make

    CT_DoLog EXTRA "Installing C library"

    CT_DoExecLog ALL make install install_root="${CT_SYSROOT_DIR}"

    CT_EndStep
}

# This function finishes the glibc install
do_libc_finish() {
    # Nothing to be done for eglibc
    :
}

# Build up the addons list, separated with $1
do_libc_add_ons_list() {
    local sep="$1"
    local addons_list=$(echo "${CT_LIBC_ADDONS_LIST//,/${sep}}" |tr -s ,)
    case "${CT_THREADS}" in
        none)   ;;
        *)      addons_list="${addons_list}${sep}${CT_THREADS}";;
    esac
    [ "${CT_LIBC_GLIBC_USE_PORTS}" = "y" ] && addons_list="${addons_list}${sep}ports"
    addons_list="${addons_list%%${sep}}"
    echo "${addons_list##${sep}}"
}
