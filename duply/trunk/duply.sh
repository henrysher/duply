#!/usr/bin/env bash
#
###############################################################################
#  duply (grown out of ftplicity), is a shell front end to duplicity that     #
#  simplifies the usage by managing settings for backup jobs in profiles.     #
#  It supports executing multiple commands in a batch mode to enable single   #
#  line cron entries and executes pre/post backup scripts.                    #
#  Since version 1.5.0 all duplicity backends are supported. Hence the name   #
#  changed from ftplicity to duply.                                           #
#  See http://duply.net or http://ftplicity.sourceforge.net/ for more info.   #
#  (c) 2006 Christiane Ruetten, Heise Zeitschriften Verlag, Germany           #
#  (c) 2008-2012 Edgar Soldin (changes since version 1.3)                     #
###############################################################################
#  LICENSE:                                                                   #
#  This program is licensed under GPLv2.                                      #
#  Please read the accompanying license information in gpl.txt.               #
###############################################################################
#  TODO/IDEAS/KNOWN PROBLEMS:
#  - possibility to restore time frames (incl. deleted files)
#    realizable by listing each backup and restore from 
#    oldest to the newest, problem: not performant
#  - search file in all backups function and show available
#    versions with backups date (list old avail since 0.6.06)
#  - edit profile opens conf file in vi 
#  - implement log-fd interpretation
#  - add a duplicity option check against the options pending 
#    deprecation since 0.5.10 namely --time-separator
#                               --short-filenames
#                              --old-filenames
#  - add 'exclude_<command>' list usage eg. exclude_verify
#  - featreq 25: a download/install duplicity option
#  - hint on install software if a piece is missing
#  - import/export profile from/to .tgz function !!!
#
#
#  CHANGELOG:
#  1.7.1 (30.3.2014)
#  - bugfix: purge-* commands renamed to purgeFull, purgeIncr due to 
#     incompatibility with new minus batch separator 
#
#  1.7.0 (20.3.2014)
#  - disabled gpg key id plausibility check, too many valid possibilities
#  - featreq 7 "Halt if precondition fails":
#     added and(+), or(-) batch command(separator) support
#  - featreq 26 "pre/post script with shebang line": 
#     if a script is flagged executable it's executed in a subshell 
#     now as opposed to sourced to bash, which is the default
#  - bugfix: do not check if dpbx, swift credentials are set anymore 
#  - bugfix: properly escape profile name, archdir if used as arguments
#  - add DUPL_PRECMD conf setting for use with e.g. trickle
#
#  1.6.0 (1.1.2014)
#  - support gs backend
#  - support dropbox backend
#  - add gpg-agent support to gpg test routines
#  - autoenable --use-agent if passwords were not defined in config
#  - GPG_OPTS are now honored everywhere, keyrings or complete gpg
#    homedir can thus be configured to be located anywhere
#  - always import both secret and public key if avail from config profile
#  - new explanatory comments in initial exclude file
#  - bugfix 7: Duply only imports one key at a time 
#
#  1.5.11 (19.07.2013)
#  - purge-incr command for remove-all-inc-of-but-n-full feature added
#    patch provided by Moritz Augsburger, thanks!
#  - documented version command in man page
#
#  1.5.10 (26.03.2013)
#  - minor indent and documentation fixes
#  - bugfix: exclude filter failed on ubuntu, mawk w/o posix char class support
#  - bugfix: fix url_decoding generally and for python3
#  - bugfix 3609075: wrong script results in status line (thx David Epping)
#
#  1.5.9 (22.11.2012)
#  - bugfix 3588926: filter --exclude* params for restore/fetch ate too much
#  - restore/fetch now also ignores --include* or --exclude='foobar' 
#
#  1.5.8 (26.10.2012)
#  - bugfix 3575487: implement proper cloud files support
#
#  1.5.7 (10.06.2012)
#  - bugfix 3531450: Cannot use space in target URL (file:///) anymore
#
#  1.5.6 (24.5.2012)
#  - commands purge, purge-full have no default value anymore for security 
#    reasons; instead max value can be given via cmd line or must be set
#    in profile; else an error is shown.
#  - minor man page modifications
#
#  versioning scheme will be simplified to [major].[minor].[patch] version
#  with the next version raise
#
#  1.5.5.5 (4.2.2012)
#  - bugfix 3479605: SEL context confused profile folder's permission check
#  - colon ':' in url passphrase got ignored, added python driven url_decoding
#    for user & pass to better process special chars
#
#  1.5.5.4 (16.10.2011)
#  - bugfix 3421268: SFTP passwords from conf ignored and always prompted for
#  - add support for separate sign passphrase (needs duplicity 0.6.14+)
#
#  1.5.5.3 (1.10.2011)
#  - bugfix 3416690: preview threw echo1 error
#  - fix unknown cmds error usage & friends if more than 2 params were given
#
#  1.5.5.2 (23.9.2011)
#  - bugfix 3409643: ssh key auth did ask for passphrase (--ssh-askpass ?)
#  - bugfix: mawk does not support \W and did not split multikey definitions
#  - all parameters should survive  single (') and double (") quotes now
#
#  1.5.5.1 (7.6.2011)
#  - featreq 3311881: add ftps as supported by duplicity 0.6.13 (thx mape2k)
#  - bugfix 3312208: signing detection broke symmetric gpg test routine
#
#  1.5.5 (2.5.2011)
#  - bugfix: fetch problem with space char in path, escape all params 
#    containing non word chars
#  - list available profiles, if given profile cannot be found
#  - added --use-agent configuration hint
#  - bugfix 3174133: --exclude* params in conf DUPL_PARAMS broke 
#    fetch/restore
#  - version command now prints out 'using installed' info
#  - featreq 3166169: autotrust imported keys, based on code submitted by 
#    Martin Ellis - imported keys are now automagically trusted ultimately 
#  - new txt2man feature to create manpages for package maintainers
#
#  1.5.4.2 (6.1.2011)
#  - new command changelog
#  - bugfix 3109884: freebsd awk segfaulted on printf '%*', use print again
#  - bugfix: freebsd awk hangs on 'awk -W version' 
#  - bugfix 3150244: mawk does not know '--version'
#  - minor help text improvements
#  - new env vars CMD_PREV,CMD_NEXT replacing CMD env var for scripts
#
#  1.5.4.1 (4.12.2010)
#  - output awk, python, bash version now in prolog
#  - shebang uses /usr/bin/env now for freebsd compatibility, 
#    bash not in /bin/bash 
#  - new --disable-encryption parameter, 
#    to override profile encr settings for one run
#  - added exclude-if-present setting to conf template
#  - bug 3126972: GPG_PW only needed for signing/symmetric encryption 
#    (even though duplicity still needs it)
#
#  1.5.4 (15.11.2010)
#  - as of 1.5.3 already, new ARCH_DIR config option
#  - multiple key support
#  - ftplicity-Feature Requests-2994929: separate encryption and signing key
#  - key signing of symmetric encryption possible (duplicity patch committed)
#  - gpg tests disable switch
#  - gpg tests now previewable and more intelligent
#
#  1.5.3 (1.11.2010)
#  - bugfix 3056628: improve busybox compatibility, grep did not have -m param
#  - bugfix 2995408: allow empty password for PGP key
#  - bugfix 2996459: Duply erroneously escapes '-' symbol in username
#  - url_encode function is now pythonized
#  - rsync uses FTP_PASSWORD now if duplicity 0.6.10+ , else issue warning
#  - feature 3059262: Make pre and post aware of parameters, 
#                     internal parameters + CMD of pre or post 
#
#  1.5.2.3 (16.4.2010)
#  - bugfix: date again, should now work virtually anywhere
#
#  1.5.2.2 (3.4.2010)
#  - minor bugfix: duplicity 0.6.8b version string now parsable
#  - added INSTALL.txt
#
#  1.5.2.1 (23.3.2010)
#  - bugfix: date formatting is awked now and should work on all platforms
#
#  1.5.2 (2.3.2010)
#  - bugfix: errors print to STD_ERR now, failed tasks print an error message
#  - added --name=duply_<profile> for duplicity 0.6.01+ to name cache folder
#  - simplified & cleaned profileless commands, removed second instance
#  - generalized separator time routines
#  - added support for --no-encryption (GPG_KEY='disabled'), see conf examples
#  - minor fixes
#
#  1.5.1.5 (5.2.2010)
#  - bugfix: added special handling of credentials for rsync, imap(s)
#
#  1.5.1.4 (7.1.2010)
#  - bugfix: nsecs defaults now to zeroes if date does not deliver [0-9]{9}
#  - check if ncftp binary is available if url protocol is ftp
#  - bugfix: duplicity output is now printed to screen directly to resolve
#            'mem alloc problem' bug report
#  - bugfix: passwords will not be in the url anymore to solve the 'duply shows
#            sensitive data in process listing' bug report
#
#  1.5.1.3 (24.12.2009) 'merry xmas'
#  - bugfix: gpg pass now apostrophed to allow space and friends
#  - bugfix: credentials are now url encoded to allow special chars in them
#            a note about url encoding has been added to the conf template
#
#  1.5.1.2 (1.11.2009)
#  - bugfix: open parenthesis in password broke duplicity execution
#  - bugfix: ssh/scp backend does not always need credentials e.g. key auth
#
#  1.5.1.1 (21.09.2009)
#  - bugfix: fixed s3[+http] TARGET_PASS not needed routine
#  - bugfix: TYPO in duply 1.5.1 prohibited the use of /etc/duply
#    see https://sourceforge.net/tracker/index.php?func=detail&
#                aid=2864410&group_id=217745&atid=1041147
#
#  1.5.1 (21.09.2009) - duply (fka. ftplicity)
#  - first things first: ftplicity (being able to support all backends since 
#    some time) will be called duply (fka. ftplicity) from now on. The addendum
#    is for the time being to circumvent confusion.
#  - bugfix: exit code is 1 (error) not 0 (success), if at least on duplicity 
#            command failed
#  - s3[+http] now supported natively by translating user/pass to access_key/
#    secret_key environment variables needed by duplicity s3 boto backend 
#  - bugfix: additional output lines do not confuse version check anymore
#  - list command supports now age parameter (patch by stefan on feature 
#    request tracker)
#  - bugfix: option/param pairs are now correctly passed on to duplicity
#  - bugfix: s3[+http] needs no TARGET_PASS if command is read only
#
#  1.5.0.2 (31.07.1009)
#  - bugfix: insert password in target url didn't work with debian mawk
#            related to previous bug report
#
#  1.5.0.1 (23.07.2009)
#  - bugfix: gawk gensub dependency raised an error on debian's default mawk
#            replaced with match/substr command combination (bug report)
#            https://sf.net/tracker/?func=detail&atid=1041147&aid=2825388&
#            group_id=217745
#
#  1.5.0 (01.07.2009)
#  - removed ftp limitation, all duplicity backends should work now
#  - bugfix: date for separator failed on openwrt busybox date, added a 
#    detecting workaround, milliseconds are not available w/ busybox date
#
#  1.4.2.1 (14.05.2009)
#  - bugfix: free temp space detection failed with lvm, fixed awk parse routine
#
#  1.4.2 (22.04.2009)
#  - gpg keys are now exported as gpgkey.[id].asc , the suffix reflects the
#    armored ascii nature, the id helps if the key is switched for some reason
#    im/export routines are updated accordingly (import is backward compatible 
#    to the old profile/gpgkey files)         
#  - profile argument is treated as path if it contains slashes 
#    (for details see usage)
#  - non-ftplicity options (all but --preview currently) are now passed 
#    on to duplicity 
#  - removed need for stat in secure_conf, it is ls based now
#  - added profile folder readable check
#  - added gpg version & home info output
#  - awk utility availability is now checked, because it was mandatory already
#  - tmp space is now checked on writability and space requirement
#    test fails on less than 25MB or configured $VOLSIZE, 
#    test warns if there is less than two times $VOLSIZE because 
#    that's required for --asynchronous-upload option  
#  - gpg functionality is tested now before executing duplicity 
#    test drive contains encryption, decryption, comparison, cleanup
#    this is meant to detect non trusted or other gpg errors early
#  - added possibility of doing symmetric encryption with duplicity
#    set GPG_KEY="" or simply comment it out
#  - added hints in config template on the depreciation of 
#    --short-filenames, --time-separator duplicity options
#
#  new versioning scheme 1.4.2b => 1.4.2, 
#  beta b's are replaced by a patch count number e.g. 1.4.2.1 will be assigned
#  to the first bug fixing version and 1.4.2.2 to the second and so on
#  also the releases will now have a release date formatted (Day.Month.Year)
#
#  1.4.1b1 - bugfix: ftplicity changed filesystem permission of a folder
#            named exactly as the profile if existing in executing dir
#          - improved plausibility checking of config and profile folder
#          - secure_conf only acts if needed and prints a warning now
#
#  1.4.1b  - introduce status (duplicity collection-status) command
#          - pre/post script output printed always now, not only on errors
#          - new config parameter GPG_OPTS to pass gpg options
#            added examples & comments to profile template conf
#          - reworked separator times, added duration display
#          - added --preview switch, to preview generated command lines
#          - disabled MAX_AGE, MAX_FULL_BACKUPS, VERBOSITY in generated
#            profiles because they have reasonable defaults now if not set
#
#  1.4.0b1 - bugfix: incr forces incremental backups on duplicity,
#            therefore backup translates to pre_bkp_post now
#          - bugfix: new command bkp, which represents duplicity's 
#            default action (incr or full if full_if_older matches
#            or no earlier backup chain is found)
#
#  new versioning scheme 1.4 => 1.4.0, added new minor revision number
#  this is meant to slow down the rapid version growing but still keep 
#  versions cleanly separated.
#  only additional features will raise the new minor revision number. 
#  all releases start as beta, each bugfix release will raise the beta 
#  count, usually new features arrive before a version 'ripes' to stable
#    
#  1.4.0b
#    1.4b  - added startup info on version, time, selected profile
#          - added time output to separation lines
#          - introduced: command purge-full implements duplicity's 
#            remove-all-but-n-full functionality (patch by unknown),
#            uses config variable $MAX_FULL_BACKUPS (default = 1)
#          - purge config var $MAX_AGE defaults to 1M (month) now 
#          - command full does not execute pre/post anymore
#            use batch command pre_full_post if needed 
#          - introduced batch mode cmd1_cmd2_etc
#            (in turn removed the bvp command)
#          - unknown/undefined command issues a warning/error now
#          - bugfix: version check works with 0.4.2 and older now
#    1.3b3 - introduced pre/post commands to execute/debug scripts
#          - introduced bvp (backup, verify, purge)
#          - bugfix: removed need for awk gensub, now mawk compatible
#    1.3b2 - removed pre/post need executable bit set 
#          - profiles now under ~/.ftplicity as folders
#          - root can keep profiles in /etc/ftplicity, folder must be
#            created by hand, existing profiles must be moved there
#          - removed ftplicity in path requirement
#          - bugfix: bash < v.3 did not know '=~'
#          - bugfix: purge works again 
#    1.3   - introduces multiple profiles support
#          - modified some script errors/docs
#          - reordered gpg key check import routine
#          - added 'gpg key id not set' check
#          - added error_gpg (adds how to setup gpg key howto)
#          - bugfix: duplicity 0.4.4RC4+ parameter syntax changed
#          - duplicity_version_check routine introduced
#          - added time separator, shortnames, volsize, full_if_older 
#            duplicity options to config file (inspired by stevie 
#            from http://weareroot.de) 
#    1.1.1 - bugfix: encryption reactivated
#    1.1   - introduced config directory
#    1.0   - first release
###############################################################################


