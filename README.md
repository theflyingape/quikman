# quikman
Commodore VIC20: my original 1984 machine language game program disassembled 
from casette tape

QUIKMAN: 1984 revisited
by Robert Hurst on October 27, 2008	

A couple of years ago, I was rejoined with my old Commodore VIC20 software 
library my brother had kept.  Some of which were programs I wrote and saved 
using ordinary audio cassette tape.  I decided to try and resurrect the data, 
because I still have my old VIC20 and datasette drive.  But if the data 
successfully loaded into the computer’s memory, how could I then transfer it 
over to a modern PC?  This problem cannot be new to me, so after a few google 
searches, I learned of a PC serial cable and some DOS software that would allow 
me to hook up and use a Commodore floppy drive… but not tape.

In steps ebay.  I was able to purchase a new-in-the-box VIC 1540 diskette drive 
for $15 shipped.  I then got pillaged another $10 for a box of 5-1/4″ floppy 
disks.  Fortunately back then, I practiced the good discipline of recording on 
both sides of each tape, as well as to keep a master copy of all things 
relevant on an additional tape.  So with a freshly cleaned datasette head and a 
LOT of load attempts, I was able to retrieve all of my saved programs from the 
22-year aged tapes.

I forgot about the “fun” it was to format a 170kb floppy disk.  Compared to 
cassette tape, floppies were amazingly faster.  Today, you can download a copy 
of it faster than you can type “RUN” on the VIC’s keyboard.  Seriously though, 
using the tapes and floppies was like experiencing it new all over again.  And 
that was kind of fun, though I am glad not to be fussing over such clumsy media 
with severely limited storage capacity.

I have been able to enjoy the result of this tape librarian nightmare through 
the use of machine emulation software, specifically from the VICE Team.  But a 
funny thing struck me this past week — one of my programs is a game I wrote in 
1984 called QUIKMAN.  I named it QUIK instead of you-know-who, because earlier 
that year I wrote my first fully machine language program dubbed QUIKVIC — 
quick as in fast, which it really was on a 1mHz 8-bit 6502 CPU.  As it went for 
me back then, I had this one final week off during the last of my college days, 
and I decided to spend it writing this game.  I believed then that there would 
never be another opportunity for me to create this game, because I was grooming 
to be a professional data processing programmer using mainframes — my dream of 
being an arcade game programmer would die, but I needed to try and do this one 
last time.

I abandoned both my girlfriend and bathing that week, and spent 20-hour days in 
front of the parlor’s Zenith color TV with my little VIC20 and machine language 
monitor cartridge.  The result of the game came out just fine for something 
that ultimately loads & runs on a machine with only 3.5kb of memory and 
8-colors.  As a matter of opinion, my recreation of this arcade megahit is far, 
FAR superior than what the licensed owners produced for the home computer 
market of that day.  Still, I have always felt I could have done better…  If 
only I had the time, and perhaps even the tools.  And now after 24-years, that 
feeling of an incomplete job has resurfaced.

What triggered that gut reaction was my accidental discovery of a software 
project on cc65.org.  It stirred up fond memories of my first C compiler, as it 
was also for the 6502 CPU powering the mighty Commodore 128.  But this was not 
that product of that day.  However, it sports a nifty 6502 assembler with 
preset configurations to compile for Commodore 8-bit computers, including the 
VIC20!  I used to own Merlin 128, too, so I had some pretty high expectations 
from this tool.

After some light reading of its documentation, I became convinced that I could 
resurrect my QUIKMAN code into an original assembler source format that could 
be recompiled back into its original binary format.  Turning back to VICE, I 
loaded QUIKMAN, virtually attached the VICMON cartridge, and had it virtually 
print (to an ASCII text file) a disassembled listing of its machine code and 
data.  Here is a copy of that listing.

Over the past 5 days, I have been massaging that listing into newly-formatted 
assembler source, worthy of today’s coding standards.  The goal was to produce 
an assembler source version that would compile into a binary that was EXACTLY 
the same as the originally hand-coded machine language version.  After my first 
successful pass at compiling, I simply could not wait to look for deltas — I 
had to boot it up and see if the program ran.  Naturally, I was disappointed 
when the screen turned blue and did nothing.  I found the first “bug” and fixed 
it, and to my surprise and delight, a version of QUIKMAN was up and running.  
Way too cool!!

I then had the chore to compare the new binary against the old one.  It is 
really important to complete the first objective in making an assembler source 
that would compile exactly as the original.  To accomplish this without too 
much effort, I turned to the use of two command-line tools: hexdump and meld.  
By issuing:

hexdump -C quikman.p00 > quikman.old
hexdump -C quikman.prg > quikman.new

I could then compare the two outputs with this graphical diff view:

meld quikman.old quikman.new

It highlighted just a few differences, which had no real adverse affects on the 
program functionality, but I wanted it to be precisely the same.  After a few 
more edits, validated by a clean meld view, the assembler source is now 
complete.

Now I wonder how many more days I’ll go without bathing until I figure I am 
done with its next revision … ?


