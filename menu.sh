#!/bin/bash
set -e
exec 2>error_log.txt

function setup_tui() {
    tput clear
    tput smcup
    tput civis 
    # Save terminal settings
    ORIGINAL_STTY=$(stty -g)
    
    # Disable canonical mode and input echoing for single-key input
    stty -icanon min 1 -echo

    trap after_tui EXIT

    STOP_MENU=false
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
    FEATURE_STATE=("" "" "" "")

    MODE_LEN="${#MODES[@]}"
    
    FEATURES_NUM="${#FEATURES[@]}"
    CURRENT_MODE=0
    TOTAL_ITEMS=$(($MODE_LEN + $FEATURES_NUM))

    CURRENT_CURSOR_INDEX=0
    PREVIOUS_CURSOR_INDEX=-1
    CURSOR_ON_FEATURE=false

    REVERSE_ON=$(tput rev)
    REVERSE_OFF=$(tput sgr0)

    # (before_headers after_headers after_middle after_options)
    EMPTY_LINES_SPACING=(5 5 5 5 5)
    COL=5
}

draw_static_screen() {
    STATIC_INDEX=0  # incriments in draw_static_line
    # draw static text
    draw_static_line ${EMPTY_LINES_SPACING[0]}
    draw_static_line "Wecome to the Archnet install menu" "header"
    draw_static_line "Select 1 Install Option:" "header"
    draw_static_line ${EMPTY_LINES_SPACING[1]}
    MODE_START_INDEX=$STATIC_INDEX

    draw_static_line $MODE_LEN
    draw_static_line ${EMPTY_LINES_SPACING[2]}
    FEAT_START_INDEX=$STATIC_INDEX

    draw_static_line "Advanced Selection:" "middle"
    draw_static_line ${EMPTY_LINES_SPACING[3]}

    draw_static_line $FEATURES_NUM
    draw_static_line ${EMPTY_LINES_SPACING[4]}
    echo $STATIC_INDEX >> error_log.txt
    draw_static_line "Instructions: Use [Up]/[Down] to move, [Space] to select/toggle" "footer"
    draw_static_line "[Enter] to apply, [Q] to quit." "footer"
}

function draw_screen() {
    tput clear
    draw_static_screen

    # draw Modes
    for ((i=0; i<$MODE_LEN; i++)); do
        if [ $i -eq $CURRENT_MODE ]; then
            draw_line $i true true
        else
            draw_line $i false false
        fi
    done

    # draw feats
    set_feats_from_mode $CURRENT_MODE
}

draw_static_line() {
    # $1: text
    # $2: kind (header,middle,footer)

    # $1: number of spaces
    tput cup $STATIC_INDEX $COL
    if [ $# -eq 1 ]; then
        for ((i=0; i<$1; i++)); do
            echo "i: $run $STATIC_INDEX" >> error_log.txt
            echo -e ""
            STATIC_INDEX=$(( $STATIC_INDEX + 1 ))
        done
    else 
        echo -e "$1"
        STATIC_INDEX=$(( $STATIC_INDEX + 1 ))
    fi
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
            STOP_MENU=true  # finishes loop
            QUIT=false
            ;; 
        
        # Q: Quit
        'q' | 'Q')
            STOP_MENU=true
            QUIT=true       # quiting the install
            ;;
    esac
}