# important definitions #######################################################

ME_LONG="$0"
ME="$(basename $0)"
ME_NAME="${ME%%.*}"
ME_VERSION="1.7.1"
ME_WEBSITE="http://duply.net"

# default config values
DEFAULT_SOURCE='/path/of/source'
DEFAULT_TARGET='scheme://user[:password]@host[:port]/[/]path'
DEFAULT_TARGET_USER='_backend_username_'
DEFAULT_TARGET_PASS='_backend_password_'
DEFAULT_GPG_KEY='_KEY_ID_'
DEFAULT_GPG_PW='_GPG_PASSWORD_'

# function definitions ##########################
function set_config { # sets config vars
  local CONFHOME_COMPAT="$HOME/.ftplicity"
  local CONFHOME="$HOME/.duply"
  local CONFHOME_ETC_COMPAT="/etc/ftplicity"
  local CONFHOME_ETC="/etc/duply"

  # confdir can be delivered as path (must contain /)
  if [ `echo $FTPLCFG | grep /` ] ; then 
    CONFDIR=$(readlink -f $FTPLCFG 2>/dev/null || \
              ( echo $FTPLCFG|grep -v '^/' 1>/dev/null 2>&1 \
               && echo $(pwd)/${FTPLCFG} ) || \
              echo ${FTPLCFG})          
  # or DEFAULT in home/.duply folder (NEW)
  elif [ -d "${CONFHOME}" ]; then
    CONFDIR="${CONFHOME}/${FTPLCFG}"
  # or in home/.ftplicity folder (OLD)
  elif [ -d "${CONFHOME_COMPAT}" ]; then
    CONFDIR="${CONFHOME_COMPAT}/${FTPLCFG}"
    warning_oldhome "${CONFHOME_COMPAT}" "${CONFHOME}"
  # root can put profiles under /etc/duply (NEW) if path exists
  elif [ -d "${CONFHOME_ETC}" ] && [ "$EUID" -eq 0 ]; then
    CONFDIR="${CONFHOME_ETC}/${FTPLCFG}"
  # root can keep profiles under /etc/ftplicity (OLD) if path exists
  elif [ -d "${CONFHOME_ETC_COMPAT}" ] && [ "$EUID" -eq 0 ]; then
    CONFDIR="${CONFHOME_ETC_COMPAT}/${FTPLCFG}"
    warning_oldhome "${CONFHOME_ETC_COMPAT}" "${CONFHOME_ETC}"
  # hmm no profile folder there, then use default for error later
  else
    CONFDIR="${CONFHOME}/${FTPLCFG}" # continue, will fail later in main
  fi

  # remove trailing slash, get profile name etc.
  CONFDIR="${CONFDIR%/}"
  NAME="${CONFDIR##*/}"
  CONF="$CONFDIR/conf"
  PRE="$CONFDIR/pre"
  POST="$CONFDIR/post"
  EXCLUDE="$CONFDIR/exclude"
  KEYFILE="$CONFDIR/gpgkey.asc"
  
}

function version_info { # print version information
  cat <<END
  $ME version $ME_VERSION
  ($ME_WEBSITE)
END
}

function version_info_using { 
  cat <<END
$(version_info)

  $(using_info)
END
}

function using_info {
  duplicity_version_get
  # freebsd awk (--version only), debian mawk (-W version only), deliver '' so awk does not wait for input
  AWK_VERSION=$((awk --version '' 2>/dev/null || awk -W version '' 2>/dev/null) | awk '/.+/{sub(/^[Aa][Ww][Kk][ \t]*/,"",$0);print $0;exit}')
  PYTHON_VERSION=$(python -V 2>&1| awk '{print tolower($0);exit}')
  GPG_INFO=`gpg --version 2>/dev/null| awk '/^gpg/{v=$1" "$3};/^Home/{print v" ("$0")"}'`
  BASH_VERSION=$(bash --version | awk '/^GNU bash, version/{sub(/GNU bash, version[ ]+/,"",$0);print $0}')
  echo -e "Using installed duplicity version ${DUPL_VERSION:-(not found)}${PYTHON_VERSION+, $PYTHON_VERSION}\
${GPG_INFO:+, $GPG_INFO}${AWK_VERSION:+, awk '${AWK_VERSION}'}${BASH_VERSION:+, bash '${BASH_VERSION}'}."
}

function usage_info { # print usage information

  cat <<USAGE_EOF
VERSION:
$(version_info)
  
DESCRIPTION: 
  Duply deals as a wrapper for the mighty duplicity magic.
  It simplifies running duplicity with cron or on command line by:

    - keeping recurring settings in profiles per backup job
    - enabling batch operations eg. backup_verify_purge
    - executing pre/post scripts for every command
    - precondition checking for flawless duplicity operation

  For each backup job one configuration profile must be created.
  The profile folder will be stored under '~/.${ME_NAME}/<profile>'
  (where ~ is the current users home directory).
  Hint:  
   If the folder '/etc/${ME_NAME}' exists, the profiles for the super
   user root will be searched & created there.

USAGE:
  first time usage (profile creation):  
    $ME <profile> create

  general usage in single or batch mode (see EXAMPLES):  
    $ME <profile> <command>[[_|+|-]<command>[_|+|-]...] [<options> ...]

  For batches the conditional separators can also be written as pseudo commands
  and(+), or(-). See SEPARATORS for details.

  Non $ME options are passed on to duplicity (see OPTIONS).
  All conf parameters can also be defined in the environment instead.

PROFILE:
  Indicated by a path or a profile name (<profile>), which is resolved 
  to '~/.${ME_NAME}/<profile>' (~ expands to environment variable \$HOME).

  Superuser root can place profiles under '/etc/${ME_NAME}'. Simply create
  the folder manually before running $ME as superuser.
  Note:  
    Already existing profiles in root's profile folder will cease to work
    unless there are moved to the new location manually.

  example 1:   $ME humbug backup

  Alternatively a _path_ might be used e.g. useful for quick testing, 
  restoring or exotic locations. Shell expansion should work as usual.
  Hint:  
    The path must contain at least one path separator '/', 
    e.g. './test' instead of only 'test'.

  example 2:   $ME ~/.${ME_NAME}/humbug backup

SEPARATORS:
  _ (underscore)  
             neutral separator
  + (plus sign), _and_  
             conditional AND
             the next command will only be executed if the previous succeeded
  - (minus sign), _or_  
             conditional OR
             the next command will only be executed if the previous failed

   example:  
    'pre_and_bkp_or_verify_post' translates to 'pre+bkp-verify_post

COMMANDS:
  usage      get usage help text

  and/or     pseudo commands for better batch cmd readability (see SEPARATORS)
  create     creates a configuration profile
  backup     backup with pre/post script execution (batch: pre_bkp_post),
              full (if full_if_older matches or no earlier backup is found)
              incremental (in all other cases)
  pre/post   execute '<profile>/$(basename "$PRE")', '<profile>/$(basename "$POST")' scripts
  bkp        as above but without executing pre/post scripts
  full       force full backup
  incr       force incremental backup
  list [<age>]  
             list all files in backup (as it was at <age>, default: now)
  status     prints backup sets and chains currently in repository
  verify     list files changed since latest backup
  restore <target_path> [<age>]  
             restore the complete backup to <target_path> [as it was at <age>]
  fetch <src_path> <target_path> [<age>]  
             fetch single file/folder from backup [as it was at <age>]
  purge [<max_age>] [--force]  
             list outdated backup files (older than \$MAX_AGE)
              [use --force to actually delete these files]
  purgeFull [<max_full_backups>] [--force]  
             list outdated backup files (\$MAX_FULL_BACKUPS being the number of
             full backups and associated incrementals to keep, counting in 
             reverse chronological order)
              [use --force to actually delete these files]
  purgeIncr [<max_fulls_with_incrs>] [--force]  
             list outdated incremental backups (\$MAX_FULLS_WITH_INCRS being 
             the number of full backups which associated incrementals will be
             kept, counting in reverse chronological order) 
              [use --force to actually delete these files]
  cleanup [--force]  
             list broken backup chain files archives (e.g. after unfinished run)
              [use --force to actually delete these files]

  changelog  print changelog / todo list
  txt2man    feature for package maintainers - create a manpage based on the 
             usage output. download txt2man from http://mvertes.free.fr/, put 
             it in the PATH and run '$ME txt2man' to create a man page.
  version    show version information of $ME and needed programs

OPTIONS:
  --force    passed to duplicity (see commands: purge, purge-full, cleanup)
  --preview  do nothing but print out generated duplicity command lines
  --disable-encryption  
             disable encryption, overrides profile settings

PRE/POST SCRIPTS:
  All internal duply variables will be readable in the scripts.
  Some of interest might be

    CONFDIR, SOURCE, TARGET_URL_<PROT|HOSTPATH|USER|PASS>, 
    GPG_<KEYS_ENC|KEY_SIGN|PW>, CMD_<PREV|NEXT>

  The CMD_* variables were introduced to allow different actions according to 
  the command the scripts were attached to e.g. 'pre_bkp_post_pre_verify_post' 
  will call the pre script two times, with CMD_NEXT variable set to 'bkp' 
  on the first and to 'verify' on the second run.

EXAMPLES:
  create profile 'humbug':  
    $ME humbug create (now edit the resulting conf file)
  backup 'humbug' now:  
    $ME humbug backup
  list available backup sets of profile 'humbug':  
    $ME humbug status
  list and delete obsolete backup archives of 'humbug':  
    $ME humbug purge --force
  restore latest backup of 'humbug' to /mnt/restore:  
    $ME humbug restore /mnt/restore
  restore /etc/passwd of 'humbug' from 4 days ago to /root/pw:  
    $ME humbug fetch etc/passwd /root/pw 4D
    (see "duplicity manpage", section TIME FORMATS)
  a one line batch job on 'humbug' for cron execution:  
    $ME humbug backup_verify_purge --force

FILES:
  in profile folder '~/.${ME_NAME}/<profile>' or '/etc/${ME_NAME}'
  conf             profile configuration file
  pre,post         pre/post scripts (see above for details)
  gpgkey.*.asc     exported GPG key files
  exclude          a globbing list of included or excluded files/folders
                   (see "duplicity manpage", section FILE SELECTION)

$(hint_profile)

SEE ALSO:
  duplicity man page:
    duplicity(1) or http://duplicity.nongnu.org/duplicity.1.html
USAGE_EOF
}

