#!/bin/sh

add_xml_config() {
    CONFIG_XML="$1"
    APPEND_XML="$2"
    PLACEHOLDER="$3"
    # Escape backslashes, forward slashes, and ampersands for sed compatibility
    ESCAPED_PLACEHOLDER=$(echo $PLACEHOLDER | sed -e 's/[\/&]/\\&/g')
    # Use awk to replace the placeholder with the contents of the IPSEC config file
    awk -v var="$ESCAPED_PLACEHOLDER" -v file="$APPEND_XML" '
        BEGIN { while((getline line < file) > 0) { content = content line "\n" } }
        { gsub(var, content); print }
    ' "$CONFIG_XML" > "$CONFIG_XML.tmp"
    # Remove empty lines from the temporary output file and overwrite the original CONFIG_XML
    sed '/^$/d' "$CONFIG_XML.tmp" > "$CONFIG_XML"
    # Clean up temporary file
    rm "$CONFIG_XML.tmp"
}

JSON_GLOBAL=$(echo $1 | sed 's/\\\"/\"/g')
JSON_IPSEC=$(echo $2 | sed 's/\\\"/\"/g')

env ASSUME_ALWAYS_YES=YES pkg install jq

# parse global params json string
ShellScriptName=$(echo "$JSON_GLOBAL" | jq -r '.ShellScriptName')
OpnScriptURI=$(echo "$JSON_GLOBAL" | jq -r '.OpnScriptURI')
OpnVersion=$(echo "$JSON_GLOBAL" | jq -r '.OpnVersion')
WALinuxVersion=$(echo "$JSON_GLOBAL" | jq -r '.WALinuxVersion')
OpnType=$(echo "$JSON_GLOBAL" | jq -r '.OpnType')
TrustedSubnetAddressPrefix=$(echo "$JSON_GLOBAL" | jq -r '.TrustedSubnetAddressPrefix')
WindowsVmSubnetAddressPrefix=$(echo "$JSON_GLOBAL" | jq -r '.WindowsVmSubnetAddressPrefix')
publicIPAddress=$(echo "$JSON_GLOBAL" | jq -r '.publicIPAddress')
opnSenseSecondarytrustedNicIP=$(echo "$JSON_GLOBAL" | jq -r '.opnSenseSecondarytrustedNicIP')

# parse  ipsec params json string
Phase1RemoteGw1=$(echo "$JSON_IPSEC" | jq -r '.Phase1RemoteGw1')
Phase1RemoteGw2=$(echo "$JSON_IPSEC" | jq -r '.Phase1RemoteGw2')
Phase1PreSharedKey=$(echo "$JSON_IPSEC" | jq -r '.Phase1PreSharedKey')
Phase2RemoteGw1TunnelIpLocal=$(echo "$JSON_IPSEC" | jq -r '.Phase2RemoteGw1TunnelIpLocal')
Phase2RemoteGw1TunnelIpRemote=$(echo "$JSON_IPSEC" | jq -r '.Phase2RemoteGw1TunnelIpRemote')
Phase2RemoteGw2TunnelIpLocal=$(echo "$JSON_IPSEC" | jq -r '.Phase2RemoteGw2TunnelIpLocal')
Phase2RemoteGw2TunnelIpRemote=$(echo "$JSON_IPSEC" | jq -r '.Phase2RemoteGw2TunnelIpRemote')

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
if [ "$OpnType" = "Primary" ]; then
    fetch ${OpnScriptURI}config-active-active-primary.xml
    fetch ${OpnScriptURI}get_nic_gw.py
    gwip=$(python get_nic_gw.py $TrustedSubnetAddressPrefix)
    sed -i "" "s/yyy.yyy.yyy.yyy/$gwip/" config-active-active-primary.xml
    sed -i "" "s_zzz.zzz.zzz.zzz_${WindowsVmSubnetAddressPrefix}_" config-active-active-primary.xml
    sed -i "" "s/www.www.www.www/${publicIPAddress}/" config-active-active-primary.xml
    sed -i "" "s/xxx.xxx.xxx.xxx/${opnSenseSecondarytrustedNicIP}/" config-active-active-primary.xml
    sed -i "" "s/<hostname>OPNsense<\/hostname>/<hostname>OPNsense-Primary<\/hostname>/" config-active-active-primary.xml
    cp config-active-active-primary.xml /usr/local/etc/config.xml

elif [ "$OpnType" = "Secondary" ]; then
    fetch ${OpnScriptURI}config-active-active-secondary.xml
    fetch ${OpnScriptURI}get_nic_gw.py
    gwip=$(python get_nic_gw.py $TrustedSubnetAddressPrefix)
    sed -i "" "s/yyy.yyy.yyy.yyy/$gwip/" config-active-active-secondary.xml
    sed -i "" "s_zzz.zzz.zzz.zzz_${WindowsVmSubnetAddressPrefix}_" config-active-active-secondary.xml
    sed -i "" "s/www.www.www.www/${publicIPAddress}/" config-active-active-secondary.xml
    sed -i "" "s/<hostname>OPNsense<\/hostname>/<hostname>OPNsense-Secondary<\/hostname>/" config-active-active-secondary.xml
    cp config-active-active-secondary.xml /usr/local/etc/config.xml

