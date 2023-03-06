# AFClone
Forensics image creation powered by ArchLinux

# Build ISO
## Docker
Simple way to build AFClone - run special Docker image as shown bellow:
```bash
docker run --privileged --rm -v "$(pwd)"/afclone:/profile -v "$(pwd)"/out:/out leitosama/mkarchiso
```
Image will be stored in `out` subdirectory
