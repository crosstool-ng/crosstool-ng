#!/bin/bash

########################################
# Common meta-language implementation

declare -A info

debug()
{
    if [ -n "${DEBUG}" ]; then
        echo "DEBUG :: $@" >&2
    fi
}

warn()
{
    echo "WARN  :: $@" >&2
}

error()
{
    echo "ERROR :: $@" >&2
    exit 1
}

find_end()
{
    local token="${1}"
    local count=1

    # Skip first line, we know it has the proper '#!' command on it
    endline=$[l + 1]
    while [ "${endline}" -le "${end}" ]; do
        case "${tlines[${endline}]}" in
            "#!${token} "*)
                count=$[count + 1]
                ;;
            "#!end-${token}")
                count=$[count - 1]
                ;;
        esac
        if [ "${count}" = 0 ]; then
            return
        fi
        endline=$[endline + 1]
    done
    error "line ${l}: '${token}' token is unpaired"
}

set_iter()
{
    local name="${1}"

    if [ "${info[iter_${name}]+set}" = "set" ]; then
        error "Iterator over '${name}' is already set up"
    fi
    shift
    debug "Setting iterator over '${name}' to '$*'"
    info[iter_${name}]="$*"
}

run_if()
{
    local cond="${1}"
    local endline

    find_end "if"
    if eval "${cond}"; then
        debug "True conditional '${cond}' at lines ${l}..${endline}"
        run_lines $[l + 1] $[endline - 1]
    else
        debug "False conditional '${cond}' at lines ${l}..${endline}"
    fi
    lnext=$[endline + 1]
    debug "Continue at line ${lnext}"
}

do_foreach()
{
    local var="${1}"
    local v saveinfo

    shift
    if [ "`type -t enter_${var}`" != "function" ]; then
        error "No parameter setup routine for iterator over '${var}'"
    fi
    for v in ${info[iter_${var}]}; do
        saveinfo=`declare -p info`
        eval "enter_${var} ${v}"
        eval "$@"
        eval "${saveinfo#declare -A }"
    done
}

run_foreach()
{
    local var="${1}"
    local endline

    if [ "${info[iter_${var}]+set}" != "set" ]; then
        error "line ${l}: iterator over '${var}' is not defined"
    fi
    find_end "foreach"
    debug "Loop over '${var}', lines ${l}..${endline}"
    do_foreach ${var} run_lines $[l + 1] $[endline - 1]
    lnext=$[endline + 1]
    debug "Continue at line ${lnext}"
}

run_lines()
{
    local start="${1}"
    local end="${2}"
    local l lnext s v

    debug "Running lines ${start}..${end}"
    l=${start}
    while [ "${l}" -le "${end}" ]; do
        lnext=$[l+1]
        s="${tlines[${l}]}"
        # Expand @@foo@@ to ${info[foo]}. First escape quotes/backslashes.
        s="${s//\\/\\\\}"
        s="${s//\$/\\\$}"
        while [ -n "${s}" ]; do
            case "${s}" in
                *@@*@@*)
                    v="${s#*@@}"
                    v="${v%%@@*}"
                    if [ "${info[${v}]+set}" != "set" ]; then
                        error "line ${l}: reference to undefined variable '${v}'"
                    fi
                    s="${s%%@@*}\${info[${v}]}${s#*@@*@@}"
                    ;;
                *@@*)
                    error "line ${l}: non-paired @@ markers"
                    ;;
                *)
                    break
                    ;;
            esac
        done

        debug "Evaluate: ${s}"
        case "${s}" in
            "#!if "*)
                run_if "${s#* }"
                ;;
            "#!foreach "*)
                run_foreach "${s#* }"
                ;;
            "#!"*)
                error "line ${l}: unrecognized command"
                ;;
            *)
                # Not a special command
                eval "echo \"${s//\"/\\\"}\""
                ;;
        esac
        l=${lnext}
    done
}

