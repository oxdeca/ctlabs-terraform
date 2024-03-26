#!/bin/bash

ZIP=/usr/bin/zip

ARCHIVE=./hello_http.zip
FILES="*.txt *.py"

${ZIP} ${ARCHIVE} ${FILES}
