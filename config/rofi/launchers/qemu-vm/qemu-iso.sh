#!/bin/sh
ISO_DIR="$HOME/Downloads"
HDD_DIR="$HOME/VMs"

if [ "$#" -eq 0 ]; then
  find "$ISO_DIR" -maxdepth 1 -type f -iname "*.iso" -printf "%f\n" | sort
  exit 0
fi

iso="$*"

# Detach QEMU so rofi can exit immediately
setsid -f sh -c "
  qemu-system-x86_64 \
    -enable-kvm \
    -machine q35,accel=kvm \
    -cpu host -smp 6 -m 4096 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.fd \
    -device virtio-vga-gl \
    -display sdl,gl=on \
    -audiodev pa,id=snd0 \
    -device ich9-intel-hda -device hda-output,audiodev=snd0 \
    -device virtio-net-pci,netdev=n0 -netdev user,id=n0,hostfwd=tcp::2222-:22 \
    -device virtio-rng-pci \
    -cdrom \"$ISO_DIR/$iso\" \
    -drive file=\"$HDD_DIR/disk.qcow2\",if=virtio,format=qcow2
    -boot order=d \
    >/dev/null 2>&1
" >/dev/null 2>&1

# IMPORTANT: print nothing and exit so rofi closes
exit 0
