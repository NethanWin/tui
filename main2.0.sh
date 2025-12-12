


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
        # UP Arrow
        $'\x1b[A' | $'\x1b[D')
            move_up
            ;;
        # DOWN Arrow
        $'\x1b[B' | $'\x1b[C')
            move_down
            ;;

        # Space Key ($'\x20' or actual space char ' '): Select Mode OR Toggle Feature
        ' ')
            toggle_option
            ;;

        # Enter Key: Confirm/Submit (Enter is $'\x0a' or sometimes $'\r' for Carriage Return)
        #$'\n' | $'\r') 
        $'\x0a' | '')
            CLOSE_TUI=true  # finishes loop
            QUIT=false
            ;; 
        
        # Q: Quit
        'q' | 'Q')
            CLOSE_TUI=true
            QUIT=true       # quiting the install
            ;;
    esac
}

function move_up() {
    #echo -e "(${FEATURE_STATE[$CURRENT_CURSOR_INDEX]}) ${FEATURES[$CURRENT_CURSOR_INDEX]}"
    CURRENT_CURSOR_INDEX=$((CURRENT_CURSOR_INDEX - 1))
    #echo -e "${REVERSE_ON}(${FEATURE_STATE[$CURRENT_CURSOR_INDEX]}) ${FEATURES[$CURRENT_CURSOR_INDEX]}${REVERSE_OFF}"
}

function move_down() {
    if (($CURRENT_CURSOR_INDEX >= $MODES_NUM)); then
        # feat
        draw_line $CURRENT_CURSOR_INDEX ${FEATURE_STATE[$CURRENT_CURSOR_INDEX]} false
        CURRENT_CURSOR_INDEX=$((CURRENT_CURSOR_INDEX + 1))
        draw_line $CURRENT_CURSOR_INDEX ${FEATURE_STATE[$CURRENT_CURSOR_INDEX]} true
    else
        # mode
        draw_line $CURRENT_CURSOR_INDEX $([ "$CURRENT_MODE" -eq "$CURRENT_CURSOR_INDEX" ] && echo true || echo false) false
        CURRENT_CURSOR_INDEX=$((CURRENT_CURSOR_INDEX + 1))
        draw_line $CURRENT_CURSOR_INDEX $([ "$CURRENT_MODE" -eq "$CURRENT_CURSOR_INDEX" ] && echo true || echo false) true
    fi
    
    #echo -e "(${FEATURE_STATE[$CURRENT_CURSOR_INDEX]}) ${FEATURES[$CURRENT_CURSOR_INDEX]}"
    #CURRENT_CURSOR_INDEX=$((CURRENT_CURSOR_INDEX + 1))
    #echo -e "${REVERSE_ON}(${FEATURE_STATE[$CURRENT_CURSOR_INDEX]}) ${FEATURES[$CURRENT_CURSOR_INDEX]}${REVERSE_OFF}"
}

function toggle_option() {
    # in space key press
    local state
    if (($CURRENT_CURSOR_INDEX >= $MODES_NUM)); then
        # toggle feat
        if [${FEATURE_STATE[(($CURRENT_CURSOR_INDEX - $MODE_NUM))]} == 1]; then
            state=0
        else
            state=1
        fi
        FEATURE_STATE[(($CURRENT_CURSOR_INDEX - $MODE_NUM))]=$state
        draw_line $CURRENT_CURSOR_INDEX $state true
    else
        # set mode
        if (($CURRENT_MODE != $CURRENT_CURSOR_INDEX)); then
            CURRENT_MODE=$CURRENT_CURSOR_INDEX
            draw_line $CURRENT_CURSOR_INDEX true true
        fi
    fi

}

function draw_line() {
    # $1: cursor index (0-end of features)
    # $2: mark or unmark state?
    # $3 optional: is reverse
    local start
    local char
    if $3; then
            start="${REVERSE_ON}"
            end="${REVERSE_OFF}"
    fi

    if (($1 < $MODES_NUM)); then
        # Mode
        if $2; then
            char="*"
        else
            char=" "
        fi
        echo -e "${start}($char) ${MODES[$1]}${end}"
    else
        # Feature
        if [ "$2" = "true" ]; then
            char="V"
        else
            char=" "
        fi
        echo -e "${start}[$char] ${FEATURES[$1-$MODES_NUM]}${end}"
    fi
}


#setup_tui
#draw_screen
CLOSE_TUI=false
declare -a MODES=(
    "mode dev boy"
    "mode give me bloattt!!"
    "mode basic man"
)
declare -a FEATURES=(
    "feat install ssh"
    "feat setup minikube"
    "feat upgrade"
    "feat reboot"
)
declare -a FEATURE_STATE=(
    0
    0
    0
    0
)

MODES_NUM=${#MODES[@]}
FEATURES_NUM=${#FEATURES[@]}
CURRENT_MODE=0

CURRENT_CURSOR_INDEX=0
PREVIOUS_CURSOR_INDEX=-1
CURSOR_ON_FEATURE=false

REVERSE_ON=$(tput rev)
REVERSE_OFF=$(tput sgr0)


# main loop
while !($CLOSE_TUI); do
    handle_key_press
done

#after_tui
#echo -e "${REVERSE_ON}[X] ${DESCRIPTION}${REVERSE_OFF}      "

if $QUIT; then
    echo "quiting"
else
    echo "cauntiniuing install"
fi