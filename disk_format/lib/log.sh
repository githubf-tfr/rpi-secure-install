#!/bin/bash
log_info()    { echo -e "[INFO ] $(date +'%F %T') $*"; }
log_warn()    { echo -e "[WARN ] $(date +'%F %T') $*" >&2; }
log_error()   { echo -e "[ERROR] $(date +'%F %T') $*" >&2; }
log_debug()   { [[ "${DEBUG:-0}" == "1" ]] && echo -e "[DEBUG] $(date +'%F %T') $*"; }
