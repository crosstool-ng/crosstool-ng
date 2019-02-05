#!/bin/bash

CTNG=${CTNG-../../ct-ng}

current_tc=unknown
fails_tc=0
fails_total=0

fail()
{
    fails_tc=$[fails_tc + 1]
    fails_total=$[fails_total + 1]
}

finish()
{
    if [ "${fails_tc}" != 0 ]; then
        echo ">>>>> $current_tc: FAIL" >&2
    else
        echo ">>>>> $current_tc: PASS" >&2
    fi
    fails_tc=0
}

run_sample()
{
    local -A expect_set expect_unset
    local o v ln

    # Basename for logging
    exec {LOG}>"logs/${current_tc}.log"

    # Determine expected values
    while read ln; do
        case "${ln}" in
            "## "*"="*)
                ln=${ln#* }
                o=${ln%%=*}
                v=${ln#*=}
                expect_set[${o}]=${v}
                ;;
            "## "*" is not set")
                ln=${ln#* }
                o=${ln%% *}
                expect_unset[${o}]=1
                ;;
        esac
    done < "samples/${current_tc}.config"

    # Now run the upgrade
    echo ">>>> Running the config through an upgrade" >&${LOG}
    cp "samples/${current_tc}.config" .config
    ${CTNG} upgradeconfig >&${LOG} 2>&${LOG}
    echo >&${LOG}
    echo ">>>> Checking the config after the upgrade" >&${LOG}
    while read ln; do
        case "${ln}" in
            *"="*)
                o=${ln%%=*}
                v=${ln#*=}
                if [ "${expect_unset[${o}]+set}" = "set" ]; then
                    echo "Expect ${o} to be unset" >&${LOG}
                    echo "Actual value of ${o}: ${v}" >&${LOG}
                    fail
                elif [ "${expect_set[${o}]+set}" = "set" ]; then
                    if [ "${expect_set[${o}]}" != "${v}" ]; then
                        echo "Expect value of ${o}: ${expect_set[${o}]}" >&${LOG}
                        echo "Actual value of ${o}: ${v}" >&${LOG}
                        fail
                    else
                        echo "Matched value of ${o}: ${v}" >&${LOG}
                    fi
                fi
                unset expect_set[${o}]
                unset expect_unset[${o}]
                ;;
            "# "*" is not set")
                ln=${ln#* }
                o=${ln%% *}
                if [ "${expect_set[${o}]+set}" = "set" ]; then
                    echo "Expect value of ${o}: ${expect_set[${o}]}" >&${LOG}
                    echo "Actual ${o} is unset" >&${LOG}
                    fail
                elif [ "${expect_unset[${o}]+set}" = "set" ]; then
                    echo "Matched unset ${o}" >&${LOG}
                fi
                unset expect_set[${o}]
                unset expect_unset[${o}]
                ;;
        esac
    done < .config
    for o in "${!expect_set[@]}"; do
        echo "Expect value of ${o}: ${expect_set[${o}]}" >&${LOG}
        echo "Variable ${o} not present" >&${LOG}
        fail
    done
    for o in "${!expect_unset[@]}"; do
        echo "Expect ${o} being unset" >&${LOG}
        echo "Variable ${o} not present" >&${LOG}
        fail
    done
    exec {LOG}>&-
    finish
}

mkdir -p logs
for i in samples/*.config; do
    current_tc=${i#samples/}
    current_tc=${current_tc%.config}
    run_sample
done

if [ "${fails_total}" != 0 ]; then
    exit 1
fi
exit 0
