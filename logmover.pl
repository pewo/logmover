#!/usr/bin/perl -w

use strict;
use File::Basename;
use File::Path;
use Data::Dumper;


my($destbase) = "/local/backup/logs";



sub modtime2path($) {
        my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(shift);
	$year += 1900;
	$mon += 1;

	my($path) = $destbase . sprintf("/%4.4d/%02.2d",$year,$mon);
	return($path);
}

sub modtime2ext($) {
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(shift);
	$year += 1900;
	$mon += 1;

	my($ext) = sprintf("%4.4d%02.2d%02.2d_%02.2d%02.2d",$year,$mon,$mday,$hour,$min);
	return($ext);
}

sub makepath($) {
	my($dir) = shift;
	if ( -d $dir ) {
		return;
	}

	mkpath($dir,1,0700);

	if ( ! -d $dir ) {
		chdir($dir);
		die "$dir: $!\n";
	}
}

sub copy($$) {
	my($src) = shift;
	my($dst) = shift;

	my($rc);
	$rc = system("/bin/cp","-p",$src,$dst);
	if ( $rc ) {
		return(0);
	}
	else {
		return(1);
	}
}

sub move($$) {
	my($src) = shift;
	my($dst) = shift;

	my($rc);
	$rc = copy($src,$dst);
	unless ( $rc ) {
		return(0);
	}

	$rc = unlink($src);
	unless ( $rc ) {
		return(0);
	}

	return(1);
}

sub read_newsyslog_conf() {
	my(@files) = ();
	if ( open(CONF,"</etc/newsyslog.conf") ) {
		foreach ( <CONF> ) {
			next unless ( m|^/| );
			my($file) = split;
			next unless ( -f $file );
			push(@files,$file);
		}
	}
	return(@files);
}

sub read_syslog_conf() {
	my(@files) = ();
	if ( open(CONF,"</etc/syslog.conf") ) {
		foreach ( <CONF> ) {
                	my(@arr) = split;
                	my($file) = $arr[-1];
                	next unless ( $file );
			$file =~ s/^-//;
			print "file: $file\n";
                	#next unless ( $file =~ /^\/var\/adm\/fhnet-syslog\// );
                	next unless ( -f $file );
                	push(@files,$file);
        	}
	}
        return(@files);
}

sub read_logrotate_conf($) {
	my($conf) = shift;
	my($ldebug) = 0;
	my(@files) = ();
	if ( open(CONF,"<$conf") ) {
		print "DEBUG Conf=[$conf]\n" if ( $ldebug );
			
		foreach ( <CONF> ) {
			s/\s+$//;
			chomp;
			print "DEBUG Got1=[$_]\n" if ( $ldebug );
			if ( /^\/.*\{/ ) {
				s/\{//;
				print "DEBUG Got2=[$_]\n" if ( $ldebug );
				my($file);
				foreach $file ( split ) {
					print "\tDEBUG File=[$file]\n" if ( $ldebug );
					my($subfile);
					foreach $subfile ( < $file > ) {
						next unless ( -f $subfile );
						push(@files,$subfile);
					}
				}
			}
			elsif ( /^\// ) {
				next unless ( -f $_ );
				print "DEBUG Got3=[$_]\n" if ( $ldebug );
				push(@files,$_);
			}
		}
		close(CONF);
	}
	return(@files);
}

sub read_logrotate() {
	my(@files);
	@files = ( @files, read_logrotate_conf("/etc/logrotate.conf") );
	my($conf);
	foreach $conf ( </etc/logrotate.d/*> ) {
		@files = ( @files, read_logrotate_conf($conf));
	}
	return(@files);
}

#########################################
#    
#     #    #    ##       #    #    #
#     ##  ##   #  #      #    ##   #
#     # ## #  #    #     #    # #  #
#     #    #  ######     #    #  # #
#     #    #  #    #     #    #   ##
#     #    #  #    #     #    #    #
#
#########################################

makepath($destbase);


my(%files);
my($path);
foreach $path ( read_newsyslog_conf, read_syslog_conf, read_logrotate ) {
	$files{$path}=1;
}


foreach $path ( sort keys %files ) {
	my(%poss);
        my($dir) = dirname($path);
        my($base) = basename($path);

        print "dir=[$dir], base=[$base]\n";

        my($file);
        foreach $file ( <$dir/$base.*.gz> ) {
		$poss{$file}=1;
	}

        foreach $file ( <$dir/$base-*.gz> ) {
		$poss{$file}=1;
	}

	foreach $file ( sort keys %poss ) {

                print "Src: $file\n";
		$base = basename($file);
                unless ( open(S,"<$file") ) {
                        print "reading $file: $!\n";
                        next;
                }
                close(S);

                my($mod);
                $mod = (stat($file))[9];
                unless ( $mod ) {
                        print "stat($file): $!\n";
                        next;
                }

                my($newpath) = modtime2path($mod);
                makepath($newpath);
                my($ext) = modtime2ext($mod);
                my($dest) = $newpath . "/" . $base . "." . $ext . ".gz";
                print "Dst: $dest\n";
                move($file,$dest);
        }
}
