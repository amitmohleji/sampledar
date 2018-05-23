#
# Sample code to demonstrate the usage of CQ Perl APIs for User
# Administration
#
#
#######################################################################
# Usage:
#
# cqperl cqusertools.pl
# [--HELP]
# {--DBSET=<dbset>}
# {--ADMIN_USER=<username>}
# {--ADMIN_PWD=<password>}
# [--USERDB=<user db name>]
# [--SUBSCRIBE_ALL_DBS=true/false]
# [--UNSUBSCRIBE_ALL_DBS=true/false]
# {--COMMAND=<command>}
# user1 user2 ... user-n
#
# COMMANDS available are "ADD_USER", "RENAME_USER", "SUBSCRIBE_USER",
# "UNSUBSCRIBE_USER", "ACTIVATE_USER" and "DEACTIVATE_USER"
#
#
#######################################################################
use CQPerlExt;
use strict;
use warnings;
use Getopt::Long;
use Error qw(:try);
# Define command syntax...
my($Usage) = "Usage:\n"
."\n"
." cqperl cqusertools.pl [--HELP]\n"
." {--DBSET=<dbset>}\n"
." {--ADMIN_USER=<username>}\n"
." {--ADMIN_PWD=<password>}\n"
." [--USERDB=<user db name>]\n"
." [--SUBSCRIBE_ALL_DBS=true/false]\n"
." [--UNSUBSCRIBE_ALL_DBS=true/false]\n"
." {--COMMAND=<command>}\n"
." user1 user2 ... user-n\n"
."\n"
." Parameters:\n"
." --HELP Displays this usage message\n"
." --DBSET: CQ DBSet (connection) name\n"
." --ADMIN_USER: CQ administrative user\n"
." --ADMIN_PWD: CQ administrative user's password\n"
." --USERDB: CQ User database. This needs to be specified for SubScribe/unsubscribe_user commands\n"
." COMMANDS available are 'ADD_USER', 'RENAME_USER', 'SUBSCRIBE_USER', 'UNSUBSCRIBE_USER', 'ACTIVATE_USER' and 'DEACTIVATE_USER'\n"
;

