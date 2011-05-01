#!/usr/bin/perl -w

#	Nariman - is a "NARod.ru Image MANipulator"
#	This is a script for uploading and managing image files on narod.ru
#	free site hosting. Because narod.ru is useless and terrible site hosting,
#	this script make it most useful.

use strict;

use Net::FTP;
use Image::Magick;
use File::Copy;

# Image Resize Procedure
sub image_resize {
	my $img_name=$_[0];
	my $preview_name=$img_name;
	my $width=$_[1];
	my $height=$_[2];
	my $tmp_dir=$_[3]."/";
	my $unique=$_[4];
	$preview_name="preview_".$unique.$img_name;	
	copy($img_name,$tmp_dir.$unique.$img_name) or die "Can not copy file $img_name to temp directory $tmp_dir";
	my $workimage=new Image::Magick;
	$workimage->read($tmp_dir.$unique.$img_name);
	#
	#Getting work image size
	#
	my $work_width=$workimage->get('width');
	my $work_height=$workimage->get('height');
	my $workimage_fsize=sprintf("%.2f",($workimage->get('filesize'))/1024);
	#
	#Preview geometry set
	#
	if($work_width>$work_height)
	{
		my $resize_c=$work_width / $width;
		$height=$work_height / $resize_c;
	}
	else
	{
		my $resize_c=$work_height / $height;
		$width=$work_width / $resize_c;
	}
	my $preview_text="^_^ $work_width"."x"."$work_height $workimage_fsize"."Kb";
	$workimage->Resize(width=>$width, height=>$height);
	$workimage->Annotate(text=>$preview_text, gravity=>'south', style=>'normal', undercolor=>'white');
	$workimage->write($tmp_dir.$preview_name);
	print "Preview for $img_name complete\n";
}

# Album page generating procedure
sub album_gen {

}

# Help view procedure
sub help_view {
	print "NARIMAN - NARod.ru Image MANipulator\n\n";
	print "using: nariman.pl [ OPTONS ] [FILE1 FILE2]\n\n";
	print "Command line options:\n\n";
	print "long\t\tshort\tdescription\n";
	print "--help\t\t-h\tThis help view\n";
	print "--config\t-c\tUse custom configuration file\n";
	print "--create\t-ca\tCreate new album on server\n";
	print "--delete\t-da\tDelete album on server\n";
	print "--dir\t\t-d\tLoad all images in directory. This is non-recursive reading!\n";
	print "";
	print "Deleting albums or images can not realized. make it manually :-[";
	print "\n\nThanks for using\n";
	exit 0;
}

# Synchronizing album list
sub album_sync{
	my $ftp=Net::FTP->new($_[0],Debug=>0) or die "Can not connect to $_[0]";
	$ftp->login($_[1],$_[2]) or die "Can not login";
	$ftp->cwd("/albums") or die "Can not change directory", $ftp->message;
	$ftp->put($_[3]) or die "Can not upload file", $ftp->message;;
	open (ALBUMLIST, $_[3]);
	while (<ALBUMLIST>)
	{
		if($_=~/^\w/)
		{

			my ($albumname,$albumdesc)=split(/\;/,$_);
			$ftp->mkdir($albumname); # or die "Can not create directory ", $ftp->message;
		}
	}
	close(ALBUMLIST);

	$ftp->quit;
}
sub tmp_dir_clear {
	print "Deleting temporary files";
	my $tmp_dir=$_[0]."/";
	my $file;
	my @files;
	opendir (TMPDIR,$tmp_dir) or die "Can not open temp dir";
	@files=grep(!/^\.\.?$/,readdir(TMPDIR));
	foreach $file (@files)
	{
		print ".";
		unlink $tmp_dir.$file;
	}
	closedir(TMPDIR);
	print "\nComplete!";
}

##Default variables
# Default config file
#
#Stupud construction :-[
my ($name, $pass, $uid, $gid, $quota, $comment, $gcos, $dir, $shell, $expire) = getpwuid($>);
my $config_file="$dir/.config/nariman/nariman.conf";
my %imagelist;
my $imagecount=0;
my %config;
my $optname;
my $optval;
my $flag=0;
my %albums;
my $albumname;
my $albumdesc;
my $alb_name;
my $albumnumber=0;
my $act;
my $select=0;
my $select_alb;
my $unique=int(rand(100000));
# Album list
my $album_list="$dir/.config/nariman/albumlist";
# Error Messages
my $errmiss="ERROR: Missing parameter\n";
# 
# Links variables
my $direct_link;
my $html_direct;
my $html_preview;
my $bbcode_direct;
my $bbcode_preview;
my $bbcode_big_preview;
my $bbcode_big_direct;
my $preview_link;
my $album_address;


