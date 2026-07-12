1. Chonsole refactor

Chonsole currently has a couple of files with a lot of lines. They need to be split up. Aim at around 300 LOC but higher counts ONLY acceptable if there's a good reason (doubtful in 99% cases).

Remove useless unit tests (move tests to a separate place and prefer integration tests), or move them to a different folder so they don't make implementation files larger.

My guess is that you're implementing a basic text input there and that implementation should probably be moved elsewhere as it'll likely be used in different places across the SBC too.
Obviously you will want to make it extensible so that you can use it in chonsole, stuff like tab, special semantics of up/down and so on are chonsole specific.

Other thing you may want to split from view is the suggestion part, so something like view_text_input.rs and view_suggestion.rs

2. Chonsole missing commands in list

when I type / I only see a very small subset of commands. Is it not possible to list this? This is far too insufficient and I don't want you to enumerate it, as I don't want to maintain this list.

3. Chonsole missing custom commands like /texture, /gamerules

Original chonsole had other special commands like /texture $ssmf_specular , which would allow me to preview textures. /gamerules would allow me to view and set gamerules, and so on.

Please check everything original had and implement it all