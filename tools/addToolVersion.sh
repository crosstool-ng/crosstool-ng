#!/bin/sh

# Adds a new version to one of the toolchain component
myname="$0"

doHelp() {
    cat <<-EOF
Usage: ${myname} <tool> [option] <version>
  'tool' in one of:
    --gcc, --tcc, --binutils, --glibc, --uClibc, --linux, --cygwin

  Valid mandatory 'option' for tool==gcc is one of:
    --core, --final

  Valid mandatory 'option' for tool==linux is one of:
    --install, --sanitised, --copy

  'version' is a valid version for the specified tool.

  Examples:
    add version 2.6.19.2 to linux kernel install method:
      ${myname} --linux --install 2.6.19.2

    add versions 2.3.5 and 2.3.6 to glibc:
      ${myname} --glibc 2.3.5 2.3.6
EOF
}

tool=
tool_prefix=
CORE=
FINAL=
VERSION=

i=1
while [ $i -le $# ]; do
    case "${!i}" in
        --gcc)          cat=CC;        tool=gcc;      tool_prefix=cc_;      tool_suffix=;;
#        --tcc)          cat=CC;        tool=tcc;      tool_prefix=cc_;      tool_suffix=;;
        --binutils)     cat=BINUTILS;  tool=binutils; tool_prefix=;         tool_suffix=;;
        --glibc)        cat=LIBC;      tool=glibc;    tool_prefix=libc_;    tool_suffix=;;
        --uClibc)       cat=LIBC;      tool=uClibc;   tool_prefix=libc_;    tool_suffix=;;
        --linux)        cat=KERNEL;    tool=linux;    tool_prefix=kernel_;;
#        --cygwin)       cat=KERNEL;    tool=cygwin;   tool_prefix=kernel_;;
        --core)         CORE=1;;
        --final)        FINAL=1;;
        --install)      tool_suffix=install;;
        --sanitised)    tool_suffix=sanitised;;
        --copy)         tool_suffix=copy;;
        -h|--help)      doHelp; exit 0;;
        -*)             echo "Unknown option: \"${!i}\". (use -h/--help for help"; exit 1;;
        *)              VERSION="${VERSION} ${!i}";;
    esac
    i=$((i+1))
done

[ -n "${tool}" -o -n "${VERSION}" ] || { doHelp; exit 1; }

case "${cat}" in
    CC)     [ -z "${CORE}" -a -z "${FINAL}" ] && { doHelp; exit 1; };;
    KERNEL) unset FINAL CORE
            [ -z "${tool_suffix}" ] && { doHelp; exit 1; }
            ;;
    *)      FINAL=1; CORE=;;
esac

for ver in ${VERSION}; do
	v=`echo "${ver}" |sed -r -e 's/-/_/g; s/\./_/g;'`
    if [ -n "${CORE}" ]; then
        L1="config ${cat}_CORE_V_${v}\n"
        L2="    bool\n"
        L3="    prompt \"${ver}\"\n"
        L4="    default \"${ver}\" if ${cat}_CORE_V_${v}"
        sed -r -i -e 's/^(# CT_INSERT_VERSION_ABOVE)$/'"${L1}${L2}${L3}"'\n\1/;
                      s/^(# CT_INSERT_VERSION_STRING_ABOVE)$/'"${L4}"'\n\1/;' config/${tool_prefix}core_${tool}.in
    fi
    if [ -n "${FINAL}" ]; then
        L1="config ${cat}_V_${v}\n"
        L2="    bool\n"
        L3="    prompt \"${ver}\"\n"
        L4="    default \"${ver}\" if ${cat}_V_${v}"
        sed -r -i -e 's/^(# CT_INSERT_VERSION_ABOVE)$/'"${L1}${L2}${L3}"'\n\1/;
                      s/^(# CT_INSERT_VERSION_STRING_ABOVE)$/'"${L4}"'\n\1/;' config/${tool_prefix}${tool}.in
    fi
    if [ "${cat}" = "KERNEL" ]; then
        TOOL_SUFFIX="`echo \"${tool_suffix}\" |tr [[:lower:]] [[:upper:]]`"
        L1="config ${cat}_${TOOL_SUFFIX}_V_${v}\n"
        L2="    bool\n"
        L3="    prompt \"${ver}\"\n"
        # Extra versions are not necessary visible:
        case "${ver}" in
            *.*.*.*) L4="    depends on KERNEL_VERSION_SEE_EXTRAVERSION\n";;
            *)       L4=;;
        esac
        # Sanitised headers always have an extra version:
        [ "${tool_suffix}" = "sanitised" ] && L4=
        L5="    default \"${ver}\" if ${cat}_${TOOL_SUFFIX}_V_${v}"
        sed -r -i -e 's/^(# CT_INSERT_VERSION_ABOVE)$/'"${L1}${L2}${L3}${L4}"'\n\1/;
                      s/^(# CT_INSERT_VERSION_STRING_ABOVE)$/'"${L5}"'\n\1/;' config/${tool_prefix}${tool}_headers_${tool_suffix}.in
    fi
done