# analyzing command line arguments 
foreach my $argnum (0..$#ARGV)
{
	if($ARGV[$argnum] eq '--help' or $ARGV[$argnum] eq '-h')
	{
		&help_view();
	}
	if($ARGV[$argnum] eq '--config' or $ARGV[$argnum] eq '-c')
	{
		if($ARGV[$argnum+1])
		{
			$config_file=$ARGV[$argnum+1];
			$flag=1;
		}
		else
		{
			print $errmiss;
			exit 1;
		}
	}
	if($ARGV[$argnum] eq '--create' or $ARGV[$argnum] eq '-ca')
	{
		if($ARGV[$argnum+1])
		{
			$alb_name=$ARGV[$argnum+1];		
			$act=1;
		}
		else
		{
			print $errmiss;
			exit 1;
		}
	}
	if($ARGV[$argnum] eq '--delete' or $ARGV[$argnum] eq '-da')
	{
			$alb_name=$ARGV[$argnum+1];		
			$act=2;
	}

	if($ARGV[$argnum] eq '--dir' or $ARGV[$argnum] eq '-d' )
	{
		if($ARGV[$argnum+1])
		{
			$act=3;
			my $dir_name=$ARGV[$argnum+1];
			opendir(IMGDIR,$dir_name) or die "Error to opening directory $dir_name\n";
			my @files=grep(/\.jpg|\.png|\.gif/,readdir(IMGDIR));
			closedir(IMGDIR);
			print @files;
			while(my ($num,$filename)=each @files)
			{
				$imagelist{$num}=$filename;
			}

		}
		else
		{
			print $errmiss;
			exit 1;
		}
	}
	if($ARGV[$argnum])
	{
		if($flag==1)
		{
			$flag=0;
		}
		else
		{
			if($ARGV[$argnum]=~/.*\.png|jpg|gif/ )
			{
				$act=3;
				$imagelist{$imagecount}=$ARGV[$argnum];
				$imagecount++;
			}
		}
	}
}
if(!$ARGV[0])
{
	print "NARIMAN v1.0\ntype nariman --help for more information :)\n";
}
# Config reading
open (CONFIG,$config_file);
while (<CONFIG>)
{
	if($_=~/^\w/)
	{
		s/\n//;
		($optname,$optval)=split(/=/,$_);
		$config{$optname}=$optval;	
	}
}
close (CONFIG);
# while (($optname,$optval)=each %config)
#{
#	print "$optname = $optval\n";
#}

#Adding new Album
if($act==1)
{
	open (ALBUMLIST,">>$config{'album_list'}");
	print "Enter album description:\n";
	chomp (my $alb_desc=<STDIN>);
	print "Add new album";
	print (ALBUMLIST "$alb_name;$alb_desc\n");
	close (ALBUMLIST);
	&album_sync($config{'site'},$config{'username'},$config{'password'},$config{'album_list'});
	exit 0;
}
# Start image preview creating
if($act==3)
{
	print "Start preview creating\n\n";
	while(my($fileid,$filename)=each %imagelist)
	{
		&image_resize($filename,$config{'width'},$config{'height'},$config{'tmp_dir'},$unique);
	}
	print "Sync albums\n";
	&album_sync($config{'site'},$config{'username'},$config{'password'},$config{'album_list'});
	print "\nSelect album to upload\n\n";
	open (ALBUMLIST,$config{'album_list'});
	print "N\tAlbum name\tAlbum Description\n\n";
	while (<ALBUMLIST>)
	{
		if($_=~/^\w/)
		{
			$albumnumber++;
			($albumname,$albumdesc)=split(/\;/,$_);
			$albums{$albumnumber}=$albumname;
			print "$albumnumber\t$albums{$albumnumber}\t\t$albumdesc";
		}
	}
	close(ALBUMLIST);
	chomp($select=<STDIN>);
#
# Uploading files via FTP
#
	my $ftp=Net::FTP->new($config{'site'},Debug=>0) or die "Can not connect to $_[0]";
	$ftp->login($config{'username'},$config{'password'}) or die "Can not login";
	$ftp->cwd("/albums/$albums{$select}") or die "Can not change directory", $ftp->message;
	$ftp->binary;
	while (my ($fileid,$filename)= each %imagelist)
	{
		$ftp->put($config{'tmp_dir'}."/".$unique.$filename) or die "Can not upload file", $ftp->message;;
		$ftp->put($config{'tmp_dir'}."/"."preview_".$unique.$filename) or die "Can not upload file", $ftp->message;;
	}
	$ftp->quit;

	print "File uploading complete\n\n";
	print "Your links:\n";
	while (my ($fileid,$filename)= each %imagelist)
	{
	$direct_link=$config{'website'}."/albums/".$albums{$select}."/".$unique.$imagelist{$fileid};
	$preview_link=$config{'website'}."/albums/".$albums{$select}."/preview_".$unique.$imagelist{$fileid};
	$html_direct="<img src=\"".$direct_link."\">";
	$html_preview="<a href=\"".$direct_link."\"><img src=\"".$preview_link."\"></a>";
	$bbcode_direct="[img]".$direct_link."[/img]";
	$bbcode_preview="[url=\"".$direct_link."\"][img]".$preview_link."[/img][/url]";
	$bbcode_big_preview="[URL=\"".$direct_link."\"][IMG]".$preview_link."[/IMG][/URL]";
	$bbcode_big_direct="[IMG]".$direct_link."[/IMG]";
	print "================================================================\n";
	print $imagelist{$fileid}."\n\n";
	print "Direct link:\n$direct_link\n";
	print "HTML direct link:\n$html_direct\n";
	print "HTML preview link:\n$html_preview\n";
	print "BBCode direct link:\n$bbcode_direct\n";
	print "BBCode direct link (big lettres):\n$bbcode_big_direct\n";
	print "BBCode preview link:\n$bbcode_preview\n";
	print "BBCode preview link (big letters):\n$bbcode_big_preview\n";
	
	}
	$album_address=$config{'website'}."/albums/".$albums{$select}."/";
	print "Album Address\n$album_address\n";
	&tmp_dir_clear($config{'tmp_dir'});

}







