#!/bin/bash
VERSION="0.0.1"
YYYY=`date +'%Y'`
JSONBIN="$(command -v jq)"
DBBIN="$(command -v mysql)"
SHUFBIN="$(command -v shuf)"
DBARGS="--raw"
COLLATE="" # "character set utf8 collate utf8_bin"
RANDOMWORDS="random-words.txt"
# Database commands
ADMINDBUSER="root"
ADMINDB='mysql'
ADMINCHECK='show tables;'

ADMINCHECKDB='SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = "%s";'
ADMINDROPDB='drop database %s ; '
ADMINCREATEDB="create database %s $COLLATE; "

ADMINCHECKUSER='select * from user where user = "%s";'
ADMINDELETEUSER='delete from user where user = "%s";'
ADMINCREATEUSER="GRANT ALL PRIVILEGES ON %s.* TO '%s'@'%%' identified by '%s';"

RESULTS=()

#DEFAULT ACTION
ACTION='setup'
OUTPUT=""
INPUT='DATA_CONTRACT.json'
WORDS=$RANDOMWORDS
DBUSER=$ADMINDBUSER

#options
SHORTOPTIONS="vw:u:i:o:a:"
LONGOPTIONS="version,words:,user:,input:,output:,action:"

PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")
if [[ $? -ne 0 ]]; then
    # e.g. $? == 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# read getopts output this way to handle the quoting right:
eval set -- "$PARSED"

# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -v|--version)
            echo "Version: $VERSION"
            exit
	    ;;
        -a|--action)
            ACTION="$2"
            shift 2
	    ;;
        -u|--user)
            DBUSER="$2"
            shift 2
	    ;;
        -i|--input)
            INPUT="$2"
            shift 2
	    ;;
        -w|--words)
            WORDS="$2"
            shift 2
	    ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done


# Check for our required Binaries..

if ! [ -x "$JSONBIN" ]; then 
     echo "I require jq but it's not installed.  Aborting."
     exit 1 
fi

if ! [ -x "$DBBIN" ]; then 
     echo "I require MYSQL but it's not installed.  Aborting."
#     exit 1
fi

echo "JsonParser: $JSONBIN"
echo "mysql: $DBBIN"

# Get down to business

#parsing input
CONTRACT="$(cat $INPUT)"

echo "Processing $INPUT"
# Read json
TEAMNUM=`echo ${CONTRACT} | $JSONBIN '.numberOfTeams' `
if [ $? -ne 0 ]; then
   echo "JSON is not parserable.."
   exit 1;
fi
echo "Processing $TEAMNUM teams";

echo -n "Password for $DBUSER:"
read -s PASS
echo

DBCMD="$DBBIN $DBARGS -u $DBUSER -p$PASS -e "

# check for database access
echo "Checking database permissions...."
`$DBCMD "use $ADMINDB; $ADMINCHECK"`

# action
# setup = installs new databases/users for the current year (INPUT) based on json file.
# remove = removes existing database/users for current year (INPUT) based on json file.
# backup = back up (mysqldump) database/users for current year (INPUT) based on json file.

if [ "$ACTION" == "setup" ]; then
   echo "WARNING THIS WILL REMOVE ANY EXISTING DATA FROM THE DATABASE FROM CURRENT CONTRACT, and RE-CREATE IT"
   echo "Are you sure?"
  
   for ((i=1;i<$TEAMNUM;i++))
   do 
   DBNAME="${YYYY}_team_${i}"
   UNAME="${YYYY}_team_${i}"
   echo "Checking for existing Database: $DBNAME"
   printf -v CHKDB "$ADMINCHECKDB" "$DBNAME"
   printf -v DROPDB "$ADMINDROPDB" "$DBNAME"
  
   OUT=`$DBCMD "$CHKDB"`

   echo "Dropping Database"
   #ya i know shouldn't just ignore stderr
   OUT=`$DBCMD "$DROPDB" 2>/dev/null `
 
   echo "Creating Database"

   printf -v CREATEDB "$ADMINCREATEDB" "$DBNAME"
   OUT=`$DBCMD "$CREATEDB"`
   
   #echo "Commands:"
   #echo $CHKDB
   #echo $DROPDB
   #echo $CREATEDB

   echo "Checking for existing user"

   printf -v CHECKUSER "$ADMINCHECKUSER" "$UNAME"
   OUT=`$DBCMD "use $ADMINDB; $CHECKUSER"`

   echo "Removing existing user"

   printf -v DELETEUSER "$ADMINDELETEUSER" "$UNAME"
   #ya i know shouldn't just ignore stderr
   OUT=`$DBCMD "use $ADMINDB; $DELETEUSER" 2>/dev/null `

   echo "Creating user $UNAME and assigning permissions to database $DBNAME"
   PASS=`$SHUFBIN -n2 $RANDOMWORDS | sed 'N;s/\n/_/'` 
   printf -v CREATEUSER "$ADMINCREATEUSER" "$DBNAME" "$UNAME" "$PASS"
   OUT=`$DBCMD "$CREATEUSER"`

   #echo "Commands:"
   #echo $SELUSER
   #echo $CREATEUSER
   ITEM="$DBNAME,$UNAME,$PASS"
 
   RESULTS+="$ITEM\n"
done   

echo "Writing Results"
if [ "$OUTPUT" == "" ]; then
      echo ${RESULTS[@]}
else
      echo "${RESULTS[@]}" > $OUTPUT
fi

echo "Setup Complete."
# another action

elif [ "$ACTION" == "remove" ]; then
echo "NOT Implemented yet.. :("
elif [ "$ACTION" == "backup" ]; then
echo "NOT Implemented yet.. :("
else 
echo "No Action jackson"
fi

