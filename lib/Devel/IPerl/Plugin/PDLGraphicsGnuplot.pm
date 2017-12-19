package Devel::IPerl::Plugin::PDLGraphicsGnuplot;
# ABSTRACT: IPerl plugin to make PDL::Graphics::Gnuplot plots displayable

use strict;
use warnings;

use PDL::Graphics::Gnuplot;
use Role::Tiny;
use Devel::IPerl::Display::SVG;
use Devel::IPerl::Display::PNG;

our $IPerl_compat = 1;
our $IPerl_format = 'SVG';

our $IPerl_format_info = {
	'SVG' => { suffix => '.svg', displayable => 'Devel::IPerl::Display::SVG' },
	'PNG' => { suffix => '.png', displayable => 'Devel::IPerl::Display::PNG' },
};

sub register {
	Role::Tiny->apply_roles_to_package( 'PDL::Graphics::Gnuplot', q(Devel::IPerl::Plugin::PDLGraphicsGnuplot::IPerlRole) );
}

{
package
	Devel::IPerl::Plugin::PDLGraphicsGnuplot::IPerlRole;

use Moo::Role;
use Capture::Tiny qw(capture_stderr capture_stdout);
use Path::Tiny;

around new => sub {
	my $orig = shift;

	my $gpwin = $orig->(@_);

	if( $Devel::IPerl::Plugin::PDLGraphicsGnuplot::IPerl_compat ) {
		# We turn on dumping so that the plot does not go to an actual
		# terminal (a "dry-run"). This is so that we can actually have
		# the output go to a terminal later when
		# C<iperl_data_representations> is called.
		capture_stderr(sub {
			# capture to avoid printing out the dumping warning
			$gpwin->option( dump => 1 );
		});
	}

	return $gpwin;
};

around _printGnuplotPipe => sub {
	my $orig = shift;

	if( $Devel::IPerl::Plugin::PDLGraphicsGnuplot::IPerl_compat ) {
		my ($dump_stdout, $dump_stderr);
		local *STDOUT;
		#local *STDERR;
		open STDOUT, '>', \$dump_stdout or die "Can't open STDOUT: $!";
		#open STDERR, '>', \$dump_stderr or die "Can't open STDERR $!";
		return $orig->(@_);
	} else {
		return $orig->(@_);
	}
};

sub iperl_data_representations {
	my ($gpwin) = @_;
	return unless $Devel::IPerl::Plugin::PDLGraphicsGnuplot::IPerl_compat;
	capture_stderr(sub {
		# capture to avoid printing out the dumping warning
		$gpwin->option( dump => 0);
	});

	my $format = $Devel::IPerl::Plugin::PDLGraphicsGnuplot::IPerl_format;
	my $format_info = $Devel::IPerl::Plugin::PDLGraphicsGnuplot::IPerl_format_info;

	die "Format $format not supported" unless exists $format_info->{$format};

	my $suffix = $format_info->{$format}{suffix};
	my $displayable = $format_info->{$format}{displayable};

	my $tmp_filename = Path::Tiny->tempfile( SUFFIX => $suffix );
	capture_stderr( sub {
		$gpwin->option( hardcopy => "$tmp_filename" );
		$gpwin->replot();
		$gpwin->close;
	});

	capture_stderr( sub  {
		# capture to avoid printing out the dumping warning
		$gpwin->option( dump => 0 );
	} );

	return $displayable->new( filename => $tmp_filename )->iperl_data_representations;
}

}

1;
