#!/usr/bin/env bash
set -euo pipefail

find . | cpio --create --format=newc | gzip > ../initrd.img

