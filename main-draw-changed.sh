#!/bin/bash

# --- Configuration & State ---
function setup_tui() {
    MODES=("Dev" "All" "Minimal")
    NUM_MODES=${#MODES[@]}
    MODE_END_INDEX=$((NUM_MODES - 1)) # Index of the last mode

    FEATURES=(
        "DB_OPTIMIZE:Database Tuning and Optimization:0" 
        "WEB_CACHING:Enable Web Server Caching:0"
        "LOG_ROTATE:Setup Log Rotation & Monitoring:0"
        "NET_FIREWALL:Configure Network Firewall Rules:0"
        "BENCHMARKS:Run Post-Install Benchmarks:0"
    )
    NUM_FEATURES=${#FEATURES[@]}
    TOTAL_ITEMS=$((NUM_MODES + NUM_FEATURES))   # to know when youre in the last item and then go up

    # Current State Variables
    CURRENT_FOCUS_INDEX=0   
    CURRENT_MODE_INDEX=0      # Stores the actual selected mode index (0, 1, or 2)
    NEEDS_REDRAW=1          # Flag to track if the screen needs to be redrawn

    # sets feature list to unselected(0)
    declare -a FEATURE_STATES
    for i in "${!FEATURES[@]}"; do
        FEATURE_STATES[$i]=0
    done

    # --- Terminal Control Codes (set using tput) ---
    MOVE_CURSOR=$(tput cup)
    CURSOR_HIDE=$(tput civis)
    CURSOR_SHOW=$(tput cnorm)
    REVERSE_ON=$(tput rev)
    REVERSE_OFF=$(tput sgr0)


    # --- Layout Constants ---
    RADIO_COL=5
    CHECK_COL=40
    START_ROW=0
    TITLE_ROW=1
    INSTRUCT_ROW=$((NUM_FEATURES + 5))

    


    # --- Initial Setup ---
    if ! command -v tput &> /dev/null; then
        echo "Error: tput (part of ncurses) is required but not found."
        exit 1
    fi

    CURRENT_MODE_INDEX=$CURRENT_FOCUS_INDEX 
    apply_mode_defaults 

    # setup screen to "raw mode"
    echo -e "${CURSOR_HIDE}"
    #clear_screen
    tput smcup

    # Save current terminal settings
    ORIGINAL_STTY=$(stty -g)

    # Disable canonical mode and input echoing for single-key input
    stty -icanon min 1 -echo

    trap cleanup EXIT
    NEEDS_REDRAW=1      # draw screen first time
}

# --- Drawing Functions ---
function draw_text() {
    # $1 text, $2 is reverse, $3 row
    local row=$((START_ROW + $3))
    local col=1
    local start_text="$(tput cup $row $col)"
    local end_text=""
    if $2; then
        start_text="${start_text}${REVERSE_ON}"
        end_text="${REVERSE_OFF}${end_text}"
    fi
    
    #echo -e "${MOVE_CURSOR}${ROW} ${RADIO_COL}${HIGHLIGHT}(${STATUS}) ${MODES[$i]}${CLEAR}      "

    echo -e "${start_text}$1${end_text}"
}

function apply_mode_defaults() {
    local mode="${MODES[$CURRENT_MODE_INDEX]}"
    
    # Reset features
    for i in "${!FEATURE_STATES[@]}"; do
        FEATURE_STATES[$i]=0
    done

    # Apply defaults
    if [[ $CURRENT_MODE_INDEX == 1 ]]; then
        for i in "${!FEATURE_STATES[@]}"; do
            FEATURE_STATES[$i]=1
        done
    elif [[ $CURRENT_MODE_INDEX == 2 ]]; then
        FEATURE_STATES[0]=1
        FEATURE_STATES[2]=1
    fi
    NEEDS_REDRAW=1
}

function draw_mode_list() {
    #echo -e "${MOVE_CURSOR}${TITLE_ROW} ${RADIO_COL}${BOLD_ON}1. Installation Mode (Up/Down/Space key)${BOLD_OFF}"

    echo -e "      Choose Install Option:      "
    echo
    for i in "${!MODES[@]}"; do
        ROW=$((i + START_ROW))

        HIGHLIGHT=""
        CLEAR=""
        if [[ "$i" -eq "$CURRENT_FOCUS_INDEX" ]]; then
            HIGHLIGHT="${REVERSE_ON}"
            CLEAR="${REVERSE_OFF}"
        fi

        STATUS=" "
        if [[ $i -eq $CURRENT_MODE_INDEX ]]; then
            STATUS="*"
        fi
        
        echo -e "      ${HIGHLIGHT}(${STATUS}) ${MODES[$i]}${CLEAR}      "
        #echo -e "${MOVE_CURSOR}${ROW} ${RADIO_COL}${HIGHLIGHT}(${STATUS}) ${MODES[$i]}${CLEAR}      "
    done
}

function draw_feature_list() {
    draw_text "Advanced Selection3" false 10
    draw_text "Advanced Selection20" false 20


    for i in "${!FEATURES[@]}"; do
        ROW=$((i + START_ROW))
        FEATURE_FOCUS_INDEX=$((i + NUM_MODES)) # Global index for this feature item

        HIGHLIGHT=""
        CLEAR=""
        if [[ "$FEATURE_FOCUS_INDEX" -eq "$CURRENT_FOCUS_INDEX" ]]; then
            HIGHLIGHT="${REVERSE_ON}"
            CLEAR="${REVERSE_OFF}"
        fi

        STATUS=" "
        if [[ ${FEATURE_STATES[$i]} -eq 1 ]]; then
            STATUS="X"
        fi

        #DESCRIPTION=$(echo "${FEATURES[$i]}" | cut -d: -f2)
        
        #echo -e "     ${HIGHLIGHT}[${STATUS}] ${DESCRIPTION}${CLEAR}      "
    done
}

# Trap function to restore terminal settings upon exit
function cleanup() {
    stty "$ORIGINAL_STTY"
    tput cnorm
    tput rmcup
}

function handle_key_press() {
    # Read single character without timeout
    IFS='' read -n 1 -s -r key
    #key=$(dd bs=1 count=1 2>/dev/null) # old way not needed

    # Reads two key presses to detect arrow keys
    if [[ "$key" == $'\x1b' ]]; then
        read -n 2 -t 0.001 sequence
        key="$key$sequence"
    fi

    # Process Input
    case "$key" in
        # Arrow Keys
        $'\x1b[A') # UP Arrow
            if (( CURRENT_FOCUS_INDEX > 0 )); then
                CURRENT_FOCUS_INDEX=$((CURRENT_FOCUS_INDEX - 1))
            fi
            NEEDS_REDRAW=1
            return 0
            ;;
        $'\x1b[B') # DOWN Arrow
            if (( CURRENT_FOCUS_INDEX < TOTAL_ITEMS - 1 )); then
                CURRENT_FOCUS_INDEX=$((CURRENT_FOCUS_INDEX + 1))
            fi
            NEEDS_REDRAW=1
            return 0
            ;;

        # Space Key ($'\x20' or actual space char ' '): Select Mode OR Toggle Feature
        ' ')
            if (( CURRENT_FOCUS_INDEX <= MODE_END_INDEX )); then
                # Focus is in the Mode List (Radio) -> Select it
                CURRENT_MODE_INDEX=$CURRENT_FOCUS_INDEX
                apply_mode_defaults 
            else
                # Focus is in the Feature List (Checkbox) -> Toggle it
                FEATURE_STATE_INDEX=$((CURRENT_FOCUS_INDEX - NUM_MODES))
                
                # Toggle the current feature state
                if [[ ${FEATURE_STATES[$FEATURE_STATE_INDEX]} -eq 1 ]]; then
                    FEATURE_STATES[$FEATURE_STATE_INDEX]=0
                    draw_text "XXX" true 3
                else
                    FEATURE_STATES[$FEATURE_STATE_INDEX]=1
                    draw_text "VVV" true 3
                fi
            fi
            NEEDS_REDRAW=1
            return 0
            ;;

        # Enter Key: Confirm/Submit (Enter is $'\x0a' or sometimes $'\r' for Carriage Return)
        #$'\n' | $'\r') 
        $'\x0a' | '')
            IS_CONFIRMED=true
            return 1 # Exit the loop and run the cleanup/output section
            ;; 
        
        # Q: Quit
        'q' | 'Q') 
            IS_CONFIRMED=false
            return 1 # trap EXIT will handle cleanup
            ;;
        *)
            return 0
            ;;
    esac
}

