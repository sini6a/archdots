#!/usr/bin/env bash

rofi -modi "greenclip:greenclip print" -show greenclip -run-command '{cmd}' -theme-str 'configuration { show-icons: false; }'
