#!/usr/bin/env bash

function test {
    data1=`date`
    data2="hello world!"

    echo $data1 >&1
}

result=`test`

echo $result