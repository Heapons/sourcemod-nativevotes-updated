![](https://wiki.teamfortress.com/w/images/8/88/Voting_YYN.png)
# <img src="https://cdn.fastly.steamstatic.com/steamcommunity/public/images/apps/440/033bdd91842b6aca0633ee1e5f3e6b82f2e8962f.ico" width="32" height="32" style="vertical-align: text-bottom;">/<img src="https://store.steampowered.com/favicon.ico" width="32" height="32" style="vertical-align: text-bottom;"> NativeVotes — Continued!
This fork aims to expand upon [<img src="https://avatars.githubusercontent.com/u/15315481" width="16" height="16" style="vertical-align: text-bottom;"/> sapphonie](https://github.com/sapphonie)['s work](https://github.com/sapphonie/sourcemod-nativevotes-updated).

> [!WARNING]
> This plugin has only been tested in [<img src="https://cdn.fastly.steamstatic.com/steamcommunity/public/images/apps/440/033bdd91842b6aca0633ee1e5f3e6b82f2e8962f.ico" width="16" height="16" style="vertical-align: text-bottom;"> **Team Fortress 2**](https://store.steampowered.com/app/440)‼ If it doesn't work in any other game, open an [issue](https://github.com/Heapons/sourcemod-nativevotes-updated/issues/new).

# [Differences](https://github.com/sapphonie/sourcemod-nativevotes-updated/compare/master...Heapons:sourcemod-nativevotes-updated:master)
## General
- Include [NativeVotes BaseVotes and FunVotes](https://github.com/powerlord/sourcemod-nativevotes-basevotes) in this repository.
  - Show player avatar on vote panel (if the game supports it).
    - Applies to: [voteban](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_basevotes/voteban.sp), [votekick](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_basevotes/votekick.sp), [voteburn](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_funvotes/voteburn.sp), [voteslay](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_funvotes/voteslay.sp).
- Chat tweaks.
  - Team-colored player names.
  - Highlight map names.
- Update [Nominations](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_nominations.sp) and [Rock The Vote](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_rockthevote.sp) to be on par with the latest [Sourcemod](https://github.com/alliedmodders/sourcemod/tree/master/plugins) version.

### Team Fortress 2
- Fixed ✔️/❌ vote counts.
- Add [`sm_voterp`](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_voterp.sp).
  - Controls `tf_medieval_autorp` cvar.
- MVM Support.

## [Rock The Vote](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_rockthevote.sp)
- Admin commands.
  - `sm_forcertv`.
    - Force a RTV.
  - `sm_resetrtv`.
    - Reset RTV counts.
- Allow players to retract their rock-the-vote.
  - Execute `sm_rtv` again to undo.
---
|Name|Default Value|Description|
|-|-|-|
|`sm_rtv_needed`|`0.60`|Percentage of players needed to rockthevote|
|`sm_rtv_minplayers`|`0`|Number of players required before RTV will be enabled|
|`sm_rtv_initialdelay`|`30.0`|Time (in seconds) before first RTV can be held|
|`sm_rtv_interval`|`240.0`|Time (in seconds) after a failed RTV before another can be held|
|`sm_rtv_changetime`|`0`|When to change the map after a successful RTV: 0 - Instant, 1 - RoundEnd, 2 - MapEnd|
|`sm_rtv_postvoteaction`|`0`|What to do with RTV's after a mapvote has completed.<br>0 - Allow (success = instant change), 1 - Deny|

## [Nominations](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_nominations.sp)
### Team Fortress 2
- Attempting to nominate with no argument will open **Vote Setup** (`callvote`).
  - Can be toggled with `sm_nominate_use_callvote`.
- Support partial map name matches.
---
|Name|Default Value|Description|
|-|-|-|
|`sm_nominate_excludeold`|`1`|Specifies if the current map should be excluded from the Nominations list|
|`sm_nominate_excludecurrent`|`1`|Specifies if the MapChooser excluded maps should also be excluded from Nominations|
|`sm_nominate_maxfound`|`0`|Maximum number of nomination matches to add to the menu.<br>0 = infinite|
|`sm_nominate_use_callvote`|`1`|Specifies whether to execute callvote when nominating without specifying the map.|

## [MapChooser](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_mapchooser.sp)
- Automatically generate mapcycle files.
  - Can be refreshed with `sm_reloadmaplist`.
- **[TF2]** Clean up workshop maps to reduce disk size.
---
|Name|Default Value|Description|
|-|-|-|
|`sm_mapvote_endvote`|`1`|Specifies if MapChooser should run an end of map vote|
|`sm_mapvote_start`|`3.0`|Specifies when to start the vote based on time remaining (in minutes)|
|`sm_mapvote_startround`|`2.0`|Specifies when to start the vote based on rounds remaining. Use '0' on TF2 to start vote during bonus round time|
|`sm_mapvote_startfrags`|`5.0`|Specifies when to start the vote based on frags remaining|
|`sm_extendmap_timestep`|`15`|Specifies how many more minutes each extension makes|
|`sm_extendmap_roundstep`|`5`|Specifies how many more rounds each extension makes|
|`sm_extendmap_fragstep`|`10`|Specifies how many more frags are allowed when map is extended|
|`sm_mapvote_exclude`|`5`|Specifies how many past maps to exclude from the vote|
|`sm_mapvote_include`|`5`|Specifies how many maps to include in the vote|
|`sm_mapvote_novote`|`1`|Specifies whether MapChooser should pick a map if no votes are received|
|`sm_mapvote_extend`|`0`|Number of extensions allowed each map|
|`sm_mapvote_dontchange`|`1`|Specifies if a 'Don't Change' option should be added to early votes|
|`sm_mapvote_voteduration`|`20`|Specifies how long the mapvote should be available for (in seconds)|
|`sm_mapvote_runoff`|`0`|Hold runoff votes if winning choice is less than a certain margin|
|`sm_mapvote_runoffpercent`|`50`|If winning choice has less than this percent of votes, hold a runoff|
|`sm_mapcycle_auto`|`0`|Specifies whether to automatically populate the maps list.|
|`sm_mapcycle_exclude`|`.*itemtest.*\|background01\|^tr.*$`|Specifies which maps shouldn't be automatically added (regex pattern).|
|`sm_workshop_map_collection`|""|Specifies the workshop collection to fetch the maps from.<br>[<img src="https://cdn.fastly.steamstatic.com/steamcommunity/public/images/apps/440/033bdd91842b6aca0633ee1e5f3e6b82f2e8962f.ico" width="16" height="16" style="vertical-align: text-bottom;"> **Team Fortress 2**](https://store.steampowered.com/app/440) (or its mods) only|
|`sm_workshop_map_cleanup`|`0`|Specifies whether to automatically cleanup workshop maps on map change<br>[<img src="https://cdn.fastly.steamstatic.com/steamcommunity/public/images/apps/440/033bdd91842b6aca0633ee1e5f3e6b82f2e8962f.ico" width="16" height="16" style="vertical-align: text-bottom;"> **Team Fortress 2**](https://store.steampowered.com/app/440) (or its mods) only|

> [!WARNING]
> There's currently a bug where leaving `sm_mapcycle_auto` enabled at all times will make all plugins unable to find [`mapcyclefile`](https://developer.valvesoftware.com/wiki/Mapcycle.txt). But if you're still going to leave it on for whatever reason, [`sm_reload_nominations`](https://github.com/Heapons/sourcemod-nativevotes-updated/blob/master/addons/sourcemod/scripting/nativevotes_nominations.sp#L247-L251) works as a temporary fix.