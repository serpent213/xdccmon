# XDCCmon by Steffen Beyer (xdccmon@reactor.de)
# version 0.55, 5. feb 2003

# x-chat script
# records file offerings on all channels

# http://www.reactor.de/xdccmon/

# tested under linux with x-chat 1.8.9 and perl 5.6.1

# license: GPL, version 2 or newer
# (http://www.gnu.org/licenses/gpl.html)


package XDCCmon;

# configuration

# keep entries for $keep minutes (default 30)
my $keep = 30;

# command name (default "mon")
my $cmdname = "mon";

# default action (default "new")
my $defaction = "new";

# colors (default 1 => 7, 2 => 6, 3 => 10)
my $color1 = 7;
my $color2 = 6;
my $color3 = 10;

# /configuration


# color table
#   1 - Black        2 - Navy Blue   3 - Green       4 - Red
#   5 - Brown        6 - Purple      7 - Olive       8 - Yellow
#   9 - Lime Green  10 - Teal       11 - Aqua Light 12 - Royal Blue
#  13 - Hot Pink    14 - Dark Gray  15 - Light Gray 16 - White


use warnings;
use strict;

use constant VERSION => "0.55";

use constant COLOR => "\003";
use constant BOLD => "\002";

my %memory = my @access = ();
my $lastnew = my $maxtotal = 0;
$keep *= 60;

$_ = COLOR . ($_ < 10 ? "0" : "") . $_ foreach ($color1,$color2,$color3);

IRC::register("XDCCmon",VERSION,"","");
IRC::print("$color1** XDCCmon version " . VERSION .
	" by Steffen Beyer (xdccmon\@reactor.de)\n");
IRC::add_message_handler("PRIVMSG","XDCCmon::msg_handler");
IRC::add_command_handler($cmdname,"XDCCmon::cmd_handler");
IRC::print("$color2++ running. (try \"/$cmdname help\")\n");

sub msg_handler {
	my ($nick,$channel,$msg) = shift =~ /^:(.*?)!.* PRIVMSG (.*?) :(.*)$/;

	my $plain = $msg;
	$plain =~ s/(?:@{[ COLOR ]}\d{0,2}(?:,\d{1,2})?|@{[ BOLD ]}|[\004-\037])//g;

	if ($plain =~ /^.{0,14}#\d{1,5}\D/ and
		$plain =~ /[«\(\[].{0,4}\d.{0,4}[\]\)»]/) {

		my $result = "$channel ${nick}: $msg";
		my $key = "$channel ${nick}: $plain";
		$key =~ s/\s*\D\d+(?:x|\s*gets)\b//;

		$memory{$key}->{tfirst} = time unless defined $memory{$key};
		$memory{$key}->{tlast} = time;
		$memory{$key}->{wcount} = $result;

		my $tlimit = time - $keep;
		foreach my $entry (keys %memory) {
			delete $memory{$entry} if $memory{$entry}->{tlast} < $tlimit;
		}

		$maxtotal = keys %memory if $maxtotal < keys %memory;
	}

	return 0;
}

sub cmd_handler {
	my $command = lc shift;

	sub sortrule {
		lc(($a =~ /^(.+?)#\d/)[0]) cmp lc(($b =~ /^(.+?)#\d/)[0]) ||
		($a =~ /#(\d+)/)[0] <=> ($b =~ /#(\d+)/)[0]
	};

	my $i = 1;
	my $maxlen = length keys %memory;
	my $showline = sub {
		my $entry = shift;

		@access = () if $i == 1;

		($access[$i]->{nick},$access[$i]->{id}) =
			($entry =~ /^.*? (.*?): .*(#\d{1,3})/);
		join("",BOLD," "x($maxlen - length $i),$i++,BOLD,": ",
			$memory{$entry}->{wcount},"\n");
	};

	$command = $defaction unless $command;
		
	if ($command eq "show") {
		IRC::print("$color2++ XDCCmon catched:\n");

		IRC::print(&$showline($_)) foreach (sort sortrule keys %memory);

	} elsif ($command eq "new") {
		IRC::print("$color2++ XDCCmon catched recently:\n");

		foreach my $entry (sort sortrule keys %memory) {
			IRC::print(&$showline($entry))
				if $memory{$entry}->{tfirst} >= $lastnew;
		}

		$lastnew = time;

	} elsif ($command =~ /^get\s+(\d+)\s*$/) {
		my $monid = $1;

		if (defined $access[$monid]) {
			my ($id,$nick) = ($access[$monid]->{id},$access[$monid]->{nick});

			IRC::print("$color2++ XDCCmon get $id from $nick\n");
			IRC::command("/msg $nick xdcc send $id");
		} else {
			IRC::print("$color2++ XDCCmon get: invalid ID\n");
		}

	} elsif ($command =~ /^grep\s+(.*?)\s*$/) {
		my @patterns = split /\s+/,$1;
		IRC::print("$color2++ XDCCmon search: " .
			join("+",@patterns) . "\n");

		ENTRY: foreach my $entry (sort sortrule keys %memory) {
			foreach my $pattern (@patterns) {
				next ENTRY unless $entry =~ /$pattern/i;
			}

			IRC::print(&$showline($entry));
		}

	} elsif ($command eq "stats") {
		my %stats;
		foreach my $entry (keys %memory) {
			my $channel = ($entry =~ /^(.*?) /)[0];
			$stats{lc $channel}->{count}++;
			$stats{lc $channel}->{name} = $channel;
		}

		IRC::print("$color2++ XDCCmon channel stats:\n");

		my $total = 0;
		foreach my $channel (sort keys %stats) {
			IRC::print($stats{$channel}->{name} . ": " .
				$stats{$channel}->{count} . "\n");
			$total += $stats{$channel}->{count};
		}

		IRC::print(join("","${color3}total files: $total (max. $maxtotal)   channels: ",
			scalar keys %stats,"   files/channel: ",
			keys(%stats) ? sprintf("%.1f",$total/(keys %stats)) : "mu",
			"\n"));

	} elsif ($command eq "reset") {
		%memory = ();
		IRC::print("$color2++ XDCCmon memory cleared.\n");

	} elsif ($command eq "help") {
		my $head = "\n$color3/$cmdname ";
		IRC::print(join($head,"$color2++ XDCCmon usage:",
			"show         " . COLOR . "display all collected entries",
			"new          " . COLOR . "display new entries since last \"/$cmdname new\"",
			"grep WORD+   " . COLOR . "search memory for entries containing all selected words",
			"get ID       " . COLOR . "trigger download of file with selected ID (\"xdcc send #x\")",
			"stats        " . COLOR . "display channel statistics",
			"reset        " . COLOR . "clear memory\n"));

	} else {
		IRC::print("$color2++ XDCCmon unknown command: $command\n");
		IRC::print("$color2++ available: " . BOLD . "(get ID) (grep WORD+) " .
			"new reset show stats\n");
	}

  	return 1;
}
