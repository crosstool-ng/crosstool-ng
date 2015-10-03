# Add current directory to PATH
export PATH="$(pwd):$PATH"

# Manage the travis build
ct-ng_travis_build()
{
	# Override the log behaviour
	sed -i	-e 's/^.*\(CT_LOG_ERROR\).*$/# \1 is not set/' \
		-e 's/^.*\(CT_LOG_WARN\).*$/# \1 is not set/' \
		-e 's/^.*\(CT_LOG_INFO\).*$/# \1 is not set/' \
		-e 's/^.*\(CT_LOG_EXTRA\).*$/\1=y/' \
		-e 's/^.*\(CT_LOG_ALL\).*$/# \1 is not set/' \
		-e 's/^.*\(CT_LOG_DEBUG\).*$/# \1 is not set/' \
		-e 's/^.*\(CT_LOG_LEVEL_MAX\).*$/\1="EXTRA"/' \
		-e 's/^.*\(CT_LOG_PROGRESS_BAR\).*$/# \1 is not set/' \
		-e 's/^.*\(CT_LOCAL_TARBALLS_DIR\).*$/\1="${HOME}\/src"/' \
		-e 's/^.*\(CT_SAVE_TARBALLS\).*$/\1=y/' \
		.config

	# Build the sample
	ct-ng build.2 &
	local build_pid=$!

	# Start a runner task to print a "still running" line every 5 minutes
	# to avoid travis to think that the build is stuck
	{
		while true
		do
			sleep 300
			printf "Crosstool-NG is still running ...\r"
		done
	} &
	local runner_pid=$!

	# Wait for the build to finish and get the result
	wait $build_pid 2>/dev/null
	local result=$?

	# Stop the runner task
	kill $runner_pid
	wait $runner_pid 2>/dev/null

	# Return the result
	return $result
}
