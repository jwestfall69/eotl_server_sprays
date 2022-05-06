# eotl_server_sprays

### Overview
<hr>
This is a TF2 sourcemod plugin.

This plugin as the name suggests allows for server side sprays.  These sprays can be automatically applied to maps based on the eotl_server_sprays.cfg config file.  The idea for this plugin comes from [Franug-Sprays](https://github.com/Franc1sco/Franug-Sprays).

The main motivation for this plugin to help people make the link between map names (at vote time) and actual maps by having a server spray in each spawn that contains a kinda info graphic of a bunch of maps/map names.  But sprays can be place anywhere in the map.

**NOTE**: While this plugin refers to stuff as sprays they are technically decals in source engine lingo.  Because they are actually decals, the format of the .vmt files is slightly different then normal client side spray .vmt files. Additionally the sprays are temporary entities, meaning the server doesn't track the entities and instead just sends the command to the client so show spray at location xyz.  As such the sprays dont count towards the servers max entities.

By default players will have server side sprays enabled.

### Say Commands
<hr>

**!ss disable**


This command will disable server side sprays.  The change will not take effect until map change.  This is a side effect of the sprays being temporary entities.


**!ss**

This command will re-enable server side sprays.  The user should see the sprays instantly.


When eotl_ss_command_limited is set to 0 the following additional forms of !ss are enabled for all players.  These are really to figure out spray placement so they can be added to the config file.

**!ss list**

This will list the available sprays as defined in the config file

**!ss [sprayname]**

This will apply the [sprayname] spray to the surface the player is currently looking at.

Once the spray is applied the server will provide the client with the following style text message:

"Sprayed <sprayname> at location -255.968750 -1059.740600 464.29284"

The 3 float values are what you would use when adding a spray to the map in the config file.  Sprays should be applied to flat surfaces or you will get some weird results.  Sprays can also sometimes bleed into the surface behind the surface you are looking at, so that is something to watch out for.


### Config File (addons/sourcemod/configs/eotl_server_sprays.cfg)
<hr>

This config file defines the different sprays that can exist as well as map configs for where those spray should be placed. Please refer to the config file for more detail on this.


### Convars
<hr>

**eotl_ss_command_limited [0/1]**
  This limits the !ss command to only allow players to enable/disable
  server side sprays.

  Default: 1 (limited mode)


### Sprays
<hr>

As a refresher
  * .vtf are data files that contain the texture
  * .vmt are text files that reference a .vtf and apply attributes to it

Utils like VTFEdit can be used to convert a png/jpg into a vtf file.

Its most common that there is a 1 to 1 mapping between a vtf and vmt files, but its not required.  Refer to the eotl logos included for examples of multiple .vmt referencing the same .vtf file.

As mentioned above we are actually using decals so the content of the .vmt files are different then normal client side sprays. Given the following vtf

```materials/custom/eotl-sprays/myspray.vtf```

The associated vmt should be called

```materials/custom/eotl-sprays/myspray.vmt```

With the contents of the vmt containing

```
LightmappedGeneric
{
	"$basetexture"	"custom/eotl-sprays/myspray"
	"$translucent" "1"
	"$decal" "1"
	"$decalscale" "0.25"
}
```

You should note that the $basetexture value is pointing at the .vtf file,
but doesn't include "materials/" or the ".vtf" extension.  The $decalscale
value as you should expect, allows scaling the size of the decal.

**IMPORTANT**: If a client has already downloaded a vmt/vtf they will not
download it again, even if you change it server side.  So its best to
figure out your spray/decalscale on a private server first before pushing
to your public one.