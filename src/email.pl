#!/usr/bin/perl
use strict;
use warnings;
use Encode;
use Mail::IMAPClient;
use IO::Socket::SSL;
use MIME::Parser;
use Date::Parse qw(str2time);
use Date::Format qw(time2str);

sub setFlagStatus($$$$);
sub writeStatusLineFile(@);
sub formatStatusLine(@);
sub mergeUnreadCounts($@);
sub readUnreadCounts();
sub writeUnreadCounts($@);
sub relTime($);
sub clearError($);
sub hasError($);
sub readError($);
sub writeError($$);
sub readLastUpdated($);
sub writeLastUpdated($);
sub readUidFileCounts($$$);
sub readUidFile($$$);
sub writeUidFile($$$@);
sub cacheAllHeaders($$$);
sub cacheBodies($$$$@);
sub getBody($$$);
sub writeAttachments($$);
sub parseMimeEntity($);
sub parseAttachments($);
sub getCachedHeaderUids($$);
sub readCachedHeader($$$);
sub openFolder($$$);
sub getClient($);
sub getSocket($);
sub formatHeaderField($$);
sub formatDate($);
sub getFolderName($);
sub parseFolders($);
sub hasWords($);
sub readSecrets();
sub validateSecrets($);
sub modifySecrets($$);

my $SMTP_CLI_EXEC = "/opt/qtemail/bin/smtp-cli";
my $TMP_DIR = "/var/tmp";

my $secretsFile = "$ENV{HOME}/.secrets";
my $secretsPrefix = "email";
my @accConfigKeys = qw(user password server port);
my @accExtraConfigKeys = qw(
  inbox
  sent
  folders
  ssl
  smtp_server
  smtp_port
  new_unread_cmd
  skip
  preferHtml
  bodyCacheMode
);
my %enums = (
  bodyCacheMode => [qw(all unread none)],
);
my @optionsConfigKeys = qw(update_cmd encrypt_cmd decrypt_cmd);

my @headerFields = qw(Date Subject From To);
my $emailDir = "$ENV{HOME}/.cache/email";
my $unreadCountsFile = "$emailDir/unread-counts";
my $statusLineFile = "$emailDir/status-line";

my $VERBOSE = 0;
my $DATE_FORMAT = "%Y-%m-%d %H:%M:%S";
my $MAX_UNREAD_TO_CACHE = 100;

my $settings = {
  Peek => 1,
  Uid => 1,
  Ignoresizeerrors => 1,
};

my $okCmds = join "|", qw(
  --update --header --body --body-plain --body-html --attachments
  --smtp
  --mark-read --mark-unread
  --accounts --folders --print --summary --status-line
  --has-error --has-new-unread --has-unread
  --cache-all-bodies
  --read-config --write-config --read-options --write-options
);

