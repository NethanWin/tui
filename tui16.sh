#!/bin/bash

# --- Configuration & State ---
MODES=("BASIC" "STANDARD" "ADVANCED")
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
TOTAL_ITEMS=$((NUM_MODES + NUM_FEATURES))

# Current State Variables
CURRENT_FOCUS_INDEX=0   
CURRENT_MODE_INDEX=0      # Stores the actual selected mode index (0, 1, or 2)
NEEDS_REDRAW=1          # Flag to track if the screen needs to be redrawn

declare -a FEATURE_STATES
for i in "${!FEATURES[@]}"; do
    FEATURE_STATES[$i]=0
done

# --- Terminal Control Codes (set using tput) ---
CLEAR_SCREEN=$(tput clear)
MOVE_CURSOR=$(tput cup)
CURSOR_HIDE=$(tput civis)
CURSOR_SHOW=$(tput cnorm)
REVERSE_ON=$(tput rev)
REVERSE_OFF=$(tput sgr0)
BOLD_ON=$(tput bold)
BOLD_OFF=$(tput sgr0)

# --- Layout Constants ---
RADIO_COL=5
CHECK_COL=40
START_ROW=3
TITLE_ROW=1
INSTRUCT_ROW=$((NUM_FEATURES + 5))

# --- Drawing Functions ---

function apply_mode_defaults() {
    local mode="${MODES[$CURRENT_MODE_INDEX]}"
    
    # Reset features
    for i in "${!FEATURE_STATES[@]}"; do
        FEATURE_STATES[$i]=0
    done

    # Apply defaults
    if [[ "$mode" == "ADVANCED" ]]; then
        for i in "${!FEATURE_STATES[@]}"; do
            FEATURE_STATES[$i]=1
        done
    elif [[ "$mode" == "STANDARD" ]]; then
        FEATURE_STATES[0]=1
        FEATURE_STATES[2]=1
    fi
    NEEDS_REDRAW=1
}

function draw_mode_list() {
    echo -e "${MOVE_CURSOR}${TITLE_ROW} ${RADIO_COL}${BOLD_ON}1. Installation Mode (Up/Down/Space key)${BOLD_OFF}"

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
        
        echo -e "${MOVE_CURSOR}${ROW} ${RADIO_COL}${HIGHLIGHT}(${STATUS}) ${MODES[$i]}${CLEAR}      "
    done
}

function draw_feature_list() {
    echo -e "${MOVE_CURSOR}${TITLE_ROW} ${CHECK_COL}${BOLD_ON}2. Optional Features (Up/Down/Space key)${BOLD_OFF}"

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

        DESCRIPTION=$(echo "${FEATURES[$i]}" | cut -d: -f2)
        
        echo -e "${MOVE_CURSOR}${ROW} ${CHECK_COL}${HIGHLIGHT}[${STATUS}] ${DESCRIPTION}${CLEAR}      "
    done
}

# --- Initial Setup ---
if ! command -v tput &> /dev/null; then
    echo "Error: tput (part of ncurses) is required but not found."
    exit 1
fi

CURRENT_MODE_INDEX=$CURRENT_FOCUS_INDEX 
apply_mode_defaults 

echo -e "${CURSOR_HIDE}${CLEAR_SCREEN}"
tput smcup

# Save current terminal settings
ORIGINAL_STTY=$(stty -g)

# Disable canonical mode and input echoing for single-key input
stty -icanon min 1 -echo

# Trap function to restore terminal settings upon exit
function cleanup() {
    stty "$ORIGINAL_STTY"
    tput cnorm
    tput rmcup
}
trap cleanup EXIT

# --- Main Interaction Loop (Final Key Mapping) ---
while true; do
    
    if [[ $NEEDS_REDRAW -eq 1 ]]; then
        echo -e "${CLEAR_SCREEN}"
        draw_mode_list
        draw_feature_list
        # FINAL INSTRUCTIONS
        echo -e "${MOVE_CURSOR}${INSTRUCT_ROW} 5${BOLD_ON}Instructions:${BOLD_OFF} Use [Up]/[Down] to move, [Space] to select/toggle, [Enter] to submit, [Q] to quit."
        NEEDS_REDRAW=0
    fi

    # Read single character without timeout
    key=$(dd bs=1 count=1 2>/dev/null)

    # Handle Escape Sequences (Arrows)
    if [[ "$key" == $'\x1b' ]]; then
        # Read the next two characters for the arrow key sequence without waiting
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
            ;;
        $'\x1b[B') # DOWN Arrow
            if (( CURRENT_FOCUS_INDEX < TOTAL_ITEMS - 1 )); then
                CURRENT_FOCUS_INDEX=$((CURRENT_FOCUS_INDEX + 1))
            fi
            NEEDS_REDRAW=1
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
                else
                    FEATURE_STATES[$FEATURE_STATE_INDEX]=1
                fi
            fi
            NEEDS_REDRAW=1
            ;;

        # Enter Key: Confirm/Submit (Enter is $'\x0a' or sometimes $'\r' for Carriage Return)
        #$'\n' | $'\r') 
        $'\x0a' | '') 
            break # Exit the loop and run the cleanup/output section
            ;; 
        
        # Q: Quit
        'q' | 'Q') 
            exit 1 # trap EXIT will handle cleanup
            ;;
    esac
done

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

sleep 80
