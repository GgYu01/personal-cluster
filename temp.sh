#!/usr/bin/env bash



echo "--- [STARTING EXPERIMENT A: FULL CONFIG] ---" > /root/k3s_direct_boot.log

# 准备好 K3s 启动参数
K3S_EXEC_ARGS="server \
    --cluster-init \
    --datastore-endpoint=http://127.0.0.1:2379 \
    --tls-san=api.core01.prod.gglohh.top \
    --tls-san=172.245.187.113 \
    --disable=traefik \
    --disable=servicelb \
    --disable-cloud-controller \
    --flannel-iface=eth0 \
    --selinux=false \
    --kubelet-arg=fail-swap-on=false \
    --admission-control-config-file=/etc/rancher/k3s/admission-config-full.yaml"

# 直接执行 K3s 并将所有输出（标准输出和标准错误）追加到日志文件
# 我们预计这可能会失败
/usr/local/bin/k3s $K3S_EXEC_ARGS >> /root/k3s_direct_boot.log 2>&1 || true

echo "--- [FINISHED EXPERIMENT A] ---" >> /root/k3s_direct_boot.log

# 等待几秒确保进程有时间退出
sleep 5
/usr/local/bin/k3s-killall.sh || true # 再次清理




echo "--- [STARTING EXPERIMENT B: MINIMAL CONFIG] ---" >> /root/k3s_direct_boot.log

# 更新启动参数，指向极简配置文件
K3S_EXEC_ARGS="server \
    --cluster-init \
    --datastore-endpoint=http://127.0.0.1:2379 \
    --tls-san=api.core01.prod.gglohh.top \
    --tls-san=172.245.187.113 \
    --disable=traefik \
    --disable=servicelb \
    --disable-cloud-controller \
    --flannel-iface=eth0 \
    --selinux=false \
    --kubelet-arg=fail-swap-on=false \
    --admission-control-config-file=/etc/rancher/k3s/admission-config-minimal.yaml"

# 再次尝试直接执行
/usr/local/bin/k3s $K3S_EXEC_ARGS >> /root/k3s_direct_boot.log 2>&1 || true

echo "--- [FINISHED EXPERIMENT B] ---" >> /root/k3s_direct_boot.log