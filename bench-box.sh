#!/bin/sh
# 同机可复现的 CPU / 内存 / 温度基准（BusyBox ash 即可，无外部依赖）
# 用法：sh bench-box.sh
# 说明：该 BusyBox 的 date 不支持 %s%N，故计时统一用 /proc/uptime
MB=${MB:-400}                    # 每路数据量（MB），可用环境变量覆盖

now() { awk '{print $1}' /proc/uptime; }
dur() { awk -v a=$1 -v b=$2 'BEGIN{printf "%.2f", (b-a)}'; }
rate() { awk -v m=$1 -v t=$2 'BEGIN{printf "%.0f MB/s", m/(t+0.001)}'; }

echo "### CPU"
grep -m1 'model name' /proc/cpuinfo
echo "cores=$(grep -c '^processor' /proc/cpuinfo)"
echo "flags(key): $(grep -m1 flags /proc/cpuinfo | tr ' ' '\n' | grep -xE 'aes|avx|avx2|sse4_1|sse4_2|sha_ni|bmi1|bmi2|adx|rdrand' | tr '\n' ' ')"
echo "governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null) cur=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null) max=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)"
echo "mem_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')"
echo "load=$(cat /proc/loadavg)"

echo
echo "### 1) single-core md5 ${MB}MB"
A=$(now); head -c $((MB*1024*1024)) /dev/zero | md5sum >/dev/null; B=$(now)
T=$(dur $A $B); echo "time ${T}s => $(rate $MB $T)"

echo "### 2) single-core sha256 ${MB}MB"
A=$(now); head -c $((MB*1024*1024)) /dev/zero | sha256sum >/dev/null; B=$(now)
T=$(dur $A $B); echo "time ${T}s => $(rate $MB $T)"

echo "### 3) 4-way parallel md5 (4 x ${MB}MB)"
A=$(now)
i=1
while [ $i -le 4 ]; do ( head -c $((MB*1024*1024)) /dev/zero | md5sum >/dev/null ) & i=$((i+1)); done
wait
B=$(now); T=$(dur $A $B)
echo "time ${T}s => aggregate $(rate $((MB*4)) $T)"

echo
echo "### thermal"
for z in /sys/class/thermal/thermal_zone*/temp; do
  [ -f "$z" ] && echo "  $z = $(cat "$z")"
done 2>/dev/null | head -4

echo
echo "NOTE: BusyBox md5/sha256 are scalar implementations (no SIMD / SHA-NI),"
echo "      so these numbers reflect IPC x clock, not accelerated crypto throughput."