# to check call 'duply txt2man | man -l -'
function usage_txt2man {
  usage_info | \
  awk '/^^[^[:lower:][:space:]][^[:lower:]]+$/{gsub(/[^[:upper:]]/," ",$0)}{print}' |\
  txt2man -t"$(toupper "${ME_NAME}")" -s1 -r"${ME_NAME}-${ME_VERSION}" -v'User Manuals'
}

function changelog {
  cat $ME_LONG | awk '/^#####/{on=on+1}(on==3){sub(/^#(  )?/,"",$0);print}'
}

function create_config {
  if [ ! -d "$CONFDIR" ] ; then
    mkdir -p "$CONFDIR" || error "Couldn't create config '$CONFDIR'."
  # create initial config file
    cat <<EOF >"$CONF"
# gpg encryption settings, simple settings:
#  GPG_KEY='disabled' - disables encryption alltogether
#  GPG_KEY='<key1>[,<key2>]'; GPG_PW='pass' - encrypt with keys, sign 
#    with key1 if secret key available and use GPG_PW for sign & decrypt
#  GPG_PW='passphrase' - symmetric encryption using passphrase only
GPG_KEY='${DEFAULT_GPG_KEY}'
GPG_PW='${DEFAULT_GPG_PW}'
# gpg encryption settings in detail (extended settings)
#  the above settings translate to the following more specific settings
#  GPG_KEYS_ENC='<keyid1>,[<keyid2>,...]' - list of pubkeys to encrypt to
#  GPG_KEY_SIGN='<keyid1>|disabled' - a secret key for signing
#  GPG_PW='<passphrase>' - needed for signing, decryption and symmetric
#   encryption. If you want to deliver different passphrases for e.g. 
#   several keys or symmetric encryption plus key signing you can use
#   gpg-agent. Add '--use-agent' to the duplicity parameters below.
#   also see "A NOTE ON SYMMETRIC ENCRYPTION AND SIGNING" in duplicity manpage
# notes on en/decryption
#  private key and passphrase will only be needed for decryption or signing.
#  decryption happens on restore and incrementals (compare archdir contents).
#  for security reasons it makes sense to separate the signing key from the
#  encryption keys. https://answers.launchpad.net/duplicity/+question/107216
#GPG_KEYS_ENC='<pubkey1>,<pubkey2>,...'
#GPG_KEY_SIGN='<prvkey>'
# set if signing key passphrase differs from encryption (key) passphrase
# NOTE: available since duplicity 0.6.14, translates to SIGN_PASSPHRASE
#GPG_PW_SIGN='<signpass>'

# gpg options passed from duplicity to gpg process (default='')
# e.g. "--trust-model pgp|classic|direct|always" 
#   or "--compress-algo=bzip2 --bzip2-compress-level=9"
#   or "--personal-cipher-preferences AES256,AES192,AES..."
#   or "--homedir ~/.duply" - keep keyring and gpg settings duply specific
#GPG_OPTS=''

# disable preliminary tests with the following setting
#GPG_TEST='disabled'

# credentials & server address of the backup target (URL-Format)
# syntax is
#   scheme://[user:password@]host[:port]/[/]path
# for details see duplicity manpage, section URL Format
#   http://duplicity.nongnu.org/duplicity.1.html#sect8
# probably one out of
#   # for cloudfiles backend user id is CLOUDFILES_USERNAME, password is 
#   # CLOUDFILES_APIKEY, you might need to set CLOUDFILES_AUTHURL manually
#   cf+http://[user:password@]container_name
#   dpbx:///some_dir
#   file://[relative|/absolute]/local/path
#   ftp[s]://user[:password]@other.host[:port]/some_dir
#   gdocs://user[:password]@other.host/some_dir
#   # for the google cloud storage (since duplicity 0.6.22)
#   # user/password are GS_ACCESS_KEY_ID/GS_SECRET_ACCESS_KEY
#   gs://bucket[/prefix] 
#   hsi://user[:password]@other.host/some_dir
#   imap[s]://user[:password]@host.com[/from_address_prefix]
#   mega://user[:password]@mega.co.nz/some_dir
#   rsync://user[:password]@host.com[:port]::[/]module/some_dir
#   # rsync over ssh (only keyauth)
#   rsync://user@host.com[:port]/[relative|/absolute]_path
#   # for the s3 user/password are AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY
#   s3://[user:password@]host/bucket_name[/prefix]
#   s3+http://[user:password@]bucket_name[/prefix]
#   # scp and sftp are aliases for the ssh backend
#   ssh://user[:password]@other.host[:port]/[/]some_dir
#   swift://container_name
#   tahoe://alias/directory
#   # for Ubuntu One set TARGET_PASS to oauth access token
#   #   "consumer_key:consumer_secret:token:token_secret"
#   # if non given credentials will be prompted for and one will be created
#   u1://host_is_ignored/volume_path
#   u1+http:///volume_path
#   webdav[s]://user[:password]@other.host/some_dir
# ATTENTION: characters other than A-Za-z0-9.-_.~ in the URL have 
#            to be replaced by their url encoded pendants, see
#            http://en.wikipedia.org/wiki/Url_encoding 
#            if you define the credentials as TARGET_USER, TARGET_PASS below 
#            duply will try to url_encode them for you if the need arises
TARGET='${DEFAULT_TARGET}'
# optionally the username/password can be defined as extra variables
# setting them here _and_ in TARGET results in an error
#TARGET_USER='${DEFAULT_TARGET_USER}'
#TARGET_PASS='${DEFAULT_TARGET_PASS}'

# base directory to backup
SOURCE='${DEFAULT_SOURCE}'

# a command that runs duplicity e.g. 
#  shape bandwidth use via trickle
#  "trickle -s -u 640 -d 5120" # 5Mb up, 40Mb down"
#DUPL_PRECMD=""

# exclude folders containing exclusion file (since duplicity 0.5.14)
# Uncomment the following two lines to enable this setting.
#FILENAME='.duplicity-ignore'
#DUPL_PARAMS="\$DUPL_PARAMS --exclude-if-present '\$FILENAME'"

# Time frame for old backups to keep, Used for the "purge" command.  
# see duplicity man page, chapter TIME_FORMATS)
#MAX_AGE=1M

# Number of full backups to keep. Used for the "purge-full" command. 
# See duplicity man page, action "remove-all-but-n-full".
#MAX_FULL_BACKUPS=1

# Number of full backups for which incrementals will be kept for.
# Used for the "purge-incr" command.
# See duplicity man page, action "remove-all-inc-of-but-n-full".
#MAX_FULLS_WITH_INCRS=1

# activates duplicity --full-if-older-than option (since duplicity v0.4.4.RC3) 
# forces a full backup if last full backup reaches a specified age, for the 
# format of MAX_FULLBKP_AGE see duplicity man page, chapter TIME_FORMATS
# Uncomment the following two lines to enable this setting.
#MAX_FULLBKP_AGE=1M
#DUPL_PARAMS="\$DUPL_PARAMS --full-if-older-than \$MAX_FULLBKP_AGE " 

# sets duplicity --volsize option (available since v0.4.3.RC7)
# set the size of backup chunks to VOLSIZE MB instead of the default 25MB.
# VOLSIZE must be number of MB's to set the volume size to.
# Uncomment the following two lines to enable this setting. 
#VOLSIZE=50
#DUPL_PARAMS="\$DUPL_PARAMS --volsize \$VOLSIZE "

# verbosity of output (error 0, warning 1-2, notice 3-4, info 5-8, debug 9)
# default is 4, if not set
#VERBOSITY=5

# temporary file space. at least the size of the biggest file in backup
# for a successful restoration process. (default is '/tmp', if not set)
#TEMP_DIR=/tmp

# Modifies archive-dir option (since 0.6.0) Defines a folder that holds 
# unencrypted meta data of the backup, enabling new incrementals without the 
# need to decrypt backend metadata first. If empty or deleted somehow, the 
# private key and it's password are needed.
# NOTE: This is confidential data. Put it somewhere safe. It can grow quite 
#       big over time so you might want to put it not in the home dir.
# default '~/.cache/duplicity/duply_<profile>/'
# if set  '\${ARCH_DIR}/<profile>'
#ARCH_DIR=/some/space/safe/.duply-cache

# DEPRECATED setting
# sets duplicity --time-separator option (since v0.4.4.RC2) to allow users 
# to change the time separator from ':' to another character that will work 
# on their system.  HINT: For Windows SMB shares, use --time-separator='_'.
# NOTE: '-' is not valid as it conflicts with date separator.
# ATTENTION: only use this with duplicity < 0.5.10, since then default file 
#            naming is compatible and this option is pending depreciation 
#DUPL_PARAMS="\$DUPL_PARAMS --time-separator _ "

# DEPRECATED setting
# activates duplicity --short-filenames option, when uploading to a file
# system that can't have filenames longer than 30 characters (e.g. Mac OS 8)
# or have problems with ':' as part of the filename (e.g. Microsoft Windows)
# ATTENTION: only use this with duplicity < 0.5.10, later versions default file 
#            naming is compatible and this option is pending depreciation
#DUPL_PARAMS="\$DUPL_PARAMS --short-filenames "

# more duplicity command line options can be added in the following way
# don't forget to leave a separating space char at the end
#DUPL_PARAMS="\$DUPL_PARAMS --put_your_options_here " 

EOF

# create initial exclude file
    cat <<EOF >"$EXCLUDE"
# although called exclude, this file is actually a globbing file list
# duplicity accepts some globbing patterns, even including ones here
# here is an example, this incl. only 'dir/bar' except it's subfolder 'foo'
# - dir/bar/foo
# + dir/bar
# - **
# for more details see duplicity manpage, section File Selection
# http://duplicity.nongnu.org/duplicity.1.html#sect9

EOF

  # Hints on first usage
  cat <<EOF

Congratulations. You just created the profile '$FTPLCFG'.
The initial config file has been created as 
'$CONF'.
You should now adjust this config file to your needs.

$(hint_profile)

EOF
fi

}

