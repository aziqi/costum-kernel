# KernelSU-Next for a9y18qlte (Samsung Galaxy A9 2018)

Proyek ini menambahkan dukungan **KernelSU-Next** (versi Legacy Non-GKI) ke kernel `a9y18qlte` (4.4.205) menggunakan metode **Manual Hooks (Non-Kprobes)**.

## Mengapa Manual Hooks?
Kernel 4.4 sering kali mengalami *kernel panic* atau ketidakstabilan jika menggunakan `kprobe`. 
Dalam `defconfig` asli kernel ini, `CONFIG_KPROBES` sudah dinonaktifkan (`# not set`). Oleh karena itu, kita mematikan `CONFIG_HAVE_KPROBES` dan menginjeksikan panggilan fungsi KSU secara langsung ke dalam VFS (Virtual File System) kernel di `fs/exec.c`, `fs/open.c`, `fs/read_write.c`, dan `fs/stat.c`.

Defconfig kernel ini juga **sudah bersih** dari fitur keamanan Samsung (`CONFIG_DEFEX`, `CONFIG_RKP`, `CONFIG_TIMA` dinonaktifkan secara bawaan), sehingga tidak akan terjadi bootloop dari Knox/Hypervisor.

---

## 🚀 Cara Build

Karena ini adalah kernel Linux arm64, build tidak bisa dilakukan secara *native* di Windows. Kamu punya dua pilihan:

### Pilihan 1: Build via GitHub Actions (Sangat Disarankan)
Metode ini gratis, otomatis, dan tidak memerlukan setup environment lokal.

1. Upload seluruh folder ini (termasuk `.github/workflows` dan file `thongass000-v4.4.205-stable.zip`) ke repositori GitHub pribadimu.
2. Buka tab **Actions** di repositorimu.
3. Pilih workflow **Build KernelSU-Next for a9y18qlte** dan klik **Run workflow**.
4. Tunggu sekitar 30-45 menit.
5. Setelah selesai, unduh artifact **a9y18qlte-KSUN-Zip** di halaman ringkasan workflow.

### Pilihan 2: Build Lokal (WSL / Linux)
Jika kamu memiliki WSL (Windows Subsystem for Linux) atau VM Ubuntu:

1. Buka terminal Linux di direktori ini.
2. Pastikan dependencies terinstal: `sudo apt install build-essential bc bison flex libssl-dev python3 zip unzip curl git`
3. Beri izin eksekusi pada script: `chmod +x build-local.sh`
4. Jalankan: `./build-local.sh`
5. File `a9y18qlte-KSUN.zip` akan otomatis dibuat di direktori ini.

---

## 📱 Cara Instalasi (Flashing)

1. Pindahkan file `a9y18qlte-KSUN.zip` hasil build ke penyimpanan HP (Internal / SD Card).
2. Reboot ke TWRP (Custom Recovery).
3. (Opsional tapi disarankan) Lakukan backup partisi `Boot` via TWRP sebelum flash.
4. Pilih menu **Install** > Pilih `a9y18qlte-KSUN.zip`.
5. *Swipe to confirm flash*.
6. Reboot System.
7. Setelah menyala, install **KernelSU-Next Manager APK** (pilih rilis terbaru dari repo resmi KernelSU-Next).
8. Buka aplikasi KernelSU-Next, seharusnya muncul status **"Working"**.

---

## 🛠️ Troubleshooting

Jika terjadi *bootloop* atau KSU tidak terdeteksi:
*   **Bootloop logo:** Ini menandakan hook di `fs/exec.c` tidak kompatibel atau terjadi *kernel panic*. Untuk memastikannya, ekstrak `boot.img` asli dari ROM kamu dan flash via TWRP agar HP bisa nyala kembali.
*   **Aplikasi KernelSU Manager "Not Supported":** KSU gagal di-compile atau tidak ter-hook dengan benar ke kernel. Cek file `build.log` dari hasil GitHub Actions untuk melihat apakah ada error saat script Python melakukan integrasi.

*Script integrasi yang digunakan menggunakan versi fallback (`mlm-games/KernelSU-Non-GKI`) yang disesuaikan untuk device Non-GKI seperti a9y18qlte.*
