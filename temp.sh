# This command is designed to be non-interactive and comprehensive.
# Please copy the entire block and run it.
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@172.245.187.113 '
    echo "### HOST NETWORK SNAPSHOT - START ###"
    
    echo "\n--- [1] IP Address Information ---"
    ip addr
    
    echo "\n--- [2] Kernel IP Forwarding Status ---"
    sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding
    
    echo "\n--- [3] Docker Network List ---"
    docker network ls
    
    echo "\n--- [4] Docker Network Inspection ---"
    # Loop through each docker network and inspect it
    for net in $(docker network ls --format "{{.ID}}"); do
        echo "\n--- Inspecting Network ID: ${net} ---"
        docker network inspect ${net}
    done
    
    echo "\n--- [5] Full IPTables Ruleset (nat table) ---"
    iptables -t nat -S
    
    echo "\n--- [6] Full IPTables Ruleset (filter table) ---"
    iptables -t filter -S
    
    echo "\n### HOST NETWORK SNAPSHOT - END ###"
'