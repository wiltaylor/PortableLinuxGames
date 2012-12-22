#!/bin/bash

pg4l_dir=$(dirname $0)

case $(cat /etc/issue | head -n 1) in
	Arch*)
		find_dependencies_package() { pacman -Si $1 | egrep "Depends On" | grep -v None | cut -d: -f2; }
		find_dependencies_file() { pacman -Qip $1 | egrep "Depends On" | grep -v None | cut -d: -f2; }
		find_file_for_package() { ls -1t /var/cache/pacman/pkg/$1-[0-9]*.pkg.tar.xz 2>/dev/null| head -n1; }
		uncompress_package_file() { tar -xf $1; }
		download_packages() { sudo pacman -Sw --noconfirm $@; }
		;;
	Ubuntu* | Debian*)
		find_dependencies_package() { apt-get info $1; }
		find_dependencies_file() { dpkg info $1; }
		find_file_for_package() { pkg=$1; ls -1t /var/cache/dpkg/$1-[0-9]*.pkg.tar.xz 2>/dev/null| head -n1; }
		uncompress_package_file() { dpkg -d $1; }
		download_packages() { apt-get download $@; }
		;;
	*)
		echo "Distro not supported"
		exit 1
		;;
esac

MODE="pkg"

for i in $@; do
	case $i in
		pkg)
			MODE="pkg"
			;;
		ldd)
			MODE="ldd"
			;;
	esac
done

pkgs=
files=

# Recolect list of packages
if [ $MODE = "pkg" ]; then

	for i in $@; do
		case $i in
			-*)
				ignore+=" ${i#*-}"
				;;
			*)
				if [ -f $i ]; then
					# Argument is a file
					files+=" $i"
					pkgs+=" $(find_dependencies_file $i)"
				else
					# Argument is the name of a package
					pkgs+=" $i"
					pkgs+=" $(find_dependencies_package $i)"
				fi
				;;
		esac
	done

elif [ $mode = "ldd" ]; then

	bin=$1
	for i in $(ldd $bin); do
		true
	done

fi


# Download and unpack packages
[ "$pkgs" -o "$files" ] || { echo "Nothing to do"; exit; }

[ "$files" ] && {
	echo "These files will be included:"
	for i in $files; do
		echo "  $i"
	done
}
	
[ "$pkgs" ] && {
	echo "These packages will be included:"

	for i in $ignore; do
		echo "Ignoring $i..."
		pkgs=${pkgs//$i/}
	done

	for i in $pkgs; do
		pkgs=${pkgs//$i/${i%%[<>=]*}}
	done

	for i in $pkgs; do
		echo "  $i"
	done
}


[ "$pkgs" ] && {
	# Make sure all packages are downloaded
	download_packages $pkgs || exit

	# Find the file corresponding with each package
	for i in $pkgs; do
		f=$(find_file_for_package $i)
	
		if [ -f "$f" ]; then
			files+=" $f"
		else
		       	echo "!! Could not find $i"
		fi
	done
}

[ "$files" ] && {
	for i in $files; do
		echo "Uncompressing $i..."
		uncompress_package_file $i
	done
	
	rubbish="usr/include usr/share/man usr/share/info usr/share/doc usr/share/mime usr/share/aclocal usr/lib/pkgconfig/ usr/lib/*.a .INSTALL .PKGINFO"
	for i in $rubbish; do
		[ -d "$i" ] && {
			echo "Deleting $i..."
			rm -rf "$i"
		}
	done

	for i in $(ls -1 usr/share/applications/*.desktop 2>/dev/null); do
		sed -e"s/Exec=.*/Exec=AppRun/" $i -i
		mv -v $i .
	done
	rmdir usr/share/applications/ 2>/dev/null

	echo "Icons: $(ls -1 usr/share/pixmaps/*.{png,xpm})"
}

[ -f AppRun ] || {
	echo "Creating AppRun..."
	cp $pg4l_dir/AppRun .
	#cp $pg4l_dir/AppRun.desktop .

	chmod +x AppRun
}


