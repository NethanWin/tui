A selector TUI for Archnet (install script with options)

Preview:
```
      Wecome to the Archnet install menu
      Select 1 Install Option:    

      (*) dev boy
      ( ) mode give me bloattt!!
      ( ) basic man

      Advanced Selection:

      [X] install ssh
      [X] setup minikube
      [ ] upgrade
      [ ] reboot
      

      Instructions: Use [Up]/[Down] to move, [Space] to select/toggle
                    [Enter] to apply, [Q] to quit.
```


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
    draw_static_line "Instructions: Use [Up]/[Down] to move, [Space] to select/toggle" "footer"
    draw_static_line "[Enter] to apply, [Q] to quit." "footer"