
sh configureopnsense.sh \
'{"OpnScriptURI":"https://raw.githubusercontent.com/kaysalawu/opnazure/master/scripts/","OpnType":"TwoNics","OpnVersion":"23.7","ShellScriptName":"configureopnsense.sh","TrustedSubnetAddressPrefix":"10.11.2.0/24","WALinuxVersion":"2.9.1.1","WindowsVmSubnetAddressPrefix":"1.1.1.1/32","opnSenseSecondarytrustedNicIP":"","publicIPAddress":"8.8.8.8"}' \
'{"Phase1PreSharedKey":"abc123","Phase1RemoteGw1":"4.207.8.15","Phase1RemoteGw2":"4.207.9.30","Phase2RemoteGw1TunnelIpLocal":"169.254.21.2","Phase2RemoteGw1TunnelIpRemote":"169.254.21.1","Phase2RemoteGw2TunnelIpLocal":"169.254.21.6","Phase2RemoteGw2TunnelIpRemote":"169.254.21.5"}'
