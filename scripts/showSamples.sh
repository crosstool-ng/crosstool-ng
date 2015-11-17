#!/bin/sh
# Yes, this is supposed to be a POSIX-compliant shell script.

# Parses all samples on the command line, and for each of them, prints
# the versions of the main tools

# Use tools discovered by ./configure
. "${CT_LIB_DIR}/paths.sh"

[ "$1" = "-v" ] && opt="$1" && shift
[ "$1" = "-w" ] && opt="$1" && shift
[ "$1" = "-W" ] && opt="$1" && shift

# GREP_OPTIONS screws things up.
export GREP_OPTIONS=

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

    # libc needs some love
    local libc_name="${CT_LIBC}"
    local libc_ver="${CT_LIBC_VERSION}"
    if [ "${CT_LIBC}" = "uClibc" -a "${CT_LIBC_UCLIBC_NG}" = "y" ]; then
        libc_name="uClibc-ng"
    elif [ "${CT_LIBC}" = "mingw" ]; then
        libc_ver="${CT_WINAPI_VERSION}"
    fi

    case "${sample}" in
        current)
            sample_type="l"
            sample="$( ${CT_NG} show-tuple )"
            case "${CT_TOOLCHAIN_TYPE}" in
                canadian)
                    sample="${CT_HOST},$sample"
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
            printf "    %-*s : %s\n" ${width} "OS" "${CT_KERNEL}${CT_KERNEL_VERSION:+-}${CT_KERNEL_VERSION}"
            if [    -n "${CT_GMP}"              \
                 -o -n "${CT_MPFR}"             \
                 -o -n "${CT_PPL}"              \
                 -o -n "${CT_CLOOG}"            \
                 -o -n "${CT_MPC}"              \
                 -o -n "${CT_LIBELF}"           \
                 -o -n "${CT_EXPAT}"            \
                 -o -n "${CT_NCURSES}"          \
                 -o -n "${CT_GMP_TARGET}"       \
                 -o -n "${CT_MPFR_TARGET}"      \
                 -o -n "${CT_PPL_TARGET}"       \
                 -o -n "${CT_CLOOG_TARGET}"     \
                 -o -n "${CT_MPC_TARGET}"       \
                 -o -n "${CT_LIBELF_TARGET}"    \
                 -o -n "${CT_EXPAT_TARGET}"     \
                 -o -n "${CT_NCURSES_TARGET}"   \
               ]; then
                printf "    %-*s :" ${width} "Companion libs"
                complibs=1
            fi
            [ -z "${CT_GMP}"     -a -z "${CT_GMP_TARGET}"     ] || printf " gmp-%s"       "${CT_GMP_VERSION}"
            [ -z "${CT_MPFR}"    -a -z "${CT_MPFR_TARGET}"    ] || printf " mpfr-%s"      "${CT_MPFR_VERSION}"
            [ -z "${CT_PPL}"     -a -z "${CT_PPL_TARGET}"     ] || printf " ppl-%s"       "${CT_PPL_VERSION}"
            [ -z "${CT_CLOOG}"   -a -z "${CT_CLOOG_TARGET}"   ] || printf " cloog-ppl-%s" "${CT_CLOOG_VERSION}"
            [ -z "${CT_MPC}"     -a -z "${CT_MPC_TARGET}"     ] || printf " mpc-%s"       "${CT_MPC_VERSION}"
            [ -z "${CT_LIBELF}"  -a -z "${CT_LIBELF_TARGET}"  ] || printf " libelf-%s"    "${CT_LIBELF_VERSION}"
            [ -z "${CT_EXPAT}"   -a -z "${CT_EXPAT_TARGET}"   ] || printf " expat-%s"     "${CT_EXPAT_VERSION}"
            [ -z "${CT_NCURSES}" -a -z "${CT_NCURSES_TARGET}" ] || printf " ncurses-%s"   "${CT_NCURSES_VERSION}"
            [ -z "${complibs}"  ] || printf "\n"
            printf  "    %-*s : %s\n" ${width} "binutils" "binutils-${CT_BINUTILS_VERSION}"
            printf  "    %-*s :" ${width} "C compilers"
            cc=$(echo ${CT_CC} | ${awk} '{ print toupper($0)}')
            version=$(eval echo \${CT_CC_${cc}_VERSION})
            compiler=$(echo $cc | ${awk} '{print tolower($0)}')
            printf " $compiler  |  $version"
            printf "\n"
            printf  "    %-*s : %s" ${width} "Languages" "C"
            [ "${CT_CC_LANG_CXX}" = "y"     ] && printf ",C++"
            [ "${CT_CC_LANG_FORTRAN}" = "y" ] && printf ",Fortran"
            [ "${CT_CC_LANG_JAVA}" = "y"    ] && printf ",Java"
            [ "${CT_CC_LANG_ADA}" = "y"     ] && printf ",ADA"
            [ "${CT_CC_LANG_OBJC}" = "y"    ] && printf ",Objective-C"
            [ "${CT_CC_LANG_OBJCXX}" = "y"  ] && printf ",Objective-C++"
            [ "${CT_CC_LANG_GOLANG}" = "y"  ] && printf ",Go"
            [ -n "${CT_CC_LANG_OTHERS}"     ] && printf ",${CT_CC_LANG_OTHERS}"
            printf "\n"
            printf  "    %-*s : %s (threads: %s)\n" ${width} "C library" "${libc_name}${libc_ver:+-}${libc_ver}" "${CT_THREADS}"
            printf  "    %-*s :" ${width} "Tools"
            [ "${CT_TOOL_sstrip}"   ] && printf " sstrip"
            [ "${CT_DEBUG_dmalloc}" ] && printf " dmalloc-${CT_DMALLOC_VERSION}"
            [ "${CT_DEBUG_duma}"    ] && printf " duma-${CT_DUMA_VERSION}"
            [ "${CT_DEBUG_gdb}"     ] && printf " gdb-${CT_GDB_VERSION}"
            [ "${CT_DEBUG_ltrace}"  ] && printf " ltrace-${CT_LTRACE_VERSION}"
            [ "${CT_DEBUG_strace}"  ] && printf " strace-${CT_STRACE_VERSION}"
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
                printf "  ${CT_KERNEL_VERSION}  "
            fi
        fi
        printf "|  ${CT_BINUTILS_VERSION}  "
        printf "| "
        cc=$(echo ${CT_CC} | ${awk} '{ print toupper($0)}')
        version=$(eval echo \${CT_CC_${cc}_VERSION})
        compiler=$(echo $cc | ${awk} '{print tolower($0)}')
        printf " $compiler  |  $version"
        printf "  "
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
    ( dump_single_sample ${opt} "${sample}" )
done
