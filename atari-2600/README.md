# Google Chrome Dinosaur game demake for the Atari 2600

This project implements the classic Google Chrome Dinosaur browser game on the 
Atari 2600, trying to preserve as much as possible of the original.

## Implementation details

I tried to keep a journal about the project and its progress but proved too 
difficult to keep up (I became a dad recently before starting the project) and
I only worked on this sporadically, sometimes during commute times to work.

The folder structure is as follows:

<table>
<tr>
<th>Folder name</th><th>Description</th>
</tr>

<tr>
<td><code>bin</code></td>
<td>Binaries of the project. Where the ROM file should be located after 
successfully building the project using <code>make</code></td>
</tr>

<tr>
<td><code>blog</code></td>
<td>My poor attempt to keep a journal about the project. I kept it for the comedic factor, Take a look and have a laugh at my poor soul</td>
</tr>

<tr>
<td><code>documentation</code></td>
<td>Nothing useful here really for the general public, but in there is some
quick reference material that is handy to keep around in an offline mode (useful
specially when commuting), stuff like opcode cycle count, playfield reference, etc. 
There is a <code>notes.txt</code> used as sort of scratch file when trying to 
understand why the <code>sbc</code> required a set carry</td>
</tr>

<tr>
<td><code>graphics</code></td>
<td>This folder contain scratch GIMP files and other prototypes images </td>
</tr>

<tr>
<td><code>scr</code></td>
<td>Root folder for the source code</td>
</tr>

<tr>
<td><code>scr/kernels</code></td>
<td>The kernel routines are isolated in their own files and stored in this 
folder for easy access.</td>
</tr>

<tr>
<td><code>scr</code></td>
<td>Main </td>
</tr>

</table>

TODO Finish this README
