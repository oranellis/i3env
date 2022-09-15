# i3env
Setup scripts and files related to building my desktop environment, designed to be run from the arch install image.

To build my arch i3 install from an arch live boot environment (after setting up networking) simply clone this repo to the drive with 
```bash
cd / && pacman -Sy git && git clone http://github.com/oranellis/dotfiles
```
Then after mounting the target drive, cd into the mount point and run the installer script at `/dotfiles/archi3/install`.

If using the grub auto installer then ensure there is a partition on the same drive as the OS with the type 'EFI System' for automatic setup.