# used in usage AND create_config
function hint_profile {
  cat <<EOF
IMPORTANT:
  Copy the _whole_ profile folder after the first backup to a safe place.
  It contains everything needed to restore your backups. You will need 
  it if you have to restore the backup from another system (e.g. after a 
  system crash). Keep access to these files restricted as they contain 
  _all_ informations (gpg data, ftp data) to access and modify your backups.

  Repeat this step after _all_ configuration changes. Some configuration 
  options are crucial for restoration.

EOF
}

function separator {
  echo "--- $@ ---"
}

function inform {
  echo -e "\nINFO:\n\n$@\n"
}

function warning {
  echo -e "\nWARNING:\n\n$@\n"
}

function warning_oldhome {
  local old=$1 new=$2
  warning " ftplicity changed name to duply since you created your profiles.
  Please rename the old folder
  '$old'
  to
  '$new'
  and this warning will disappear.
  If you decide not to do so profiles will _only_ work from the old location."
}

function error_print {
  echo -e "$@" >&2
}

function error {
  error_print "\nSorry. A fatal ERROR occured:\n\n$@\n"
  exit -1
}

function error_gpg {
  [ -n "$2" ] && local hint="\n  $2\n\n  "
  
  error "$1

Hint${hint:+s}:
  ${hint}Maybe you have not created a gpg key yet (e.g. gpg --gen-key)?
  Don't forget the used _password_ as you will need it.
  When done enter the 8 digit id & the password in the profile conf file.

  The key id can be found doing a 'gpg --list-keys'. In the  example output 
  below the key id would be FFFFFFFF for the public key.

  pub   1024D/FFFFFFFF 2007-12-17
  uid                  duplicity
  sub   2048g/899FE27F 2007-12-17
"
}

# TODO
function error_gpg_key {
  local KEY_ID=$1
  local KIND=$2
  error_gpg "${KIND} gpg key '${KEY_ID}' cannot be found." \
"Doublecheck if the above key is listed by 'gpg --list-keys' or available 
  as gpg key file '$(basename "$(gpg_keyfile ${KEY_ID})")' in the profile folder.
  If not you can put it there and $ME will autoimport it on the next run.
  Alternatively import it manually as the user you plan to run $ME with."
}

function error_gpg_test {
  [ -n "$2" ] && local hint="\n  $2\n\n  "

  error "$1

Hint${hint:+s}:
  ${hint}This error means that gpg is probably misconfigured or not working 
  correctly. The error message above should help to solve the problem.
  However, if for some reason $ME should misinterpret the situation you 
  can define GPG_TEST='disabled' in the conf file to bypass the test.
  Please do not forget to report the bug in order to resolve the problem
  in future versions of $ME.
"
}

function error_path {
  error "$@
PATH='$PATH'
"
}

function error_to_string {
	[ -n "$1" ] && [ "$1" -eq 0 ] && echo "OK" || echo "FAILED 'code $1'"
}

function duplicity_version_get {
	var_isset DUPL_VERSION && return
	DUPL_VERSION=`duplicity --version 2>&1 | awk '/^duplicity /{print $2; exit;}'`
	#DUPL_VERSION='0.6.08b' #,0.4.4.RC4,0.6.08b
	DUPL_VERSION_VALUE=0
	DUPL_VERSION_AWK=$(awk -v v="$DUPL_VERSION" 'BEGIN{
	if (match(v,/[^\.0-9]+[0-9]*$/)){
		rest=substr(v,RSTART,RLENGTH);v=substr(v,0,RSTART-1);}
	if (pos=match(rest,/RC([0-9]+)$/)) rc=substr(rest,pos+2)
	split(v,f,"[. ]"); if(f[1]f[2]f[3]~/^[0-9]+$/) vvalue=f[1]*10000+f[2]*100+f[3]; else vvalue=0
	print "#"v"_"rest"("rc"):"f[1]"-"f[2]"-"f[3]
	print "DUPL_VERSION_VALUE=\047"vvalue"\047"
	print "DUPL_VERSION_RC=\047"rc"\047"
	print "DUPL_VERSION_SUFFIX=\047"rest"\047"
	}')
	eval "$DUPL_VERSION_AWK"
	#echo -e ",$DUPL_VERSION,$DUPL_VERSION_VALUE,$DUPL_VERSION_RC,$DUPL_VERSION_SUFFIX,"
}

function duplicity_version_check {
	if [ $DUPL_VERSION_VALUE -eq 0 ]; then
		inform "duplicity version check failed (please report, this is a bug)" 
	elif [ $DUPL_VERSION_VALUE -le 404 ] && [ ${DUPL_VERSION_RC:-4} -lt 4 ]; then
		error "The installed version $DUPL_VERSION is incompatible with $ME v$ME_VERSION.
You should upgrade your version of duplicity to at least v0.4.4RC4 or
use the older ftplicity version 1.1.1 from $ME_WEBSITE."
	fi
}

function duplicity_version_ge {
  [ "$DUPL_VERSION_VALUE" -ge "$1" ]
}

function duplicity_version_lt {
  ! duplicity_version_ge "$1"
}

function run_script { # run pre/post scripts
  local ERR=0
  local SCRIPT="$1"
  if [ ! -z "$PREVIEW" ] ; then	
    echo "$([ ! -x "$SCRIPT" ] && echo ". ")$SCRIPT"
  elif [ -r "$SCRIPT" ] ; then 
    echo -n "Running '$SCRIPT' "
    if [ -x "$SCRIPT" ]; then
      OUT=$("$SCRIPT" 2>&1)
      ERR=$?
    else
      OUT=$(. "$SCRIPT" 2>&1)
      ERR=$?
    fi
    [ $ERR -eq "0" ] && echo "- OK" || echo "- FAILED (code $ERR)"
    echo -en ${OUT:+"Output: $OUT\n"} ;
  else
    echo "Skipping n/a script '$SCRIPT'."
  fi
  return $ERR
}

function run_cmd {
  # run or print escaped cmd string
  CMD_ERR=0
  if [ -n "$PREVIEW" ]; then
    CMD_OUT=$( echo "$@ 2>&1" )
    CMD_MSG="-- Run cmd '$CMD_MSG' --\n$CMD_OUT"
  elif [ -n "$CMD_DISABLED" ]; then
    CMD_MSG="$CMD_MSG (DISABLED) - $CMD_DISABLED"
  else
    CMD_OUT=` eval $@ 2>&1 `
    CMD_ERR=$?
    if [ "$CMD_ERR" = "0" ]; then
      CMD_MSG="$CMD_MSG (OK)"
    else
      CMD_MSG="$CMD_MSG (FAILED)"
    fi
  fi
  echo -e "$CMD_MSG"
  # reset
  unset CMD_DISABLED CMD_MSG
  return $CMD_ERR
}

function qw { quotewrap "$@"; }

function quotewrap {
  local param="$@"
  # quote strings having non word chars (e.g. spaces)
  if echo "$param"  | awk '/[^A-Za-z0-9_\.\-]/{exit 0}{exit 1}'; then
    echo "$param" | awk '{\
      gsub(/[\047]/,"\047\\\047\047",$0);\
      gsub(/[\042]/,"\047\\\042\047",$0);\
      print "\047"$0"\047"}'
    return
  fi
  echo $param
}

function duplicity_params_global {
  # already done? return
  var_isset 'DUPL_PARAMS_GLOBAL' && return
  local DUPL_ARG_ENC

  # use key only if set in config, else leave it to symmetric encryption
  if gpg_disabled; then
    local DUPL_PARAM_ENC='--no-encryption'
  else
    local DUPL_PARAM_ENC=$(gpg_prefix_keyset ' --encrypt-key ' 'GPG_KEYS_ENC')
    gpg_signing && local DUPL_PARAM_SIGN=$(gpg_prefix_keyset ' --sign-key ' 'GPG_KEY_SIGN')
    # interpret password settings
    var_isset 'GPG_PW' && DUPL_ARG_ENC="PASSPHRASE=$(qw "${GPG_PW}")"
    var_isset 'GPG_PW_SIGN' && DUPL_ARG_ENC="${DUPL_ARG_ENC} SIGN_PASSPHRASE=$(qw "${GPG_PW_SIGN}")"
  fi

  local GPG_OPTS=${GPG_OPTS:+"--gpg-options $(qw "${GPG_OPTS}")"}

  # set name for dupl archive folder, since 0.6.0
  if duplicity_version_ge 601; then
    local DUPL_ARCHDIR=''
    if var_isset 'ARCH_DIR'; then
      DUPL_ARCHDIR="--archive-dir $(qw "${ARCH_DIR}")"
    fi
    DUPL_ARCHDIR="${DUPL_ARCHDIR} --name $(qw "duply_${NAME}")"
  fi

DUPL_PARAMS_GLOBAL="${DUPL_ARCHDIR} ${DUPL_PARAM_ENC} \
${DUPL_PARAM_SIGN} --verbosity '${VERBOSITY:-4}' \
 ${GPG_OPTS}"

DUPL_VARS_GLOBAL="TMPDIR='$TEMP_DIR' \
 ${DUPL_ARG_ENC}"
}

# filter the DUPL_PARAMS var from conf
function duplicity_params_conf {
	# reuse cmd var from main loop
	## in/exclude parameters are currently not supported on restores
	if [ "$cmd" = "fetch" ] || [ "$cmd" = "restore" ]; then
		# filter exclude params from fetch/restore
		echo "$DUPL_PARAMS" | awk '{gsub(/--(ex|in)clude[a-z-]*(([ \t]+|=)[^-][^ \t]+)?/,"");print}'
		return
	fi
	
	echo "$DUPL_PARAMS"
}

function duplify { # the actual wrapper function
  local PARAMSNOW DUPL_CMD DUPL_CMD_PARAMS

  # put command (with params) first in duplicity parameters
  for param in "$@" ; do
  # split cmd from params (everything before splitchar --)
    if [ "$param" == "--" ] ; then
      PARAMSNOW=1
    else
      # wrap in quotes to protect from spaces
      [ ! $PARAMSNOW ] && \
        DUPL_CMD="$DUPL_CMD $(qw $param)" \
      || \
        DUPL_CMD_PARAMS="$DUPL_CMD_PARAMS $(qw $param)"
    fi
  done

  # init global duplicity parameters same for all tasks
  duplicity_params_global

  var_isset 'PREVIEW' && local RUN=echo || local RUN=eval
$RUN ${DUPL_VARS_GLOBAL} ${BACKEND_PARAMS} \
 ${DUPL_PRECMD} duplicity $DUPL_CMD $DUPL_PARAMS_GLOBAL $(duplicity_params_conf)\
 $GPG_USEAGENT $DUPL_CMD_PARAMS ${PREVIEW:+}

  local ERR=$?
  return $ERR
}

