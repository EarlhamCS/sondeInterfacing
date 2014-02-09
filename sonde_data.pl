#!/usr/bin/perl -w

##############################################################
# Keck grant project, 2007
# Water monitoring station YSI sonde data polling script
# Written by Jeffrey Klyce, Modified by Maduna
#
# Sonde must be setup in the following way:
# system setup > comm setup > baudrate = 9600
# run > discrete sample > sample interval = 1
# advanced > advanced setup > VT100 emulation = on
# advanced > advanced setup > auto sleep RS232 = on
##############################################################

use strict;
use warnings;
use threads;
use Getopt::Long;
use Device::SerialPort;

sub getreading;
# Subroutine to setup and interact with sonde.
# Returns output of one run command to sonde.

my $DEBUG = 0;
my @INPL;
my @UNITS;

# Output labels for the different parameters by position in the sonde output.
$INPL[0]="all";       $UNITS[0]="";           # all parameters
$INPL[1]="date";      $UNITS[1]="mm/dd/yy";   # sonde date
$INPL[2]="time";      $UNITS[2]="hh:mm:ss";   # sonde time
$INPL[3]="temp";      $UNITS[3]="C";          # temperature
$INPL[4]="spcond";    $UNITS[4]="uS/cm";      # specific conductivity
$INPL[5]="cond";      $UNITS[5]="uS/cm";      # conductivity
$INPL[6]="resist";    $UNITS[6]="Ohm*cm";     # resistance
$INPL[7]="tds";       $UNITS[7]="g/L";        # total dissolved solids
$INPL[8]="sal";       $UNITS[8]="ppt";        # salinity
$INPL[9]="do_perc";   $UNITS[9]="perc";       # dissolved oxygen percentage
$INPL[10]="do_percL"; $UNITS[10]="percLocal"; # dissolved oxygen percentage Local
$INPL[11]="do_mg";    $UNITS[11]="mg/L";      # dissolved oxygen mass/volume
$INPL[12]="do_chrg";  $UNITS[12]="chrg";      # dissolved oxygen charge
$INPL[13]="pH";       $UNITS[13]="pH";        # pH
$INPL[14]="pHmV";     $UNITS[14]="mV";        # pH in mV
$INPL[15]="orp";      $UNITS[15]="mV";        # redox potential

# Sonde port setup parameters

my $S_COMM_PORT="/dev/tty.USA19Hfa13P1.1";  #macbook env test.
my $S_BAUDRATE=9600;            # could be changed
my $S_PARITY="none";            # fixed by sonde interface
my $S_DATABITS=8;               # fixed by sonde interface
my $S_STOPBITS=1;               # fixed by sonde interface
my $S_HANDSHAKE="none";         # fixed by sonde interface
my $S_READ_CHAR_TIME=0;         # don't wait for each character
my $S_READ_CONST_TIME=100;      # time per unfulfilled "read" call

# Due to limitations in the SerialPort module, only 255 can be used as the
# number of chars to read per read command.
my $READ_SIZE=255;

# Number of seconds to wait for sonde run command to complete and give a
# good number of readings.
my $RUN_TIME=15;

# Values needed for threading
my $RETRY=2;         # number of times to retry thread
my $THREAD_TIME=10;  # number of seconds to wait per thread

########## Get and validate command line parameter ###########

# parameter that is to be produced by script, given on the command line
my $parameter="";

GetOptions('p=s' => \$parameter);

# turn on debugging if polling one parameter at a time
if ($parameter ne $INPL[0]) {
    $DEBUG = 1; }

if ($DEBUG) {
    print "validating parameter...\n"; }

my $found=0; # indicates that the parameter is valid
foreach my $inplt (@INPL)
{
    if ($parameter eq $inplt)
    {
        $found=1;
    }
}

if ($found==0)
{
    die "Error! missing argument \"-p <parameter>\".         THE ONLY VALID PARAMETERS ARE:
         {all,date,time,temp,spcond,cond,resist,tds,sal,do_perc,do_percL,do_mg,do_chrg,pH,pHmV,orp}\n";
}

