# Parses all samples on the command line, and for each of them, prints
# the versions of the main tools

# Use tools discovered by ./configure
. "${CT_LIB_DIR}/paths.sh"
. "${CT_LIB_DIR}/scripts/functions"

[ "$1" = "-v" ] && opt="$1" && shift

# GREP_OPTIONS screws things up.
export GREP_OPTIONS=

fieldwidth=15

# Dummy version which is invoked from .config
CT_Mirrors() { :; }

# Dump a short package description with a name and version in a format
# " <name>[-<version>]"
dump_pkgs_desc()
{
    local category="${1}"
    local field="${2}"
    shift 2
    local show_version
    local tmp

    printf "    %-*s :" ${fieldwidth} "${field}"
    while [ -n "${1}" ]; do
        eval "tmp=\"\${CT_${category}_${1}}\""
        if [ -n "${tmp}" ]; then
            CT_GetPkgBuildVersion "${category}" "${1}" show_version
            printf " %s" "${show_version}"
        fi
        shift
    done
    printf "\n"
}

# Dump a short package description with a name and version in a format
# " <name>[-<version>]"
dump_choice_desc()
{
    local category="${1}"
    local field="${2}"
    local show_version

    CT_GetChoicePkgBuildVersion "${category}" show_version
    printf "    %-*s : %s\n" ${fieldwidth} "${field}" "${show_version}"
}

# Dump a single sample
# Note: we use the specific .config.sample config file
dump_single_sample()
{
    local verbose=0
    local complibs
    [ "$1" = "-v" ] && verbose=1 && shift
    local sample="$1"
    . $(pwd)/.config.sample

    case "${sample}" in
        current)
            sample_type="l"
            sample="$( ${CT_NG} show-tuple )"
            case "${CT_TOOLCHAIN_TYPE}" in
                canadian)
                    sample="${CT_HOST},${sample}"
                    ;;
            esac
            ;;
        *)  if [ -f "${CT_TOP_DIR}/samples/${sample}/crosstool.config" ]; then
                sample_top="${CT_TOP_DIR}"
                sample_type="L"
            else
                sample_top="${CT_LIB_DIR}"
                sample_type="G"
            fi
            ;;
    esac
    printf "[%s" "${sample_type}"
    [ -f "${sample_top}/samples/${sample}/broken" ] && printf "B" || printf "."
    [ "${CT_EXPERIMENTAL}" = "y" ] && printf "X" || printf "."
    printf "]   %s\n" "${sample}"
    if [ ${verbose} -ne 0 ]; then
        case "${CT_TOOLCHAIN_TYPE}" in
            cross)  ;;
            canadian)
                printf "    %-*s : %s\n" ${fieldwidth} "Host" "${CT_HOST}"
                ;;
        esac
        # FIXME get choice/menu names from generated kconfig files as well
        # FIXME get the list of menu components from generated kconfig files
        dump_choice_desc KERNEL "OS"
        dump_pkgs_desc COMP_LIBS "Companion libs" GMP MPFR MPC ISL CLOOG LIBELF EXPAT NCURSES \
                LIBICONV GETTEXT
        dump_choice_desc BINUTILS "Binutils"
        dump_choice_desc CC "Compiler"
        printf "    %-*s : %s" ${fieldwidth} "Languages" "C"
        [ "${CT_CC_LANG_CXX}" = "y"     ] && printf ",C++"
        [ "${CT_CC_LANG_FORTRAN}" = "y" ] && printf ",Fortran"
        [ "${CT_CC_LANG_JAVA}" = "y"    ] && printf ",Java"
        [ "${CT_CC_LANG_ADA}" = "y"     ] && printf ",ADA"
        [ "${CT_CC_LANG_OBJC}" = "y"    ] && printf ",Objective-C"
        [ "${CT_CC_LANG_OBJCXX}" = "y"  ] && printf ",Objective-C++"
        [ "${CT_CC_LANG_GOLANG}" = "y"  ] && printf ",Go"
        [ -n "${CT_CC_LANG_OTHERS}"     ] && printf ",${CT_CC_LANG_OTHERS}"
        printf "\n"

        dump_choice_desc LIBC "C library"
        dump_pkgs_desc DEBUG "Debug tools" DUMA GDB LTRACE STRACE
        dump_pkgs_desc COMP_TOOLS "Companion tools" AUTOCONF AUTOMAKE LIBTOOL M4 MAKE
    fi
}

for sample in "${@}"; do
    dump_single_sample ${opt} "${sample}"
done