function secureconf { # secure the configuration dir
	#PERMS=$(ls -la $(dirname $CONFDIR) | grep -e " $(basename $CONFDIR)\$" | awk '{print $1}')
	local PERMS="$(ls -la "$CONFDIR/." | awk 'NR==2{print $1}')"
	if [ "${PERMS/#drwx------*/OK}" != 'OK' ] ; then
		chmod u+rwX,go= "$CONFDIR"; local ERR=$?
		warning "The profile's folder 
'$CONFDIR'
permissions are not safe ($PERMS). Secure them now. - ($(error_to_string $ERR))"
	fi
}

# params are $1=timeformatstring (default like date output), $2=epoch seconds since 1.1.1970 (default now)
function date_fix {
	local DEFAULTFORMAT='%a %b %d %H:%M:%S %Z %Y'
	# gnu date with -d @epoch
	date=$(date ${2:+-d @$2} ${1:++"$1"} 2> /dev/null) && \
		echo $date && return
	# date bsd,osx with -r epoch
	date=$(date ${2:+-r $2} ${1:++"$1"} 2> /dev/null) && \
		echo $date && return	
	# date busybox with -d epoch -D %s
	date=$(date ${2:+-d $2 -D %s} ${1:++"$1"} 2> /dev/null) && \
		echo $date && return
	## some date commands do not support giving a time w/o setting it systemwide (irix,solaris,others?)
	# python fallback
	date=$(python -c "import time;print time.strftime('${1:-$DEFAULTFORMAT}',time.localtime(${2}))" 2> /dev/null) && \
		echo $date && return
	# awk fallback
	date=$(awk "BEGIN{print strftime(\"${1:-$DEFAULTFORMAT}\"${2:+,$2})}" 2> /dev/null) && \
		echo $date && return
	# perl fallback
	date=$(perl  -e "use POSIX qw(strftime);\$date = strftime(\"${1:-$DEFAULTFORMAT}\",localtime(${2}));print \"\$date\n\";" 2> /dev/null) && \
		echo $date && return
	# error
	echo "ERROR"
	return 1
}

function nsecs {
	# only 9 digit returns, e.g. not all date(s) deliver nsecs
	local NSECS=$(date +%N 2> /dev/null | head -1 |grep -e "^[[:digit:]]\{9\}$")
	echo ${NSECS:-000000000}
}

function nsecs_to_sec {
	echo $(($1/1000000000)).$(printf "%03d" $(($1/1000000%1000)) )
}

function datefull_from_nsecs {
	date_from_nsecs $1 '%F %T'
}

