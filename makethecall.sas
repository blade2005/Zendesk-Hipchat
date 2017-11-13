#!/bin/bash
################################################################################
# TODO: Move these configurations to a config file and source them instead
##CONFIG VARS###
ROOM_ID2=XXXX #Room ID for hipchat to post
HC_USER="XXX" #user to notify about alerts too 
AUTH_TOKEN="xxxxx" #my auth token
NOTIFY="True" #notify yes
FROM="SAS - !!Ticket Management!! " #from
HOMEDIR="/home/rthomas"
CASES_FILE="$HOMEDIR/sas-case/cases.txt"
CHECKLIST_FILE="$HOMEDIR/sas-case/checklist"
ZD_USER_LIST="listusers"
HIPCHAT_URL="https://api.hipchat.com/v2"
ZENDESK_GROUP="36888527"
ZENDESK_URL="https://alertlogic.zendesk.com"
DEBUG=0
################################# Global VARS ##################################
d=$(date)
stime="00" #start
etime="07" #end
time=$(date +"%H:%M") #current time
day=$(date | awk {'print $1'}) #the day
################################################################################
function print_and_die {
    local mystring
    local ret
    mystring=$2
    ret=$1
    echo -e "$mystring"
    exit $ret
}

function print_debug {
    local mystring
    mystring=$1
    if [ "$DEBUG" -eq 1 ];then
        echo -e "$mystring"
    fi
}

function strip_newlines {
    local mystring=$1
    echo -n "$mystring" | sed ':a;N;$!ba;s/\n/ /g'
}

function post_ticket {
    local ticket
    local checklist
    local count
    local color
    local message
    ticket=$1
    checklist=$2
    count=$3
    color=$4
    message=$5

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
    }" "$HIPCHAT_URL/user/$HC_USER/message?auth_token=$AUTH_TOKEN" 2>/dev/null
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

function clean_file {
    local filename
    local tempfile
    filename=$1
    tempfile=$(mktemp)
    sed "s/['\"]//g" "${filename}" | tr -cd '\11\12\40-\176' | perl -pe's/[^[:ascii:]]//g' | perl -pe's/[^[:ascii:]]//g' > ${tempfile}
    mv ${tempfile} $filename
}

function start {
    local tickets
    clean_file "$CASES_FILE"

    ticket_ids_count=$(grep -i "SmolPeri" $CASES_FILE | uniq | awk '{print $1'} | sed -e 's/<[^>]*>//g' | wc -l) #pulled tickets

    if [ -s $CHECKLIST_FILE ];then #if checklist not empty then
        check_unassigned_loop "$@"

    elif [[ "$ticket_ids_count" -eq 0 ]];then #if no difference then rerun
        print_and_die 1 "Currently no Unassigned Tickets.\n\n========================================\n"

    else
        init_loop "$@"
    fi

}
function check_unassigned_loop {
    echo -e "=============== Unassigned Tickets Checklist ==========================\n"
    while read ticket; do
        check_unassigned "$ticket"
    done <$CHECKLIST_FILE

    echo -e "===============================================================================\n"
    init_loop

function check_unassigned {
    local message
    local ticket
    local checklist
    local count
    local color
    ticket=$1

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
            message=$(strip_newlines "<b>Ticket: $ticket - has been solved.</b>")

        elif [[ $havemoved != "$ZENDESK_GROUP" || $havemoved != '$ZENDESK_GROUP' ]];then #if not in sas queue
            message=$(strip_newlines "<b>Ticket: $ticket - has been moved from the SAS Queue.</b>")
        else
            message=$(strip_newlines "<b>Ticket: $ticket - has been solved.</b>")
        fi
        checklist="y"
        color="green"
        post_ticket "$ticket" "$checklist" "$count" "$color" "$message"

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
                message=$(strip_newlines "<b>Ticket Remains Unacknowledged: $ticket, $lookup $case</b>")
                post_ticket "$ticket" "0" "$count" "red" "$message"
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
            who=$(grep -w "$whodidit" $ZD_USER_LIST | awk {'print $2'})
        fi
        MESSAGE=$(strip_newlines "<b>Ticket Assigned to User: $who, $ticket, $lookup</b>")
        color="green"
        checklist="y"
        post_ticket "$ticket" "$checklist" "$count" "$color" "$message"
    fi
}

function add_to_checklist {
    local ticket=$1
    local lookups=$2
    
}

function lookup_ticket {
    local ticket
    ticket=$1
    grep -w "$ticket" $CASES_FILE | sed -e's/[ \t]*$//' #lookup these cases in our library
}

function is_in_check_list {
    local ticket
    ticket=$1
    local checkin
    checkin=$(grep -w "$ticket" $CHECKLIST_FILE)
    if [[ "$checkin" = "" || "$checkin" = " " ]];then #and not in checklist
        echo -n 0 # is IN checklist
    else
        echo -n 1 # is NOT in checklist
    fi
}

function get_ticket_id {
    local ticket
    local ticket_id
    ticket=$1
    ticket_id=$(grep -w "$ticket" $CASES_FILE | grep -v "SmolPeri" | awk '{print $1'}| sed -e 's/<[^>]*>//g')

    if [[ "$c2" == "" || $c2 == " " ]];then #if no asigned found
        echo -n 0 # NO ticket id
    else
        echo -n $ticket_id # Ticket ID
    fi
}

