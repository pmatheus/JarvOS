#!/usr/bin/env bash
# Lowercase, terse, no commas. "wed 6 may"
LC_TIME=C date +"%a %-d %b" | tr '[:upper:]' '[:lower:]'
