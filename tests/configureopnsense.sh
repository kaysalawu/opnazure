#!/bin/sh

# Script Params
# $1 = OPNScriptURI
# $2 = OpnVersion
# $3 = WALinuxVersion
# $4 = Primary/Secondary/TwoNics
# $5 = Trusted Nic subnet prefix - used to get the gw
# $6 = Windows-VM-Subnet subnet prefix - used to route/nat allow internet access from Windows Management VM
# $7 = ELB VIP Address
# $8 = Private IP Secondary Server

# Check if Primary or Secondary Server to setup Firewal Sync
# Note: Firewall Sync should only be setup in the Primary Server
if [ "$4" = "Primary" ]; then
    fetch $1config-active-active-primary.xml
    fetch $1get_nic_gw.py
    gwip=$(python get_nic_gw.py $5)
    sed -i "" "s/yyy.yyy.yyy.yyy/$gwip/" config-active-active-primary.xml
    sed -i "" "s_zzz.zzz.zzz.zzz_$6_" config-active-active-primary.xml
    sed -i "" "s/www.www.www.www/$7/" config-active-active-primary.xml
    sed -i "" "s/xxx.xxx.xxx.xxx/$8/" config-active-active-primary.xml
    sed -i "" "s/<hostname>OPNsense<\/hostname>/<hostname>OPNsense-Primary<\/hostname>/" config-active-active-primary.xml
    cp config-active-active-primary.xml /usr/local/etc/config.xml
elif [ "$4" = "Secondary" ]; then
    fetch $1config-active-active-secondary.xml
    fetch $1get_nic_gw.py
    gwip=$(python get_nic_gw.py $5)
    sed -i "" "s/yyy.yyy.yyy.yyy/$gwip/" config-active-active-secondary.xml
    sed -i "" "s_zzz.zzz.zzz.zzz_$6_" config-active-active-secondary.xml
    sed -i "" "s/www.www.www.www/$7/" config-active-active-secondary.xml
    sed -i "" "s/<hostname>OPNsense<\/hostname>/<hostname>OPNsense-Secondary<\/hostname>/" config-active-active-secondary.xml
    cp config-active-active-secondary.xml /usr/local/etc/config.xml
elif [ "$4" = "TwoNics" ]; then
    fetch $1config.xml
    fetch $1get_nic_gw.py
    gwip=$(python get_nic_gw.py $5)
    sed -i "" "s/yyy.yyy.yyy.yyy/$gwip/" config.xml
    sed -i "" "s_zzz.zzz.zzz.zzz_$6_" config.xml
    cp config.xml /usr/local/etc/config.xml
fi