function date_from_nsecs {
	local FORMAT=${2:-%T}
	local TIME=$(nsecs_to_sec $1)
	local SECS=${TIME%.*}
	local DATE=$(date_fix "%T" ${SECS:-0})
	echo $DATE.${TIME#*.}
}

function var_isset {
	if [ -z "$1" ]; then
		echo "ERROR: function var_isset needs a string as parameter"
	elif eval "[ \"\${$1}\" == 'not_set' ]" || eval "[ \"\${$1-not_set}\" != 'not_set' ]"; then
		return 0
	fi
	return 1
}

function url_encode {
  # utilize python, silently do nothing on error - because no python no duplicity
  OUT=$(python -c "
try: import urllib.request as urllib
except ImportError: import urllib
print(urllib.${2}quote('$1'));
" 2>/dev/null ); ERR=$?
  [ "$ERR" -eq 0 ] && echo $OUT || echo $1
}

function url_decode {
  # reuse function above with a simple string param hack
  url_encode "$1" "un"
}

function toupper {
  echo "$@"|awk '$0=toupper($0)'
}

function tolower {
  echo "$@"|awk '$0=tolower($0)'
}

function gpg_disabled {
  echo "${GPG_KEY}${GPG_KEYS_ENC}" | grep -iq 'disabled'
}

function gpg_signing {
  return $(echo ${GPG_KEY_SIGN} | grep -ic 'disabled')
}

# parameter key id, key_type
function gpg_keyfile {
  local GPG_KEY="$1" TYPE="$2"
  local KEYFILE="${KEYFILE//.asc/${GPG_KEY:+.$GPG_KEY}.asc}"
  echo "${KEYFILE//.asc/${TYPE:+.$(tolower $TYPE)}.asc}"
}

# parameter key id
function gpg_import {
  local i FILE FOUND=0 KEY_ID="$1" KEY_TYPE="$2" KEY_FP="" ERR=0
  # create a list of legacy key file names and current naming scheme
  # we always import pub and sec if they are avail in conf folder
  local KEYFILES=( "$CONFDIR/gpgkey" "$(gpg_keyfile $KEY_ID)" \
                   "$(gpg_keyfile $KEY_ID PUB)" "$(gpg_keyfile $KEY_ID SEC)")

  # Try autoimport from existing old gpgkey files 
  # and new gpgkey.XXX.asc files (since v1.4.2)
  # and even newer gpgkey.XXX.[pub|sec].asc
  for (( i = 0 ; i < ${#KEYFILES[@]} ; i++ )); do
    FILE=${KEYFILES[$i]}
    if [ -f "$FILE" ]; then
      FOUND=1
      
      CMD_MSG="Import keyfile '$FILE' to keyring"
      run_cmd "$GPG" $GPG_OPTS --batch --import "$FILE"
      if [ "$CMD_ERR" != "0" ]; then 
        warning "Import failed.${CMD_OUT:+\n$CMD_OUT}"
        ERR=1
        # continue with next
        continue
      fi
    fi
  done

  if [ "$FOUND" -eq 0 ]; then
    warning "No keyfile for '$KEY_ID' found in profile\n'$CONFDIR'."
  fi

  # try to set trust automagically
  CMD_MSG="Autoset trust of key '$KEY_ID'to ultimate"
  run_cmd echo $(gpg_fingerprint $KEY_ID):6: \| "$GPG" $GPG_OPTS --import-ownertrust --batch --logger-fd 1
  if [ "$CMD_ERR" = "0" ] && [ -z "$PREVIEW" ]; then 
   # success on all levels, we're done
   return $ERR
  fi

  # failover: user has to set trust manually
  echo -e "For $ME to work you have to set the trust level 
with the command \"trust\" to \"ultimate\" (5) now.
Exit the edit mode of gpg with \"quit\"."
  CMD_MSG="Running gpg to manually edit key '$KEY_ID'"
  run_cmd sleep 5\; "$GPG" $GPG_OPTS --edit-key $KEY_ID

  return $ERR
}

# check for 8 digits and using 0x00.. here because gpg uses substring matching by default
# see 'How to specify a user ID' on gpg manpage
function gpg_fingerprint {
  [ ${#1} -eq 8 ] \
    && local PRINT=$("$GPG" $GPG_OPTS --fingerprint 0x"$1" 2>&1|awk -F= 'NR==2{gsub(/ /,"",$2);$2=toupper($2); if ( $2 ~ /^[A-F0-9]+$/ && length($2) == 40 ) print $2; else exit 1}') \
    && [ -n "$PRINT" ] && echo $PRINT && return 0
  return 1
}

function gpg_export_if_needed {
  local SUCCESS FILE KEY_TYPE KEY_LIST=$1
  local TMPFILE="$TEMP_DIR/${ME_NAME}.$$.$(date_fix %s).gpgexp"
  for KEY_ID in $KEY_LIST; do
    # check if already exported, do it if not
    for KEY_TYPE in PUB SEC; do
      FILE="$(gpg_keyfile $KEY_ID $KEY_TYPE)"
      if [ ! -f "$FILE" ] && eval gpg_$(tolower $KEY_TYPE)_avail $KEY_ID; then
        # exporting
        CMD_MSG="Export $KEY_TYPE key $KEY_ID"
        run_cmd $GPG $GPG_OPTS --armor --export"$(test "SEC" = "$KEY_TYPE" && echo -secret-keys)"" $KEY_ID >> \"$TMPFILE\""

        if [ "$CMD_ERR" = "0" ]; then
          CMD_MSG="Write file '"$(basename "$FILE")"'"
          run_cmd " mv \"$TMPFILE\" \"$FILE\""
        fi

        if [ "$CMD_ERR" != "0" ]; then
          warning "Backup failed.${CMD_OUT:+\n$CMD_OUT}"
        else
          SUCCESS=1
        fi

        # cleanup
        rm "$TMPFILE" 1>/dev/null 2>&1
      fi
    done
  done
  
  [ -n "$SUCCESS" ] && inform "$ME exported new keys to your profile.
You should backup your changed profile folder now and store it in a safe place."
}

function gpg_key_cache {
  local RES
  local PREFIX="GPG_KEY"
  local CACHE="PREFIX_$1_$2"
  if [ "$1" = "RESET" ]; then
    eval unset PREFIX_PUB_$2 PREFIX_SEC_$2
    return 255
  elif ! var_isset "$CACHE"; then
    if [ "$1" = "PUB" ]; then
      RES=$("$GPG" $GPG_OPTS --list-key "$2" > /dev/null 2>&1; echo -n $?)
    elif [ "$1" = "SEC" ]; then
      RES=$("$GPG" $GPG_OPTS --list-secret-key "$2" > /dev/null 2>&1; echo -n $?)
    else
      return 255
    fi
    eval $CACHE=$RES
  fi
  eval return \$$CACHE
}

function gpg_pub_avail {
  gpg_key_cache PUB $1
}

function gpg_sec_avail {
  gpg_key_cache SEC $1
}

function gpg_key_format {
  echo $1 | grep -q '^[0-9a-fA-F]\{8\}$'
}

function gpg_split_keyset {
  awk "BEGIN{ keys=toupper(\"$@\"); gsub(/[^A-Z0-9]/,\" \",keys); print keys }"
}

function gpg_join_keyset {
  local KEY_ID OUT
  for KEY_ID in $@; do
    [ -z "$OUT" ] && OUT=$KEY_ID || OUT=${OUT},${KEY_ID}
  done
  echo $OUT
}

function gpg_prefix_keyset {
  local KEY_ID OUT KEYSET
  [ -n "$2" ] && eval "local KEYSET=\"\${$2[@]}\""
  for KEY_ID in $KEYSET; do
    OUT=${OUT}${1}${KEY_ID}
  done
  echo $OUT
}

# grep a variable from conf text file (currently not used)
function gpg_passwd {
  [ -r "$CONF" ] && \
  awk '/^[ \t]*GPG_PW[ \t=]/{\
        sub(/^[ \t]*GPG_PW[ \t]*=*/,"",$0);\
        gsub(/^[ \t]*[\047"]|[\047"][ \t]*$/,"",$0);\
        print $0; exit}' "$CONF"
}

function gpg_key_decryptable {
  # decryption needs pass, might be empty, but must be set
  #var_isset 'GPG_PW' || return 1
  local KEY_ID
  for KEY_ID in ${GPG_KEYS_ENC[@]}; do
    gpg_sec_avail $KEY_ID && return 0
  done
  return 1
}

function gpg_symmetric {
  [ -z "${GPG_KEY}${GPG_KEYS_ENC}" ]
}

# checks for max two params if they are set, typically GPG_PW & GPG_PW_SIGN
function gpg_param_passwd {
  var_isset GPG_USEAGENT && exit 1
  
  if ( [ -n "$1" ] && var_isset "$1" ) || ( [ -n "$2" ] && var_isset "$2" ); then
    echo "--passphrase-fd 0"
  fi
}

# select the earlist defined and create an "echo <value> |" string
function gpg_pass_pipein {
  var_isset GPG_USEAGENT && exit 1
  
  for var in "$@"
  do
    if var_isset "$var"; then
      echo "echo $(qw $(eval echo \$$var)) |"
      return 0
    fi
  done
  
  return 1
}

# start of script #######################################################################

# confidentiality first, all we create is only readable by us
umask 077

# check if ftplicity is there & executable
[ -n "$ME_LONG" ] && [ -x "$ME_LONG" ] || error "$ME missing. Executable & available in path? ($ME_LONG)"

if [ ${#@} -eq 1 ]; then
	cmd="${1}"
else
	FTPLCFG="${1}" ; cmd="${2}"
fi

# deal with command before profile validation calls
# show requested version
# OR requested usage info
# OR create a profile
# OR fall through
##if [ ${#@} -le 2 ]; then
case "$cmd" in
  changelog)
    changelog
    exit 0
    ;;
  create)
    set_config
    if [ -d "$CONFDIR" ]; then
      error "The profile '$FTPLCFG' already exists in
'$CONFDIR'.

Hint:
 If you _really_ want to create a new profile by this name you will 
 have to manually delete the existing profile folder first."
      exit 1
    else
      create_config
      exit 0
    fi
    ;;
  txt2man)
    set_config
    usage_txt2man
    exit 0
    ;;
  usage|-help|--help|-h|-H)
    set_config
    usage_info
    exit 0
    ;;
  version|-version|--version|-v|-V)
    version_info_using
    exit 0
    ;;
  # fallthrough.. we got a command that needs an existing profile
  *)
    # if we reach here, user either forgot profile or chose wrong profileless command
    if [ ${#@} -le 1 ]; then
      error "\
 Missing or wrong parameters. 
 Only the commands 
   changelog, create, usage, txt2man, version
 can be called without selecting an existing profile first.
 Your command was '$cmd'.

 Hint: Run '$ME usage' to get help."
    fi
esac


# Hello world
echo "Start $ME v$ME_VERSION, time is $(date_fix '%F %T')."

# check system environment
DUPLICITY="$(which duplicity 2>/dev/null)"
[ -z "$DUPLICITY" ] && error_path "duplicity missing. installed und available in path?"
# init, exec duplicity version check info
duplicity_version_get
duplicity_version_check

[ -z "$(which awk 2>/dev/null)" ] && error_path "awk missing. installed und available in path?"

### read configuration
set_config
# check validity
if [ ! -d "$CONFDIR" ]; then 
    error "Selected profile '$FTPLCFG' does not resolve to a profile folder in
'$CONFDIR'.

Hints:
 Select one of the available profiles: $(ls -1p $(dirname "$CONFDIR")|  awk 'BEGIN{ORS="";OFS=""}/\/$/&&!/^\.+\/$/{print sep"\047"substr($0,0,length($0)-1)"\047";sep=","}').
 Use '$ME <name> create' to create a new profile.
 Use '$ME usage' to get usage help."
elif [ ! -x "$CONFDIR" ]; then
    error "\
Profile folder in '$CONFDIR' cannot be accessed.

Hint: 
 Check the filesystem permissions and set directory accessible e.g. 'chmod 700'."
elif [ ! -f "$CONF" ] ; then
  error "'$CONF' not found."
elif [ ! -r "$CONF" ] ; then
  error "'$CONF' not readable."
else
  . "$CONF"
  #KEYFILE="${KEYFILE//.asc/${GPG_KEY:+.$GPG_KEY}.asc}"
  TEMP_DIR=${TEMP_DIR:-'/tmp'}
  # backward compatibility: old TARGET_PW overrides silently new TARGET_PASS if set
  if var_isset 'TARGET_PW'; then
    TARGET_PASS="${TARGET_PW}"
  fi
fi
echo "Using profile '$CONFDIR'."

# secure config dir, if needed w/ warning
secureconf

# split TARGET in handy variables
TARGET_SPLIT_URL=$(echo $TARGET | awk '{ \
  target=$0; match(target,/^([^\/:]+):\/\//); \
  prot=substr(target,RSTART,RLENGTH);\
  rest=substr(target,RSTART+RLENGTH); \
  if (credsavail=match(rest,/^[^@]*@/)){\
    creds=substr(rest,RSTART,RLENGTH-1);\
    credcount=split(creds,cred,":");\
    rest=substr(rest,RLENGTH+1);\
    # split creds with regexp\
    match(creds,/^([^:]+)/);\
    user=substr(creds,RSTART,RLENGTH);\
    pass=substr(creds,RSTART+1+RLENGTH);\
  };\
  # filter quotes or escape them\
  gsub(/[\047\042]/,"",prot);\
  gsub(/[\047\042]/,"",rest);\
  gsub(/[\047]/,"\047\\\047\047",creds);\
  print "TARGET_URL_PROT=\047"prot"\047\n"\
         "TARGET_URL_HOSTPATH=\047"rest"\047\n"\
         "TARGET_URL_CREDS=\047"creds"\047\n";\
   if(user){\
     gsub(/[\047]/,"\047\\\047\047",user);\
     print "TARGET_URL_USER=\047"user"\047\n"}\
   if(pass){\
     gsub(/[\047]/,"\047\\\047\047",pass);\
     print "TARGET_URL_PASS=$(url_decode \047"pass"\047)\n"}\
  }')
eval ${TARGET_SPLIT_URL}

# check if backend specific software is in path
[ -n "$(echo ${TARGET_URL_PROT} | grep -i -e '^ftp://$')" ] && \
  [ -z "$(which ncftp 2>/dev/null)" ] && error_path "Protocol 'ftp' needs ncftp. Installed und available in path?" 
[ -n "$(echo ${TARGET_URL_PROT} | grep -i -e '^ftps://$')" ] && \
  [ -z "$(which lftp 2>/dev/null)" ] && error_path "Protocol 'ftps' needs lftp. Installed und available in path?"

# fetch commmand from parameters ########################################################
# Hint: cmds is also used to check if authentification info sufficient in the next step 
cmds="$2"; shift 2

# translate backup to batch command 
cmds=${cmds//backup/pre_bkp_post}

# complain if command(s) missing
[ -z $cmds ] && error "  No command given.

  Hint: 
    Use '$ME usage' to get usage help."

# process params
for param in "$@"; do
  #echo !$param!
  case "$param" in
    # enable ftplicity preview mode
    '--preview')
      PREVIEW=1
      ;;
    # interpret duplicity disable encr switch
    '--disable-encryption')
      GPG_KEY='disabled'
      ;;
    *)
      if [ `echo "$param" | grep -e "^-"` ] || \
         [ `echo "$last_param" | grep -e "^-"` ] ; then
        # forward parameter[/option pairs] to duplicity
        dupl_opts["${#dupl_opts[@]}"]=${param}
      else
        # anything else must be a parameter (eg. for fetch, ...)
        ftpl_pars["${#ftpl_pars[@]}"]=${param}
      fi
      last_param=${param}
      ;;
  esac
done

# plausibility check config - VARS & KEY ################################################
# check if src, trg, trg pw
# auth info sufficient 
# gpg key, gpg pwd (might be empty) set in config
# OR key in local gpg db
# OR key can be imported from keyfile 
# OR fail
if [ -z "$SOURCE" ] || [ "$SOURCE" == "${DEFAULT_SOURCE}" ]; then
 error " Source Path (setting SOURCE) not set or still default value in conf file 
 '$CONF'."

elif [ -z "$TARGET" ] || [ "$TARGET" == "${DEFAULT_TARGET}" ]; then
 error " Backup Target (setting TARGET) not set or still default value in conf file 
 '$CONF'."

elif var_isset 'TARGET_USER' && var_isset 'TARGET_URL_USER' && \
     [ "${TARGET_USER}" != "${TARGET_URL_USER}" ]; then
 error " TARGET_USER ('${TARGET_USER}') _and_ user in TARGET url ('${TARGET_URL_USER}') 
 are configured with different values. There can be only one.
 
 Hint: Remove conflicting setting."

elif var_isset 'TARGET_PASS' && var_isset 'TARGET_URL_PASS' && \
     [ "${TARGET_PASS}" != "${TARGET_URL_PASS}" ]; then
 error " TARGET_PASS ('${TARGET_PASS}') _and_ password in TARGET url ('${TARGET_URL_PASS}') 
 are configured with different values. There can be only one.
 
 Hint: Remove conflicting setting."
fi

# check if authentication information sufficient
if ( ( ! var_isset 'TARGET_USER' && ! var_isset 'TARGET_URL_USER' ) && \
       ( ! var_isset 'TARGET_PASS' && ! var_isset 'TARGET_URL_PASS' ) ); then
  # ok here some exceptions:
  #   protocols that do not need passwords
  #   s3[+http] only needs password for write operations
  #   u1[+http] can ask for creds and create an oauth token
  if [ -n "$(tolower "${TARGET_URL_PROT}" | grep -e '^\(dpbx\|file\|tahoe\|ssh\|scp\|sftp\|swift\|u1\(\+http\)\?\)://$')" ]; then
    : # all is well file/tahoe do not need passwords, ssh might use key auth
  elif [ -n "$(tolower "${TARGET_URL_PROT}" | grep -e '^s3\(\+http\)\?://$')" ] && \
     [ -z "$(echo ${cmds} | grep -e '\(bkp\|incr\|full\|purge\|cleanup\)')" ]; then
    : # still fine, it's possible to read only access configured buckets anonymously
  else
    error " Backup target credentials needed but not set in conf file 
 '$CONF'.
 Setting TARGET_USER or TARGET_PASS or the corresponding values in TARGET url 
 are missing. Some protocols only might need it for write access to the backup 
 repository (commands: bkp,backup,full,incr,purge) but not for read only access
 (e.g. verify,list,restore,fetch). 
 
 Hints:
   Add the credentials (user,password) to the conf file.
   To force an empty password set TARGET_PASS='' or TARGET='prot://user:@host..'.
"
  fi
fi

# GPG config plausibility check1 (disabled check) #############################
if gpg_disabled; then
	: # encryption disabled, all is well

elif [ -z "${GPG_KEY}${GPG_KEYS_ENC}${GPG_KEY_SIGN}" ] && ! var_isset 'GPG_PW'; then
	warning "GPG_KEY and GPG_PW are empty or not set in conf file 
'$CONF'.
Will disable encryption for duplicity now.

Hint: 
 If you really want to use _no_ encryption you can disable this warning by 
 setting GPG_KEY='disabled' in conf file."
 GPG_KEY='disabled'
fi

# GPG availability check (now we know if gpg is really needed)#################
if ! gpg_disabled; then 
	GPG="$(which gpg 2>/dev/null)"
	[ -z "$GPG" ] && error_path "gpg missing. installed und available in path?"
fi


# Output versions info ########################################################
using_info

# GPG create key settings, config check2 (needs gpg) ##########################
if gpg_disabled; then
	: # the following tests are not necessary
else

# key set?
if [ "$GPG_KEY" == "${DEFAULT_GPG_KEY}" ]; then 
  error_gpg "Encryption Key GPG_KEY still default in conf file 
'$CONF'."
fi

# disabled as keys can really be given in too many forms e.g. short/long id, fingerprint, email, name ...
## check gpg keys format
#for KEY_SET_NAME in GPG_KEY GPG_KEYS_ENC $(gpg_signing && echo -n GPG_KEY_SIGN); do
#  eval KEY_SET="\${${KEY_SET_NAME}}"
#  for KEY_ID in $(gpg_split_keyset "$KEY_SET"); do
#    # test format [ ! $(echo $GPG_KEY | grep '^[0-9a-fA-F]\{8\}$') ] not set correct (8 digit ID) or
#    gpg_key_format ${KEY_ID} || \
#      error_gpg "GPG key '${KEY_ID}' set in '${KEY_SET_NAME}' is not \na valid 8 character hex digit string e.g. '012345AB'."
#  done
#done

# create enc gpg keys array, for further processing
GPG_KEYS_ENC=( $(gpg_split_keyset ${GPG_KEY}) $(gpg_split_keyset ${GPG_KEYS_ENC}) )

# check gpg encr public keys availability
for (( i = 0 ; i < ${#GPG_KEYS_ENC[@]} ; i++ )); do
  KEY_ID=${GPG_KEYS_ENC[$i]}
  # test availability, try to import, retest
  if ! gpg_pub_avail ${KEY_ID}; then
    echo "Encryption public key '${KEY_ID}' not found."
    gpg_import "${KEY_ID}" PUB
    gpg_key_cache RESET ${KEY_ID}
    gpg_pub_avail ${KEY_ID} || error_gpg_key "${KEY_ID}" "Public"
  fi
done

# gpg secret sign key availability
# if none set, autoset first encryption key as sign key
if ! gpg_signing; then
  echo "Signing disabled per configuration."
# try first key, if one set
elif ! var_isset 'GPG_KEY_SIGN'; then
  KEY_ID=${GPG_KEYS_ENC[0]}
  if [ -z "${KEY_ID}" ]; then
    echo "Signing disabled. Not GPG_KEY entries in config."
    GPG_KEY_SIGN='disabled'
  else  
    # use avail OR try import OR fail
    if gpg_sec_avail "${KEY_ID}"; then
      GPG_KEY_SIGN=${KEY_ID}
    else
      gpg_import "${KEY_ID}" SEC
      gpg_key_cache RESET ${KEY_ID}
      if gpg_sec_avail "${KEY_ID}"; then
        GPG_KEY_SIGN=${KEY_ID}
      fi
    fi

    # interpret sign key setting
    if var_isset 'GPG_KEY_SIGN'; then
      echo "Autoset found secret key of first GPG_KEY entry '${KEY_ID}' for signing."
    else
      echo "Signing disabled. First GPG_KEY entry's '${KEY_ID}' private key is missing."
      GPG_KEY_SIGN='disabled'
    fi
  fi
else
  KEY_ID=${GPG_KEY_SIGN}
  if ! gpg_sec_avail ${KEY_ID}; then
    inform "Secret signing key defined in setting GPG_KEY_SIGN='${KEY_ID}' not found.\nTry to import."
    gpg_import "${KEY_ID}" SEC
    gpg_key_cache RESET ${KEY_ID}
    gpg_sec_avail ${KEY_ID} || error_gpg_key "${KEY_ID}" "Private"
  else
    echo "Use configured key '${KEY_ID}' as signing key."
  fi
fi

# pw set? 
# symmetric needs one, always
if gpg_symmetric && ( [ -z "$GPG_PW" ] || [ "$GPG_PW" == "${DEFAULT_GPG_PW}" ] ) \
  ; then
  error_gpg "Encryption passphrase GPG_PW (needed for symmetric encryption) 
is empty/not set or still default value in conf file 
'$CONF'."
fi
# this is a technicality, we can only pump one pass via pipe into gpg
# but symmetric already always needs one for encryption
if gpg_symmetric && var_isset GPG_PW && var_isset GPG_PW_SIGN &&\
  [ -n "$GPG_PW_SIGN" ] && [ "$GPG_PW" != "$GPG_PW_SIGN" ]; then
  error_gpg "GPG_PW _and_ GPG_PW_SIGN are defined but not identical in config
'$CONF'.
This is unfortunately impossible. For details see duplicity manpage, 
section 'A Note On Symmetric Encryption And Signing'.

Tip: Separate signing keys may have empty passwords e.g. GPG_PW_SIGN=''."
fi
# key enc can deal without, but might profit from gpg-agent
# if GPG_PW is not set alltogether
# if signing key is different from first (main) enc key (we can only pipe one pass into gpg)
if ! gpg_symmetric && \
   ( ! var_isset GPG_PW || \
     ( gpg_signing && ! var_isset GPG_PW_SIGN && [ "$GPG_KEY_SIGN" != "${GPG_KEYS_ENC[0]}" ] ) ); then
  echo "Autoenable use of gpg-agent. GPG_PW or GPG_PW_SIGN (enc != sign key) not set."

  GPG_USEAGENT="--use-agent"
fi

# end GPG config plausibility check2 
fi

# config plausibility check - SPACE ###########################################
# is tmp writeable
# is tmp big enough
if [ ! -d "$TEMP_DIR" ]; then
    error "Temporary file space '$TEMP_DIR' is not a directory."
elif [ ! -w "$TEMP_DIR" ]; then
    error "Temporary file space '$TEMP_DIR' not writable."
fi

# get volsize, default duplicity volume size is 25MB since v0.5.07
VOLSIZE=${VOLSIZE:-25}
# get free temp space
TEMP_FREE="$(df $TEMP_DIR 2>/dev/null | awk 'END{pos=(NF-2);if(pos>0) print $pos;}')"
# check for free space or FAIL
if [ "$((${TEMP_FREE:-0}-${VOLSIZE:-0}*1024))" -lt 0 ]; then
    error "Temporary file space '$TEMP_DIR' free space is smaller ($((TEMP_FREE/1024))MB)
than one duplicity volume (${VOLSIZE}MB).
    
  Hint: Free space or change TEMP_DIR setting."
fi

# check for enough async upload space and WARN only
if [ $((${TEMP_FREE:-0}-2*${VOLSIZE:-0}*1024)) -lt 0 ]; then
    warning "Temporary file space '$TEMP_DIR' free space is smaller ($((TEMP_FREE/1024))MB)
than two duplicity volumes (2x${VOLSIZE}MB). This can lead to problems when 
using the --asynchronous-upload option.
    
  Hint: Free space or change TEMP_DIR setting."
fi

# test - GPG SANITY #####################################################################
# if encryption is disabled, skip this whole section
if gpg_disabled; then
  echo -e "Test - En/Decryption skipped. (GPG disabled)"
elif [ "$GPG_TEST" = "disabled" ]; then 
  echo -e "Test - En/Decryption skipped. (Testing disabled)"
else

GPG_TEST="$TEMP_DIR/${ME_NAME}.$$.$(date_fix %s)"
function cleanup_gpgtest { 
  echo -en "Cleanup - Delete '${GPG_TEST}_*'"
  rm ${GPG_TEST}_* 2>/dev/null && echo "(OK)" || echo "(FAILED)"
}

# signing enabled?
if gpg_signing; then
  CMD_PARAM_SIGN="--sign --default-key ${GPG_KEY_SIGN}"
  CMD_MSG_SIGN="Sign with ${GPG_KEY_SIGN}"
fi

# using keys
if [ ${#GPG_KEYS_ENC[@]} -gt 0 ]; then

  for KEY_ID in ${GPG_KEYS_ENC[@]}; do
    CMD_PARAMS="$CMD_PARAMS -r ${KEY_ID}"
  done
  # check encrypting
  CMD_MSG="Test - Encrypt to $(gpg_join_keyset ${GPG_KEYS_ENC[@]})${CMD_MSG_SIGN:+ & $CMD_MSG_SIGN}"
  run_cmd $(gpg_pass_pipein GPG_PW_SIGN GPG_PW) $GPG $CMD_PARAM_SIGN $(gpg_param_passwd GPG_PW_SIGN GPG_PW) $CMD_PARAMS $GPG_USEAGENT --batch --status-fd 1 $GPG_OPTS -o "${GPG_TEST}_ENC" -e "$ME_LONG"

  if [ "$CMD_ERR" != "0" ]; then 
    KEY_NOTRUST=$(echo "$CMD_OUT"|awk '/^\[GNUPG:\] INV_RECP 10/ { print $4 }')
    [ -n "$KEY_NOTRUST" ] && HINT="Key '${KEY_NOTRUST}' seems to be untrusted. If you really trust this key try to
  'gpg --edit-key $KEY_NOTRUST' and raise the trust level to ultimate. If you
  can trust all of your keys set GPG_OPTS='--trust-model always' in conf file."
    error_gpg_test "Encryption failed (Code $CMD_ERR).${CMD_OUT:+\n$CMD_OUT}" "$HINT"
  fi

  # check decrypting
  CMD_MSG="Test - Decrypt"
  gpg_key_decryptable || CMD_DISABLED="No matching secret key or GPG_PW not set."
  run_cmd $(gpg_pass_pipein GPG_PW) "$GPG" $(gpg_param_passwd GPG_PW) $GPG_OPTS -o "${GPG_TEST}_DEC" $GPG_USEAGENT --batch -d "${GPG_TEST}_ENC"

  if [ "$CMD_ERR" != "0" ]; then 
    error_gpg_test "Decryption failed.${CMD_OUT:+\n$CMD_OUT}"
  fi

# symmetric only
else
  # check encrypting
  CMD_MSG="Test - Encryption with passphrase${CMD_MSG_SIGN:+ & $CMD_MSG_SIGN}"
  run_cmd $(gpg_pass_pipein GPG_PW) "$GPG" $GPG_OPTS $CMD_PARAM_SIGN --passphrase-fd 0 -o "${GPG_TEST}_ENC" --batch -c "$ME_LONG"
  if [ "$CMD_ERR" != "0" ]; then 
    error_gpg_test "Encryption failed.${CMD_OUT:+\n$CMD_OUT}"
  fi

  # check decrypting
  CMD_MSG="Test - Decryption with passphrase"
  run_cmd $(gpg_pass_pipein GPG_PW) "$GPG" $GPG_OPTS --passphrase-fd 0 -o "${GPG_TEST}_DEC" --batch -d "${GPG_TEST}_ENC"
  if [ "$CMD_ERR" != "0" ]; then 
    error_gpg_test "Decryption failed.${CMD_OUT:+\n$CMD_OUT}"
  fi
fi

# compare original w/ decryptginal
CMD_MSG="Test - Compare"
[ -r "${GPG_TEST}_DEC" ] || CMD_DISABLED="File not found. Nothing to compare."
run_cmd "test \"\$(cat '$ME_LONG')\" = \"\$(cat '${GPG_TEST}_DEC')\""

if [ "$CMD_ERR" = "0" ]; then 
  cleanup_gpgtest
else
  error_gpg_test "Comparision failed.${CMD_OUT:+\n$CMD_OUT}"
fi

fi # end disabled

## an empty line
#echo

# Exclude file is needed, create it if necessary
[ -f "$EXCLUDE" ] || touch "$EXCLUDE"

# export only used keys, if bkp not already exists ######################################
gpg_export_if_needed "${GPG_KEYS_ENC[@]} $(gpg_signing && echo $GPG_KEY_SIGN)"


# command execution #####################################################################

# urldecode url vars into plain text
var_isset 'TARGET_URL_USER' && TARGET_URL_USER="$(url_decode "$TARGET_URL_USER")"
var_isset 'TARGET_URL_PASS' && TARGET_URL_PASS="$(url_decode "$TARGET_URL_PASS")"

# defined TARGET_USER&PASS vars replace their URL pendants 
# (double defs already dealt with)
var_isset 'TARGET_USER' && TARGET_URL_USER="$TARGET_USER"
var_isset 'TARGET_PASS' && TARGET_URL_PASS="$TARGET_PASS"

# build target backend data depending on protocol
case "$(tolower "${TARGET_URL_PROT%%:*}")" in
  's3'|'s3+http')
    BACKEND_PARAMS="AWS_ACCESS_KEY_ID='${TARGET_URL_USER}' AWS_SECRET_ACCESS_KEY='${TARGET_URL_PASS}'"
    BACKEND_URL="${TARGET_URL_PROT}${TARGET_URL_HOSTPATH}"
    ;;
  'gs')
    BACKEND_PARAMS="GS_ACCESS_KEY_ID='${TARGET_URL_USER}' GS_SECRET_ACCESS_KEY='${TARGET_URL_PASS}'"
    BACKEND_URL="${TARGET_URL_PROT}${TARGET_URL_HOSTPATH}"
    ;;
  'cf+http')
    # respect potentially set cloudfile env vars
    var_isset 'CLOUDFILES_USERNAME' && TARGET_URL_USER="$CLOUDFILES_USERNAME"
    var_isset 'CLOUDFILES_APIKEY' && TARGET_URL_PASS="$CLOUDFILES_APIKEY"
    # add them to duplicity params
    var_isset 'TARGET_URL_USER' && \
      BACKEND_PARAMS="CLOUDFILES_USERNAME=$(qw "${TARGET_URL_USER}")"
    var_isset 'TARGET_URL_PASS' && \
      BACKEND_PARAMS="$BACKEND_PARAMS CLOUDFILES_APIKEY=$(qw "${TARGET_URL_PASS}")"
    BACKEND_URL="${TARGET_URL_PROT}${TARGET_URL_HOSTPATH}"
    # info on missing AUTH_URL
    if ! var_isset 'CLOUDFILES_AUTHURL'; then
      echo -e "INFO: No CLOUDFILES_AUTHURL defined (in conf).\n      Will use default from python-cloudfiles (probably rackspace)."
    else
      BACKEND_PARAMS="$BACKEND_PARAMS CLOUDFILES_AUTHURL=$(qw "${CLOUDFILES_AUTHURL}")"
    fi
    ;;
  'file'|'tahoe'|'dpbx'|'swift')
    BACKEND_URL="${TARGET_URL_PROT}${TARGET_URL_HOSTPATH}"
    ;;
  'rsync')
    # everything in url (this backend does not support pass in env var)
    # this is obsolete from version 0.6.10 (buggy), hopefully fixed in 0.6.11
    # print warning older version is detected
    var_isset 'TARGET_URL_USER' && BACKEND_CREDS="$(url_encode "${TARGET_URL_USER}")"
    if duplicity_version_lt 610; then
      warning "\
Duplicity version '$DUPL_VERSION' does not support providing the password as 
env var for rsync backend. For security reasons you should consider to 
update to a version greater than '0.6.10' of duplicity."
      var_isset 'TARGET_URL_PASS' && BACKEND_CREDS="${BACKEND_CREDS}:$(url_encode "${TARGET_URL_PASS}")"
    else
      var_isset 'TARGET_URL_PASS' && BACKEND_PARAMS="FTP_PASSWORD=$(qw "${TARGET_URL_PASS}")"
    fi
    var_isset 'BACKEND_CREDS' && BACKEND_CREDS="${BACKEND_CREDS}@"
    BACKEND_URL="${TARGET_URL_PROT}${BACKEND_CREDS}${TARGET_URL_HOSTPATH}"
    ;;
  *)
    # for all other protocols we put username in url and pass into env var 
    # for sec�rity reasons, we url_encode username to protect special chars
    var_isset 'TARGET_URL_USER' && 
      BACKEND_CREDS="$(url_encode "${TARGET_URL_USER}")@"
    # sortout backends with special ways to handle password
    case "$(tolower "${TARGET_URL_PROT%%:*}")" in
      'imap'|'imaps')
        var_isset 'TARGET_URL_PASS' && BACKEND_PARAMS="IMAP_PASSWORD=$(qw "${TARGET_URL_PASS}")"
      ;;
      'ssh'|'sftp'|'scp')
        # ssh backend wants to be told that theres a pass to use
        var_isset 'TARGET_URL_PASS' && \
          DUPL_PARAMS="$DUPL_PARAMS --ssh-askpass" && \
          BACKEND_PARAMS="FTP_PASSWORD=$(qw "${TARGET_URL_PASS}")"
      ;;
      *)
        # rest uses FTP_PASS var
        var_isset 'TARGET_URL_PASS' && \
          BACKEND_PARAMS="FTP_PASSWORD=$(qw "${TARGET_URL_PASS}")"
      ;;
    esac
    BACKEND_URL="${TARGET_URL_PROT}${BACKEND_CREDS}${TARGET_URL_HOSTPATH}"
    ;;
