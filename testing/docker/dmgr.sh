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

}Usage: $0 [action] [containters]

Action is one of:

   build     Build or rebuild the specified containers.

If containers are not specified, the action is applied to all available containers.
EOF
    exit 1
}

# Build a docker container, store its ID.
action_build()
{
    local cntr=$1

    msg "Building Docker container for ${cntr}"
    docker build -t "ctng-${cntr}" "${cntr}"
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
        /setup-scripts/su-as-user `id -un` `id -u` `id -gn` `id -g` "$@"
}

# Run the test
action_test()
{
    local cntr=$1

    # The test assumes the top directory is bootstrapped, but clean.
    msg "Setting up crosstool-NG in ${cntr}"
    _dckr "${cntr}" /setup-scripts/ctng-install
    msg "Running build-all in ${cntr}"
    _dckr "${cntr}" /setup-scripts/ctng-test-all
}

# Enter the container using the same user account/environment as for testing.
action_enter()
{
    local cntr=$1

    msg "Entering ${cntr}"
    _dckr "${cntr}"
}

# Clean up after test suite run
action_clean()
{
    local cntr=$1

    msg "Cleaning up after ${cntr}"
    rm -rf build-${cntr}
}

action=$1
shift
all_containers=`ls */Dockerfile | sed 's,/Dockerfile,,'`
selected_containers="${*:-${all_containers}}"

case "${action}" in
    build|test|enter|clean)
        for c in ${selected_containers}; do
            eval "action_${action} $c"
        done
        ;;
    "")
        usage "No action specified."
        ;;
    *)
        usage "Unknown action ${action}."
        ;;
esac
