#!/bin/sh
echo -n "$(dpkg-parsechangelog --show-field Version | cut -d- -f1)"
