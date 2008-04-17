#!/bin/bash

# Adds a new version to one of the toolchain component
myname="$0"

doHelp() {
    cat <<-EOF
Usage: ${myname} <tool> [option] <version>
  'tool' in one of:
    --gcc, --binutils, --glibc, --uClibc, --linux,
    --gdb, --dmalloc, --duma, --strace, --ltrace, --libelf

  Valid options for all tools:
    --experimental, -x
      mark the version as being experimental

    --obsolete, -o
      mark the version as being obsolete

  Valid mandatory 'option' for tool==linux is one and only one of:
    --install, --sanitised, --copy

  'version' is a valid version for the specified tool.

  Examples:
    add version 2.6.19.2 to linux kernel install method:
      ${myname} --linux --install 2.6.19.2

    add versions 2.3.5 and 2.3.6 to glibc:
      ${myname} --glibc 2.3.5 2.3.6
EOF
}

cat=
tool=
tool_prefix=
tool_suffix=
VERSION=
EXP=
OBS=
prompt_suffix=

i=1
while [ $i -le $# ]; do
    case "${!i}" in
        # Tools:
        --gcc)              cat=CC;        tool=gcc;      tool_prefix=cc;      tool_suffix=;;
        --binutils)         cat=BINUTILS;  tool=binutils; tool_prefix=;        tool_suffix=;;
        --glibc)            cat=LIBC;      tool=glibc;    tool_prefix=libc;    tool_suffix=;;
        --uClibc)           cat=LIBC;      tool=uClibc;   tool_prefix=libc;    tool_suffix=;;
        --linux)            cat=KERNEL;    tool=linux;    tool_prefix=kernel;  tool_suffix=;;
        --gdb)              cat=GDB;       tool=gdb;      tool_prefix=debug    tool_suffix=;;
        --dmalloc)          cat=DMALLOC;   tool=dmalloc;  tool_prefix=debug    tool_suffix=;;
        --duma)             cat=DUMA;      tool=duma;     tool_prefix=debug    tool_suffix=;;
        --strace)           cat=STRACE;    tool=strace;   tool_prefix=debug    tool_suffix=;;
        --ltrace)           cat=LTRACE;    tool=ltrace;   tool_prefix=debug    tool_suffix=;;
        --libelf)           cat=LIBELF;    tool=libelf;   tool_prefix=tools    tool_suffix=;;
        # Tools options:
        -x|--experimental)  EXP=1; OBS=; prompt_suffix=" (EXPERIMENTAL)";;
        -o|--obsolete)      OBS=1; EXP=; prompt_suffix=" (OBSOLETE)";;
        --install)          tool_suffix=install;;
        --sanitised)        tool_suffix=sanitised;;
        --copy)             tool_suffix=copy;;
        # Misc:
        -h|--help)          doHelp; exit 0;;
        -*)                 echo "Unknown option: \"${!i}\". (use -h/--help for help"; exit 1;;
        *)                  VERSION="${VERSION} ${!i}";;
    esac
    i=$((i+1))
done

[ -n "${tool}" -o -n "${VERSION}" ] || { doHelp; exit 1; }

case "${cat}" in
    KERNEL) [ -z "${tool_suffix}" ] && { doHelp; exit 1; } ;;
    *)      ;;
esac

for ver in ${VERSION}; do
    unset DEP L1 L2 L3 L4 L5 FILE
    v=`echo "${ver}" |sed -r -e 's/-/_/g; s/\./_/g;'`
    if [ "${cat}" = "KERNEL" ]; then
        TOOL_SUFFIX="`echo \"${tool_suffix}\" |tr [[:lower:]] [[:upper:]]`"
        L1="config ${cat}_${TOOL_SUFFIX}_V_${v}\n"
        L2="    bool\n"
        L3="    prompt \"${ver}${prompt_suffix}\"\n"
        # Extra versions are not necessary visible:
        case "${tool_suffix},${ver}" in
            sanitised,*)    ;; # Sanitised headers always have an extra version
            *,*.*.*.*)      DEP="${DEP} && KERNEL_VERSION_SEE_EXTRAVERSION";;
        esac
        L5="    default \"${ver}\" if ${cat}_${TOOL_SUFFIX}_V_${v}"
        FILE="config/${tool_prefix}/${tool}_headers_${tool_suffix}.in"
    else
        L1="config ${cat}_V_${v}\n"
        L2="    bool\n"
        L3="    prompt \"${ver}${prompt_suffix}\"\n"
        L5="    default \"${ver}\" if ${cat}_V_${v}"
        FILE="config/${tool_prefix}/${tool}.in"
    fi
    [ -n "${EXP}" ] && DEP="${DEP} && EXPERIMENTAL"
    [ -n "${OBS}" ] && DEP="${DEP} && OBSOLETE"
    case "${DEP}" in
        "") ;;
        *)  L4="    depends on `echo \"${DEP}\" |sed -r -e 's/^ \\&\\& //; s/\\&/\\\\&/g;'`\n"
    esac
    sed -r -i -e 's/^(# CT_INSERT_VERSION_ABOVE)$/'"${L1}${L2}${L3}${L4}"'\n\1/;
                  s/^(# CT_INSERT_VERSION_STRING_ABOVE)$/'"${L5}"'\n\1/;' "${FILE}"
done