function assignee {
    local ticket
    local whodidit
    ticket=$1
    whodidit=$(grep -w "$ticket" $CASES_FILE | sed 's/^.*lelUser //' | awk {'print $1'})
    echo -n "$whodidit"
}

function stylized_subject {
    local ticket
    local lookup
    ticket=$1
    lookup=$(grep -w "$ticket" cases.txt | awk '!($1="")' | sed 's/SmolPeri/Unassigned/g' | sed 's/lelUser.*//') #lookup these cases in our library
    echo -en "$lookup"
}

function hyperlink_ticket {
    local ticket_id
    ticket_id=$1
    $case_link=$(echo -e "<a href="$ZENDESK_URL/agent/tickets/$ticket_id">Click here for a link to the case</a></br>**Please Acknowledge!**</br>") #cre$
    echo -en "$case_link"
}

function handle_moved_ticket {
    local ticket
    ticket=$1

    print_debug "I haz moved! $ticket"

    havemoved=$(grep -w "$ticket" $CASES_FILE | sed 's/^.*lelGroup //')
    if [[ $havemoved != "$ZENDESK_GROUP" || $havemoved != ""$ZENDESK_GROUP"" ]];then
        message=$(strip_newlines "<b>Ticket Action: $ticket - has been moved from the SAS Queue.</b>")

    elif [[ $havemoved = "$ZENDESK_GROUP" || $havemoved = '$ZENDESK_GROUP' ]];then #this is a possible bug
        message=$(strip_newlines "<b>Ticket Action: $ticket - showing as still in SAS but not in cases.txt</b>")
        post_ticket "$ticket" "" "" "$color" "$message"
        continue
    else
        message=$(strip_newlines "<b>Ticket Action: $ticket - has been solved.</b>")
    fi

    color="green"
    checklist="y"
    post_ticket "$ticket" "$checklist" "$count" "$color" "$message"    
}

