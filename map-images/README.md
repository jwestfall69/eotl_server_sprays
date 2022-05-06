# Creating Mini-Maps Sprays

This directory contains the images used to create the mini-maps sprays.

These are the steps I used to generate them

### Creating screenshots in TF2
<hr>

  * Set video resolution to 1920x1080 (or some other 16:9 resolution)
  * Start local game with whatever map you want
  * Pick a team/class and spawn
  * Run the following commands (I suggest putting them in a pics.cfg file and running that)
```
sv_cheats 1
noclip
cl_drawhud 0
fog_enable 0
r_lod 0
r_drawviewmodel 0
mat_picmip -1
cl_showfps 0
```

This should remove all hud related stuff from the screen and just leave the map as the only thing being rendered.

  * Find a location on the map you want to take a picture of.  I would personally suggest a location where players end up spending a lot of time at (ie a choke point or last point).

  * Take the screenshot

### Creating The Mini-Map Images
<hr>

  * I did this in gimp on MacOS
  * Open screenshot
  * Scale image to 160x90
  * Put the map name minus any map version in the name in the lower left (ie: pl_cashworks_final -> pl_cashworks)

    * Font: "Ariel, Black", Size: 10px, antialias disabled
    * The left side of the "p" in pl_ should be 1 pixel away from the left of the image.  Likewise the "_" should 1 pixel away from the bottom of the image.
    * Place a white background behind the text that is 1 pixel wider then the font on all sides. This can be done by making a new layer and placing it between the background map layer and the text layer.  Then adding the white on the new layer.
  * Export, save as png


### Merging The Mini-Map Images Into A Map Set PNG
<hr>

  * Note: Textures width and height must be a power of 2, this is why the map set pngs are so much larger then they need to be.
  * Open an existing map set png file
  * Open 16 mini map pngs
  * For each mini map png, copy/paste it over an existing mini map in the set png
  * Export, save as png picking a different name

### Convert the PNG Into A Spray/Decal
<hr>

  * Fire up VTFEdit
  * Import the map set png
  * Save as, replacing .png with .vtf
  * Use one of the exist .vmt files to make one for your new map set spray