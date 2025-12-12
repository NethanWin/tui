


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
    if (($CURRENT_CURSOR_INDEX <= 0)); then
        return
    fi
    if (($CURRENT_CURSOR_INDEX >= $MODES_NUM)); then
        # feat
        CURRENT_FEAT_INDEX=$(($CURRENT_CURSOR_INDEX - $MODES_NUM))
        local condition="${FEATURE_STATE[$CURRENT_FEAT_INDEX]}"
        draw_line $CURRENT_CURSOR_INDEX $condition false
        CURRENT_CURSOR_INDEX=$((CURRENT_CURSOR_INDEX - 1))
        CURRENT_FEAT_INDEX=$((CURRENT_FEAT_INDEX - 1))

        if (($CURRENT_CURSOR_INDEX == (($MODES_NUM - 1)))); then
            # moving between feat to mode
            CURRENT_FEAT_INDEX=$(($CURRENT_CURSOR_INDEX - $MODES_NUM))
            INDEX=$([ "$CURRENT_MODE" -eq "$CURRENT_CURSOR_INDEX" ] && echo true || echo false)
            draw_line $CURRENT_CURSOR_INDEX $INDEX true

        else
            draw_line $CURRENT_CURSOR_INDEX ${FEATURE_STATE[$CURRENT_FEAT_INDEX]} true
        fi
    else
        # mode
        draw_line $CURRENT_CURSOR_INDEX $([ "$CURRENT_MODE" -eq "$CURRENT_CURSOR_INDEX" ] && echo true || echo false) false
        CURRENT_CURSOR_INDEX=$((CURRENT_CURSOR_INDEX - 1))
        draw_line $CURRENT_CURSOR_INDEX $([ "$CURRENT_MODE" -eq "$CURRENT_CURSOR_INDEX" ] && echo true || echo false) true
    fi
}

function move_down() {
    if (($CURRENT_CURSOR_INDEX >= $(($TOTAL_NUM - 1)))); then
        return
    fi
    if (($CURRENT_CURSOR_INDEX >= $MODES_NUM)); then
        # feat
        CURRENT_FEAT_INDEX=$(($CURRENT_CURSOR_INDEX - $MODES_NUM))
        local condition="${FEATURE_STATE[$CURRENT_FEAT_INDEX]}"
        draw_line $CURRENT_CURSOR_INDEX $condition false
        CURRENT_CURSOR_INDEX=$((CURRENT_CURSOR_INDEX + 1))
        CURRENT_FEAT_INDEX=$((CURRENT_FEAT_INDEX + 1))
        draw_line $CURRENT_CURSOR_INDEX ${FEATURE_STATE[$CURRENT_FEAT_INDEX]} true
    else
        # mode
        draw_line $CURRENT_CURSOR_INDEX $([ "$CURRENT_MODE" -eq "$CURRENT_CURSOR_INDEX" ] && echo true || echo false) false
        CURRENT_CURSOR_INDEX=$((CURRENT_CURSOR_INDEX + 1))
        if (($CURRENT_CURSOR_INDEX == $MODES_NUM)); then
            # moving between mode and feat
            CURRENT_FEAT_INDEX=$(($CURRENT_CURSOR_INDEX - $MODES_NUM))
            INDEX=${FEATURE_STATE[$CURRENT_FEAT_INDEX]}
            draw_line $CURRENT_CURSOR_INDEX $INDEX true
        else
            draw_line $CURRENT_CURSOR_INDEX $([ "$CURRENT_MODE" -eq "$CURRENT_CURSOR_INDEX" ] && echo true || echo false) true
        fi
    fi
}

function toggle_option() {
    # in space key press
    local state
    if (($CURRENT_CURSOR_INDEX >= $MODES_NUM)); then
        # toggle feat
        CURRENT_FEAT_INDEX=$(($CURRENT_CURSOR_INDEX - $MODES_NUM))
        state="${FEATURE_STATE[$CURRENT_FEAT_INDEX]}"
        if $state; then
            state=false
        else
            state=true
        fi
        #echo $state
        FEATURE_STATE[$CURRENT_FEAT_INDEX]=$state
        draw_line $CURRENT_CURSOR_INDEX $state true
    else
        # set mode
        if (($CURRENT_MODE != $CURRENT_CURSOR_INDEX)); then
            draw_line $CURRENT_MODE false false
            CURRENT_MODE=$CURRENT_CURSOR_INDEX
            draw_line $CURRENT_CURSOR_INDEX true true
        fi
    fi

}

function draw_line() {
    # $1: cursor index (0-end of features)
    # $2: mark or unmark state?
    # $3: is reverse
    
    tput cup $1 5
    local start
    local char
    if [ "$3" = "true" ]; then
            start="$start${REVERSE_ON}"
            end="${REVERSE_OFF}"
    fi

    if (($1 < $MODES_NUM)); then
        # Mode
        if "$2" = "true"; then
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

function draw_screen() {
    
    tput clear
    
    for ((i=0; i<$MODES_NUM; i++)); do
        if [ $i -eq $CURRENT_MODE ]; then
            draw_line $i true true
        else
            draw_line $i false false
        fi
    done


    for ((i=$MODES_NUM; i<$TOTAL_NUM; i++)); do
        draw_line $i ${FEATURE_STATE[$(($i - $MODES_NUM))]} false 
    done
}

function setup_tui() {
    tput clear
    tput smcup
    tput civis 
    #tput cnorm
    # Save current terminal settings
    ORIGINAL_STTY=$(stty -g)

    # Disable canonical mode and input echoing for single-key input
    stty -icanon min 1 -echo

    #trap cleanup EXIT

    CLOSE_TUI=false
    MODES=(
        "mode dev boy"
        "mode give me bloattt!!"
        "mode basic man"
    )
    FEATURES=(
        "feat install ssh"
        "feat setup minikube"
        "feat upgrade"
        "feat reboot"
    )
    FEATURE_STATE=(
        false
        false
        false
        false
    )

    MODES_NUM="${#MODES[@]}"

    
    FEATURES_NUM="${#FEATURES[@]}"
    CURRENT_MODE=0
    TOTAL_NUM=$(($MODES_NUM + $FEATURES_NUM))

    CURRENT_CURSOR_INDEX=0
    PREVIOUS_CURSOR_INDEX=-1
    CURSOR_ON_FEATURE=false

    REVERSE_ON=$(tput rev)
    REVERSE_OFF=$(tput sgr0)
}

setup_tui
draw_screen

# main loop
while !($CLOSE_TUI); do
    handle_key_press
    #draw_screen
done

#after_tui
#echo -e "${REVERSE_ON}[X] ${DESCRIPTION}${REVERSE_OFF}      "

if $QUIT; then
    echo "quiting"
else
    echo "cauntiniuing install"
fi