######################### Query sonde ########################

if ($DEBUG) {
    print "querying sonde...\n"; }

my $reading="";
my $not_done=1;
my $IOthread;
my $try=$RETRY;

while ($not_done && $try)
{
     print "Outer loop \n";
    #$IOthread=threads->new(\&getreading);
    $IOthread = threads->create(\&getreading);
    for (my $i=0; $i<$THREAD_TIME; $i++)
    {
         print "Inner loop $i\n";
        if ($IOthread->is_joinable())
        {
             print "Thread is joinable.\n";
            $reading=$IOthread->join;
            print "SEEWALD reading = $reading \n";
            $not_done=0;
            last;
        }
        else
        {
            print "Sleeping.\n";
            sleep 1;
        }
    }
    
    if ($not_done)
    {
        if (!$IOthread->is_joinable())
        {
            # print "Killing unfinished thread.\n";
            $IOthread->kill('KILL')->detach();
            $try--;
        }
        else
        {
            # print "Thread done.\n";
            $reading=$IOthread->join;
            $not_done=0;
        }
    }
}

if (!$try)
{
    die "Sonde I/O is hanging. Check sonde.\n";
}

############### Process and print sonde output ###############

if ($DEBUG) 
{
    my @params = ("date","time","temp","spcond","cond",
		  "resist","tds","sal","do_perc","do_percL",
		  "do_mg","do_chrg","pH","pHmV","orp");
    
    print "processing sonde output...\n"; 
    print "-------------------------- RAW READING ----------------------\n";
    
    foreach (@params) {                                                          
        print "$_   "; } 
    print "\n";
    foreach (@UNITS) {
	print "$_   "; }

    print "\n$reading\n";
    print "\n-------------------------- $parameter ------------------------------- \n" 
}

# spilt reading lines and take a good reading
# sonde needs 5 seconds to stabilize
$reading=(split(/\n/, $reading))[$RUN_TIME-5];

# spilt reading line into fields
my @inp=split(/\s+/, $reading);

# match sonde reading fields to labels
my %output=($INPL[0]=>$reading,    # all  (split reading)
            $INPL[1]=>$inp[0],     # sonde date
            $INPL[2]=>$inp[1],     # sonde time
            $INPL[3]=>$inp[2],     # temperature
            $INPL[4]=>$inp[3],     # specific conductivity
            $INPL[5]=>$inp[4],     # conductivity
	    $INPL[6]=>$inp[5],     # resistance
	    $INPL[7]=>$inp[6],     # total dissolved solids
	    $INPL[8]=>$inp[7],     # salinity
	    $INPL[9]=>$inp[8],     # dissolved oxygen percentage
	    $INPL[10]=>$inp[9],    # dissolved oxygen percentage Local
	    $INPL[11]=>$inp[10],   # dissolved oxygen mass/volume
	    $INPL[12]=>$inp[11],   # dissolved oxygen charge
	    $INPL[13]=>$inp[12],   # pH
	    $INPL[14]=>$inp[13],   # pH in mV
	    $INPL[15]=>$inp[14]);  # redox potential

my %units=($INPL[0]=>$UNITS[0],     # all  (split reading)
	   $INPL[1]=>$UNITS[1],     # sonde date
	   $INPL[2]=>$UNITS[2],     # sonde time
	   $INPL[3]=>$UNITS[3],     # temperature
	   $INPL[4]=>$UNITS[4],     # specific conductivity
	   $INPL[5]=>$UNITS[5],     # conductivity
	   $INPL[6]=>$UNITS[6],     # resistance
	   $INPL[7]=>$UNITS[7],     # total dissolved solids
	   $INPL[8]=>$UNITS[8],     # salinity
	   $INPL[9]=>$UNITS[9],     # dissolved oxygen percentage
	   $INPL[10]=>$UNITS[10],   # dissolved oxygen percentage Local
	   $INPL[11]=>$UNITS[11],   # dissolved oxygen mass/volume
	   $INPL[12]=>$UNITS[12],   # dissolved oxygen charge
	   $INPL[13]=>$UNITS[13],   # pH
	   $INPL[14]=>$UNITS[14],   # pH in mV
	   $INPL[15]=>$UNITS[15]);  # redox potential

