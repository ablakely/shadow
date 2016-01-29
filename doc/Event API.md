# Shadow API: Events

Written by Aaron Blakely

### Example
    $bot = Shadow::Core;

    $bot->add_handler($eventstring, "<function name>");

## Description
Shadow is based on a callback event loop. Here's a list of all the current events supported by the API and their hooks.

# Events
`$eventstring` is composed of the event's class and name

## Classes
### event
    join_me    - $nick, $hostmask, $chan - Self channel join event
    join       - $nick, $hostmask, $chan - Channel join event
    part_me    - $nick, $hostmask, $chan, $text - Self channel part
    part       - $nick, $hostmask, $chan, $text - chanel part
    quit       - $nick, $host, $chan, $text, @channels - user quit
    nick_me    - $nick, $host, $newnick - self nickname change
    nick       - $nick, $host, $newnick, @channels - nickname change
    mode       - $nick, $host, $chan, $action, @mode - mode change
    voice_me   - $nick, $host, $chan, $action - self v mode event
    halfop_me  - $nick, $host, $chan, $action - self h mode
    op_me      - $nick, $host, $chan, $action - self o mode event
    protect_me - $nick, $host, $chan, $action - self a mode event
    owner_me   - $nick, $host, $chan, $action - self q mode event
    ban_me     - $nick, $host, $chan, $action - self b mode event
    notice     - $nick, $host, $target, $text - notice event
    invite     - $nick, $chan                 - invite event
    kick       - $nick, $chan, $kicked, $text - kick event
    connected  - $nick                        - connected event
    nicktaken  - $nick, $tmpnick              - nickname in use
    topic      - $nick, $host, $chan, $topic  - topic change event

### mode
    voice      - $nick, $host, $chan, $action, $who - v mode event
    halfop     - $nick, $host, $chan, $action, $who - h mode event
    op         - $nick, $host, $chan, $action, $who - o mode event
    protect    - $nick, $host, $chan, $action, $who - a mode
    owner      - $nick, $host, $chan, $action, $who - q mode
    ban        - $nick, $host, $chan, $action, $who - b mode
    otherp     - $nick, $host, $chan, $action, $bit, $count - lkIe modes event
    other      - $nick, $host, $chan, $action, $bit - other mode event

### messages
    chancmd <cmd>   - $nick, $host, $chan, $text - channel fantasy cmd
    chancmd default - $nick, $host, $chan, $text
    chanmecmd <cmd> - $nick, $host, $chan, $text - channel action cmd
    chanmecmd default -$nick, $host, $chan, $text
    privcmd <cmd> - $nick, $host, $chan, $text
    message channel - $nick, $host, $chan, $text - channel message
    message private - $nick, $host, $chan, $text - private message
    privcmd <cmd>   - $nick, $host, $chan, $text - privmsg cmd
    ctcp <cmd> - $nick, $target, $params
