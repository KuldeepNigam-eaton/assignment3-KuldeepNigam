#!/bin/sh
# Wrapper for assignment 4 package expectations.
# Runs finder-test.sh using PATH-resolved utilities and conf under /etc/finder-app/conf.

set -e
exec finder-test.sh "$@"
