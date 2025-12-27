![](https://wiki.teamfortress.com/w/images/8/88/Voting_YYN.png)
# <img src="https://cdn.fastly.steamstatic.com/steamcommunity/public/images/apps/440/033bdd91842b6aca0633ee1e5f3e6b82f2e8962f.ico" width="32" height="32" style="vertical-align: text-bottom;">/<img src="https://store.steampowered.com/favicon.ico" width="32" height="32" style="vertical-align: text-bottom;"> NativeVotes — Continued!
This fork aims to expand upon [<img src="https://avatars.githubusercontent.com/u/15315481" width="16" height="16" style="vertical-align: text-bottom;"/> sapphonie](https://github.com/sapphonie)['s work](https://github.com/sapphonie/sourcemod-nativevotes-updated).

> [!WARNING]
> This plugin has only been tested in [<img src="https://cdn.fastly.steamstatic.com/steamcommunity/public/images/apps/440/033bdd91842b6aca0633ee1e5f3e6b82f2e8962f.ico" width="16" height="16" style="vertical-align: text-bottom;"> **Team Fortress 2**](https://store.steampowered.com/app/440)‼ If it doesn't work in any other game, open an [issue](https://github.com/Heapons/sourcemod-nativevotes-updated/issues/new).

# To-Do (Wishlist...?)
## General
- [x] Include [NativeVotes BaseVotes and FunVotes](https://github.com/powerlord/sourcemod-nativevotes-basevotes) in this repository.
- Colored chat.
  - [x] Team-colored player names.
  - [x] Highlight map names.
    - [ ] Parse workshop map titles.
- [x] Update [Nominations](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_nominations.sp) and [Rock The Vote](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_rockthevote.sp) to match with the latest [Sourcemod](https://github.com/alliedmodders/sourcemod/tree/master/plugins) version.
- [x] Add [`sm_voterp`](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_voterp.sp).
  - Controls `tf_medieval_autorp` cvar.
## [Rock The Vote](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_rockthevote.sp)
- [x] Add `sm_forcertv` for admins.
- [x] Allow players to retract their rock-the-vote.
  - Execute `sm_rtv` again to undo.
## [Nominations](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_nominations.sp)
- [ ] Download and nominate workshop maps.
  - Inspired by [[TF2] Workshop Vote](https://forums.alliedmods.net/showthread.php?p=2717878).