my $usage = "
  Simple IMAP client. {--smtp command is a convenience wrapper around smtp-cli}
  Configuration is in $secretsFile
    Each line is one key of the format: $secretsPrefix.ACCOUNT_NAME.FIELD = value
    Account names can be any word characters (alphanumeric plus underscore)
    Other keys are ignored.
    required fields:
      user     {Required} IMAP username, usually the full email address
      password {Required} *password in plaintext*
      server   {Required} IMAP server
      port     {Required} IMAP server port
      ssl      {Optional} false to forcibly disable security
      inbox    {Optional} main IMAP folder name to use (default is \"INBOX\")
      sent     {Optional} IMAP folder name to use for sent mail
      folders  {Optional} colon-separated list of additional folders to fetch
        each folder has a FOLDER_NAME,
        which is the directory on the filesystem will be lowercase
        FOLDER_NAME is the folder, with all non-alphanumeric characters
          replaced with _s, and all leading and trailing _s removed
        e.g.:  junk:[GMail]/Drafts:_12_/ponies
               =>  [\"junk\", \"gmail_drafts\", \"12_ponies\"]

  ACCOUNT_NAME    the word following \"$secretsPrefix.\" in $secretsFile
  FOLDER_NAME     \"inbox\", \"sent\" or one of the names from \"folders\"
  UID             an IMAP UID {UIDVALIDITY is assumed to never change}

  $0 -h|--help
    show this message

  $0 [--update] [--folder=FOLDER_NAME_FILTER] [ACCOUNT_NAME ACCOUNT_NAME ...]
    -for each account specified {or all non-skipped accounts if none are specified}:
      -login to IMAP server, or create file $emailDir/ACCOUNT_NAME/error
      -for each FOLDER_NAME {or just FOLDER_NAME_FILTER if specified}:
        -fetch and write all message UIDs to
          $emailDir/ACCOUNT_NAME/FOLDER_NAME/all
        -fetch and cache all message headers in
          $emailDir/ACCOUNT_NAME/FOLDER_NAME/headers/UID
        -fetch and cache bodies according to bodyCacheMode config
            all    => every header that was cached gets its body cached
            unread => every unread message gets its body cached
            none   => no bodies are cached
          $emailDir/ACCOUNT_NAME/FOLDER_NAME/bodies/UID
        -fetch all unread messages and write their UIDs to
          $emailDir/ACCOUNT_NAME/FOLDER_NAME/unread
        -write all message UIDs that are now in unread and were not before
          $emailDir/ACCOUNT_NAME/FOLDER_NAME/new-unread
    -update global unread counts file $unreadCountsFile
      ignored or missing accounts are preserved in $unreadCountsFile

      write the unread counts, one line per account, to $unreadCountsFile
      e.g.: 3:AOL
            6:GMAIL
            0:WORK_GMAIL

  $0 --smtp ACCOUNT_NAME SUBJECT BODY TO [ARG ARG ..]
    simple wrapper around smtp-cli. {you can add extra recipients with --to}
    calls:
      $SMTP_CLI_EXEC \\
        --server=<smtp_server> --port=<smtp_port> \\
        --user=<user> --pass=<password> \\
        --from=<user> \\
        --subject=SUBJECT --body-plain=BODY \\
        --to=TO \\
        ARG ARG ..

  $0 --mark-read [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    login and mark the indicated message(s) as read

  $0 --mark-unread [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    login mark the indicated message(s) as unread

  $0 --accounts
    format and print information about each account
    \"ACCOUNT_NAME:<timestamp>:<relative_time>:<unread_count>/<total_count>:<error>\"

  $0 --folders ACCOUNT_NAME
    format and print information about each folder for the given account
    \"FOLDER_NAME:<unread_count>/<total_count>\"

  $0 --header [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    format and print the header of the indicated message(s)
    prints each of [@headerFields]
      one per line, formatted \"UID.FIELD: VALUE\"

  $0 --body [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    download, format and print the body of the indicated message(s)
    if body is cached, skip download
    if message has a plaintext and HTML component, only one is returned
    if preferHtml is false, plaintext is returned, otherwise, HTML

  $0 --body-plain [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    same as --body, but override preferHtml=false

  $0 --body-html [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    same as --body, but override preferHtml=true

  $0 --attachments [--folder=FOLDER_NAME] ACCOUNT_NAME DEST_DIR UID [UID UID ...]
    download the body of the indicated message(s) and save any attachments to DEST_DIR
    if body is cached, skip download

  $0 --print [--folder=FOLDER_NAME] [ACCOUNT_NAME ACCOUNT_NAME ...]
    format and print cached unread message headers and bodies

  $0 --summary [--folder=FOLDER_NAME] [ACCOUNT_NAME ACCOUNT_NAME ...]
    format and print cached unread message headers

  $0 --status-line [ACCOUNT_NAME ACCOUNT_NAME ...]
    does not fetch anything, merely reads $unreadCountsFile
    format and print $unreadCountsFile
    the string is a space-separated list of the first character of
      each account name followed by the integer count
    no newline character is printed
    if the count is zero for a given account, it is omitted
    if accounts are specified, all but those are omitted
    e.g.: A3 G6

  $0 --has-error [ACCOUNT_NAME ACCOUNT_NAME ...]
    checks if $emailDir/ACCOUNT_NAME/error exists
    print \"yes\" and exit with zero exit code if it does
    otherwise, print \"no\" and exit with non-zero exit code

  $0 --has-new-unread [ACCOUNT_NAME ACCOUNT_NAME ...]
    checks for any NEW unread emails, in any account
      {UIDs in $emailDir/ACCOUNT_NAME/new-unread}
    if accounts are specified, all but those are ignored
    print \"yes\" and exit with zero exit code if there are new unread emails
    otherwise, print \"no\" and exit with non-zero exit code

  $0 --has-unread [ACCOUNT_NAME ACCOUNT_NAME ...]
    checks for any unread emails, in any account
      {UIDs in $emailDir/ACCOUNT_NAME/unread}
    if accounts are specified, all but those are ignored
    print \"yes\" and exit with zero exit code if there are unread emails
    otherwise, print \"no\" and exit with non-zero exit code

  $0 --read-config ACCOUNT_NAME
    reads $secretsFile
    for each line of the form \"$secretsPrefix.ACCOUNT_NAME.KEY\\s*=\\s*VAL\"
      print KEY=VAL

  $0 --write-config ACCOUNT_NAME KEY=VAL [KEY=VAL KEY=VAL]
    modifies $secretsFile
    for each KEY/VAL pair:
      removes any line that matches \"$secretsPrefix.ACCOUNT_NAME.KEY\\s*=\"
      adds a line at the end \"$secretsPrefix.ACCOUNT_NAME.KEY = VAL\"

  $0 --read-options
    reads $secretsFile
    for each line of the form \"$secretsPrefix.KEY\\s*=\\s*VAL\"
      print KEY=VAL

  $0 --write-options KEY=VAL [KEY=VAL KEY=VAL]
    reads $secretsFile
    for each line of the form \"$secretsPrefix.KEY\\s*=\\s*VAL\"
      print KEY=VAL
";

sub main(@){
  my $cmd = shift if @_ > 0 and $_[0] =~ /^($okCmds)$/;
  $cmd = "--update" if not defined $cmd;

  die $usage if @_ > 0 and $_[0] =~ /^(-h|--help)$/;

  if($cmd =~ /^(--read-config|--read-options)$/){
    my $configGroup;
    if($cmd eq "--read-config"){
      die $usage if @_ != 1;
      $configGroup = shift;
    }elsif($cmd eq "--read-options"){
      die $usage if @_ != 0;
      $configGroup = undef;
    }
    my $config = readSecrets;
    my $accounts = $$config{accounts};
    my $options = $$config{options};
    my $vals = defined $configGroup ? $$accounts{$configGroup} : $options;
    if(defined $vals){
      for my $key(keys %$vals){
        print "$key=$$vals{$key}\n";
      }
    }
    exit 0;
  }elsif($cmd =~ /^(--write-config|--write-options)$/){
    my $configGroup;
    if($cmd eq "--write-config"){
      die $usage if @_ < 2;
      $configGroup = shift;
    }elsif($cmd eq "--write-options"){
      die $usage if @_ < 1;
      $configGroup = undef;
    }
    my @keyValPairs = @_;
    my $config = {};
    for my $keyValPair(@keyValPairs){
      if($keyValPair =~ /^(\w+)=(.*)$/){
        $$config{$1} = $2;
      }else{
        die "Malformed KEY=VAL pair: $keyValPair\n";
      }
    }
    modifySecrets $configGroup, $config;
    exit 0;
  }

  my $config = readSecrets();
  validateSecrets $config;
  my @accOrder = @{$$config{accOrder}};
  my $accounts = $$config{accounts};
  my %accFolders = map {$_ => parseFolders $$accounts{$_}} keys %$accounts;

  if($cmd =~ /^(--update)$/){
    $VERBOSE = 1;
    my $folderNameFilter;
    if(@_ > 0 and $_[0] =~ /^--folder=([a-z]+)$/){
      $folderNameFilter = $1;
      shift;
    }
    my @accNames;
    if(@_ == 0){
      for my $accName(@accOrder){
        my $skip = $$accounts{$accName}{skip};
        if(not defined $skip or $skip !~ /^true$/i){
          push @accNames, $accName;
        }
      }
    }else{
      @accNames = @_;
    }

    my $counts = {};
    my $isError = 0;
    my @newUnreadCommands;
    for my $accName(@accNames){
      my $acc = $$accounts{$accName};
      die "Unknown account $accName\n" if not defined $acc;
      clearError $accName;
      my $c = getClient($acc);
      if(not defined $c){
        $isError = 1;
        my $msg = "ERROR: Could not authenticate $$acc{name} ($$acc{user})\n";
        warn $msg;
        writeError $accName, $msg;
        writeStatusLineFile(@accOrder);
        next;
      }

      my $folders = $accFolders{$accName};
      my $unreadCount = 0;
      my $hasNewUnread = 0;
      for my $folderName(sort keys %$folders){
        if(defined $folderNameFilter and $folderName ne $folderNameFilter){
          print "skipping $folderName\n";
          next;
        }
        my $imapFolder = $$folders{$folderName};
        my $f = openFolder($imapFolder, $c, 0);
        if(not defined $f){
          $isError = 1;
          my $msg = "ERROR: Could not open folder $folderName\n";
          warn $msg;
          writeError $accName, $msg;
          writeStatusLineFile(@accOrder);
          next;
        }

        my @newMessages = cacheAllHeaders($accName, $folderName, $c);

        my @unread = $c->unseen;
        $unreadCount += @unread;

        my @toCache;
        my $bodyCacheMode = $$acc{bodyCacheMode};
        $bodyCacheMode = 'unread' if not defined $bodyCacheMode;
        if($bodyCacheMode eq "all"){
          @toCache = @newMessages;
        }elsif($bodyCacheMode eq "unread"){
          @toCache = @unread;
        }elsif($bodyCacheMode eq "none"){
          @toCache = ();
        }

        cacheBodies($accName, $folderName, $c, $MAX_UNREAD_TO_CACHE, @toCache);

        $c->close();

        my %oldUnread = map {$_ => 1} readUidFile $accName, $folderName, "unread";
        writeUidFile $accName, $folderName, "unread", @unread;
        my @newUnread = grep {not defined $oldUnread{$_}} @unread;
        writeUidFile $accName, $folderName, "new-unread", @newUnread;
        $hasNewUnread = 1 if @newUnread > 0;
      }
      $c->logout();
      $$counts{$accName} = $unreadCount;
      my $hasError = hasError $accName;
      if(not $hasError){
        writeLastUpdated $accName;
        if($hasNewUnread){
          my $cmd = $$acc{new_unread_cmd};
          push @newUnreadCommands, $cmd if defined $cmd and $cmd !~ /^\s*$/;
        }
      }
    }
    mergeUnreadCounts $counts, @accOrder;
    writeStatusLineFile(@accOrder);
    if(defined $$config{options}{update_cmd}){
      my $cmd = $$config{options}{update_cmd};
      print "running update_cmd: $cmd\n";
      system "$cmd";
    }
    for my $cmd(@newUnreadCommands){
      print "running new_unread_cmd: $cmd\n";
      system "$cmd";
    }
    exit $isError ? 1 : 0;
  }elsif($cmd =~ /^(--smtp)$/){
    die $usage if @_ < 4;
    my ($accName, $subject, $body, $to, @args) = @_;
    my $acc = $$accounts{$accName};
    die "Unknown account $accName\n" if not defined $acc;
    exec $SMTP_CLI_EXEC,
      "--server=$$acc{smtp_server}", "--port=$$acc{smtp_port}",
      "--user=$$acc{user}", "--pass=$$acc{password}",
      "--from=$$acc{user}",
      "--subject=$subject", "--body-plain=$body", "--to=$to",
      @args;
  }elsif($cmd =~ /^(--mark-read|--mark-unread)$/){
    my $folderName = "inbox";
    if(@_ > 0 and $_[0] =~ /^--folder=([a-z]+)$/){
      $folderName = $1;
      shift;
    }
    $VERBOSE = 1;
    die $usage if @_ < 2;
    my ($accName, @uids) = @_;
    my $readStatus = $cmd =~ /^(--mark-read)$/ ? 1 : 0;
    my $acc = $$accounts{$accName};
    die "Unknown account $accName\n" if not defined $acc;
    my $imapFolder = $accFolders{$accName}{$folderName};
    die "Unknown folder $folderName\n" if not defined $imapFolder;
    my $c = getClient($acc);
    die "Could not authenticate $accName ($$acc{user})\n" if not defined $c;
    my $f = openFolder($imapFolder, $c, 1);
    die "Error getting folder $folderName\n" if not defined $f;
    for my $uid(@uids){
      setFlagStatus($c, $uid, "Seen", $readStatus);
    }
    my @unread = readUidFile $$acc{name}, $folderName, "unread";
    my %all = map {$_ => 1} readUidFile $$acc{name}, $folderName, "all";
    my %marked = map {$_ => 1} @uids;

    my %toUpdate = map {$_ => 1} grep {defined $all{$_}} keys %marked;
    @unread = grep {not defined $toUpdate{$_}} @unread;
    if(not $readStatus){
      @unread = (@unread, sort keys %toUpdate);
    }
    writeUidFile $$acc{name}, $folderName, "unread", @unread;
    my $count = @unread;
    mergeUnreadCounts {$accName => $count}, @accOrder;
    writeStatusLineFile(@accOrder);
    $c->close();
    $c->logout();
  }elsif($cmd =~ /^(--accounts)$/){
    die $usage if @_ != 0;
    for my $accName(@accOrder){
      my $folders = $accFolders{$accName};
      my $unreadCount = 0;
      my $totalCount = 0;
      my $lastUpdated = readLastUpdated $accName;
      my $lastUpdatedRel = relTime $lastUpdated;
      my $error = readError $accName;
      $error = "" if not defined $error;
      for my $folderName(sort keys %$folders){
        $unreadCount += readUidFileCounts $accName, $folderName, "unread";
        $totalCount += readUidFileCounts $accName, $folderName, "all";
      }
      $lastUpdated = 0 if not defined $lastUpdated;
      print "$accName:$lastUpdated:$lastUpdatedRel:$unreadCount/$totalCount:$error\n";
    }
  }elsif($cmd =~ /^(--folders)$/){
    die $usage if @_ != 1;
    my $accName = shift;
    my $folders = $accFolders{$accName};
    for my $folderName(sort keys %$folders){
      my $unreadCount = readUidFileCounts $accName, $folderName, "unread";
      my $totalCount = readUidFileCounts $accName, $folderName, "all";
      printf "$folderName:$unreadCount/$totalCount\n";
    }
  }elsif($cmd =~ /^(--header)$/){
    my $folderName = "inbox";
    if(@_ > 0 and $_[0] =~ /^--folder=([a-z]+)$/){
      $folderName = $1;
      shift;
    }
    die $usage if @_ < 2;
    my ($accName, @uids) = @_;
    binmode STDOUT, ':utf8';
    for my $uid(@uids){
      my $hdr = readCachedHeader($accName, $folderName, $uid);
      die "Unknown message: $uid\n" if not defined $hdr;
      for my $field(@headerFields){
        print "$uid.$field: $$hdr{$field}\n";
      }
    }
  }elsif($cmd =~ /^(--body|--body-plain|--body-html|--attachments)$/){
    my $folderName = "inbox";
    if(@_ > 0 and $_[0] =~ /^--folder=([a-z]+)$/){
      $folderName = $1;
      shift;
    }
    die $usage if @_ < 2;
    my ($accName, $destDir, @uids);
    if($cmd =~ /^(--body|--body-plain|--body-html)/){
      ($accName, @uids) = @_;
      $destDir = $TMP_DIR;
      die $usage if not defined $accName or @uids == 0;
    }elsif($cmd =~ /^(--attachments)$/){
      ($accName, $destDir, @uids) = @_;
      die $usage if not defined $accName or @uids == 0
        or not defined $destDir or not -d $destDir;
    }

    my $acc = $$accounts{$accName};
    my $preferHtml = 1;
    $preferHtml = 0 if defined $$acc{preferHtml} and $$acc{preferHtml} =~ /false/i;
    $preferHtml = 0 if $cmd eq "--body-plain";
    $preferHtml = 1 if $cmd eq "--body-html";
    die "Unknown account $accName\n" if not defined $acc;
    my $imapFolder = $accFolders{$accName}{$folderName};
    die "Unknown folder $folderName\n" if not defined $imapFolder;
    my $c;
    my $f;
    my $mimeParser = MIME::Parser->new();
    $mimeParser->output_dir($destDir);
    for my $uid(@uids){
      my $body = readCachedBody($accName, $folderName, $uid);
      if(not defined $body){
        if(not defined $c){
          $c = getClient($acc);
          die "Could not authenticate $accName ($$acc{user})\n" if not defined $c;
        }
        if(not defined $f){
          my $f = openFolder($imapFolder, $c, 0);
          die "Error getting folder $folderName\n" if not defined $f;
        }
        cacheBodies($accName, $folderName, $c, undef, $uid);
        $body = readCachedBody($accName, $folderName, $uid);
      }
      if(not defined $body){
        die "No body found for $accName=>$folderName=>$uid\n";
      }
      if($cmd =~ /^(--body|--body-plain|--body-html)$/){
        my $fmt = getBody($mimeParser, $body, $preferHtml);
        chomp $fmt;
        print "$fmt\n";
      }elsif($cmd =~ /^(--attachments)$/){
        my @attachments = writeAttachments($mimeParser, $body);
        for my $attachment(@attachments){
          print " saved att: $attachment\n";
        }
      }
    }
    $c->close() if defined $c;
    $c->logout() if defined $c;
  }elsif($cmd =~ /^(--cache-all-bodies)$/){
    $VERBOSE = 1;
    die $usage if @_ != 2;
    my ($accName, $folderName) = @_;

    my $acc = $$accounts{$accName};
    die "Unknown account $accName\n" if not defined $acc;
    my $c = getClient($acc);
    die "Could not authenticate $accName ($$acc{user})\n" if not defined $c;

    my $imapFolder = $accFolders{$accName}{$folderName};
    die "Unknown folder $folderName\n" if not defined $imapFolder;
    my $f = openFolder($imapFolder, $c, 0);
    die "Error getting folder $folderName\n" if not defined $f;

    my @messages = $c->messages;
    cacheBodies($accName, $folderName, $c, undef, @messages);
  }elsif($cmd =~ /^(--print)$/){
    my $folderName = "inbox";
    if(@_ > 0 and $_[0] =~ /^--folder=([a-z]+)$/){
      $folderName = $1;
      shift;
    }
    my @accNames = @_ == 0 ? @accOrder : @_;
    my $mimeParser = MIME::Parser->new();
    $mimeParser->output_dir($TMP_DIR);
    binmode STDOUT, ':utf8';
    for my $accName(@accNames){
      my @unread = readUidFile $accName, $folderName, "unread";
      for my $uid(@unread){
        my $hdr = readCachedHeader($accName, $folderName, $uid);
        my $cachedBody = readCachedBody($accName, $folderName, $uid);
        my $body = getBody($mimeParser, $cachedBody, 0);
        $body = "" if not defined $body;
        $body = "[NO BODY]\n" if $body =~ /^\s*$/;
        $body =~ s/^/  /mg;
        print "\n"
          . "ACCOUNT: $accName\n"
          . "UID: $uid\n"
          . "DATE: $$hdr{Date}\n"
          . "FROM: $$hdr{From}\n"
          . "TO: $$hdr{To}\n"
          . "SUBJECT: $$hdr{Subject}\n"
          . "BODY:\n$body\n"
          . "\n"
          ;
      }
    }
  }elsif($cmd =~ /^(--summary)$/){
    my $folderName = "inbox";
    if(@_ > 0 and $_[0] =~ /^--folder=([a-z]+)$/){
      $folderName = $1;
      shift;
    }
    my @accNames = @_ == 0 ? @accOrder : @_;
    for my $accName(@accNames){
      my @unread = readUidFile $accName, $folderName, "unread";
      for my $uid(@unread){
        my $hdr = readCachedHeader($accName, $folderName, $uid);
        print ""
          . "$accName"
          . " $$hdr{Date}"
          . " $$hdr{From}"
          . " $$hdr{To}"
          . "\n"
          . "  $$hdr{Subject}"
          . "\n"
          ;
      }
    }
  }elsif($cmd =~ /^(--status-line)$/){
    my @accNames = @_ == 0 ? @accOrder : @_;
    my $line = formatStatusLine(@accNames);
    print $line;
  }elsif($cmd =~ /^(--has-error)$/){
    my @accNames = @_ == 0 ? @accOrder : @_;
    for my $accName(@accNames){
      if(hasError $accName){
        print "yes\n";
        exit 0;
      }
    }
    print "no\n";
    exit 1;
  }elsif($cmd =~ /^(--has-new-unread)$/){
    my @accNames = @_ == 0 ? @accOrder : @_;
    my @fmts;
    for my $accName(@accNames){
      my $folders = $accFolders{$accName};
      for my $folderName(sort keys %$folders){
        my $unread = readUidFileCounts $accName, $folderName, "new-unread";
        if($unread > 0){
          print "yes\n";
          exit 0;
        }
      }
    }
    print "no\n";
    exit 1;
  }elsif($cmd =~ /^(--has-unread)$/){
    my @accNames = @_ == 0 ? @accOrder : @_;
    my @fmts;
    for my $accName(@accNames){
      my $folders = $accFolders{$accName};
      for my $folderName(sort keys %$folders){
        my $unread = readUidFileCounts $accName, $folderName, "unread";
        if($unread > 0){
          print "yes\n";
          exit 0;
        }
      }
    }
    print "no\n";
    exit 1;
  }
}

sub setFlagStatus($$$$){
  my ($c, $uid, $flag, $status) = @_;
  if($status){
    print "$uid $flag => true\n" if $VERBOSE;
    $c->set_flag($flag, $uid) or die "FAILED: set $flag on $uid\n";
  }else{
    print "$uid $flag => false\n" if $VERBOSE;
    $c->unset_flag($flag, $uid) or die "FAILED: unset flag on $uid\n";
  }
}

sub writeStatusLineFile(@){
  my @accNames = @_;
  my $line = formatStatusLine @accNames;
  open FH, "> $statusLineFile" or die "Could not write $statusLineFile\n";
  print FH $line;
  close FH;
}
sub formatStatusLine(@){
  my @accNames = @_;
  my $counts = readUnreadCounts();
  my @fmts;
  for my $accName(@accNames){
    die "Unknown account $accName\n" if not defined $$counts{$accName};
    my $count = $$counts{$accName};
    my $errorFile = "$emailDir/$accName/error";
    my $fmt = substr($accName, 0, 1) . $count;
    if(-f $errorFile){
      push @fmts, "$fmt!err";
    }else{
      push @fmts, $fmt if $count > 0;
    }
  }
  return "@fmts\n";
}

sub mergeUnreadCounts($@){
  my ($counts , @accOrder)= @_;
  $counts = {%{readUnreadCounts()}, %$counts};
  writeUnreadCounts($counts, @accOrder);
}
sub readUnreadCounts(){
  my $counts = {};
  if(not -e $unreadCountsFile){
    return $counts;
  }
  open FH, "< $unreadCountsFile" or die "Could not read $unreadCountsFile\n";
  for my $line(<FH>){
    if($line =~ /^(\d+):(.*)/){
      $$counts{$2} = $1;
    }else{
      die "malformed $unreadCountsFile line: $line";
    }
  }
  return $counts;
}
sub writeUnreadCounts($@){
  my ($counts , @accOrder)= @_;
  open FH, "> $unreadCountsFile" or die "Could not write $unreadCountsFile\n";
  for my $accName(@accOrder){
    print FH "$$counts{$accName}:$accName\n";
  }
  close FH;
}

sub relTime($){
  my ($time) = @_;
  return "never" if not defined $time;
  my $diff = time - $time;

  return "now" if $diff == 0;

  my $ago;
  if($diff > 0){
    $ago = "ago";
  }else{
    $diff = 0 - $diff;
    $ago = "in the future";
  }

  my @diffs = (
    [second  => int(0.5 + $diff)],
    [minute  => int(0.5 + $diff / 60)],
    [hour    => int(0.5 + $diff / 60 / 60)],
    [day     => int(0.5 + $diff / 60 / 60 / 24)],
    [month   => int(0.5 + $diff / 60 / 60 / 24 / 30.4)],
    [year    => int(0.5 + $diff / 60 / 60 / 24 / 365.25)],
  );
  my @diffUnits = map {$$_[0]} @diffs;
  my %diffVals = map {$$_[0] => $$_[1]} @diffs;

  for my $unit(reverse @diffUnits){
    my $val = $diffVals{$unit};
    if($val > 0){
      my $unit = $val == 1 ? $unit : "${unit}s";
      return "$val $unit $ago";
    }
  }
}

sub hasError($){
  my ($accName) = @_;
  my $errorFile = "$emailDir/$accName/error";
  return -f $errorFile;
}
sub clearError($){
  my ($accName) = @_;
  my $errorFile = "$emailDir/$accName/error";
  system "rm", "-f", $errorFile;
}
sub readError($){
  my ($accName) = @_;
  my $errorFile = "$emailDir/$accName/error";
  if(not -f $errorFile){
    return undef;
  }
  open FH, "< $errorFile" or die "Could not read $errorFile\n";
  my $error = join "", <FH>;
  close FH;
  return $error;
}
sub writeError($$){
  my ($accName, $msg) = @_;
  my $errorFile = "$emailDir/$accName/error";
  open FH, "> $errorFile" or die "Could not write to $errorFile\n";
  print FH $msg;
  close FH;
}

sub readLastUpdated($){
  my ($accName) = @_;
  my $f = "$emailDir/$accName/last_updated";
  if(not -f $f){
    return undef;
  }
  open FH, "< $f" or die "Could not read $f\n";
  my $time = <FH>;
  close FH;
  chomp $time;
  return $time;
}
sub writeLastUpdated($){
  my ($accName) = @_;
  my $f = "$emailDir/$accName/last_updated";
  open FH, "> $f" or die "Could not write to $f\n";
  print FH time . "\n";
  close FH;
}

sub readUidFileCounts($$$){
  my ($accName, $folderName, $fileName) = @_;
  my $dir = "$emailDir/$accName/$folderName";

  if(not -f "$dir/$fileName"){
    return 0;
  }else{
    my $count = `wc -l $dir/$fileName`;
    if($count =~ /^(\d+)/){
      return $1;
    }
    return 0
  }
}

sub readUidFile($$$){
  my ($accName, $folderName, $fileName) = @_;
  my $dir = "$emailDir/$accName/$folderName";

  if(not -f "$dir/$fileName"){
    return ();
  }else{
    my @uids = `cat "$dir/$fileName"`;
    chomp foreach @uids;
    return @uids;
  }
}
sub writeUidFile($$$@){
  my ($accName, $folderName, $fileName, @uids) = @_;
  my $dir = "$emailDir/$accName/$folderName";
  system "mkdir", "-p", $dir;

  open FH, "> $dir/$fileName" or die "Could not write $dir/$fileName\n";
  print FH "$_\n" foreach @uids;
  close FH;
}

sub cacheAllHeaders($$$){
  my ($accName, $folderName, $c) = @_;
  print "fetching all message ids\n" if $VERBOSE;
  my @messages = $c->messages;
  print "fetched " . @messages . " ids\n" if $VERBOSE;

  my $dir = "$emailDir/$accName/$folderName";
  writeUidFile $accName, $folderName, "all", @messages;

  my $headersDir = "$dir/headers";
  system "mkdir", "-p", $headersDir;

  my %toSkip = map {$_ => 1} getCachedHeaderUids($accName, $folderName);

  @messages = grep {not defined $toSkip{$_}} @messages;
  my $total = @messages;

  print "downloading headers for $total messages\n" if $VERBOSE;
  my $headers = $c->parse_headers(\@messages, @headerFields);

  print "encoding and formatting $total headers\n" if $VERBOSE;
  my $count = 0;
  my $segment = int($total/20);

  if($VERBOSE){
    my $old_fh = select(STDOUT);
    $| = 1;
    select($old_fh);
  }

  for my $uid(keys %$headers){
    $count++;
    if($segment > 0 and $count % $segment == 0){
      my $pct = int(0.5 + 100*$count/$total);
      #print "\n" if $pct > 50 and $pct <= 55 and $VERBOSE;
      print "\n";
      print " $pct%" if $VERBOSE;
    }
    my $hdr = $$headers{$uid};
    my @fmtLines;
    my @rawLines;
    for my $field(sort @headerFields){
      my $vals = $$hdr{$field};
      my $val;
      if(not defined $vals or @$vals == 0){
        warn "\nWARNING: $uid has no field $field\n";
        $val = "";
      }else{
        $val = $$vals[0];
      }
      if($val =~ s/\n/\\n/){
        warn "\nWARNING: newlines in $uid $field {replaced with \\n}\n";
      }
      my $rawVal = $val;
      my $fmtVal = formatHeaderField($field, $val);
      push @fmtLines, "$field: $fmtVal\n";
      push @rawLines, "raw_$field: $rawVal\n";
    }
    open FH, "> $headersDir/$uid";
    binmode FH, ':utf8';
    print FH (@fmtLines, @rawLines);
    close FH;
  }
  print "\n" if $segment > 0 and $VERBOSE;

  return @messages;
}

sub cacheBodies($$$$@){
  my ($accName, $folderName, $c, $maxCap, @messages) = @_;
  my $bodiesDir = "$emailDir/$accName/$folderName/bodies";
  system "mkdir", "-p", $bodiesDir;

  local $| = 1;

  my %toSkip = map {$_ => 1} getCachedBodyUids($accName, $folderName);
  @messages = grep {not defined $toSkip{$_}} @messages;
  if(defined $maxCap and $maxCap > 0 and @messages > $maxCap){
    my $count = @messages;
    print "only caching $maxCap out of $count\n" if $VERBOSE;
    @messages = reverse @messages;
    @messages = splice @messages, 0, $maxCap;
    @messages = reverse @messages;
  }
  print "caching bodies for " . @messages . " messages\n" if $VERBOSE;
  my $total = @messages;
  my $count = 0;
  my $segment = int($total/20);
  $segment = 100 if $segment > 100;

  for my $uid(@messages){
    $count++;
    if($segment > 0 and $count % $segment == 0){
      my $pct = int(0.5 + 100*$count/$total);
      my $date = `date`;
      chomp $date;
      print "  {cached $count/$total bodies} $pct%  $date\n" if $VERBOSE;
    }
    my $body = $c->message_string($uid);
    $body = "" if not defined $body;
    if($body =~ /^\s*$/){
      if($body =~ /^\s*$/){
        warn "WARNING: no body found for $accName $folderName $uid\n";
      }
    }else{
      open FH, "> $bodiesDir/$uid" or die "Could not write $bodiesDir/$uid\n";
      print FH $body;
      close FH;
    }
  }
}

sub getBody($$$){
  my ($mimeParser, $bodyString, $preferHtml) = @_;
  my $mimeBody = $mimeParser->parse_data($bodyString);

  my @parts = parseMimeEntity($mimeBody);
  my @text = map {$_->{handle}} grep {$_->{partType} eq "text"} @parts;
  my @html = map {$_->{handle}} grep {$_->{partType} eq "html"} @parts;
  my @atts = map {$_->{handle}} grep {$_->{partType} eq "attachment"} @parts;

  my $body = "";
  for my $isHtml($preferHtml ? (1, 0) : (0, 1)){
    my @strings = map {$_->as_string} ($isHtml ? @html : @text);
    my $fmt = join "\n", @strings;
    if(hasWords $fmt){
      $body .= $fmt;
      last;
    }
  }
  $body =~ s/\r\n/\n/g;
  chomp $body;
  $body .= "\n" if length($body) > 0;

  my $attachments = "";
  my $first = 1;
  for my $att(@atts){
    my $path = $att->path;
    my $attName = $path;
    $attName =~ s/.*\///;
    if($preferHtml){
      $attachments .= "<br/>" if $first;
      $attachments .= "<i>attachment: $attName</i><br/>";
    }else{
      $attachments .= "\n" if $first;
      $attachments .= "attachment: $attName\n";
    }
    $first = 0;
  }

  $mimeParser->filer->purge;
  return $attachments . $body;
}

sub writeAttachments($$){
  my ($mimeParser, $bodyString) = @_;
  my $mimeBody = $mimeParser->parse_data($bodyString);
  my @parts = parseMimeEntity($mimeBody);
  my @attachments;
  for my $part(@parts){
    my $partType = $$part{partType};
    my $path = $$part{handle}->path;
    if($partType eq "attachment"){
      push @attachments, $path;
    }else{
      unlink $path or warn "WARNING: could not remove file: $path\n";
    }
  }
  return @attachments;
}

sub parseMimeEntity($){
  my ($entity) = @_;
  my $count = $entity->parts;
  if($count > 0){
    my @parts;
    for(my $i=0; $i<$count; $i++){
      my @subParts = parseMimeEntity($entity->parts($i));
      @parts = (@parts, @subParts);
    }
    return @parts;
  }else{
    my $type = $entity->effective_type;
    my $handle = $entity->bodyhandle;
    my $disposition = $entity->head->mime_attr('content-disposition');
    my $partType;
    if($type eq "text/plain"){
      $partType = "text";
    }elsif($type eq "text/html"){
      $partType = "html";
    }elsif(defined $disposition and $disposition =~ /attachment/){
      $partType = "attachment";
    }else{
      $partType = "unknown";
    }
    return ({partType=>$partType, handle=>$handle});
  }
}


sub getCachedHeaderUids($$){
  my ($accName, $folderName) = @_;
  my $headersDir = "$emailDir/$accName/$folderName/headers";
  my @cachedHeaders = `cd "$headersDir"; ls`;
  chomp foreach @cachedHeaders;
  return @cachedHeaders;
}
sub getCachedBodyUids($$){
  my ($accName, $folderName) = @_;
  my $bodiesDir = "$emailDir/$accName/$folderName/bodies";
  opendir DIR, $bodiesDir or die "Could not list $bodiesDir\n";
  my @cachedBodies;
  while (my $file = readdir(DIR)) {
    next if $file eq "." or $file eq "..";
    die "malformed file: $bodiesDir/$file\n" if $file !~ /^\d+$/;
    push @cachedBodies, $file;
  }
  closedir DIR;
  chomp foreach @cachedBodies;
  return @cachedBodies;
}

sub readCachedBody($$$){
  my ($accName, $folderName, $uid) = @_;
  my $bodyFile = "$emailDir/$accName/$folderName/bodies/$uid";
  if(not -f $bodyFile){
    return undef;
  }
  return `cat "$bodyFile"`;
}

sub readCachedHeader($$$){
  my ($accName, $folderName, $uid) = @_;
  my $hdrFile = "$emailDir/$accName/$folderName/headers/$uid";
  if(not -f $hdrFile){
    return undef;
  }
  my $header = {};
  open FH, "< $hdrFile";
  binmode FH, ':utf8';
  my @lines = <FH>;
  close FH;
  for my $line(@lines){
    if($line =~ /^(\w+): (.*)$/){
      $$header{$1} = $2;
    }else{
      warn "WARNING: malformed header line: $line\n";
    }
  }
  return $header;
}

sub openFolder($$$){
  my ($imapFolder, $c, $allowEditing) = @_;
  print "Opening folder $imapFolder\n" if $VERBOSE;

  my @folders = $c->folders($imapFolder);
  if(@folders != 1){
    return undef;
  }

  my $f = $folders[0];
  if($allowEditing){
    $c->select($f) or $f = undef;
  }else{
    $c->examine($f) or $f = undef;
  }
  return $f;
}

sub getClient($){
  my ($acc) = @_;
  my $network;
  if(defined $$acc{ssl} and $$acc{ssl} =~ /^false$/){
    $network = {
      Server => $$acc{server},
      Port => $$acc{port},
    };
  }else{
    my $socket = getSocket($acc);
    return undef if not defined $socket;

    $network = {
      Socket => $socket,
    };
  }
  print "$$acc{name}: logging in\n" if $VERBOSE;
  my $c = Mail::IMAPClient->new(
    %$network,
    User     => $$acc{user},
    Password => $$acc{password},
    %$settings,
  );
  return undef if not defined $c or not $c->IsAuthenticated();
  return $c;
}

sub getSocket($){
  my $acc = shift;
  return IO::Socket::SSL->new(
    PeerAddr => $$acc{server},
    PeerPort => $$acc{port},
  );
}

sub formatHeaderField($$){
  my ($field, $val) = @_;
  $val = decode('MIME-Header', $val);
  if($field =~ /^(Date)$/){
    $val = formatDate($val);
  }
  chomp $val;
  $val =~ s/\n/\\n/g;
  return $val;
}

sub formatDate($){
  my $date = shift;
  my $d = str2time($date);
  if(defined $d){
    return time2str($DATE_FORMAT, $d);
  }
  return $date;
}

sub getFolderName($){
  my $folder = shift;
  my $name = lc $folder;
  $name =~ s/[^a-z0-9]+/_/g;
  $name =~ s/^_+//;
  $name =~ s/_+$//;
  return $name;
}

sub parseFolders($){
  my $acc = shift;
  my $fs = {};

  my $f = defined $$acc{inbox} ? $$acc{inbox} : "INBOX";
  my $name = "inbox";
  die "DUPE FOLDER: $f and $$fs{$name}\n" if defined $$fs{$name};
  $$fs{$name} = $f;

  if(defined $$acc{sent}){
    my $f = $$acc{sent};
    my $name = "sent";
    die "DUPE FOLDER: $f and $$fs{$name}\n" if defined $$fs{$name};
    $$fs{$name} = $f;
  }
  if(defined $$acc{folders}){
    for my $f(split /:/, $$acc{folders}){
      $f =~ s/^\s*//;
      $f =~ s/\s*$//;
      my $name = getFolderName $f;
      die "DUPE FOLDER: $f and $$fs{$name}\n" if defined $$fs{$name};
      $$fs{$name} = $f;
    }
  }
  return $fs;
}

sub hasWords($){
  my $msg = shift;
  $msg =~ s/\W+//g;
  return length($msg) > 0;
}

sub readSecrets(){
  my @lines = `cat $secretsFile 2>/dev/null`;
  my $accounts = {};
  my $accOrder = [];
  my $okAccConfigKeys = join "|", (@accConfigKeys, @accExtraConfigKeys);
  my $okOptionsConfigKeys = join "|", (@optionsConfigKeys);
  my $optionsConfig = {};
  my $decryptCmd;
  for my $line(@lines){
    if($line =~ /^$secretsPrefix\.decrypt_cmd\s*=\s*(.*)$/){
      $decryptCmd = $1;
      last;
    }
  }
  for my $line(@lines){
    if($line =~ /^$secretsPrefix\.($okOptionsConfigKeys)\s*=\s*(.+)$/){
      $$optionsConfig{$1} = $2;
    }elsif($line =~ /^$secretsPrefix\.(\w+)\.($okAccConfigKeys)\s*=\s*(.+)$/){
      my ($accName, $key, $val)= ($1, $2, $3);
      if(not defined $$accounts{$accName}){
        $$accounts{$1} = {name => $accName};
        push @$accOrder, $accName;
      }
      if(defined $decryptCmd and $key =~ /password/){
        $val =~ s/'/'\\''/g;
        $val = `$decryptCmd '$val'`;
        die "error encrypting password\n" if $? != 0;
        chomp $val;
      }
      $$accounts{$accName}{$key} = $val;
    }elsif($line =~ /^$secretsPrefix\./){
      die "unknown config entry: $line";
    }
  }
  return {accounts => $accounts, accOrder => $accOrder, options => $optionsConfig};
}

sub validateSecrets($){
  my $config = shift;
  my $accounts = $$config{accounts};
  for my $accName(keys %$accounts){
    my $acc = $$accounts{$accName};
    for my $key(sort @accConfigKeys){
      die "Missing '$key' for '$accName' in $secretsFile\n" if not defined $$acc{$key};
    }
  }
}

sub modifySecrets($$){
  my ($configGroup, $config) = @_;
  my $prefix = "$secretsPrefix";
  if(defined $configGroup){
    if($configGroup !~ /^\w+$/){
      die "invalid account name, must be a word i.e.: \\w+\n";
    }
    $prefix .= ".$configGroup";
  }

  my @lines = `cat $secretsFile 2>/dev/null`;
  my $encryptCmd;
  for my $line(@lines){
    if(not defined $encryptCmd and $line =~ /^$secretsPrefix\.encrypt_cmd\s*=\s*(.*)$/){
      $encryptCmd = $1;
    }
  }

  my %requiredConfigKeys = map {$_ => 1} @accConfigKeys;

  my $okConfigKeys = join "|", (@accConfigKeys, @accExtraConfigKeys);
  my $okOptionsKeys = join "|", (@optionsConfigKeys);
  for my $key(sort keys %$config){
    if(defined $configGroup){
      die "Unknown config key: $key\n" if $key !~ /^($okConfigKeys)$/;
    }else{
      die "Unknown options key: $key\n" if $key !~ /^($okOptionsKeys)$/;
    }
    my $val = $$config{$key};
    my $valEmpty = $val =~ /^\s*$/;
    if($valEmpty){
      if(defined $configGroup and defined $requiredConfigKeys{$key}){
        die "must include '$key'\n";
      }
    }
    if(defined $encryptCmd and $key =~ /password/i){
      $val =~ s/'/'\\''/g;
      $val = `$encryptCmd '$val'`;
      die "error encrypting password\n" if $? != 0;
      chomp $val;
    }
    my $newLine = $valEmpty ? '' : "$prefix.$key = $val\n";
    my $found = 0;
    for my $line(@lines){
      if($line =~ s/^$prefix\.$key\s*=.*\n$/$newLine/){
        $found = 1;
        last;
      }
    }
    if(not $valEmpty and defined $enums{$key}){
      my $okEnum = join '|', @{$enums{$key}};
      die "invalid $key: $val\nexpects: $okEnum" if $val !~ /^($okEnum)$/;
    }
    push @lines, $newLine if not $found;
  }

  open FH, "> $secretsFile" or die "Could not write $secretsFile\n";
  print FH @lines;
  close FH;
}

&main(@ARGV);
