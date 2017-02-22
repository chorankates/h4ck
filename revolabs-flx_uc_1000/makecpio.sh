#!/bin/bash
## makecpio.sh

DIR='_fake'
OUT="revo.$$.cpio"

find ${DIR} -print | cpio -ov > ${OUT}
ls -lh ${OUT}
binwalk -v ${OUT}