elif [ "$OpnType" = "TwoNics" ]; then
    fetch ${OpnScriptURI}config.xml
    fetch ${OpnScriptURI}get_nic_gw.py
    fetch ${OpnScriptURI}ipsec.xml
    gwip=$(python get_nic_gw.py $TrustedSubnetAddressPrefix)
    sed -i "" "s/yyy.yyy.yyy.yyy/$gwip/" config.xml
    sed -i "" "s_zzz.zzz.zzz.zzz_${WindowsVmSubnetAddressPrefix}_" config.xml

        # add IPSEC configuration to the config.xml if it exists
    if [ "$JSON_IPSEC" != "{}" ]; then
        add_xml_config config.xml ipsec.xml '<!--IPSEC-->'
        sed -i "" "s/Phase1RemoteGw1/$Phase1RemoteGw1/" config.xml
        sed -i "" "s/Phase1RemoteGw2/$Phase1RemoteGw2/" config.xml
        sed -i "" "s/Phase1PreSharedKey/$Phase1PreSharedKey/" config.xml
        sed -i "" "s/Phase2RemoteGw1TunnelIpLocal/$Phase2RemoteGw1TunnelIpLocal/" config.xml
        sed -i "" "s/Phase2RemoteGw1TunnelIpRemote/$Phase2RemoteGw1TunnelIpRemote/" config.xml
        sed -i "" "s/Phase2RemoteGw2TunnelIpLocal/$Phase2RemoteGw2TunnelIpLocal/" config.xml
        sed -i "" "s/Phase2RemoteGw2TunnelIpRemote/$Phase2RemoteGw2TunnelIpRemote/" config.xml
    fi
    cp config.xml /usr/local/etc/config.xml
fi

#OPNSense default configuration template
#fetch https://raw.githubusercontent.com/dmauser/opnazure/dev_active_active/scripts/$OpnScriptURI
#fetch https://raw.githubusercontent.com/dmauser/opnazure/master/scripts/$OpnScriptURI
#cp $OpnScriptURI /usr/local/etc/config.xml

# 1. Package to get root certificate bundle from the Mozilla Project (FreeBSD)
# 2. Install bash to support Azure Backup integration
env IGNORE_OSVERSION=yes
pkg bootstrap -f; pkg update -f
env ASSUME_ALWAYS_YES=YES pkg install ca_root_nss && pkg install -y bash

#Download OPNSense Bootstrap and Permit Root Remote Login
# fetch https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh.in
#fetch https://raw.githubusercontent.com/opnsense/update/7ba940e0d57ece480540c4fd79e9d99a87f222c8/src/bootstrap/opnsense-bootstrap.sh.in
fetch https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh.in
sed -i "" 's/#PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config

#OPNSense
sed -i "" "s/reboot/shutdown -r +1/g" opnsense-bootstrap.sh.in
sh ./opnsense-bootstrap.sh.in -y -r "$OpnVersion"

# Add Azure waagent
fetch https://github.com/Azure/WALinuxAgent/archive/refs/tags/v${WALinuxVersion}.tar.gz
tar -xvzf v${WALinuxVersion}.tar.gz
cd WALinuxAgent-${WALinuxVersion}/
python3 setup.py install --register-service --lnx-distro=freebsd --force
cd ..

# Fix waagent by replacing configuration settings
ln -s /usr/local/bin/python3.9 /usr/local/bin/python
##sed -i "" 's/command_interpreter="python"/command_interpreter="python3"/' /etc/rc.d/waagent
##sed -i "" 's/#!\/usr\/bin\/env python/#!\/usr\/bin\/env python3/' /usr/local/sbin/waagent
sed -i "" 's/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/' /etc/waagent.conf
fetch ${OpnScriptURI}actions_waagent.conf
cp actions_waagent.conf /usr/local/opnsense/service/conf/actions.d

# Installing bash - This is a requirement for Azure custom Script extension to run
pkg install -y bash

# Remove wrong route at initialization
cat > /usr/local/etc/rc.syshook.d/start/22-remoteroute <<EOL
#!/bin/sh
route delete 168.63.129.16
EOL
chmod +x /usr/local/etc/rc.syshook.d/start/22-remoteroute

#Adds support to LB probe from IP 168.63.129.16
# Add Azure VIP on Arp table
echo # Add Azure Internal VIP >> /etc/rc.conf
echo static_arp_pairs=\"azvip\" >>  /etc/rc.conf
echo static_arp_azvip=\"168.63.129.16 12:34:56:78:9a:bc\" >> /etc/rc.conf
# Makes arp effective
service static_arp start
# To survive boots adding to OPNsense Autorun/Bootup:
echo service static_arp start >> /usr/local/etc/rc.syshook.d/start/20-freebsd

# Reset WebGUI certificate
echo #\!/bin/sh >> /usr/local/etc/rc.syshook.d/start/94-restartwebgui
echo configctl webgui restart renew >> /usr/local/etc/rc.syshook.d/start/94-restartwebgui
echo rm /usr/local/etc/rc.syshook.d/start/94-restartwebgui >> /usr/local/etc/rc.syshook.d/start/94-restartwebgui
chmod +x /usr/local/etc/rc.syshook.d/start/94-restartwebgui
