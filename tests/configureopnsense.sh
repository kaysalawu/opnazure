#!/bin/sh

add_xml_config_section() {
    CONFIG_XML="$1"
    APPEND_XML="$2"
    PLACEHOLDER="$3"

    # Escape backslashes, forward slashes, and ampersands for sed compatibility
    ESCAPED_PLACEHOLDER=$(echo $PLACEHOLDER | sed 's/[\/&]/\\&/g')

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

# PARAMS="$1"
# PARAMS_IPSEC="$2"

# Parse PARAMS JSON string
ShellScriptName=$(echo "$PARAMS" | jq -r '.ShellScriptName')
OpnScriptURI=$(echo "$PARAMS" | jq -r '.OpnScriptURI')
OpnVersion=$(echo "$PARAMS" | jq -r '.OpnVersion')
WALinuxVersion=$(echo "$PARAMS" | jq -r '.WALinuxVersion')
OpnType=$(echo "$PARAMS" | jq -r '.OpnType')
TrustedSubnetAddressPrefix=$(echo "$PARAMS" | jq -r '.TrustedSubnetAddressPrefix')
WindowsVmSubnetAddressPrefix=$(echo "$PARAMS" | jq -r '.WindowsVmSubnetAddressPrefix')
publicIPAddress=$(echo "$PARAMS" | jq -r '.publicIPAddress')
opnSenseSecondarytrustedNicIP=$(echo "$PARAMS" | jq -r '.opnSenseSecondarytrustedNicIP')

# Parse PARAMS_IPSEC JSON string
Phase1RemoteGw1=$(echo "$PARAMS_IPSEC" | jq -r '.Phase1RemoteGw1')
Phase1RemoteGw2=$(echo "$PARAMS_IPSEC" | jq -r '.Phase1RemoteGw2')
Phase1PreSharedKey=$(echo "$PARAMS_IPSEC" | jq -r '.Phase1PreSharedKey')
Phase2RemoteGw1TunnelIpLocal=$(echo "$PARAMS_IPSEC" | jq -r '.Phase2RemoteGw1TunnelIpLocal')
Phase2RemoteGw1TunnelIpRemote=$(echo "$PARAMS_IPSEC" | jq -r '.Phase2RemoteGw1TunnelIpRemote')
Phase2RemoteGw2TunnelIpLocal=$(echo "$PARAMS_IPSEC" | jq -r '.Phase2RemoteGw2TunnelIpLocal')
Phase2RemoteGw2TunnelIpRemote=$(echo "$PARAMS_IPSEC" | jq -r '.Phase2RemoteGw2TunnelIpRemote')

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

gwip=$(python3 get_nic_gw.py $TrustedSubnetAddressPrefix)

if [ "$OpnType" = "Primary" ]; then
    curl -O $OpnScriptURIconfig-active-active-primary.xml > /dev/null 2>&1
    curl -O $OpnScriptURIget_nic_gw.py > /dev/null 2>&1
    # sed -i "" "s/yyy.yyy.yyy.yyy/$gwip/" config-active-active-primary.xml
    # sed -i "" "s_zzz.zzz.zzz.zzz_$WindowsVmSubnetAddressPrefix_" config-active-active-primary.xml
    # sed -i "" "s/www.www.www.www/$publicIPAddress/" config-active-active-primary.xml
    # sed -i "" "s/xxx.xxx.xxx.xxx/$opnSenseSecondarytrustedNicIP/" config-active-active-primary.xml
    # sed -i "" "s/<hostname>OPNsense<\/hostname>/<hostname>OPNsense-Primary<\/hostname>/" config-active-active-primary.xml
    #cp config-active-active-primary.xml /usr/local/etc/config.xml
elif [ "$OpnType" = "Secondary" ]; then
    curl -O $OpnScriptURIconfig-active-active-secondary.xml > /dev/null 2>&1
    curl -O $OpnScriptURIget_nic_gw.py > /dev/null 2>&1
    # sed -i "" "s/yyy.yyy.yyy.yyy/$gwip/" config-active-active-secondary.xml
    # sed -i "" "s_zzz.zzz.zzz.zzz_$WindowsVmSubnetAddressPrefix_" config-active-active-secondary.xml
    # sed -i "" "s/www.www.www.www/$publicIPAddress/" config-active-active-secondary.xml
    # sed -i "" "s/<hostname>OPNsense<\/hostname>/<hostname>OPNsense-Secondary<\/hostname>/" config-active-active-secondary.xml
    #cp config-active-active-secondary.xml /usr/local/etc/config.xml
elif [ "$OpnType" = "TwoNics" ]; then
    curl -O ${OpnScriptURI}config.xml > /dev/null 2>&1
    curl -O ${OpnScriptURI}get_nic_gw.py > /dev/null 2>&1
    curl -O ${OpnScriptURI}ipsec.xml > /dev/null 2>&1
    sed -i "s/yyy.yyy.yyy.yyy/$gwip/" config.xml
    sed -i "s_zzz.zzz.zzz.zzz_${WindowsVmSubnetAddressPrefix}_" config.xml

    # add IPSEC configuration to the config.xml if it exists
    if [ -n "$PARAMS_IPSEC" ]; then
        add_xml_config_section config.xml ipsec.xml '<!--IPSEC-->'
        sed -i "s/_PHASE1_REMOTE_GW1_/$remote_gw1/" config.xml
        sed -i "s/_PHASE1_REMOTE_GW2_/$remote_gw2/" config.xml
        sed -i "s/_PHASE1_PRE_SHARED_KEY_/$pre_shared_key/" config.xml
        sed -i "s/_PHASE2_REMOTE_GW1_TUNNEL_IP_LOCAL_/$remote_gw1_tunnel_ip_local/" config.xml
        sed -i "s/_PHASE2_REMOTE_GW1_TUNNEL_IP_REMOTE_/$remote_gw1_tunnel_ip_remote/" config.xml
        sed -i "s/_PHASE2_REMOTE_GW2_TUNNEL_IP_LOCAL_/$remote_gw2_tunnel_ip_local/" config.xml
        sed -i "s/_PHASE2_REMOTE_GW2_TUNNEL_IP_REMOTE_/$remote_gw2_tunnel_ip_remote/" config.xml
    fi

    #cp config.xml /usr/local/etc/config.xml
fi
