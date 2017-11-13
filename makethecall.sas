#!/bin/bash
################################################################################
# TODO: Move these configurations to a config file and source them instead
##GLOBAL VARS###
ROOM_ID2=XXXX #Room ID for hipchat to post
AUTH_TOKEN="xxxxx" #my auth token
NOTIFY="True" #notify yes
FROM="SAS - !!Ticket Management!! " #from
USER="XXX" #user to notify about alerts too 
HOMEDIR="/home/rthomas"
CASES_FILE="$HOMEDIR/sas-case/cases.txt"
CHECKLIST_FILE="$HOMEDIR/sas-case/checklist"
HIPCHAT_URL="https://api.hipchat.com/v2"
ZENDESK_GROUP="36888527"
ZENDESK_URL="https://alertlogic.zendesk.com"
d=$(date)
################################################################################
function strip_newlines {
    local mystring=$1
    echo -n "$mystring" | sed ':a;N;$!ba;s/\n/ /g'
}

function post_ticket {
    local ticket=$1
    local checklist=$2
    local count=$3
    local color=$4
    local message=$5

    if [[ $checklist == "y" || $checklist == "Y" ]];then
        sed -i 's/'$ticket'//g' $CHECKLIST_FILE
        sed -i '/^$/d' $CHECKLIST_FILE
        rm $HOMEDIR/sas-case/ticket-count/"$ticket" 2> /dev/null

    elif [[ $count == "0" || $count = "0" ]];then
        echo "yes" > $HOMEDIR/sas-case/triggered/$ticket
        echo "0" > $HOMEDIR/sas-case/ticket-count/$ticket
    fi
    post "$color" "$message"
}

function post {
    local color=$1
    local message=$2

    ##to you##
    curl -s -H "Content-Type: application/json" -X POST -d "{\
        \"color\": \"$color\",\
        \"message_format\": \"html\",\
        \"message\": \"$message\",\
        \"notify\": \"$NOTIFY\",\
        \"from\": \"$FROM\"\
    }" "$HIPCHAT_URL/room/$ROOM_ID2/notification?auth_token=$AUTH_TOKEN"

    ##to me##
    # Question: Why pipe this error to devnull but not above?
    curl -s -H "Content-Type: application/json" -X POST -d "{\
        \"color\": \"yellow\",\
        \"message_format\": \"html\",\
        \"message\": \"$message\",\
        \"notify\": \"$NOTIFY\",\
        \"from\": \"$FROM\"\
    }" "$HIPCHAT_URL/user/$USER/message?auth_token=$AUTH_TOKEN" 2>/dev/null
}

function init {
    casefile=$(cat $CASES_FILE)
    if [[ "$casefile" == "" || "$casefile" == " " || "$casefile" = "" ]];then
        echo "WARNING: Something is wrong with the perl script!!"
        sleep 5
        echo "we have slept,rerunning.."
        perl $HOMEDIR/sas-case/test-hipchat.pl
        if [ $? == 0 ];then
            start "$@"

        elif [[ "$casefile" == "" || "$casefile" == " " || "$casefile" = "" ]];then
            echo "ERROR: There was a problem, exiting."
            exit 1

        else
            echo "ERROR: There was a problem, exiting."
            exit 1

        fi

    else
        echo "" > $CASES_FILE
        perl $HOMEDIR/sas-case/test-hipchat.pl
        if [ $? == 0 ];then
                start "$@"
        else
            sleep 10
            echo "we have slept,rerunning.."
            init "$@"
        fi
    fi
}

function start {
    ###Get rid of the odd characters##
    sed  -i "s/['\"]//g" $CASES_FILE #remove stray comma characters in subject
    tr -cd '\11\12\40-\176' < $CASES_FILE > $HOMEDIR/sas-case/cases1.txt #first run of non-ascii removal
    mv $HOMEDIR/sas-case/cases1.txt $CASES_FILE
    perl -pe's/[^[:ascii:]]//g' < $CASES_FILE > $HOMEDIR/sas-case/cases1.txt #second run of non-ascii removal
    mv $HOMEDIR/sas-case/cases1.txt $CASES_FILE
    ###end of error checking###

    tick1=$(grep -i "SmolPeri" $CASES_FILE | uniq | awk '{print $1'} | sed -e 's/<[^>]*>//g') #pulled tickets
    if [ -s $CHECKLIST_FILE ];then #if checklist not empty then
        check_unassigned "$@"

    elif [[ "$tick1" = "" || "$tick1" = " "  ]];then #if no difference then rerun
        echo -e "Currently no Unassigned Tickets.\n"
        echo -e "========================================\n"
        exit 1

    else
        #GO MAIN
        main "$@"

    fi

}