function draw_screen() {
    tput clear
    draw_text "Choose Install Option:" false 2
    draw_text "( ) a" false 3
    draw_text "( ) b" false 4
    draw_text "( ) c" false 5

    draw_text "Advenced Selection" false 7

    draw_text "[ ] 1" false 9
    draw_text "[ ] 2" false 10
    draw_text "[ ] 3" false 11
    draw_text "[ ] 4" false 12

    draw_text "Instructions: Use [Up]/[Down] to move, [Space] to select/toggle" false 14
    draw_text "[Enter] to apply, [Q] to quit." false 15
    NEEDS_REDRAW=0
}

function after_tui() {
    cleanup
    if $IS_CONFIRMED; then
        echo "confiremed"
    else
        echo "quiting"
    fi

    # --- Final Output ---
    # Note: Cleanup is handled by the trap EXIT function
    echo "-----------------------------------"
    echo "✅ Configuration Complete"
    echo "-----------------------------------"
    echo "Mode Selected: ${MODES[$CURRENT_MODE_INDEX]}"
    echo "Features Selected:"
    FINAL_SELECTION=""
    for i in "${!FEATURES[@]}"; do
        if [[ ${FEATURE_STATES[$i]} -eq 1 ]]; then
            TAG=$(echo "${FEATURES[$i]}" | cut -d: -f1)
            echo " -> [X] $TAG"
            FINAL_SELECTION+="$TAG "
        else
            TAG=$(echo "${FEATURES[$i]}" | cut -d: -f1)
            echo " -> [ ] $TAG"
        fi
    done
    echo "-----------------------------------"
    echo "FINAL_SELECTION_TAGS=\"$FINAL_SELECTION\""
}

setup_tui
draw_screen
# main loop
while handle_key_press; do
    if [[ $NEEDS_REDRAW -eq 1 ]]; then
        echo damn
        #draw_screen
    fi
done
after_tui
