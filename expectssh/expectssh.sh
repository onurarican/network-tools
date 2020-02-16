#!/usr/bin/expect -f
# Onur

# Usage:
# expectssh <host> "<prompt>" "command 1" ["command 2" ... "command n"]

# Exit Codes:
# 0 : Success
# 1 : Connection problem
# 2 : Timed out
# 3 : Command problem
# 4 : Command timed out
# 10: Print help

if {[llength $argv] < 3} {
  puts "Usage:"
  puts "expectssh <host> \"<prompt>\" \"command 1\" \"command 2\" ... \"command n\""
  puts ""
  puts "Exit Codes:"
  puts "0 : Success"
  puts "1 : Connection problem"
  puts "2 : Timed out"
  puts "3 : Command problem"
  puts "4 : Command timed out"
  puts "10: Print this help"

  exit 10
}

set fp [open "~/.data/input" r]
set data [read $fp]

set host [lindex $argv 0];

set prompt [lindex $argv 1];

set timeout 10

spawn ssh $host
while {1} {
  expect \
  {
    "*(yes/no)? "      {send "yes\r"}
    "*assword:"        {send "$data\r"}
    "*$prompt"         {break}
    timeout            {exit 2}
    eof                {puts "\rBreaking - EOF\r"; exit 1}
  }
}

for {set i 2} {$i <= [llength $argv]} {incr i 1} {
  if {$i < [llength $argv]} {puts "";puts ""; puts "\r## command [expr {$i - 1}] start ##"}
  send "\r"
  expect \
  {
    "*$prompt"         {send "[lindex $argv $i]\r"}
    timeout            {exit 4}
    eof                {puts "\rBreaking - EOF\r"; exit 3}
  }

  while {1} {
    expect \
    {
      "*$prompt"       {break}
      "Press <SPACE> to continue or <Q> to quit:" {send " "}
      "(more"          {send " "}
      "More-"          {send " "}
      "ESC->exit"      {send "\x1b\r"}
      timeout          {exit 4}
      eof              {puts "\rBreaking - EOF\r"; exit 3}
    }
  }
  if {$i < [llength $argv]} {puts "\r## command [expr {$i - 1}] finish ##"}
}

send "exit\r"
puts ""

exit 0