function check_unassigned {
    echo -e "=============== Unassigned Tickets Checklist ==========================\n"
    while read ticket; do
        lookups=$(grep -w "$ticket" $CASES_FILE) #check our cases.txt for the ticket
        c2=$(grep "$ticket" $CASES_FILE | grep -v "SmolPeri" | awk '{print $1'}| sed -e 's/<[^>]*>//g')
        val=$(cat $HOMEDIR/sas-case/triggered/$ticket 2>&1)

        ##case vars##
        lookup=$(grep -w "$ticket" $CASES_FILE | awk '!($1="")' | sed 's/SmolPeri/Unassigned/g' | sed 's/lelUser.*//') #lookup these cases in o$
        case=$(echo -e "<a href="$ZENDESK_URL/agent/tickets/$ticket">Click here for a link to the case</a></br>**Please Acknowledge!**</br>")
        havemoved=$(grep -w "$ticket" $CASES_FILE | sed 's/^.*lelGroup //')
        COUNTER=$(cat $HOMEDIR/sas-case/ticket-count/"$ticket" 2> /dev/null)
        whodidit=$(grep -w "$ticket" $CASES_FILE | sed 's/^.*lelUser //' | awk {'print $1'})

        ##if return is empty then we have moved##
        if [[ "$lookups" = "" || "$lookups" = " "  ]];then
            if [[ $havemoved = " " || $havemoved = '' ]];then #if is in sas queue
                MESSAGE=$(strip_newlines "<b>Ticket: $ticket - has been solved.</b>")

            elif [[ $havemoved != "$ZENDESK_GROUP" || $havemoved != '$ZENDESK_GROUP' ]];then #if not in sas queue
                MESSAGE=$(strip_newlines "<b>Ticket: $ticket - has been moved from the SAS Queue.</b>")
            else
                MESSAGE=$(strip_newlines "<b>Ticket: $ticket - has been solved.</b>")
            fi
            checklist="y"
            color="green"
            post_ticket "$color" "$checklist"

        ##if return is not empty and our unassign check is not empty then
        elif [[ "$c2" == "" || $c2 == " " ]];then
            stime="00" #start
            etime="07" #end
            time=$(date +"%H:%M") #current time
            day=$(date | awk {'print $1'}) #the day
                if [[ $time > $stime && $time < $etime ]];then #if current time is greater than the start and less than the end time then
                    echo -e "Out of hours, continuing"
                    continue

                elif [[ "$day" == "Sat" || "$day" == "Sun" ]];then
                    echo -e "Out of hours, continuing"
                    continue

                elif [[ "$COUNTER" == "21" || "$COUNTER" -gt "21" ]];then #180 was
                    MESSAGE=$(strip_newlines "<b>Ticket Remains Unacknowledged: $ticket, $lookup $case</b>")
                    post_ticket "red" "0"
                    ontinue
                else
                   COUNTER=$((COUNTER+1))
                   echo -e "Ticket:$ticket, Count:$COUNTER\n"
                   echo $COUNTER > $HOMEDIR/sas-case/ticket-count/"$ticket" 2> /dev/null
                   continue
                fi
        else
            if [[ $whodidit == "" || $whodidit == " " || $whodidit = " "  ]];then
                who="Unknown"
            else
                who=$(grep -w "$whodidit" listusers | awk {'print $2'})
            fi
            MESSAGE=$(strip_newlines "<b>Ticket Assigned to User: $who, $ticket, $lookup</b>")
            color="green"
            checklist="y"
            post_ticket "$color" "$checklist"
        fi
    done <$CHECKLIST_FILE

    echo -e "===============================================================================\n"
    main
}

