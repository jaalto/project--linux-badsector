..  comment: the source is maintained in ReST format.
    Emacs: http://docutils.sourceforge.net/tools/editors/emacs/rst.el
    Manual: http://docutils.sourceforge.net/docs/user/rst/quickref.html

DESCRIPTION
===========

Find and relocate unused bad sectors in ext filesystem

Implement the algorithm described in STANDARDS section for the
ext[2-4] partitions only.

The I<smarmontools> can report problematic bad sectors in LBA
addressing format. This program takes LBA address that smartmaontools
reports as bad and relocates the sector provided that it is unused.

However, if the sector contains data, there is nothing that can be
done. This program is no "spinrite" and it is not cabable of reading or
restoring damaged data.

Project homepage (bugs and source) is at
<http://freecode.com/projects/badsector>

REQUIREMENTS
============

Debian packages mentioned in parenthesis.

* Linux OS
* Bash (bash)
* Standard GNU command line programs (coreutils)
* mktemp (coreutils)
* dd (coreutils)
* fdisk (util-linux)
* debugfs (e2fsprogs)
* expect (expect, which also requires package tcl8.5)
* smartctl (smartmontools)

STANDARDS
=========

*Bad block HOWTO for smartmontools* by Bruce Allen
http://smartmontools.sourceforge.net/BadBlockHowTo.txt

COPYRIGHT AND LICENSE
=====================

Copyright (C) 2007-2012 Jari Aalto <jari.aalto@cante.net>

This project is free; you can redistribute and/or modify it under
the terms of GNU General Public license either version 2 of the
License, or (at your option) any later version.

.. End of file
