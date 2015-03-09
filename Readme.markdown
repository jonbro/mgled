### to build:

coffee -c -b -m -o libs/ src/mgl.coffee

### debugging the mgl.coffee

if the error you are getting is in mgl.coffee, the editor will report that it can't find the line with the error. If you test an existing game in the player page (i.e. mgl_script/play.html?p=6e85db025e14d68c60f4) it will find the error. I haven't yet figured out how to have both source maps loaded at the same time.

### todo

need to swap to the longer function names for the following classes

- Actor
- Text
- TextActor
- Particle
- ParticleActor
- Mouse
- Key
- Sound
- Vector