#!/bin/bash
echo "{"
hasentry=no
for x in `ls /sys/class/net/` ; do
    data=`udevadm test-builtin net_id /sys/class/net/$x 2>/dev/null`
    slot=`echo "${data}" | grep ID_NET_NAME_SLOT | cut -d = -f 2`
    if [ "${slot}" != "" ] ; then
        origname="${slot}"
    else
        origname=`echo "${data}" | grep ID_NET_NAME_PATH | cut -d = -f 2`
    fi

    if [ "${origname}" != "" ] ; then
        if [ "${hasentry}" = "yes" ] ; then
        echo ","
        fi
        hasentry=yes

        echo -n "\"${x}\": \"${origname}\""
    fi
done
echo ""
echo "}"
