#!/bin/bash
################################################################################
# TODO: Move these configurations to a config file and source them instead
##CONFIG VARS###
. ~/.config/sas.conf

################################# Global VARS ##################################
DEBUG=0
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
    # Strip newlines from string, return new string
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

function get_group_id {
    # Get group_id from ticket line, if no group found return 0
    local ticket
    local a
    local group_id
    ticket=$1
    a="$(grep -w "$ticket" $CASES_FILE | sed 's/^.*lelGroup //')"
    group_id=${a:=0}
    echo -n "$group_id"
}

function get_assignee_name {
    # Return assignee name from assignee id
    local assignee_id
    assignee_id=$1
    echo -n "$(grep -w "$assignee_id" $ZD_USER_LIST | awk {'print $2'})"
}

function add_to_checklist {
    # Check if ticket is in checklist, if it is then do nothing, else add ticket
    #   to checklist
    local ticket
    local checkinit
    ticket=$1
    checkinit=$(is_in_check_list "$ticket")
    if [[ $checkinit -eq 0 ]];then
        echo "Ticket: $ticket has been placed into checklist"
        echo $ticket | sed -e 's/<[^>]*>//g' >> $CHECKLIST_FILE #check which cases are flagging

    elif [[ $checkinit -eq 1 ]];then
        echo "Ticket: $ticket, already in checklist"
    fi
}

function lookup_ticket {
    # Fetch ticket information from cases file
    local ticket
    ticket=$1
    grep -w "$ticket" $CASES_FILE | sed -e's/[ \t]*$//' #lookup these cases in our library
}

