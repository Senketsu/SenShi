# SenShi - AFK Streamer & IRC Bot
Automatic IceCast Streamer &amp; IRC Bot, easily deployable.
Currently supports only mp3 audio files. Website requests not available atm (TODO).

## About:
This started as (planned) winter pastime project.
If you ever heard or [r/a/dio](https://r-a-d.io/), this is essentially
 easily deployable [Hanyuu-sama](https://github.com/R-a-dio/Hanyuu-sama), written from scratch in Nim.
Might not be as fancy, but does the job.

**Note:** This is not a rewrite or copy of Hanyuu-sama in other language,
 but an **emulation** i.e: **'imitation of behavior'**.
**Why (call it) emulation ?**
* Developed purely from the knowledge of Hanyuu's behavior from the IRC chat.
* Haven't seen Hanyuu's source code in more than a year.
* More fun & challenging than rewritting existing code. No know-how.

### TODO:
------------------------
* Web requests support (ETA: When testing website is finished
 *(might take a while, since i just picked up webdev)* )
* More audio formats (flac, ogg ..)
* Will update when i think of more.

### How to deploy SenShi:
------------------------
Follow this guide or use [ soon to be filled with vagrant link ]
* Install **IceCast** & **MySQL** server & client libraries & **taglib**
* Arch Linux example:
`pacman -S mariadb mariadb-clients libmariadbclient icecast libshout taglib`
* Set the configs to your needs.. or not
* Install Nim devel tools **Nim** & **nimble**
* nimble install ndbex
* Follow the below Compiling guide

### Compiling SenShi:
* Use *git* to clone OR download and extract the source files & cd into it
* Compile SenShi with `nim c --threads:on senshi.nim` (optionaly -d:release flag)
* Compile this helper tool to create SenShi database for you `nim c -d:release ./other/createDatabase.nim`
* (Optional) If you ever in future want to add tracks to your DB easily `nim c -d:release ./other/fillTracks.nim`
* Run `./other/createDatabase` and let it do its job.
* Run SenShi and go trough its setup.
* Done

### Contact
* Feedback , thoughts , bug reports ?
* Feel free to contact me on [twitter](https://twitter.com/Senketsu_Dev) ,or visit [stormbit IRC network](https://kiwiirc.com/client/irc.stormbit.net/?nick=Guest|?#Senketsu)
* Or create [issue](https://github.com/Senketsu/SenShi/issues) on SenShi Github page.

