# HORUS Security Appliance – Demo Edition

This repository contains the source code and build infrastructure for a production‑quality demonstration of the HORUS Security Appliance.

## Quick Start
1. **Build the project**
   ```sh
   ./build.sh
   ```
2. **Run unit tests**
   ```sh
   ctest   # or `make test`
   ```
3. **Generate the ISO** (placeholder)
   ```sh
   ./build.sh iso
   ```
4. **Launch the demo VM**
   ```sh
   qemu-system-x86_64 -cdrom build/horus-demo.iso -m 2048 -enable-kvm
   ```

See the `docs/` directory for detailed build, architecture, and developer guides.