function move_up() {
    if (($CURRENT_CURSOR_INDEX <= 0)); then
        return
    fi
    if (($CURRENT_CURSOR_INDEX >= $MODE_LEN)); then
        # feat
        CURRENT_FEAT_INDEX=$(($CURRENT_CURSOR_INDEX - $MODE_LEN))
        local condition="${FEATURE_STATE[$CURRENT_FEAT_INDEX]}"
        draw_line $CURRENT_CURSOR_INDEX $condition false
        CURRENT_CURSOR_INDEX=$((CURRENT_CURSOR_INDEX - 1))
        CURRENT_FEAT_INDEX=$((CURRENT_FEAT_INDEX - 1))

        if (($CURRENT_CURSOR_INDEX == (($MODE_LEN - 1)))); then
            # moving between feat to mode
            CURRENT_FEAT_INDEX=$(($CURRENT_CURSOR_INDEX - $MODE_LEN))
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
    if (($CURRENT_CURSOR_INDEX >= $(($TOTAL_ITEMS - 1)))); then
        return
    fi
    if (($CURRENT_CURSOR_INDEX >= $MODE_LEN)); then
        # feat
        CURRENT_FEAT_INDEX=$(($CURRENT_CURSOR_INDEX - $MODE_LEN))
        local condition="${FEATURE_STATE[$CURRENT_FEAT_INDEX]}"
        draw_line $CURRENT_CURSOR_INDEX $condition false
        CURRENT_CURSOR_INDEX=$((CURRENT_CURSOR_INDEX + 1))
        CURRENT_FEAT_INDEX=$((CURRENT_FEAT_INDEX + 1))
        draw_line $CURRENT_CURSOR_INDEX ${FEATURE_STATE[$CURRENT_FEAT_INDEX]} true
    else
        # mode
        draw_line $CURRENT_CURSOR_INDEX $([ "$CURRENT_MODE" -eq "$CURRENT_CURSOR_INDEX" ] && echo true || echo false) false
        CURRENT_CURSOR_INDEX=$((CURRENT_CURSOR_INDEX + 1))
        if (($CURRENT_CURSOR_INDEX == $MODE_LEN)); then
            # moving between mode and feat
            CURRENT_FEAT_INDEX=$(($CURRENT_CURSOR_INDEX - $MODE_LEN))
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
    if (($CURRENT_CURSOR_INDEX >= $MODE_LEN)); then
        # toggle feat
        CURRENT_FEAT_INDEX=$(($CURRENT_CURSOR_INDEX - $MODE_LEN))
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
            set_feats_from_mode $CURRENT_CURSOR_INDEX
        fi
    fi

}

function apply_feats() {
    # $1 feat array
    # change the different feat states
    local -n new_feats=$1
    for ((i = 0; i < $FEATURES_NUM; i++)); do
        if [[ ${FEATURE_STATE[i]} != ${new_feats[i]} ]]; then
            local new_index=$(( $MODE_LEN + $i ))
            FEATURE_STATE[i]="${new_feats[i]}"              # updates the array
            draw_line "$new_index" "${new_feats[i]}" false   # draw feat with opposit mark
            
        fi
    done
}

function set_feats_from_mode() {
    local feats
    case "$1" in
        0) feats=(true false true false);;
        1) feats=(true true true true);;
        2) feats=(true false false false);;
    esac
    apply_feats feats
}

function draw_line() {
    # $1: cursor index (0-end of features)
    # $2: mark or unmark state?
    # $3: is reverse

    #tput cup $(( $1 + 5 )) $COL
    local start
    local char
    local end=""
    if [ "$3" = "true" ]; then
            start="$start${REVERSE_ON}"
            end="${REVERSE_OFF}"
    fi

    if (($1 < $MODE_LEN)); then
        # Mode
        if "$2" = "true"; then
            char="*"
        else
            char=" "
        fi
        tput cup $(( $1 + $MODE_START_INDEX )) $COL
        echo -e "${start}($char) ${MODES[$1]}${end}"
    else
        # Feature
        if [[ "$2" = "true" ]]; then
            char="V"
        else
            char=" "
        fi
        tput cup $(( $1 + $FEAT_START_INDEX )) $COL
        echo -e "${start}[$char] ${FEATURES[$1-$MODE_LEN]}${end}"
    fi
}

function after_tui() {
    stty "$ORIGINAL_STTY"
    tput cnorm
    tput rmcup
}


function main() {
    set -e
    setup_tui
    draw_screen
    # main loop
    while [[ "$STOP_MENU" != true ]]; do
        handle_key_press
    done
    after_tui

    if $QUIT; then
        echo "quiting"
    else
    
        echo "starting install..."
        echo "${FEATURE_STATE[@]}"
    fi
}

main
echo damn