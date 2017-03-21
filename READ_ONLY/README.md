# CPM Tools

This directory contains tools to help with the CPM migration.  They
will generate SQL for various tasks.  That SQL then needs to be run by
a DBA.

Note: These scripts will not run on Windows. They will run on OSX and should
run on Linux.

# Obtaining the CPM tools

Both tools are contained in a single tar file in the GitHub CPM repository
https://github.com/tl-its-umich-edu/ctools-project-migration.git They
are in the directory: src/sql/READ_ONLY.  The most recent build can be
downloaded from the TARS directory. The appropriate tar file starts with
CPMTools and also specifies a build date.

Let the tar file expand during download or double click to expand it.

Open a terminal shell and go the directory created when expanded.

# The tools

There are two tools available.

    * runVerifySiteAccessMembership.sh - Verify that can get the
     sitemembership via the CTools direct api and create sql to fixup
     membership problems if they are found.
     * runRO.sh - generate SQL to make a site read-only.

These are described separately below.

# Tool: Verifying sites have useable membership lists

## script setup

The verifyAccessSiteMembership.sh script requires an input file of
site ids (one per line, # comments and empty lines are ignored).
It also requires creating a
credentials.yml file containing the connection information for
the desired ctools instance.  To create this file copy
the credentials.yml.TEMPLATE file to credentials.yml, uncomment the
correct section for the ctools instance to be examined, and fill in
the appropriate user and password information for a CTools admin
user in that instance.

If you copy the file contents from Google Drive via an application use
Google sheets.  Do *NOT* use MS excel.

In case of a need to restore membership in a site a copy of the
*sakai\_realm\_rl\_gr* should be made in the database for each
instance.  This need only be done once.

## script execution

    ./runVerifyAccessSiteMembership.sh <site id list file name>

There are three output files:
&lt;site id file name>.&lt;time stamp>.membership.txt is a log of
the results of testing site membership.  This file contains 3
columns: the site id, the https status code, and a message.  For
successful requests the message will be "ok".  For unsuccessful
requests the status code will be returned and, if possible, there will
also be sql that can be run later to fix the membership issue.  As a
convenience the sql will be collected into the file &lt;site id file
name>.&lt;timestamp>.membership.deleteunknow.sql and a list
of the sites that had bad users is put in the file &lt;site id file
name>.&lt;timestamp>.membership.updatesites.txt.

## Running the output SQL

Have a DBA run and commit the resulting sql. To see the effect of the
results immediately a CTools admin should reset the memory caches from
the memory Ctools admin site.

The SQL may not work in some exceptional cases.
Case by case solutions may be required for some sites.

# Tool: Making CTools sites Read Only

## script setup

This script requires setting a file of site ids (one per line, # comments and
empty lines are ignored) and a configuration file.  Configuration
files are provided for each CTools instance.  The default is for a
file confgured for production CTools.

It is possible to restore permissions after a read-only operation.
The read-only sql automatically makes a back up copy of the role
function table with a name that includes the date when the sql was
generated.  If a restore is required modify the appropriate yml file
so that the 
ARCHIVE\_ROLE\_FUNCTION\_TABLE contains the name of the
appropriate archive table, one that contains the permissions to
be restored.  This value can only be determined by the person doing
the restore.

## script execution
Run the script as:

    ./runRO.sh <task> <site id file name> {optional configuration file name}

The output sql will automatically be put in the file:

    <site id file name>.<task>.sql

Arguments:

* &lt;task>: Type of sql to generate.  The possible tasks are:
READ\_ONLY\_UPDATE, READ\_ONLY\_LIST, READ\_ONLY\_RESTORE, and
READ\_ONLY\_RESTORE\_LIST. The UPDATE tasks deal with removing
permissions.  The second two deal with restoring permissions from an
archive table.

* &lt;site id file name>

* {optional configuration file name}  This defaults to a configuration
  for the production instance.  The only changes required for this
  file would be for the archive table name.

## Running the output SQL

Have a DBA run and commit the resulting sql. To see the effect of the
results immediately a CTools admin should reset the memory caches from
the memory Ctools admin site.

# Developers only: Modifying and Releasing the scripts

Developers should use the ./buildCPMTools.sh scripts to package up the
perl script into a 'packed' script that can be distributed. The build
will also package all the required files into a tar file for
distribution.  That file should be checked into the TARS directory and
then pushed to the git repository.

NOTE: Developers will need to have some CPAN packages installed to do
a build.  These will include FatPacker and YAML packages.  There may be
others as well.