esac

# protect eval from special chars in url (e.g. open ')' in password, 
# spaces in path, quotes) happens above in duplify() via quotewrap()
SOURCE="$SOURCE"
BACKEND_URL="$BACKEND_URL"
EXCLUDE="$EXCLUDE"

# replace magic separators to condition command equivalents (+=and,-=or)
cmds=$(awk -v cmds="$cmds" "BEGIN{ gsub(/\+/,\"_and_\",cmds); gsub(/\-/,\"_or_\",cmds); print cmds}")
# convert cmds to array, lowercase for safety
CMDS=( $(awk "BEGIN{ cmds=tolower(\"$cmds\"); gsub(/_/,\" \",cmds); print cmds }") )

# run cmds
for cmd in ${CMDS[*]};
do

## init
# raise index in cmd array for pre/post param
var_isset 'CMD_NO' && CMD_NO=$((++CMD_NO)) || CMD_NO=0

# get prev/nextcmd vars
nextno=$(($CMD_NO+1))
[ "$nextno" -lt "${#CMDS[@]}" ] && CMD_NEXT=${CMDS[$nextno]} || CMD_NEXT='END'
prevno=$(($CMD_NO-1))
[ "$prevno" -ge 0 ] && CMD_PREV=${CMDS[$prevno]} || CMD_PREV='START'

