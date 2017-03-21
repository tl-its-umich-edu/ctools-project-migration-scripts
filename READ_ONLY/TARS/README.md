# CPM Tools

This directory contains tools to help with the CPM migration.  They
will generate SQL for various tasks.  That SQL then needs to be run by
a DBA.

Note: These scripts will not run on Windows. They will run on OSX and should
run on Linux.

# Obtaining the CPM tools

The CPM tools are contained in a single tar file in the GitHub CPM
repository
https://github.com/tl-its-umich-edu/ctools-project-migration/blob/master/src/sql/READ_ONLY/TARS
 The appropriate tar file starts with
CPMTools and also specifies a build date.

Let the tar file expand during download or double click to expand it.

Open a terminal shell and go the directory created when expanded.

To copy a file in the terminal shell use the *cp* command.  E.g.

   *cp credentials.yml.TEMPLATE credentials.yml*

To open a file in a text editor directly from the terminal use the
open command as shown below. E.g.

*open -a TextEdit credentials.yml*

See the README.md from the tar file for details about the tools.