run_template()
{
    local -a tlines
    local src="${1}"

    debug "Running template ${src}"
    mapfile -O 1 -t tlines < "${src}"
    run_lines 1 ${#tlines[@]}
}

########################################

# Where the version configs are generated
config_dir=config/versions
template=maintainer/kconfig-versions.template

declare -A pkg_forks
declare -a pkg_masters pkg_nforks pkg_all

kconfigize()
{
    local v="${1}"

    v=${v//[^0-9A-Za-z_]/_}
    echo "${v^^}"
}

read_file()
{
    local l

    while read l; do
        case "${l}" in
            "#*") continue;;
            *) echo "info[${l%%=*}]=${l#*=}";;
        esac
    done < "${1}"
}

read_package_desc()
{
    read_file "packages/${1}/package.desc"
}

read_version_desc()
{
    read_file "packages/${1}/${2}/version.desc"
}

find_forks()
{
    local -A info

    eval `read_package_desc ${1}`

    if [ -n "${info[master]}" ]; then
        pkg_nforks[${info[master]}]=$[pkg_nforks[${info[master]}]+1]
        pkg_forks[${info[master]}]+=" ${1}"
    else
        pkg_nforks[${1}]=$[pkg_nforks[${1}]+1]
        pkg_forks[${1}]="${1}${pkg_forks[${1}]}"
        pkg_masters+=( "${1}" )
    fi
}

check_obsolete_experimental()
{
    [ -z "${info[obsolete]}" ] && only_obsolete=
    [ -z "${info[experimental]}" ] && only_experimental=
}

enter_fork()
{
    local fork="${1}"
    local -A dflt_branch=( [git]="master" [svn]="/trunk" )
    local versions
    local only_obsolete only_experimental

    eval `read_package_desc ${fork}`

    info[name]=${fork}
    info[pfx]=`kconfigize ${fork}`
    info[originpfx]=`kconfigize ${info[origin]}`
    if [ -r "packages/${info[origin]}.help" ]; then
        info[originhelp]=`sed 's/^/\t  /' "packages/${info[origin]}.help"`
    else
        info[originhelp]="${info[master]} from ${info[origin]}."
    fi

    if [ -n "${info[repository]}" ]; then
        info[vcs]=${info[repository]%% *}
        info[repository_url]=${info[repository]##* }
        info[repository_dflt_branch]=${dflt_branch[${info[vcs]}]}
    fi

    versions=`cd packages/${fork} && \
        for f in */version.desc; do [ -r "${f}" ] && echo "${f%/version.desc}"; done | \
            sort -rV | xargs echo`

    set_iter version $versions
    info[all_versions]=$versions

    only_obsolete=yes
    only_experimental=yes
    do_foreach version check_obsolete_experimental
    info[only_obsolete]=${only_obsolete}
    info[only_experimental]=${only_experimental}
}

enter_version()
{
    local version="${1}"
    local tmp

    eval `read_version_desc ${info[name]} ${version}`
    info[ver]=${version}
    info[kcfg]=`kconfigize ${version}`
    tmp=" ${info[all_versions]} "
    tmp=${tmp##* ${version} }
    info[prev]=`kconfigize ${tmp%% *}`
}

rm -rf "${config_dir}"
mkdir -p "${config_dir}"

pkg_all=( `cd packages && \
    ls */package.desc 2>/dev/null | \
    while read f; do [ -r "${f}" ] && echo "${f%/package.desc}"; done | \
    xargs echo` )
debug "Generating package version descriptions"
debug "Packages: ${pkg_all[@]}"

# We need to group forks of the same package into the same
# config file. Discover such relationships and only iterate
# over "master" packages at the top.
for p in "${pkg_all[@]}"; do
    find_forks "${p}"
done
debug "Master packages: ${pkg_masters[@]}"

# Now for each master, create its kconfig file with version
# definitions.
for p in "${pkg_masters[@]}"; do
    debug "Generating '${config_dir}/${p}.in'"
    exec >"${config_dir}/${p}.in"
    # Base definitions for the whole config file
    info=( \
        [master]=${p} \
        [masterpfx]=`kconfigize ${p}` \
        [nforks]=${pkg_nforks[${p}]} \
        )
    set_iter fork ${pkg_forks[${p}]}
    run_template "${template}"
done
