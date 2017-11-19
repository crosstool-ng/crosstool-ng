# Parses all samples on the command line, and for each of them, prints
# the versions of the main tools

# Use tools discovered by ./configure
. "${CT_LIB_DIR}/paths.sh"
. "${CT_LIB_DIR}/scripts/functions"

[ "$1" = "-v" ] && opt="$1" && shift
[ "$1" = "-w" ] && opt="$1" && shift
[ "$1" = "-W" ] && opt="$1" && shift

# GREP_OPTIONS screws things up.
export GREP_OPTIONS=

# Dummy version which is invoked from .config
CT_Mirrors() { :; }

# Dump a short package description with a name and version in a format
# " <name>[-<version>]"
dump_pkg_desc() {
    local name=$1
    local show_version

    CT_GetPkgBuildVersion ${1} show_version
    printf " %s" "${show_version}"
}

# Dump a single sample
# Note: we use the specific .config.sample config file
dump_single_sample() {
    local verbose=0
    local wiki=0
    local complibs
    [ "$1" = "-v" ] && verbose=1 && shift
    [ "$1" = "-w" ] && wiki=1 && shift
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
    if [ ${wiki} -eq 0 ]; then
        width=14
        printf "[%s" "${sample_type}"
        [ -f "${sample_top}/samples/${sample}/broken" ] && printf "B" || printf "."
        [ "${CT_EXPERIMENTAL}" = "y" ] && printf "X" || printf "."
        printf "]   %s\n" "${sample}"
        if [ ${verbose} -ne 0 ]; then
            case "${CT_TOOLCHAIN_TYPE}" in
                cross)  ;;
                canadian)
                    printf "    %-*s : %s\n" ${width} "Host" "${CT_HOST}"
                    ;;
            esac
            if [ "${CT_KERNEL}" != "bare-metal" ]; then
                printf "    %-*s :" ${width} "OS" && dump_pkg_desc KERNEL && printf "\n"
            fi
            printf "    %-*s :" ${width} "Companion libs"
            [ -z "${CT_GMP}"     ] || dump_pkg_desc GMP
            [ -z "${CT_MPFR}"    ] || dump_pkg_desc MPFR
            [ -z "${CT_ISL}"     ] || dump_pkg_desc ISL
            [ -z "${CT_CLOOG}"   ] || dump_pkg_desc CLOOG
            [ -z "${CT_MPC}"     ] || dump_pkg_desc MPC
            [ -z "${CT_LIBELF}"  -a -z "${CT_LIBELF_TARGET}"  ] || dump_pkg_desc LIBELF
            [ -z "${CT_EXPAT}"   -a -z "${CT_EXPAT_TARGET}"   ] || dump_pkg_desc EXPAT
            [ -z "${CT_NCURSES}" -a -z "${CT_NCURSES_TARGET}" ] || dump_pkg_desc NCURSES
            printf "\n"
            printf "    %-*s :" ${width} "Binutils"  && dump_pkg_desc BINUTILS && printf "\n"
            printf "    %-*s :" ${width} "Compilers" && dump_pkg_desc CC && printf "\n"
            printf "    %-*s : %s" ${width} "Languages" "C"
            [ "${CT_CC_LANG_CXX}" = "y"     ] && printf ",C++"
            [ "${CT_CC_LANG_FORTRAN}" = "y" ] && printf ",Fortran"
            [ "${CT_CC_LANG_JAVA}" = "y"    ] && printf ",Java"
            [ "${CT_CC_LANG_ADA}" = "y"     ] && printf ",ADA"
            [ "${CT_CC_LANG_OBJC}" = "y"    ] && printf ",Objective-C"
            [ "${CT_CC_LANG_OBJCXX}" = "y"  ] && printf ",Objective-C++"
            [ "${CT_CC_LANG_GOLANG}" = "y"  ] && printf ",Go"
            [ -n "${CT_CC_LANG_OTHERS}"     ] && printf ",${CT_CC_LANG_OTHERS}"
            printf "\n"
            printf  "    %-*s :" ${width} "C library" && dump_pkg_desc LIBC && printf " (threads: %s)\n" "${CT_THREADS}"
            printf  "    %-*s :" ${width} "Tools"
            [ "${CT_DEBUG_DUMA}"   ] && dump_pkg_desc DUMA
            [ "${CT_DEBUG_GDB}"    ] && dump_pkg_desc GDB
            [ "${CT_DEBUG_LTRACE}" ] && dump_pkg_desc LTRACE
            [ "${CT_DEBUG_STRACE}" ] && dump_pkg_desc STRACE
            printf "\n"
        fi
    else
        case "${CT_TOOLCHAIN_TYPE}" in
            cross)
                printf "| ''${sample}''  | "
                ;;
            canadian)
                printf "| ''"
                printf "${sample}" |${sed} -r -e 's/.*,//'
                printf "''  | ${CT_HOST}  "
                ;;
            *)          ;;
        esac
        printf "|  "
        [ "${CT_EXPERIMENTAL}" = "y" ] && printf "**X**"
        [ -f "${sample_top}/samples/${sample}/broken" ] && printf "**B**"
        printf "  |  ''${CT_KERNEL}''  |"
        if [ "${CT_KERNEL}" != "bare-metal" ];then
            if [ "${CT_KERNEL_LINUX_HEADERS_USE_CUSTOM_DIR}" = "y" ]; then
                printf "  //custom//  "
            else
                printf "  " && dump_pkg_version "${CT_KERNEL}" && printf "  "
            fi
        fi
        printf "|  " && dump_pkg_version "binutils" && printf "  "
        printf "|  ${CT_CC}  |  " && dump_pkg_version "${CT_CC}" && printf "  "
        printf "|  ''${libc_name}''  |"
        if [ "${libc_name}" != "none" ]; then
            printf "  ${libc_ver}  "
        fi
        printf "|  ${CT_THREADS:-none}  "
        printf "|  ${CT_ARCH_FLOAT}  "
        printf "|  C"
        [ "${CT_CC_LANG_CXX}" = "y"     ] && printf ", C++"
        [ "${CT_CC_LANG_FORTRAN}" = "y" ] && printf ", Fortran"
        [ "${CT_CC_LANG_JAVA}" = "y"    ] && printf ", Java"
        [ "${CT_CC_LANG_ADA}" = "y"     ] && printf ", ADA"
        [ "${CT_CC_LANG_OBJC}" = "y"    ] && printf ", Objective-C"
        [ "${CT_CC_LANG_OBJCXX}" = "y"  ] && printf ", Objective-C++"
        [ -n "${CT_CC_LANG_OTHERS}"     ] && printf "\\\\\\\\ Others: ${CT_CC_LANG_OTHERS}"
        printf "  "
        ( . "${sample_top}/samples/${sample}/reported.by"
          if [ -n "${reporter_name}" ]; then
              if [ -n "${reporter_url}" ]; then
                  printf "|  [[${reporter_url}|${reporter_name}]]  "
              else
                  printf "|  ${reporter_name}  "
              fi
          else
              printf "|  (//unknown//)  "
          fi
        )
        sample_updated="$( git log -n1 --pretty=format:'%ci' "${sample_top}/samples/${sample}" \
                           |${awk} '{ print $1; }' )"
        printf "|  ${sample_updated}  "
        echo "|"
    fi
}

if [ "${opt}" = "-w" -a ${#} -eq 0 ]; then
    printf "^ %s  |||||||||||||||\n" "$( date "+%Y%m%d.%H%M %z" )"
    printf "^ Target  "
    printf "^ Host  "
    printf "^  Status  "
    printf "^  Kernel headers\\\\\\\\ version  ^"
    printf "^  binutils\\\\\\\\ version  "
    printf "^  C compiler\\\\\\\\ version  ^"
    printf "^  C library\\\\\\\\ version  ^"
    printf "^  Threading\\\\\\\\ model  "
    printf "^  Floating point\\\\\\\\ support  "
    printf "^  Languages  "
    printf "^  Initially\\\\\\\\ reported by  "
    printf "^  Last\\\\\\\\ updated  "
    echo   "^"
    exit 0
elif [ "${opt}" = "-W" ]; then
    printf "^ Total: ${#} samples  || **X**: sample uses features marked as being EXPERIMENTAL.\\\\\\\\ **B**: sample is currently BROKEN. |||||||||||||"
    echo   ""
    exit 0
fi

for sample in "${@}"; do
    dump_single_sample ${opt} "${sample}"
done