function handle_ticket {
    local ticket
    local ticket_id
    local lookups
    local checkin
    local lookup
    local whodidit
    local case_link
    ticket=$1

    lookups=$(lookup_ticket "$ticket")
    ticket_id=$(get_ticket_id "$ticket")
    checkin=$(is_in_check_list "$ticket")

    ##case vars##
    lookup=$(stylized_subject "$ticket") #lookup these cases in our library
    whodidit=$(assignee "$ticket")
    case_link=$(hyperlink_ticket "$ticket_id") #cre$
    count=$(grep -i "SmolPeri" $CASES_FILE | uniq | awk '{print $1'} | sed -e 's/<[^>]*>//g' | wc -l)

    #add to checklist or not##
    ####################
    if [[ $lookups = " " && "$ticket_id" -eq 0 ]];then
        handle_moved_ticket "$ticket"
    elif [[ "$ticket_id" -eq 0 ]];then #if no asigned found
        if [[ "$checkin" -eq 0 ]];then #and not in checklist
            havemoved=$(grep -w "$ticket" $CASES_FILE | sed 's/^.*lelGroup //')
             if [[ $havemoved != "$ZENDESK_GROUP" || $havemoved != ""$ZENDESK_GROUP"" ]];then #if not in groyp
                #ticket was created but not in our queue #continue
                continue

            else #but if is in our grup
                if [[ $time > $stime && $time < $etime ]];then #if current time is greater than the start and less than the end time then
                    curl -s $ZENDESK_URL/api/v2/tickets/$ticket.json -H "Content-Type: application/json" -d '{"ticket": {"comment": {"body": "SBOT - This ticket was escalated out of SAS working hours, which are: 8am - 6PM CST (Monday-Friday). Please keep in mind that this ticket, and any associated alarms, will not be investigated out of these hours. However, if this is an emergency, please contact the SAS Engineer on Call. ", "public": "false"}}' \-v -u USERNAME:PASSWORD -X PUT
                    message=$(strip_newlines "<b>New Ticket: $ticket, $lookup $case</b> - Escalated out of hours")

                elif [[ "$day" == "Sat" || "$day" == "Sun" ]];then
                    curl -s $ZENDESK_URL/api/v2/tickets/$ticket.json -H "Content-Type: application/json" -d '{"ticket": {"comment": {"body": "SBOT - This ticket was escalated out of SAS working hours, which are: 8am - 6PM CST (Monday-Friday). Please keep in mind that this ticket, and any associated alarms, will not be investigated out of these hours.However, if this is an emergency, please contact the SAS Engineer on Call. ", "public": "false"}}' \-v -u USERNAME:PASSWORD -X PUT
                    message=$(strip_newlines "<b>New Ticket: $ticket, $lookup $case</b> - Escalated out of hours")

                else
                    message=$(strip_newlines "<b>New Ticket: $ticket, $lookup $case</b>")

                fi

                print_debug $message #echo case for debug
                if [[ "$count" -gt "1" ]];then #and the count is greater than 1
                    echo "count is greater than 1.."
                    sleep 30
                    color="yellow"
                    post_ticket "$ticket" "$checklist" "$count" "$color" "$message"


                else
                    #just run it
                    echo "pushing case.."
                    color="yellow"
                    post_ticket "$ticket" "$checklist" "$count" "$color" "$message"
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
                who=$(grep -w "$whodidit" $ZD_USER_LIST | awk {'print $2'})
            fi
            message=$(echo "<b>Ticket Assigned to User: $who, $ticket, $lookup</b>" | sed ':a;N;$!ba;s/\n/ /g')
            echo $message
            color="green"
            checklist="y"
            post_ticket "$ticket" "$checklist" "$count" "$color" "$message"

        else
            if [[ $whodidit == "" || $whodidit == " " ]];then
                who="Unknown"
            else
                who=$(grep -w "$whodidit" $ZD_USER_LIST | awk {'print $2'})
            fi
            MESSAGE=$(echo "<b>Ticket Assigned to User: $who, $ticket, $lookup</b>" | sed ':a;N;$!ba;s/\n/ /g')
            color="green"
            checklist="y"
            post_ticket "$ticket" "$checklist" "$count" "$color" "$message"
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

function init_loop {
    tick1=$(grep -i "SmolPeri" $CASES_FILE | uniq | awk '{print $1'} | sed -e 's/<[^>]*>//g') #pulled tickets
    count=$(grep -i "SmolPeri" $CASES_FILE | uniq | awk '{print $1'} | sed -e 's/<[^>]*>//g' | wc -l)

    for ticket in $(grep -i "SmolPeri" $CASES_FILE | awk {'print $1'} | sed -e 's/<[^>]*>//g'); do
        handle_ticket "$ticket"
    done

}
function main {
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
}

main