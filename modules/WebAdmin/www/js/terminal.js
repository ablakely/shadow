var dbug;

var colors = {
    0  : "#FFFFFF",
    1  : "#000000",
    2  : "#00007F",
    3  : "#009300",
    4  : "#FF0000",
    5  : "#7F0000",
    6  : "#9C009C",
    7  : "#FC7F00",
    8  : "#FFFF00",
    9  : "#00FC00",
    10 : "#009393",
    11 : "#00FFFF",
    12 : "#0000FC",
    13 : "#FF00FF",
    14 : "#7F7F7F",
    15 : "#D2D2D2"
};

$(document).ready(function() {
    $("#term").terminal(function(cmd) {
        var ins = this;

        if (cmd === "") {
            setTimeout(function() {
                window.scrollTo(0, document.body.scrollHeight);
            }, 3);

            return;
        }

        if (cmd[0] === "/") {
            var tmp = cmd.split("");

            tmp.shift();
            cmd = `irc "${tmp.join("")}"`;
        }

        $.ajax({
            type: "POST",
            url:  "/terminal/api",
            data: { cmd: cmd },
            async: false,
            success: function(data) {
                var tmp = data.split("\n");
    
                for (var i = 0; i < tmp.length; i++) {
                    if (tmp[i]) {
                        if (/Error\: (.*)/.test(tmp[i])) {
                            ins.echo(tmp[i], {
                                finalize: function(div) {
                                    $(div[0].children[0].children[0]).css("color", "red");
                                }
                            });
                        } else {
                            if (/\[\[(.*?)\](.*?)\x08(.*?)\x07(.*?)\]/.test(tmp[i])) {
                                while (matches = /\[\[(.*?)\](.*?)\x08(.*?)\x07(.*?)\]/.exec(tmp[i])) {
                                    /* parse escaped brackets */
                                    
                                    for (var x = 1; x < matches.length; x++) {
                                        matches[x] = matches[x].replaceAll("\x08", "[");
                                        matches[x] = matches[x].replaceAll("\x07", "]");
                                    }

                                    var msg = `[${matches[3]}]`;

                                    tmp[i] = tmp[i].replace(matches[0], `[[${matches[1]}]${$.terminal.escape_brackets(matches[2]+msg+matches[4])}]`);
                                }

                            } else if (/(\x03|\x02\x03)([0-9]{1,2})[,]?([0-9]{1,2})?(\x02)?(.*?)(\x02)?(\x03|\x02\x03)/.test(tmp[i])) {
                                while (matches = /(\x03|\x02\x03)([0-9]{1,2})[,]?([0-9]{1,2})?(\x02)?(.*?)(\x02)?(\x03|\x02\x03)/.exec(tmp[i])) {
                                    /* parse mIRC formatting codes */
                                    var fmt = ";";
                                    var bre = /x02/gs;

                                    var fg   = isNaN(parseInt(matches[2])) ? ";" : `${colors[parseInt(matches[2])]};`;
                                    var bg   = isNaN(parseInt(matches[3])) ? ";" : `${colors[parseInt(matches[3])]};`;
                                    var text = matches[5];

                                    if (bre.test(matches[1]) || bre.test(matches[4]) || bre.test(matches[6])) {
                                        fmt = "b;";
                                    }

                                    tmp[i] = tmp[i].replace(matches[0], `[[${fmt}${fg}${bg}]${$.terminal.escape_brackets(text)}]`);
                                }

                            } else if (/\x02(.*?)\x02/.test(tmp[i])) {
                                while (matches = /\x02(.*?)\x02/.exec(tmp[i])) {
                                    tmp[i] = tmp[i].replace(matches[0], `[[b;;]${matches[1]}]`);
                                }
                            }

                            ins.echo(tmp[i])
                        }
                    }
                }

                setTimeout(function() {
                    window.scrollTo(0, document.body.scrollHeight);
                }, 15);
            }
        });
    }, {
        greetings: greetings.innerHTML,
        scrollOnEcho: true
    });
});
