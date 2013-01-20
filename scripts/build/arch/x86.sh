# Compute x86-specific values

# This one really needs a little love! :-(

CT_DoArchTupleValues() {
    # Override the architecture part of the tuple:
    if [ "${CT_ARCH_64}" = "y" ]; then
        CT_TARGET_ARCH=x86_64
    else
        arch="${CT_ARCH_ARCH}"
        [ -z "${arch}" ] && arch="${CT_ARCH_TUNE}"
        case "${arch}" in
            "")                           CT_TARGET_ARCH=i386;;
            i386|i486|i586|i686)          CT_TARGET_ARCH="${arch}";;
            winchip*)                     CT_TARGET_ARCH=i486;;
            pentium|pentium-mmx|c3*)      CT_TARGET_ARCH=i586;;
            pentiumpro|pentium*|athlon*)  CT_TARGET_ARCH=i686;;
            prescott)                     CT_TARGET_ARCH=i686;;
            *)                            CT_TARGET_ARCH=i586;;
        esac
    fi
    CT_TARGET_ARCH="${CT_TARGET_ARCH}${CT_ARCH_SUFFIX}"
}
