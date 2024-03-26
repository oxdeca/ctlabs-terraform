#!/bin/bash

ZIP=/usr/bin/zip

ARCHIVE=./hello_http2.zip
FILES="*.txt *.py"

${ZIP} ${ARCHIVE} ${FILES}
