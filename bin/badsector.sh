#!/bin/bash
#
#   Copyright
#
#	Copyright (C) 2007-2012 Jari Aalto
#
#   License
#
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation; either version 2 of the License, or
#       (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program. If not, see <http://www.gnu.org/licenses/>.

AUTHOR="Jari Aalto <jari.aalto@cante.net>"
VERSION="2012.0219.1010"
LICENSE="GPL-2+"
HOMEPAGE=http://freecode.com/projects/badsector

CURDIR=$( cd $(dirname $0) ; pwd )

Version ()
{
    echo "$VERSION $LICENSE $AUTHOR $HOMEPAGE"
}

Echo ()
{
    [ "$verbose" ] && echo "# $*"
}

Warn ()
{
    echo "# $*" >&2
}

Die ()
{
    Warn "$*"
    exit 1
}

Readsector ()
{
    local dummy="To force relocating the sector, try reading it."

    local dev=$1
    local lba=$2

    if [[ ! "$dev" == /dev/* ]]; then
        echo "[ERROR] Synopsis: <DEVICE> PROBLEM_LBA" >&2
        echo "smartctl -a /dev/sda ; smartctl -l error -q errorsonly" >&2
        return 1
    fi

    if [[ ! "$lba" == *[0-9]* ]]; then
        echo "[ERROR]" \
             "Synopsis: DEVICE <PROBLEM_LBA> (Need integer or hex value)" >&2
        return 1
    fi

    if [ ! "$lba" ] || [[ ! "$lba" == *[0-9]* ]]; then
        echo "Synopsis: DEV <PROBLE_LBA>"
        echo "smartctl -a /dev/sda ; smartctl -l error -q errorsonly"
        return 1
    fi

    if [[ "$lba" == 0x* ]] || [[ "$lba" == *[a-fA-F]* ]]; then
        lba={lba#0x}   # Remove "0x" prefix
        local upperval=$(echo $lba | tr 'abcdef' 'ABCDEF')
        lba=$(echo "ibase=16 ; $upperval" | bc)
    fi

    max=$(( lba + 64 ))

    while [ $lba -lt $max ]
    do
        echo "LBA $lba"
        ${test+echo} dd if=$dev of=/dev/null bs=512 count=1 skip=$lba
        let lba+=1
    done
}

Badsector ()
{
    local help="\
Synopsis:
  $FUNCNAME [--auto] [--read] [--test] [<other options>] <device> <problem lba>

See manual page how to obtain the <problem lba> value after
running smartctl(1) with options '-t short HARRDISK_DEVICE'"

    local opt_auto opt_test opt_read

    OPTIND=1

    while getopts "aht" arg "$@"
    do
        case "$arg" in
            a)  opt_auto="auto"
                ;;
            h)  echo "$help"
                return 0
                ;;
            t)  opt_read="read"
                ;;
            t)  opt_test="test"
                ;;
            v)  Version
		return 0
                ;;
        esac
    done

    shift $(($OPTIND - 1))

    while :
    do
        case "$1" in
            --auto)
                shift
                opt_auto="auto"
                ;;
            --help)
                shift
                echo "$help"
                return 0
                ;;
            --read)
                shift
                opt_read="read"
                ;;
            --test)
                shift
                opt_test="test"
                ;;
            --version)
                shift
		Version
		return 0
                ;;
            -*)
                shift
                echo "[WARN] Uknown option" >&2
                ;;
            *)
                break
                ;;
        esac
    done

    local dev=$1
    local badsec=$2

    if [ "$opt_read" ]; then
	Readsector $dev $badsect
	return $?
    fi

    local path="/sbin:/usr/sbin:$PATH"
    local PREFIX="$FUNCNAME:"

    if [[ ! "$dev" == /dev/* ]]; then
        echo "$PREFIX [ERROR] Synopsis: <DEVICE> PROBLEM_LBA"
        return 1
    fi

    if [[ ! "$badsec" == *[0-9]* ]]; then
        echo "$PREFIX [ERROR]" \
             "Synopsis: DEVICE <PROBLEM_LBA> (Need integer or hex value)"
        return 1
    fi

    # Convert hex values to integers

    if [[ "$badsec" == 0x* ]] || [[ "$badsec" == *[a-fA-F]* ]]; then
        badsec={badsec#0x}   # Remove "0x" prefix
        local upperval=$(echo $badsec | tr 'abcdef' 'ABCDEF')
        badsec=$(echo "ibase=16 ; $upperval" | bc)
    fi

    local is_mktemp
    which mktemp > /dev/null 2>&1  && is_mktemp="has mktemp"

    local file

    if [ "$is_mktemp" ]; then
        file=$(mktemp -t tmp.$$.fdisk.XXXXXXXXXX)
    else
        file=/tmp/tmp.$$.fdisk
    fi

    PATH="$path" fdisk -lu $dev > $file || return 1

    [ -s $file ] || return 1

    #    Device Boot    Start       End    Blocks   Id  System
    # /dev/sda1   *        63   4209029   2104483+  83  Linux
    # /dev/sda2       4209030   5269319    530145   82  Linux swap

    # in fdisk(1) output, skip extended partitions. Examples:
    #
    # /dev/sda2  97   3648     28531440     f  W95 Ext'd (LBA)
    # /dev/sda3  6931 121601   921094807+   5  Extended

    local lbainfo=$(awk '
        /Ext/ {
            next
        }

        $1 !~ /\/dev/ {
            next
        }

        {
            dev   = $1
            start = $2
            end   = $3

            if ( index(start, "*") > 0 )
            {
                start = $3
                end   = $4
            }

            if ( sec > start  &&  sec < end )
            {
                print dev " " sec - start
                exit
            }
        }
        ' sec="$badsec" $file
    )

    set -- $lbainfo

    local errdev=$1
    local errlba=$2

    #  mount output: /dev/sda8 on /mnt/local/data type ext3 ...

    local mount=$(mount | awk '
        $1 ~ dev {
            print $1 " " $3 " " $5
            exit
        }' dev="$errdev"
    )

    set -- $mount

    local errfs=$2
    local errfstype=$3

    local blksize

    if [[ "$errfstype" == ext* ]]; then
        blksize=$(tune2fs -l $errdev |
            awk '/^Block size/  { print $(NF); exit }')

    elif [ ! "$mount" ]; then
        echo "$PREFIX Can't determine fstype, $errdev is not mounted"
        grep -e "$errdev" /etc/fstab /dev/null
        return 1

    else
        echo "$PREFIX Sorry, no support for mount: $mount"
        return 1
    fi

    local blknumber=$(( errlba * 512 / blksize ))

    echo "$PREFIX Problem in $errdev => $errfs at blknbr $blknumber"

    local msg="
Use debugfs to find out the file:

   debugfs $errdev
   icheck $blknumber
   ... see the inode number
   ncheck <inode>
"

    if ! which expect > /dev/null 2>&1 ||
       ! which debugfs > /dev/null 2>&1
    then
        echo "$PREFIX WARN: Program 'debugfs' or 'expect' not in PATH"
        echo "$msg"
        return 1
    fi

    # Transcript of the session
    #
    # $ debugfs
    # debugfs 1.32 (09-Nov-2002)
    # debugfs:  open /dev/sda3
    # debugfs:  icheck 2269012
    # Block     Inode number
    # 2269012   41032
    # debugfs:  ncheck 41032
    # Inode     Pathname
    # 41032     /S1/R/H/714197568-714203359/H-R-714202192-16.gwf

    # OTHER RESULTS:
    #
    # Block     Inode number
    # 24414763  <block not found>

    local expect fname

    if [ "$is_mktemp" ]; then
        expect=$(mktemp -t tmp.$$.expect.XXXXXXXXXX)
        fname=$(mktemp -t tmp.$$.expect.fname.XXXXXXXXXX)
    else
        expect=/tmp/tmp.$$.expect
        fname=/tmp/tmp.$$.expect.fname
    fi

    cat << EOF > $expect
#!/usr/bin/expect -f

    # Activate debug by uncommenting this line
    # exp_internal 1

    spawn debugfs $errdev

    expect "debugfs:"

    #  This may take while
    set timeout 120
    send "icheck $blknumber\\n"

    expect -re "(\\[0-9\\]+)\\[ \\t\\]+(.*\\[^\\r\\n\\])"
    set block \$expect_out(1,string)
    set inode \$expect_out(2,string)
    set inode [string trimleft \$inode]

    if { [string match -nocase "*found*" \$inode] } {
            send_user "$PREFIX inode at $errfs was not associated to a file\\n"
            send "quit"
            exit 0
    } else {
            send "ncheck  \$inode"
            expect -re "(\[0-9\]+)\[ \t\]+(.*/.*\[^\r\n\])"
            set path \$expect_out(2,string)

            set fd [open "$fname" w]
            puts fd \$path
            close fd

            send "quit"
    }

    exit 1
EOF

    echo "$PREFIX expect $expect"

    if ! expect $expect ; then

        if [ ! -f $fname ]; then
            # Expect script failed completely
            return 1
        fi

        #  Not clean. The inode contains file
        local path=$(< $fname)

        if [ "$opt_auto" ]; then
            local path="$errfs${fname%/}"
            md5sum $path
        else
            echo "To check file read error:"
            echo "    md5sum $fname"
        fi

        return 1
    fi

    local msg="\
To force the disk to reallocate this bad block you could write zeros to
the bad block and sync the disk.

    dd if=/dev/zero of=$errdev bs=$blksize count=1 seek=$blknumber
    sync ; sync
    smartctl -t short $dev
    ... wait for test to finish
    smartctl -l selftest $dev
"

    if [ ! "$opt_auto" ]; then
        echo "$msg"
        return 0
    fi

    local msg=""

    [ "$opt_test" ] && msg=" (TEST mode active: not done)"

    echo "$PREFIX Zeroing $blknumber with dd(1) to force relocating unused block$msg"
    ${opt_test:+echo} dd if=/dev/zero of=$errdev bs=$blksize count=1 seek=$blknumber
    sync
    sync

    echo "$PREFIX will run new test with smartctl -t short $dev$msg"

    ${opt_test:+echo} smartctl -t short $dev 2>&1 | egrep -i 'test.*will.*complete' &&
    echo "$PREFIX Verify results with smartctl -l selftest $dev"
}

Badsector

# End of file