# This file adds functions to get xtensa overlay
# Licensed under the GPL v2. See COPYING in the root of this package

# Download overlay
do_overlay_get() {
    if [ -n "${CT_OVERLAY_VERSION}" ]; then
        CT_Fetch OVERLAY
    fi
}