function is_in_check_list {
    # Check if ticket is in the checklist
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
    # Get ticket id from cases file
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

function get_assignee {
    # Retrieve assignee id from cases file
    local ticket
    local whodidit
    local assignee
    ticket=$1
    whodidit=$(grep -w "$ticket" $CASES_FILE | sed 's/^.*lelUser //' | awk {'print $1'})
    assignee=${whodidit:=0}
    echo -n "$assignee"
}

function stylized_subject {
    # return a stylized subject line
    local ticket
    local lookup
    ticket=$1
    lookup=$(grep -w "$ticket" cases.txt | awk '!($1="")' | sed 's/SmolPeri/Unassigned/g' | sed 's/lelUser.*//') #lookup these cases in our library
    echo -en "$lookup"
}

function hyperlink_ticket {
    # Return hyperlink ticket text.
    local ticket_id
    ticket_id=$1
    $case_link=$(echo -e "<a href="$ZENDESK_URL/agent/tickets/$ticket_id">Click here for a link to the case</a></br>**Please Acknowledge!**</br>") #cre$
    echo -en "$case_link"
}

function clean_file {
    # 
    local filename
    local tempfile
    filename=$1
    tempfile=$(mktemp)
    sed "s/['\"]//g" "${filename}" | tr -cd '\11\12\40-\176' | perl -pe's/[^[:ascii:]]//g' | perl -pe's/[^[:ascii:]]//g' > ${tempfile}
    mv ${tempfile} $filename
}

################################################################################
################################################################################
################################################################################

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
            print_and_die 1 "ERROR: There was a problem, exiting."

        else
            print_and_die 1 "ERROR: There was a problem, exiting."

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

function handl_ooh_ticket {

}

function check_unassigned {
    local message
    local ticket
    local checklist
    local count
    local color
    ticket=$1

    lookups=$(lookup_ticket "$ticket")
    ticket_id=$(get_ticket_id "$ticket")
    checkin=$(is_in_check_list "$ticket")

    ##case vars##
    lookup=$(stylized_subject "$ticket") #lookup these cases in our library
    assignee=$(get_assignee "$ticket")
    case_link=$(hyperlink_ticket "$ticket_id") #cre$
    group_id=$(get_group_id "$ticket")
    assignee=$(get_assignee "$ticket")

    val=$(cat $HOMEDIR/sas-case/triggered/$ticket 2>&1)

    ##case vars##
    COUNTER=$(cat "$HOMEDIR/sas-case/ticket-count/$ticket" 2>/dev/null)

    ##if return is empty then we have moved##
    if [[ "$lookups" = "" || "$lookups" = " "  ]];then
        if [[ $group_id -eq 0 ]];then #if is in sas queue
            message=$(strip_newlines "<b>Ticket: $ticket - has been solved.</b>")

        elif [[ $group_id -eq "$ZENDESK_GROUP" ]];then #if not in sas queue
            message=$(strip_newlines "<b>Ticket: $ticket - has been moved from the SAS Queue.</b>")
        else
            message=$(strip_newlines "<b>Ticket: $ticket - has been solved.</b>")
        fi
        checklist="y"
        color="green"
        post_ticket "$ticket" "$checklist" "$count" "$color" "$message"

    ##if return is not empty and our unassign check is not empty then
    elif [[ "$ticket_d" -eq 0 ]];then
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
           echo $COUNTER > "$HOMEDIR/sas-case/ticket-count/$ticket" 2> /dev/null
           continue
        fi
    else
        if [[ $assignee -eq 0 ]];then
            assignee_name="Unknown"
        else
            assignee_name=$(grep -w "$assignee" $ZD_USER_LIST | awk {'print $2'})
        fi
        message=$(strip_newlines "<b>Ticket Assigned to User: $assignee_name, $ticket, $lookup</b>")
        color="green"
        checklist="y"
        post_ticket "$ticket" "$checklist" "$count" "$color" "$message"
    fi
}

function handle_moved_ticket {
    local ticket
    ticket=$1

    print_debug "I haz moved! $ticket"

    group_id=$(grep -w "$ticket" $CASES_FILE | sed 's/^.*lelGroup //')
    if [[ $group_id != "$ZENDESK_GROUP" || $group_id != ""$ZENDESK_GROUP"" ]];then
        message=$(strip_newlines "<b>Ticket Action: $ticket - has been moved from the SAS Queue.</b>")

    elif [[ $group_id = "$ZENDESK_GROUP" || $group_id = '$ZENDESK_GROUP' ]];then #this is a possible bug
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
    assignee=$(get_assignee "$ticket")
    case_link=$(hyperlink_ticket "$ticket_id") #cre$
    count=$(grep -i "SmolPeri" $CASES_FILE | uniq | awk '{print $1'} | sed -e 's/<[^>]*>//g' | wc -l)

    #add to checklist or not##
    ####################
    if [[ $lookups = " " && "$ticket_id" -eq 0 ]];then
        handle_moved_ticket "$ticket"
    elif [[ "$ticket_id" -eq 0 ]];then #if no asigned found
        if [[ "$checkin" -eq 0 ]];then #and not in checklist
            group_id=$(get_group_id "$ticket")
             if [[ $group_id -eq "$ZENDESK_GROUP" ]];then #if not in groyp
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
        checkinit=$(is_in_check_list "$ticket")
        if [[ $checkinit -eq 0]];then
            if [[ $assignee -eq 0 ]];then
                assignee_name="Unknown"
            else
                assignee_name=$(get_assignee_name "$assignee")
            fi
            message=$(strip_newlines "<b>Ticket Assigned to User: $assignee_name, $ticket, $lookup</b>")
            print_debug $message
            post_ticket "$ticket" "y" "$count" "green" "$message"

        else
            if [[ $assignee -eq 0 ]];then
                assignee_name="Unknown"
            else
                assignee_name=$(get_assignee_name "$assignee")
            fi
            message=$(strip_newlines "<b>Ticket Assigned to User: $assignee_name, $ticket, $lookup</b>")
            post_ticket "$ticket" "y" "$count" "green" "$message"
        fi

    fi

    add_to_checklist "$ticket"
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