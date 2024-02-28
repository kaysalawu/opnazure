#!/bin/sh

set -x
exec > azure_extension_script.log 2>&1

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

JSON_GLOBAL="$1"
JSON_IPSEC="$2"

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
    curl -O $OpnScriptURIconfig-active-active-primary.xml
    curl -O $OpnScriptURIget_nic_gw.py
    gwip=$(python get_nic_gw.py $TrustedSubnetAddressPrefix)
    sed -i "s/yyy.yyy.yyy.yyy/$gwip/" config-active-active-primary.xml
    sed -i "s_zzz.zzz.zzz.zzz_${WindowsVmSubnetAddressPrefix}_" config-active-active-primary.xml
    sed -i "s/www.www.www.www/${publicIPAddress}/" config-active-active-primary.xml
    sed -i "s/xxx.xxx.xxx.xxx/${opnSenseSecondarytrustedNicIP}/" config-active-active-primary.xml
    sed -i "s/<hostname>OPNsense<\/hostname>/<hostname>OPNsense-Primary<\/hostname>/" config-active-active-primary.xml
    cp config-active-active-primary.xml /usr/local/etc/config.xml

elif [ "$OpnType" = "Secondary" ]; then
    curl -O ${OpnScriptURI}config-active-active-secondary.xml
    curl -O ${OpnScriptURI}get_nic_gw.py
    gwip=$(python get_nic_gw.py $TrustedSubnetAddressPrefix)
    sed -i "s/yyy.yyy.yyy.yyy/$gwip/" config-active-active-secondary.xml
    sed -i "s_zzz.zzz.zzz.zzz_${WindowsVmSubnetAddressPrefix}_" config-active-active-secondary.xml
    sed -i "s/www.www.www.www/${publicIPAddress}/" config-active-active-secondary.xml
    sed -i "s/<hostname>OPNsense<\/hostname>/<hostname>OPNsense-Secondary<\/hostname>/" config-active-active-secondary.xml
    cp config-active-active-secondary.xml /usr/local/etc/config.xml

elif [ "$OpnType" = "TwoNics" ]; then
    curl -O ${OpnScriptURI}config.xml
    curl -O ${OpnScriptURI}get_nic_gw.py
    curl -O ${OpnScriptURI}ipsec.xml
    gwip=$(python get_nic_gw.py $TrustedSubnetAddressPrefix)
    sed -i "s/yyy.yyy.yyy.yyy/$gwip/" config.xml
    sed -i "s_zzz.zzz.zzz.zzz_${WindowsVmSubnetAddressPrefix}_" config.xml

    # add IPSEC configuration to the config.xml if it exists
    if [ "$JSON_IPSEC" != "{}" ]; then
        add_xml_config config.xml ipsec.xml '<!--IPSEC-->'
        sed -i "s/Phase1RemoteGw1/$Phase1RemoteGw1/" config.xml
        sed -i "s/Phase1RemoteGw2/$Phase1RemoteGw2/" config.xml
        sed -i "s/Phase1PreSharedKey/$Phase1PreSharedKey/" config.xml
        sed -i "s/Phase2RemoteGw1TunnelIpLocal/$Phase2RemoteGw1TunnelIpLocal/" config.xml
        sed -i "s/Phase2RemoteGw1TunnelIpRemote/$Phase2RemoteGw1TunnelIpRemote/" config.xml
        sed -i "s/Phase2RemoteGw2TunnelIpLocal/$Phase2RemoteGw2TunnelIpLocal/" config.xml
        sed -i "s/Phase2RemoteGw2TunnelIpRemote/$Phase2RemoteGw2TunnelIpRemote/" config.xml
    fi
    #cp config.xml /usr/local/etc/config.xml
fi
