#!/bin/bash

# Run from the directory containing this script
cd `dirname $0`

msg()
{
    echo "INFO  :: $*" >&2
}

error()
{
    echo "ERROR :: $*" >&2
    exit 1
}

usage()
{
    cat >&2 <<EOF
${1:+ERROR :: $1

}Usage: $0 [action] [containter] [args...]

Action is one of:

   build     Build or rebuild the specified containers.
   install   Install crosstool-NG in specified containers.
   sample    Build a sample or if no sample name specified, all.
   enter     Spawn a shell in the specified container.
   root      Spawn a root shell in the specified container.
   clean     Clean up in the specified container.

If a special container name 'all' is used, the action is performed
on all the containers.
EOF
    exit 1
}

# Build a docker container, store its ID.
action_build()
{
    local cntr=$1

    msg "Building Docker container for ${cntr}"
    docker build --no-cache -t "ctng-${cntr}" "${cntr}"
}

# Common backend for enter/test
_dckr()
{
    local topdir=`cd ../.. && pwd`
    local cntr=$1
    shift

    mkdir -p build-${cntr}
    docker run --rm -i -t \
        -v `pwd`/common-scripts:/setup-scripts:ro \
        -v ${topdir}:/crosstool-ng:ro \
        -v `pwd`/build-${cntr}:/home \
        -v $HOME/src:/src:ro \
        ctng-${cntr} \
        ${SETUPCMD:-/setup-scripts/su-as-user `id -un` `id -u` `id -gn` `id -g`} "$@"
}

# Run the test
action_install()
{
    local cntr=$1

    # The test assumes the top directory is bootstrapped, but clean.
    msg "Setting up crosstool-NG in ${cntr}"
    _dckr "${cntr}" /setup-scripts/ctng-install
    _dckr "${cntr}" /setup-scripts/ctng-test-basic
}

# Run the test
action_sample()
{
    local cntr=$1
    shift

    # The test assumes the top directory is bootstrapped, but clean.
    msg "Building samples in ${cntr} [$@]"
    _dckr "${cntr}" /setup-scripts/ctng-build-sample "$@"
}

# Enter the container using the same user account/environment as for testing.
action_enter()
{
    local cntr=$1

    msg "Entering ${cntr}"
    _dckr "${cntr}"
}

# Enter the container using the same user account/environment as for testing.
action_root()
{
    local cntr=$1

    msg "Entering ${cntr} as root"
    SETUPCMD=/bin/bash _dckr "${cntr}"
}

# Clean up after test suite run
action_clean()
{
    local cntr=$1

    msg "Cleaning up after ${cntr}"
    if [ -d build-${cntr} ]; then
        chmod -R +w build-${cntr}
        rm -rf build-${cntr}
    fi
}

all_containers=`ls */Dockerfile | sed 's,/Dockerfile,,'`
action=$1
selected_containers=$2
shift 2
if [ "${selected_containers}" = "all" ]; then
    selected_containers="${all_containers}"
fi

case "${action}" in
    build|install|sample|enter|root|clean)
        for c in ${selected_containers}; do
            eval "action_${action} ${c} \"$@\""
        done
        ;;
    "")
        usage "No action specified."
        ;;
    *)
        usage "Unknown action ${action}."
        ;;
esac
