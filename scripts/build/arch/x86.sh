# Compute x86-specific values

# This one really need a little love! :-(

CT_DoArchValues() {
    # The architecture part of the tuple:
    arch="${CT_ARCH_ARCH}"
    [ -z "${arch}" ] && arch="${CT_ARCH_TUNE}"
    case "${arch}" in
        nocona|athlon*64|k8|athlon-fx|opteron)
            CT_DoError "Architecture is x86 (32-bit) but selected processor is \"${arch}\" (64-bit)";;
        "")                           CT_TARGET_ARCH=i386;;
        i386|i486|i586|i686)          CT_TARGET_ARCH="${arch}";;
        winchip*)                     CT_TARGET_ARCH=i486;;
        pentium|pentium-mmx|c3*)      CT_TARGET_ARCH=i586;;
        pentiumpro|pentium*|athlon*)  CT_TARGET_ARCH=i686;;
        *)                            CT_TARGET_ARCH=i586;;
    esac

    # The kernel ARCH:
    CT_KERNEL_ARCH=i386
}
