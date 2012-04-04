#!/bin/bash
#
# This script requires a working Openstack Swift development
# environment.

# Swift authentication env variables
ST_AUTH="http://127.0.0.1:8080/auth/v1.0"
ST_USER="test:tester"
ST_KEY="testing"
export ST_AUTH ST_KEY ST_USER

function gen_input {
  BOUND=$1
  for ((i=0; i < $BOUND; i++)) do
    echo "line $i"
  done
}

# Test existing functionality
function test_existing {
  # setup
  gen_input 1000 > file1.txt
  gen_input 100 > file2.txt
  gen_input 50 > file3.txt

  retval="FAILED"

  # test
  swift upload test_container file1.txt file2.txt file3.txt > /dev/null
  swift download -o tmp1.txt test_container file1.txt > /dev/null
  swift download -o tmp2.txt test_container file2.txt > /dev/null
  swift download -o tmp3.txt test_container file3.txt > /dev/null
  fail_count=0
  if [ "`cat tmp1.txt`" != "`cat file1.txt`" ]; then
    fail_count=$((fail_count + 1))
  fi
  if [ "`cat tmp2.txt`" != "`cat file2.txt`" ]; then
    fail_count=$((fail_count + 1))
  fi
  if [ "`cat tmp3.txt`" != "`cat file3.txt`" ]; then
    fail_count=$((fail_count + 1))
  fi
  if [ $fail_count -eq 0 ]; then
    retval="PASSED"
  fi

  echo "Existing swift upload test: $retval"

  # clean-up
  rm -rf tmp[123].txt
  rm -rf file[123].txt
  swift delete test_container > /dev/null
}

function test_piped_upload {
  retval="FAILED"
  INPUT=`gen_input 999`
  EXPECTED_OUTPUT="test1.txt"
  ACTUAL_OUTPUT="$(echo $INPUT | swift upload test_container test1.txt "-")"
  if [ "$EXPECTED_OUTPUT" == "$ACTUAL_OUTPUT" ];then
    swift download -o tmp1.txt test_container test1.txt > /dev/null
    if [ "$(echo $INPUT)" == "`cat tmp1.txt`" ];then
      retval="PASSED"
    fi
  fi
  echo "Piped swift upload test (positive): $retval"

  # clean-up
  rm -rf tmp1.txt
  swift delete test_container > /dev/null
}

function test_piped_upload_wrong_arg_num {
  retval="FAILED"
  cat >& out.txt <<EOF
Usage: swift [options] upload [options] container file_or_directory [file_or_directory] [...]
    Uploads to the given container the files and directories specified by the
    remaining args. -c or --changed is an option that will only upload files
    that have changed since the last upload. -S <size> or --segment-size <size>
    and --leave-segments are options as well (see --help for more). Contents
    can be supplied from standard input by adding '-' flag after a filename.
    This option allows only one container and one filename to be specified. The
    filename will be used to store the content as provided by standard input 
    in the container.
EOF
  INPUT="hello world"
  EXPECTED_OUTPUT="$(cat out.txt)"
  ACTUAL_OUTPUT=$(echo $INPUT | swift upload test_container test2.txt test1.txt - 2>&1)
  if [ "$(echo $EXPECTED_OUTPUT)" == "$(echo ${ACTUAL_OUTPUT})" ];then
    retval="PASSED"
  fi
  echo "Piped swift upload test (negative): $retval"

  # clean-up
  rm -rf tmp1.txt
  rm -rf out.txt
}

function test_piped_upload_changed_option {
  retval="FAILED"
  INPUT=`gen_input 55`
  EXPECTED_OUTPUT="test1.txt"
  ACTUAL_OUTPUT="$(echo $INPUT | swift upload -c test_container test1.txt "-")"
  if [ "$EXPECTED_OUTPUT" == "$ACTUAL_OUTPUT" ];then
    swift download -o tmp1.txt test_container test1.txt > /dev/null
    if [ "$(echo $INPUT)" == "`cat tmp1.txt`" ];then
      retval="PASSED"
    fi
  fi
  echo "Piped swift upload test with changed option (positive): $retval"

  # clean-up
  rm -rf tmp1.txt
  swift delete test_container > /dev/null
}

# Run tests
test_existing
test_piped_upload
test_piped_upload_changed_option
test_piped_upload_wrong_arg_num

