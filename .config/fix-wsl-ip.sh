#!/bin/bash
ip addr add 192.168.149.16/24 broadcast 192.168.149.16 dev eth0 label eth0:1 2> /dev/null > /dev/null
