get_volume_info() {
    actual_volume=$(amixer get Master | grep -o '[0-9]\+%' | head -n 1)
    echo $actual_volume
}
volume_info="Volume: $(get_volume_info)"

datentime=$(date "+%Y-%m-%d %H:%M:%S")
cpu_package_temp=$(sensors | awk '/CPU Package:/ {gsub("\\+|°C","",$3); print $3}')
gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
temperature_info="CPU: $cpu_package_temp°C ~ GPU: $gpu_temp°C"

echo "$temperature_info | $volume_info | $datentime"
