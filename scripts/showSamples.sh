#!/bin/sh
# Yes, this is supposed to be a POSIX-compliant shell script.

# Parses all samples on the command line, and for each of them, prints
# the versions of the main tools

# Use tools discovered by ./configure
. "${CT_LIB_DIR}/paths.mk"

[ "$1" = "-v" ] && opt="$1" && shift
[ "$1" = "-w" ] && opt="$1" && shift

# GREP_OPTIONS screws things up.
export GREP_OPTIONS=

# Dump a single sample
dump_single_sample() {
    local verbose=0
    [ "$1" = "-v" ] && verbose=1 && shift
    [ "$1" = "-w" ] && wiki=1 && shift
    local width="$1"
    local sample="$2"
    if [ -f "${CT_TOP_DIR}/samples/${sample}/crosstool.config" ]; then
        sample_top="${CT_TOP_DIR}"
        sample_type="l"
    else
        sample_top="${CT_LIB_DIR}"
        sample_type="g"
    fi
    . "${sample_top}/samples/${sample}/crosstool.config"
    if [ -z "${wiki}" ]; then
        t_width=13
        printf "    %-*s  [%s" ${width} "${sample}" "${sample_type}"
        [ -f "${sample_top}/samples/${sample}/broken" ] && printf "B" || printf " "
        [ "${CT_EXPERIMENTAL}" = "y" ] && printf "X" || printf " "
        echo "]"
        if [ ${verbose} -ne 0 ]; then
            case "${CT_TOOLCHAIN_TYPE}" in
                cross)  ;;
                canadian)
                    printf "    %-*s : %s\n" ${t_width} "Host" "${CT_HOST}"
                    ;;
            esac
            printf "    %-*s : %s\n" ${t_width} "OS" "${CT_KERNEL}${CT_KERNEL_VERSION:+-}${CT_KERNEL_VERSION}"
            if [ "${CT_GMP_MPFR}" = "y" ]; then
                printf    "    %-*s : %s\n" ${t_width} "GMP/MPFR" "gmp-${CT_GMP_VERSION} / mpfr-${CT_MPFR_VERSION}"
            fi
            if [ "${CT_PPL_CLOOG_MPC}" = "y" ]; then
                printf    "    %-*s : %s\n" ${t_width} "PPL/CLOOG/MPC" "ppl-${CT_PPL_VERSION} / cloog-${CT_CLOOG_VERSION} / mpc-${CT_MPC_VERSION}"
            fi
            printf  "    %-*s : %s\n" ${t_width} "binutils" "binutils-${CT_BINUTILS_VERSION}"
            printf  "    %-*s : %s" ${t_width} "C compiler" "${CT_CC}-${CT_CC_VERSION} (C"
            [ "${CT_CC_LANG_CXX}" = "y"     ] && printf ",C++"
            [ "${CT_CC_LANG_FORTRAN}" = "y" ] && printf ",Fortran"
            [ "${CT_CC_LANG_JAVA}" = "y"    ] && printf ",Java"
            [ "${CT_CC_LANG_ADA}" = "y"     ] && printf ",ADA"
            [ "${CT_CC_LANG_OBJC}" = "y"    ] && printf ",Objective-C"
            [ "${CT_CC_LANG_OBJCXX}" = "y"  ] && printf ",Objective-C++"
            [ -n "${CT_CC_LANG_OTHERS}"     ] && printf ",${CT_CC_LANG_OTHERS}"
            printf ")\n"
            printf  "    %-*s : %s\n" ${t_width} "C library" "${CT_LIBC}${CT_LIBC_VERSION:+-}${CT_LIBC_VERSION}"
            printf  "    %-*s :" ${t_width} "Tools"
            [ "${CT_TOOL_libelf}"   ] && printf " libelf-${CT_LIBELF_VERSION}"
            [ "${CT_TOOL_sstrip}"   ] && printf " sstrip"
            [ "${CT_DEBUG_dmalloc}" ] && printf " dmalloc-${CT_DMALLOC_VERSION}"
            [ "${CT_DEBUG_duma}"    ] && printf " duma-${CT_DUMA_VERSION}"
            [ "${CT_DEBUG_gdb}"     ] && printf " gdb-${CT_GDB_VERSION}"
            [ "${CT_DEBUG_ltrace}"  ] && printf " ltrace-${CT_LTRACE_VERSION}"
            [ "${CT_DEBUG_strace}"  ] && printf " strace-${CT_STRACE_VERSION}"
            printf "\n"
        fi
    else
        printf "| ''${sample}''  "
        printf "|  "
        [ "${CT_EXPERIMENTAL}" = "y" ] && printf "X"
        [ -f "${sample_top}/samples/${sample}/broken" ] && printf "B"
        printf '  |  '
        case "${CT_TOOLCHAIN_TYPE}" in
            cross)      ;;
            canadian)   printf "${CT_HOST}";;
            *)          ;;
        esac
        printf "  |  ''${CT_KERNEL}''  |"
        if [ "${CT_KERNEL}" != "bare-metal" ];then
            if [ "${CT_KERNEL_LINUX_HEADERS_USE_CUSTOM_DIR}" = "y" ]; then
                printf "  //custom//  "
            else
                printf "  ${CT_KERNEL_VERSION}  "
            fi
        fi
        printf "|  ${CT_BINUTILS_VERSION}  "
        printf "|  ''${CT_CC}''  "
        printf "|  ${CT_CC_VERSION}  "
        printf "|  ''${CT_LIBC}''  |"
        if [ "${CT_LIBC}" != "none" ]; then
            printf "  ${CT_LIBC_VERSION}  "
        fi
        printf "|  ${CT_THREADS:-none}  "
        printf "|  ${CT_ARCH_FLOAT_HW:+hard}${CT_ARCH_FLOAT_SW:+soft} float  "
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
              printf "|  [[http://ymorin.is-a-geek.org/|YEM]]  "
          fi
        )
        sample_updated="$( hg log -l 1 --template '{date|shortdate}' "${sample_top}/samples/${sample}" )"
        printf "|  ${sample_updated}  "
        echo "|"
    fi
}

# Get largest sample width
width=0
for sample in "${@}"; do
    [ ${#sample} -gt ${width} ] && width=${#sample}
done

if [ "${opt}" = -w ]; then
    echo "^ @@DATE@@  ^ |||||||||||||"
    printf "^ Target "
    printf "^  Status  "
    printf "^  Host  "
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
fi

for sample in "${@}"; do
    ( dump_single_sample ${opt} ${width} "${sample}" )
done

if [ "${opt}" = -w ]; then
    printf "^ Total: ${#@} samples  | ''X'': sample uses features marked as being EXPERIMENTAL.\\\\\\\\ ''B'': sample is curently BROKEN. |||||||||||||"
    echo   ""
elif [ -z "${opt}" ]; then
    echo '      l (local)       : sample was found in current directory'
    echo '      g (global)      : sample was installed with crosstool-NG'
    echo '      X (EXPERIMENTAL): sample may use EXPERIMENTAL features'
    echo '      B (BROKEN)      : sample is currently broken'
fi