function add_to_checklist {
    local ticket=$1
    local lookups=$2
    
}
function handle_ticket {
    local ticket=$1
    lookups=$(grep -w "$ticket" $CASES_FILE) #lookup these cases in our library
    c2=$(grep -w "$ticket" $CASES_FILE | grep -v "SmolPeri" | awk '{print $1'}| sed -e 's/<[^>]*>//g')
    checkin=$(cat $CHECKLIST_FILE | grep -w "$ticket")

    ##case vars##
    lookup=$(grep -w "$ticket" cases.txt | awk '!($1="")' | sed 's/SmolPeri/Unassigned/g' | sed 's/lelUser.*//') #lookup these cases in our library
    whodidit=$(grep -w "$ticket" $CASES_FILE | sed 's/^.*lelUser //' | awk {'print $1'})
    case=$(echo -e "<a href="$ZENDESK_URL/agent/tickets/$ticket">Click here for a link to the case</a></br>**Please Acknowledge!**</br>") #cre$
    count=$(grep -i "SmolPeri" $CASES_FILE | uniq | awk '{print $1'} | sed -e 's/<[^>]*>//g' | wc -l)

    #add to checklist or not##
    ####################
    if [[ $lookups = " " && "$c2" = " " ]];then
        echo "I haz moved!"
        havemoved=$(grep -w "$ticket" $CASES_FILE | sed 's/^.*lelGroup //')
        if [[ $havemoved != "$ZENDESK_GROUP" || $havemoved != ""$ZENDESK_GROUP"" ]];then
            MESSAGE=$(echo "<b>Ticket Action: $ticket - has been moved from the SAS Queue.</b>" | sed ':a;N;$!ba;s/\n/ /g')

        elif [[ $havemoved = "$ZENDESK_GROUP" || $havemoved = '$ZENDESK_GROUP' ]];then #this is a possible bug
            MESSAGE=$(echo "<b>Ticket Action: $ticket - showing as still in SAS but not in cases.txt</b>" | sed ':a;N;$!ba;s/\n/ /g')
            color="yellow"
            post_ticket "$color"
            continue
        else
            MESSAGE=$(echo "<b>Ticket Action: $ticket - has been solved.</b>" | sed ':a;N;$!ba;s/\n/ /g')
        fi

        color="green"
        checklist="y"
        post_ticket "$color" "$checklist"

    elif [[ "$c2" == "" || $c2 == " " ]];then #if no asigned found
        if [[ "$checkin" = "" || "$checkin" = " " ]];then #and not in checklist
            havemoved=$(grep -w "$ticket" $CASES_FILE | sed 's/^.*lelGroup //')
             if [[ $havemoved != "$ZENDESK_GROUP" || $havemoved != ""$ZENDESK_GROUP"" ]];then #if not in groyp
                #ticket was created but not in our queue #continue
                continue

            else #but if is in our grup
                if [[ $time > $stime && $time < $etime ]];then #if current time is greater than the start and less than the end time then
                    curl -s $ZENDESK_URL/api/v2/tickets/$ticket.json -H "Content-Type: application/json" -d '{"ticket": {"comment": {"body": "SBOT - This ticket was escalated out of SAS working hours, which are: 8am - 6PM CST (Monday-Friday). Please keep in mind that this ticket, and any associated alarms, will not be investigated out of these hours. However, if this is an emergency, please contact the SAS Engineer on Call. ", "public": "false"}}' \-v -u USERNAME:PASSWORD -X PUT
                    MESSAGE=$(echo "<b>New Ticket: $ticket, $lookup $case</b> - Escalated out of hours" | sed ':a;N;$!ba;s/\n/ /g')

                elif [[ "$day" == "Sat" || "$day" == "Sun" ]];then
                    curl -s $ZENDESK_URL/api/v2/tickets/$ticket.json -H "Content-Type: application/json" -d '{"ticket": {"comment": {"body": "SBOT - This ticket was escalated out of SAS working hours, which are: 8am - 6PM CST (Monday-Friday). Please keep in mind that this ticket, and any associated alarms, will not be investigated out of these hours.However, if this is an emergency, please contact the SAS Engineer on Call. ", "public": "false"}}' \-v -u USERNAME:PASSWORD -X PUT
                    MESSAGE=$(echo "<b>New Ticket: $ticket, $lookup $case</b> - Escalated out of hours" | sed ':a;N;$!ba;s/\n/ /g')

                else
                    MESSAGE=$(echo "<b>New Ticket: $ticket, $lookup $case</b>" | sed ':a;N;$!ba;s/\n/ /g')

                fi

                echo $MESSAGE #echo case for debug
                if [[ "$count" -gt "1" ]];then #and the count is greater than 1
                    echo "count is greater than 1.."
                    sleep 30
                    color="yellow"
                    post_ticket "$color"


                else
                    #just run it
                    echo "pushing case.."
                    color="yellow"
                    post_ticket "$color"
                fi
            fi
        else
            continue
        fi
    else
        checkinit=$(cat $CHECKLIST_FILE | grep -w "$ticket")
        if [[ $checkinit = "" || $checkinit == "" || $checkinit = " " ]];then
            if [[ $whodidit == "" || $whodidit == " " || $whodidit = " " ]];then
                who="Unknown"
            else
                who=$(grep -w "$whodidit" listusers | awk {'print $2'})
            fi
            MESSAGE=$(echo "<b>Ticket Assigned to User: $who, $ticket, $lookup</b>" | sed ':a;N;$!ba;s/\n/ /g')
            echo $MESSAGE
            color="green"
            checklist="y"
            post_ticket "$color" "$checklist"

        else
            if [[ $whodidit == "" || $whodidit == " " ]];then
                who="Unknown"
            else
                who=$(grep -w "$whodidit" listusers | awk {'print $2'})
            fi
            MESSAGE=$(echo "<b>Ticket Assigned to User: $who, $ticket, $lookup</b>" | sed ':a;N;$!ba;s/\n/ /g')
            color="green"
            checklist="y"
            post_ticket "$color" "$checklist"
        fi

    fi

    checkinit=$(cat $CHECKLIST_FILE | grep -w "$ticket")
    if [[ $checkinit = "" || $checkinit == "" || $checkinit = " " ]];then
        echo "Ticket: $ticket has been placed into checklist"
        echo $ticket | sed -e 's/<[^>]*>//g' >> $CHECKLIST_FILE #check which cases are flagging

    elif [[ `cat $CHECKLIST_FILE | grep $ticket` = $ticket || `cat $CHECKLIST_FILE | grep $ticket` == $ticket  ]];then
        echo "Ticket: $ticket, already in checklist"

    fi
}

