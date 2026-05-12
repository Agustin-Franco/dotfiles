# Dotfiles con GNU Stow

Este repositorio organiza los dotfiles por paquetes usando GNU Stow.

## Instalacion de Stow

Arch Linux:

```
sudo pacman -S stow
```

Debian/Ubuntu:

```
sudo apt update && sudo apt install -y stow
```

Fedora:

```
sudo dnf install -y stow
```

macOS (Homebrew):

```
brew install stow
```

## Uso rapido

1. Ejecuta en modo prueba:

```
./bootstrap.sh --dry-run
```

2. Ejecuta en modo real:

```
./bootstrap.sh
```

Opciones utiles:

```
./bootstrap.sh --packages "hypr alacritty nvim"
./bootstrap.sh --no-backup
./bootstrap.sh --yes
```

## Como agregar nuevos dotfiles

Ejemplo con kitty:

```
mkdir -p ~/dotfiles/kitty/.config/kitty
mv ~/.config/kitty/kitty.conf ~/dotfiles/kitty/.config/kitty/
stow -d ~/dotfiles -t ~ kitty
```

## Referencias

- https://gist.github.com/andreibosco/cb8506780d0942a712fc
- https://www.gnu.org/software/stow/
