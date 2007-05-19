#!/bin/sh

# Adds a new version to one of the toolchain component
myname="$0"

doHelp() {
    cat <<-EOF
Usage: ${myname} <tool> [option] <version>
  'tool' in one of:
    --gcc, --binutils, --glibc, --uClibc, --linux,
    --gdb, --dmalloc

  Valid options for all tools:
    --experimental, -x
      mark the version as being experimental

    --obsolete, -o
      mark the version as being obsolete

  Valid mandatory 'option' for tool==gcc is one and only one of:
    --core, --final

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
CORE=
FINAL=
VERSION=
EXP=
OBS=

i=1
while [ $i -le $# ]; do
    case "${!i}" in
        # Tools:
        --gcc)              cat=CC;        tool=gcc;      tool_prefix=cc_;      tool_suffix=;;
        --binutils)         cat=BINUTILS;  tool=binutils; tool_prefix=;         tool_suffix=;;
        --glibc)            cat=LIBC;      tool=glibc;    tool_prefix=libc_;    tool_suffix=;;
        --uClibc)           cat=LIBC;      tool=uClibc;   tool_prefix=libc_;    tool_suffix=;;
        --linux)            cat=KERNEL;    tool=linux;    tool_prefix=kernel_;  tool_suffix=;;
        --gdb)              cat=GDB;       tool=gdb;      tool_prefix=debug/    tool_suffix=;;
        --dmalloc)          cat=DMALLOC;   tool=dmalloc;  tool_prefix=debug/    tool_suffix=;;
        # Tools options:
        -x|--experimental)  EXP=1; OBS=;;
        -o|--obsolete)      OBS=1; EXP=;;
        --core)             CORE=1; FINAL=;;
        --final)            FINAL=1; CORE=;;
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
    CC)     [    -z "${CORE}" -a -z "${FINAL}" ] && { doHelp; exit 1; };;
    KERNEL) unset FINAL CORE
            [ -z "${tool_suffix}" ] && { doHelp; exit 1; }
            ;;
    *)      CORE=; FINAL=;;
esac

MIDDLE_V=; MIDDLE_F=
[ -n "${CORE}" ] && MIDDLE_V="_CORE" && MIDDLE_F="core_"
for ver in ${VERSION}; do
    unset DEP L1 L2 L3 L4 L5 FILE
    v=`echo "${ver}" |sed -r -e 's/-/_/g; s/\./_/g;'`
    if [ "${cat}" = "KERNEL" ]; then
        TOOL_SUFFIX="`echo \"${tool_suffix}\" |tr [[:lower:]] [[:upper:]]`"
        L1="config ${cat}_${TOOL_SUFFIX}_V_${v}\n"
        L2="    bool\n"
        L3="    prompt \"${ver}\"\n"
        # Extra versions are not necessary visible:
        case "${tool_suffix},${ver}" in
            sanitised,*)    ;; # Sanitised headers always have an extra version
            *,*.*.*.*)      DEP="${DEP} && KERNEL_VERSION_SEE_EXTRAVERSION";;
        esac
        L5="    default \"${ver}\" if ${cat}_${TOOL_SUFFIX}_V_${v}"
        FILE="config/${tool_prefix}${tool}_headers_${tool_suffix}.in"
    else
        L1="config ${cat}${MIDDLE_V}_V_${v}\n"
        L2="    bool\n"
        L3="    prompt \"${ver}\"\n"
        L5="    default \"${ver}\" if ${cat}${MIDDLE_V}_V_${v}"
        FILE="config/${tool_prefix}${MIDDLE_F}${tool}.in"
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