function main {
    tick1=$(grep -i "SmolPeri" $CASES_FILE | uniq | awk '{print $1'} | sed -e 's/<[^>]*>//g') #pulled tickets
    count=$(grep -i "SmolPeri" $CASES_FILE | uniq | awk '{print $1'} | sed -e 's/<[^>]*>//g' | wc -l)

    for ticket in $(grep -i "SmolPeri" $CASES_FILE | awk {'print $1'} | sed -e 's/<[^>]*>//g'); do
        handle_ticket "$ticket"
    done
}

############## Global VARS ###################################################
d=$(date)
stime="00" #start
etime="07" #end
time=$(date +"%H:%M") #current time
day=$(date | awk {'print $1'}) #the day
################################################################################

echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
echo -e " SASBOT - Ticket Notification and Alert System"
echo -e "++++++++++++++++++++++++++++++++++++++++++++++++\\n"

if [[ $time > $stime && $time < $etime ]];then #if current time is greater than the start and less than the end time then
    echo "out of hours, extending wait time to 1 hour"
    sleep 3600
    d=$(date)
    echo -e "$d\n"
    init "$@"

elif [[ "$day" == "Sat" || "$day" == "Sun" ]];then
    echo "weekend, extending wait time to 2 hours"
    sleep 7200
    d=$(date)
    echo -e "$d\n"
    init "$@"

else
    echo -e "Sleeping 10 minutes to execute"
    echo -e "$time"
    sleep 600
    d=$(date)
    echo -e "$d\n"
    init "$@"
fi
    echo -e "Round Completed.\n"