print "$output{$parameter} $units{$parameter}\n";

################ End of script ################

##############################################################
################## getreading implementation #################
##############################################################
sub getreading
{  
    if ($DEBUG) {
	print "getting reading...\n"; }
    
    my $sonde;
    $SIG{'KILL'}=sub
    {
        $sonde->close or die "Could not close sonde port.\n";
        threads->exit();
    };
    
    #################### Setup sonde port ####################
    
    if ($DEBUG) {
	print "setting up sonde port...\n"; }
    
    $sonde=Device::SerialPort->new($S_COMM_PORT)
        or die "Could not open sonde port.\n";
    
    $sonde->baudrate($S_BAUDRATE);
    $sonde->parity($S_PARITY);
    $sonde->databits($S_DATABITS);
    $sonde->stopbits($S_STOPBITS);
    $sonde->handshake($S_HANDSHAKE);
    $sonde->read_char_time($S_READ_CHAR_TIME);
    $sonde->read_const_time($S_READ_CONST_TIME);
    
    $sonde->write_settings;
    
#################### Get sonde prompt ####################

    if ($DEBUG) {
	print "getting sonde prompt...\n"; }
    
    my $count=0;       # number of loop iterations
    my $char_count=0;  # munber of chars read
    my $input="";      # input read
    my $read_buf="";   # buffer for mulitple reads per input
    my $num_out=0;     # number of chars written
    
    # Wake sonde and execute any command left on command line
    $num_out=$sonde->write("\r\n\r\n")
        or die "Could not write to sonde.\n";
    # Clear result of any command
    $sonde->purge_rx or die "Could not purge sonde RX.\n";
    
    ($char_count, $input)=$sonde->read($READ_SIZE)
        or die "Could not read from sonde.\n";
    
    $num_out=$sonde->write("\r\n")
        or die "Could not write to sonde.\n";
    
    # Read current sonde output to look for prompt
    ($char_count, $input)=$sonde->read($READ_SIZE)
        or die "Could not read from sonde.\n";
    
    $sonde->purge_rx or die "Could not purge sonde RX.\n";

    # If not at prompt, loop to get prompt
    while ($input!~/\# $/)
    {
        # Alternatly write "0" or "y" to get out of menu or run
        if ($count % 2 == 0)
        {
            $num_out=$sonde->write("0")
                or die "Could not write to sonde.\n";
        }
        else
        {
            $num_out=$sonde->write("y")
                or die "Could not write to sonde.\n";
        }
	
        $input="";

        ($char_count, $read_buf)=$sonde->read($READ_SIZE)
            or die "Could not read from sonde.\n";
        $input.=$read_buf;
        print "read_buf CURRENTLY: $read_buf \n";
        print "char_count is: $char_count \n";
        while ($char_count>0)
        {
            ($char_count, $read_buf)=$sonde->read($READ_SIZE)
                or die "Could not read from sonde.\n";
            $input.=$read_buf;
            print "***INPUT CURRENTLY*** $input \n";
        }
	
        $count++;
    }
    
################### Read data readings ###################
    
    if ($DEBUG) {
	print "reading data...\n"; }
    
    $input="";
    $num_out=$sonde->write("run\r\n") # Start run
        or die "Could not write to sonde.\n";
    
    # Wait for run to start and accumulation of readings in input
    sleep $RUN_TIME;

    $num_out=$sonde->write("0") # Stop run
        or die "Could not write to sonde.\n";
    
    ($char_count, $read_buf)=$sonde->read($READ_SIZE) # Read data readings
        or die "Could not read from sonde.\n";
    $input.=$read_buf;
    while ($char_count>0)
    {
        ($char_count, $read_buf)=$sonde->read($READ_SIZE)
            or die "Could not read from sonde.\n";
        $input.=$read_buf;
    }
    
    $sonde->close or die "Could not close sonde port.\n";
    
    return $input;
}
########################### END #############################
