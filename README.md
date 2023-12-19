# Shackleton

Early stages of a File Explorer, designed to manage file metadata where appropriate (images only at this point). Given this is an early release, I strongly suggest backing up your files just in case of mistakes; I use it to manage my own files, but no guarantees there aren't bugs in here as yet.

On MacOS, you can use the Meta key to multi-select items in the folder lists, or preview grid. For every other platform it is the Ctrl key as expected. Why MacOS insists that Ctrl can be used with the left mouse button to simulate a right click I have no idea. Single Button mice were a bad idea when Steve Jobs insisted on them and who has seen one in the last 10 years. Seriously Apple?

## External Dependencies
- We use exiftool to manipulate metadata in files hence this is required to be installed if you want to edit metadata. At least until there is a Flutter package to do it in code. On MacOS, I install this using homebrew.
- Rust is required to compile Shackleton due to downstream dependencies.

## MacOS
### Runtime
```
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
$ brew install exiftool
```
### Compilation
```
$ brew install android-studio
$ brew install rustup
$ rustup-init
```

## Windows
### Runtime
Run a Powershell as an Administrator
```
> Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
> choco install exiftool
```
### Compilation
Run a Powershell as an Administrator
```
> choco install rust
```
Then go to https://developer.android.com/studio/#downloads and download Android Studio.

## Linux
### Runtime
#### Fedora
```
$ sudo dnf install perl-Image-ExifTool
```
#### Ubuntu
```
$ sudo apt install libimage-exiftool-perl
```

### Compilation
#### Fedora
```
$ sudo dnf install rust
```
#### Ubuntu
```
$ snap install android-studio --classic
$ snap install rustup --classic
$ rustup install stable
```