# deal with condition "commands"
if var_isset 'CMD_SKIP' && [ $CMD_SKIP -gt 0 ]; then
  echo -e "\n--- Skipping command $(toupper $cmd) ! ---"
  CMD_SKIP=$(($CMD_SKIP - 1))
  continue
elif [ "$cmd" == 'and' ] && [ "$CMD_ERR" -ne "0" ]; then
  CMD_SKIP=1
  continue
elif [ "$cmd" == 'or' ] && [ "$CMD_ERR" -eq "0" ]; then
  CMD_SKIP=1
  continue
elif [ "$cmd" == 'and' ] || [ "$cmd" == 'or' ]; then
  unset 'CMD_SKIP';
  continue
fi

# save start time
RUN_START=$(date_fix %s)$(nsecs)
# user info
echo; separator "Start running command $(toupper $cmd) at $(date_from_nsecs $RUN_START)"

case "$(tolower $cmd)" in
  'pre'|'post')
    if [ "$cmd" == 'pre' ]; then
      script=$PRE
    else
      script=$POST
    fi
    # script execution in a subshell, protect us from failures/var overwrites
    ( run_script "$script" )
    ;;
  'bkp')
    duplify -- "${dupl_opts[@]}" --exclude-globbing-filelist "$EXCLUDE" \
          "$SOURCE" "$BACKEND_URL"
    ;;
  'incr')
    duplify incr -- "${dupl_opts[@]}" --exclude-globbing-filelist "$EXCLUDE" \
          "$SOURCE" "$BACKEND_URL"
    ;;
  'full')
    duplify full -- "${dupl_opts[@]}" --exclude-globbing-filelist "$EXCLUDE" \
          "$SOURCE" "$BACKEND_URL"
    ;;
  'verify')
    duplify verify -- "${dupl_opts[@]}" --exclude-globbing-filelist "$EXCLUDE" \
          "$BACKEND_URL" "$SOURCE"
    ;;
  'list')
    # time param exists since 0.5.10+
    TIME="${ftpl_pars[0]:-now}"
    duplify list-current-files -- -t "$TIME" "${dupl_opts[@]}" "$BACKEND_URL"
    ;;
  'cleanup')
    duplify cleanup -- "${dupl_opts[@]}" "$BACKEND_URL"
    ;;
  'purge')
    MAX_AGE=${ftpl_pars[0]:-$MAX_AGE}
    [ -z "$MAX_AGE" ] && error "  Missing parameter <max_age>. Can be set in profile or as command line parameter."
    
    duplify remove-older-than "${MAX_AGE}" \
          -- "${dupl_opts[@]}" "$BACKEND_URL"
    ;;
  'purgefull')
    MAX_FULL_BACKUPS=${ftpl_pars[0]:-$MAX_FULL_BACKUPS}
    [ -z "$MAX_FULL_BACKUPS" ] && error "  Missing parameter <max_full_backups>. Can be set in profile or as command line parameter."
  
    duplify remove-all-but-n-full "${MAX_FULL_BACKUPS}" \
          -- "${dupl_opts[@]}" "$BACKEND_URL"
    ;;
  'purgeincr')
    MAX_FULLS_WITH_INCRS=${ftpl_pars[0]:-$MAX_FULLS_WITH_INCRS}
    [ -z "$MAX_FULLS_WITH_INCRS" ] && error "  Missing parameter <max_fulls_with_incrs>. Can be set in profile or as command line parameter."
  
    duplify remove-all-inc-of-but-n-full "${MAX_FULLS_WITH_INCRS}" \
          -- "${dupl_opts[@]}" "$BACKEND_URL"
    ;;
  'restore')
    OUT_PATH="${ftpl_pars[0]}"; TIME="${ftpl_pars[1]:-now}";
    [ -z "$OUT_PATH" ] && error "  Missing parameter target_path for restore.
  
  Hint: 
    Syntax is -> $ME <profile> restore <target_path> [<age>]"
    
    duplify  -- -t "$TIME" "${dupl_opts[@]}" "$BACKEND_URL" "$OUT_PATH"
    ;;
  'fetch')
    IN_PATH="${ftpl_pars[0]}"; OUT_PATH="${ftpl_pars[1]}"; 
    TIME="${ftpl_pars[2]:-now}";
    ( [ -z "$IN_PATH" ] || [ -z "$OUT_PATH" ] ) && error "  Missing parameter <src_path> or <target_path> for fetch.
  
  Hint: 
    Syntax is -> $ME <profile> fetch <src_path> <target_path> [<age>]"
    
    # duplicity 0.4.7 doesnt like cmd restore in combination with --file-to-restore
    duplify -- --restore-time "$TIME" "${dupl_opts[@]}" \
              --file-to-restore "$IN_PATH" "$BACKEND_URL" "$OUT_PATH"
    ;;
  'status')
    duplify collection-status -- "${dupl_opts[@]}" "$BACKEND_URL"
    ;;    
  *)
    warning "Unknown command '$cmd'."
    ;;
esac

CMD_ERR=$?
RUN_END=$(date_fix %s)$(nsecs) ; RUNTIME=$(( $RUN_END - $RUN_START ))

# print message on error; set error code
if [ "$CMD_ERR" -ne 0 ]; then
	error_print "$(datefull_from_nsecs $RUN_END) Task '$(echo $cmd|awk '$0=toupper($0)')' failed with exit code '$CMD_ERR'."
	FTPL_ERR=1
fi

separator "Finished state $(error_to_string $CMD_ERR) at $(date_from_nsecs $RUN_END) - \
Runtime $(printf "%02d:%02d:%02d.%03d" $((RUNTIME/1000000000/60/60)) $((RUNTIME/1000000000/60%60)) $((RUNTIME/1000000000%60)) $((RUNTIME/1000000%1000)) )"

done

exit ${FTPL_ERR}