my $result = undef;
my $command = undef;
my $dbset = undef;
my $admin_user = undef;
my $admin_pwd = undef;
my $userdb = undef;
my $adminSession = undef;
my $subscribeAllDbs = undef;
my $unSubscribeAllDbs = undef;
my $help = undef;
my $noOptions = undef;
if (scalar(@ARGV) == 0)
{
$noOptions = 1;
}
Getopt::Long::Configure('ignore_case','posix_default','permute');
$result = GetOptions ("help" => \$help, "command:s" => \$command, "dbset:s" => \$dbset, "userdb:s" => \$userdb, "admin_user:s" => \$admin_user, "admin_pwd:s" => \$admin_pwd, "subscribe_all_dbs=s" => \$subscribeAllDbs, "unsubscribe_all_dbs=s" => \$unSubscribeAllDbs);
if ((defined $help)||(defined $noOptions))
{
print ("\n\n$Usage");
exit 0;
}
if ((!defined $command) || (!defined $dbset) || (!defined $admin_user) || (!defined $admin_pwd))
{
print "Usage error. You must specify 'command', 'dbset', 'admin_user' and 'admin_pwd' options\nUse -help option to see the usage";
exit 1;
}
my $b_subscribeUserToAllDbs = 0;
my $b_unSubscribeUserToAllDbs = 0;
if ((defined $subscribeAllDbs) && ($subscribeAllDbs =~ /true|yes|y|1/i))
{
my $b_subscribeUserToAllDbs = 1;
}
if ((defined $unSubscribeAllDbs) && ($unSubscribeAllDbs =~ /true|yes|y|1/i))
{
my $b_unSubscribeUserToAllDbs = 1;
}
if (!($command =~ /add_user|rename_user|activate_user|deactivate_user|subscribe_user|unsubscribe_user/i))
{
print "Invalid command. Specify one of: 'add_user', 'rename_user', 'deactivate_user', 'activate_user', 'subscribe_user', 'unsubscribe_user'\n";
exit 1;
}
#Create a Rational ClearQuest admin session
$adminSession = CQAdminSession::Build();
#Logon as admin
$adminSession->Logon( $admin_user, $admin_pwd, $dbset );
if (lc($command) eq "add_user")
{
foreach my $username (@ARGV)
{
try
{
my $newUserObj = $adminSession->CreateUser($username);
die "Unable to create the user!\n" unless $newUserObj;
$newUserObj->SetPassword("");
if ($b_subscribeUserToAllDbs)
{
$newUserObj->SetSubscribedToAllDatabases(1);
}
}
catch Error with
{
my $ex = shift;
print ("Error adding the user $username. Maybe the user already exists.\nHere is the error returned by CQ:\n$ex\n");
exit 1;
};
}
if ($b_subscribeUserToAllDbs)
{
my $dbList = $adminSession->GetDatabases();
#Get the number of databases
my $numDbs = $dbList->Count();
#Iterate through the databases. The first database is always the master. So, upgrade all (user) databases in
#this list excluding the first one (master)
for ( my $x=1; $x<$numDbs; $x++ )
{
#Get the specified item in the collection of databases
my $dbObj = $dbList->Item( $x );
#Upgrade the user database
$dbObj->UpgradeMasterUserInfo();
}
}
}
elsif (lc($command) eq "rename_user")
{
while (@ARGV)
{
my $username = shift;
my $newusername = shift;
try
{
my $userObj = $adminSession->GetUser($username);
die "Unable to find the user $username!\n" unless $userObj;
$userObj->SetLoginName($newusername, "");
# Upgrade the subscribed user dbs
upgradeSubscribedDbs ($userObj);
}
catch Error with
{
my $ex = shift;
print ("Error renaming the user $username.\nHere is the error returned by CQ:\n$ex\n");
exit 1;
};
}
}
elsif (lc($command) eq "deactivate_user")
{
foreach my $username (@ARGV)
{
my $userObj = $adminSession->GetUser($username);
die "Unable to find the user $username!\n" unless $userObj;
$userObj->SetActive(0);
# Upgrade the subscribed user dbs
upgradeSubscribedDbs ($userObj);
}
}
elsif (lc($command) eq "activate_user")
{
foreach my $username (@ARGV)
{
my $userObj = $adminSession->GetUser($username);
die "Unable to find the user $username!\n" unless $userObj;
$userObj->SetActive(1);
# Upgrade the subscribed user dbs
upgradeSubscribedDbs ($userObj);
}
}
elsif (lc($command) eq "subscribe_user")
{
die "User db is not specified\n" unless $userdb;
foreach my $username (@ARGV)
{
my $userObj = $adminSession->GetUser($username);
die "Unable to find the user $username!\n" unless $userObj;
if ($b_subscribeUserToAllDbs)
{
$userObj->SetSubscribedToAllDatabases(1);
}
else
{
my $dbObj = $adminSession->GetDatabase($userdb);
$userObj->SubscribeDatabase($dbObj);
$dbObj->UpgradeMasterUserInfo();
}
}
}
elsif (lc($command) eq "unsubscribe_user")
{
die "User db is not specified\n" unless $userdb;
foreach my $username (@ARGV)
{
my $userObj = $adminSession->GetUser($username);
die "Unable to find the user $username!\n" unless $userObj;
if ($b_unSubscribeUserToAllDbs)
{
if ($userObj->IsSubscribedToAllDatabases())
{
$userObj->SetSubscribedToAllDatabases(0);
}
else
{
print ("The user $username is not subscribed to all the databases. So, instead of --unsubscribe_all_dbs option, use --userdb option to specify the database from which the user should be unsubscribed\n");
}
}
else
{
if ($userObj->IsSubscribedToAllDatabases())
{
#Subscribing to user db works this way. If IsSubscribedToAllDatabases flag is set, the user is automatically
#subscribed to every user db (existing and future). But there will be no explicit subscription information about the
#user in the individual user dbs. (only the flag is sufficient).
#If the user was previously subscribed to all databases, then unset that flag
#Now we will have to explicitly subscribe the user to all databases except that specified by --userdb option (for unsubscription)
$userObj->SetSubscribedToAllDatabases(0);
my $dbList = $adminSession->GetDatabases();
#Get the number of databases
my $numDbs = $dbList->Count();
#Iterate through the databases. The first database is always the master. So, upgrade all (user) databases in
#this list excluding the first one (master)
for ( my $x=1; $x<$numDbs; $x++ )
{
#Get the specified item in the collection of databases
my $dbObj = $dbList->Item( $x );
my $dbname = $dbObj->GetName();
if (!(lc($dbname) eq lc($userdb)))
{
$userObj->SubscribeDatabase($dbObj);
}
#Upgrade the user database
$dbObj->UpgradeMasterUserInfo();
}
}
else
{
my $dbObj = $adminSession->GetDatabase($userdb);
$userObj->UnsubscribeDatabase($dbObj);
$dbObj->UpgradeMasterUserInfo();
}
}
}
}
CQAdminSession::Unbuild($adminSession);
sub upgradeSubscribedDbs
{
if (!defined $adminSession)
{
exit 1;
}
my ($userObj) = $_[0];
if ($userObj->IsSubscribedToAllDatabases())
{
my $dbList = $adminSession->GetDatabases();
#Get the number of databases
my $numDbs = $dbList->Count();
#Iterate through the databases. The first database is always the master. So, upgrade all (user) databases in
#this list excluding the first one (master)
for ( my $x=1; $x<$numDbs; $x++ )
{
#Get the specified item in the collection of databases
my $dbObj = $dbList->Item( $x );
#Upgrade the user database
$dbObj->UpgradeMasterUserInfo();
}
}
else
{
my $dbList = $userObj->GetSubscribedDatabases();
#Get the number of databases
my $numDbs = $dbList->Count();
#Iterate through the databases
for ( my $x=0; $x<$numDbs; $x++ )
{
#Get the specified item in the collection of databases
my $dbObj = $dbList->Item( $x );
my $dbName = $dbObj->GetName();
#Upgrade the user database
$dbObj->UpgradeMasterUserInfo();
}
}
}
