===== ASUS / NVIDIA / AMD TUNING (documented, NOT applied blindly) =====

== Supergfxctl (GPU switching) ==
Mode:                Hybrid
Config:              /etc/supergfxd.conf (copied to system/supergfxd.conf)
Modprobe:            /etc/modprobe.d/supergfxd.conf (nvidia-drm modeset=1, nouveau blacklisted)
Service:             supergfxd.service (enabled)
Associated pkg:      supergfxctl (+ switcheroo-control.service enabled, nvidia-prime)
On Arch:             these are AUR packages on clean Arch.

== asusd (ASUS ROG daemon) ==
Configs (copied to system/asusd/):
  asusd.ron      - charge limit 100%, platform profile: Performance on AC,
                   Quiet on battery; linked epp; nvidia powerd disabled on battery
  fan_curves.ron - fan curves defined but DISABLED (enabled: false) - default hardware control
  aura_tuf.ron   - keyboard backlight: Static, white, brightness High
Service: asusd.service
On Arch: asusctl is an AUR package. Manually re-copy /etc/asusd/*.ron after install.

== ASUS keyboard EC-mode (user-created workarounds) ==
- /usr/local/sbin/asus-kbd-ecmode  -> sends HID feature 70,1 to 0B05/19B6
- asus-kbd-ecmode.service (oneshot) + kbd-ec-mode.service (oneshot)
- /etc/udev/rules.d/99-asus-kbd-ec-mode.rules
Requires the hidapitester AUR tool (in aur.txt). Copy scripts to /usr/local on new machine.

== AMD (CPU/GPU) ==
- amd-ucode installed
- amd-pstate active; governor powersave
- amd-pstate-reset.service (user file, system/systemd/): writes
    'passive' then 'active' to /sys/devices/system/cpu/amd_pstate/status after boot.
  (Workaround previously used to restore active mode on resume.) Re-evaluate if needed.
- amdgpu kernel driver with KMS (no custom modprobe settings)

== NVIDIA ==
- nvidia-utils + linux-cachyos-*-nvidia-open kernel modules (open kernel modules)
- modprobe.d: options nvidia-drm modeset=1
- nvidia-powerd.service (enabled) - NVIDIA dynamic power management
- nvidia-settings installed
- Current: driver 610.57.04
On clean Arch x86_64: install nvidia-open / nvidia-open-dkms + nvidia-utils + nvidia-settings + libva-nvidia-driver.
(DKMS variant needed because Arch's default kernels differ from linux-cachyos.)

== Power profiles ==
- power-profiles-daemon enabled, current profile: performance
- platform_profile sysfs: performance
- asusd also links its own profiles to platform_profile on AC/battery

== Other tuning packages ==
- cpupower, ryzenadj, stress-ng, amd-pstate-reset service
- ananicy-cpp (auto nice daemon; CachyOS repo/AUR) enabled
- tlpi: sysctl 50-cursor.conf (no custom settings), /etc/environment only comments
NOTE: Do NOT copy /etc/mkinitcpio.conf leg of hoops blindly - see README manual steps.

== Notes for applying on Arch ==
ASUS+supergfxctl+mux notes: current firmware is a "prime" (MUX-less) laptop; Hybrid is default.
Any manual vidpid for EC must exist (0B05/19B6). Verify with `asusctl -k` and `cat /proc/acpi/...`.