package Data::CGIForm;
#
# $Id: CGIForm.pm,v 1.19 2002/12/03 04:59:06 ctriv Exp $
#
use 5.006;
use strict;
use warnings;
use Carp ();

our $VERSION = 0.2;

=head1 NAME

Data::CGIForm - Form Data Interface.

=head1 DESCRIPTION

Data::CGIForm is yet another way to parse and handle CGI form data.
The main motivation behind this module was a simple specification
based validator that could handle multiple values.

=head1 SYNOPSIS

 my %spec = (
     username => qr/^([a-z0-9]+)$/,
     password => {
         regexp => qr/^([a-z0-9+])$/,
         filter => [qw(strip_leading_ws, strip_trailing_ws)],
     },
     email => {
         regexp   => qr/^([a-z0-9@.]+)$/,
         filter   => \&qualify_domain,
         optional => 1,
         errors => {
             empty   => 'You didn\'t enter an email address.',
             invalid => 'Bad [% key %]: "[% value %]"',
         },
         extra_test   => \&check_email_addr,
     },
     email2 => {
     	equal_to => email,
     	errors   => {
     		unequal => 'Both email addresses must be the same.',
     	},
     },
 );

 my $r    = $ENV{'MOD_PERL'} ? Apache::Request->instance : CGI->new;
	
 my $form = Data::CGIForm->new(datasource => $r, spec => \%spec);
 

 my @params = $form->params;
 foreach $param (@params) {
     next unless my $error_string = $form->error($param);
 		
     print STDERR $error_string;
 }
 
 if ($form->error('username')) {
     handle_error($form->username, $form->error('username'));
 }
 
 my $email    = $form->param('email');
 my $password = $form->password;

=head1 Building the Spec

The spec is a hashref describing the format of the data expected, and the
rules that that data must match.  The keys for this hash are the parameters 
that you are expecting.

In the most simple use, the value for a key can simply be a regular expression
object.  For example:

 %spec = (
     key => qr/.../,
 );

For the more complex options, a key should point to a hashref containing the
options for that key.  The following keys are supported in the hashref:

=over 4

=item equal_to

This is simply a bit of syntaxtic sugar.  It makes this:

 email2 => {
 	equal_to => email,
 }
 
The same as:

 email2 => {
   regexp     => qr/^(.*)$/,
   extra_test => sub { 
     my ($textref, $form) = @_;
 		
     return unless my $value = $form->param('email');
 		
     if ($$textref eq $value) {
       return 1;
     } else {
       $form->param( email  => '');
       $form->param( email2 => '');
       $self->errorf(email2 => unequal => $$textref);
       $self->error( email => $self->error('email2'));
       return 0;
     }
   },
 }

C<equal_to> does not work properly with multiple values.  This is a feature.
Also, do not use C<equal_to> with a key more than once.  The dragons may 
come looking for you if you do, and you taste good with ketchup.

=item regexp

The regular expression that the data must match.

=item filter

The filter (or filters; to have more than one use an array ref) that the data 
must be passed though before it is validated.  See the 'Filters' section
below.

=item optional

boolean.  If true then the parameter is optioinal.  Note that if the parameter 
is given, then it is still validated.  It can still be marked as an error if 
parameter is given.

=item errors

A hashref to the error strings for this parameter.  See the Error Strings 
section below.

=item extra_test

A codefef (or arrayref of coderefs) of boolean functions that will be used
in the validation process.  See the Extra Test section below.

=back

=head2 Filters

These functions are used to filter the data before that data is validated. In
the spec they can be listed as a single filter, or an arrayref of many filters.

There filters are built in, and can be specified by name:

=over 4

=item strip_leading_ws

Removes any leading white space from the data.

=item strip_trailing_ws

Removes any trailing white space from the data.

=item strip_ws

Removes any white space from the data.

=item lc               

Converts the data to lowercase.  

=item uc                  

Converts the data to uppercase.  

=back

If you with you use your own filter, then list it as a coderef in the spec.

Filters are passed 1 parameter.  $_[0] is a scalar ref to the current data
being filtered.  For example:

 sub fix_newlines {
     my $textref = shift;
	 $$textref   =~ s/[\n\r]*/\n/sg;
 }
 
=cut

our %Filters = (
	strip_leading_ws  => sub { ${$_[0]} =~ s/^\s*//   },
	strip_trailing_ws => sub { ${$_[0]} =~ s/\s*$//   },
	strip_ws		  => sub { ${$_[0]} =~ s/\s*//g   },
	lc				  => sub { ${$_[0]} = lc ${$_[0]} },
	uc				  => sub { ${$_[0]} = uc ${$_[0]} },
);

=head2 Error Strings

For each key in the spec, you can specify different error messagses
for different situations.   For example

 %spec = (
     field => {
         errors => {
             empty   => "You didn't fill this out!"
             invalid => "That doesn't look right!"
         },
         ...
     },
 ); 
 
Currently, there are three error types.  C<invalid> is used when
the data does not match the validation specification, while
C<empty> is used when no data was given and the field is not optional.
C<unequal> is used when an equal_to pair does not match.

Two tags are filled in when the error messages are set:

 [% key %]     == Becomes ==> The current keyname.
 [% value %]   == Becomes ==> The value for the current key.

For example

 errors => {
     invalid => "[% value %] doesn't look like a [% key %]",
 }
 
If a type isn't given, then a default message is used.

=cut

our %DefaultErrors = (
	invalid => 'The input for [% key %] ("[% value %]") is invalid.',
	empty   => '"[% key %]" not given.',
	unequal => 'The two fields must match.',
);

our @ValidErrorFields = qw(invalid empty unequal);

=head2 Extra Test

Extra tests give the programmer a hook into the validation process.

Extra tests are declared in a similar fasion in the spec to filters, 
with the exception that everything is a coderef.  There are no built 
in extra tests.

Extra tests functions are passed 3 paramters:

$_[0] is a scalar refernce to the data being tested:

 sub is_right_size {
     return (${$_[0]} > 100 and ${$_[0]} < 1250);
 }

$_[1] is the current Data::CGIForm object.  $_[2] is the key name for the 
data being filtered.  For example:

 sub check_email {
     my ($textref, $form, $key) = @_;
     unless (Email::Valid->address($$textref)) {
         $form->error(
             $key => "address failed $Email::Valid::Details check."
         );
         return;
     }
     return 1;
 }
 
Note that just setting the error string does not clear the parameter.  You may
want to do this yourself to keep with the built in behavior:

 sub check_email {
     my ($textref, $form, $key) = @_;
     unless (Email::Valid->address($$textref)) {
         $form->param($key => '');
         $form->error(
             $key => "address failed $Email::Valid::Details check."
         );
         return;
     }
     return 1;
 }
 
=head1 METHODS

=head2 Data::CGIForm->new()

Creates the Data::CGIForm object.  As of this writing no options are supported.

This should be called in the following matter:

  Data::CGIForm->new(datasource => $r, spec => \%spec, %options)
  
C<datasource> should be something that has a C<param()> method, like a L<CGI>
object, or a L<Apache::Request> object.  C<%spec> is explained in the specification
docs above.

The following options are supported:

=over 4

=item start_param

Specifies that a given parameter acts as a switch for validation.  If the value from 
the datasource for this parameter is true, then validation will be skipped and an empty
string set as the value for each parameter in the spec.

=back

=cut 

sub new {
	my $class = shift;
	
	Carp::croak("${class}->new(): Odd number of parameters given.") unless @_ % 2 == 0;
	
	my %params = @_;
	
	for (qw(datasource spec)) {
		Carp::croak("${class}->new(): $_ not given.") unless $params{$_};
	}
	
	unless (ref $params{'datasource'} and $params{'datasource'}->can('param')) {
		Carp::croak("${class}->new(): 'datasource' must be an object with a param() method.");
	}
	
	unless (ref $params{'spec'} and ref $params{'spec'} eq 'HASH') {
		Carp::croak("${class}->new(): 'spec' must be a hashref.");
	}
	
	my $self = {
		spec   => {},
		data   => {},
		errors => {},
	};
	
	if ($params{'start_param'}) {
		unless ($params{'spec'}->{$params{'start_param'}}) {
			Carp::croak(qq(${$class}->new(): 'start_param' ("$params{'start_param'}") not listed in the spec.));
		}
		
		$self->{'start_param'} = $params{'start_param'};
	}
		
	
	bless($self, $class);
	
	# Scan the user spec, and normalize it
	$self->_scan_spec($params{'spec'});
	
	# pull the data from the datasource
	$self->_populate_vars($params{'datasource'});
	
	# run the validation spec
	$self->_validate_params unless $self->{'in_unstarted_mode'};
	
	return $self;
}

#
# $form->_scan_spec($spec)
#
# Runs though the given spec, and normalizes it.
#
sub _scan_spec {
	 my ($self, $s) = @_;
	 	 
	 foreach my $param (keys %$s) {
	 	my $value = $s->{$param};
	 		 	
	 	Carp::croak("new(): spec error: $param is not a ref") unless ref $value;
		
		if (ref $value eq 'HASH') {
			$self->_insert_spec($param => $value);
		} elsif (ref $value eq 'Regexp') {
			$self->_insert_spec($param => { regexp => $value});
		} else {
			Carp::croak("new(): spec error: $param is not a hashref or regexp");
		}
	}	
	
	$self->_insert_delayed_specs if $self->{'delayed_specs'};
}

#
# $form->_insert_spec($key => $spec)
#
# Does most of the heavy lifting for _scan_spec
#
sub _insert_spec {
	my ($self, $key, $old_spec) = @_;
	
	#
	# Make a copy just to be safe.
	#
	my $s = { %$old_spec };

	if ($s->{'equal_to'}) {
		# equal_to rules must be inserted last, so 
		# they can see all the other data that has been inserted.
		$self->{'delayed_specs'}->{$key} = $s;
		return;
	}
	
		
	
	my $regexp   = delete $s->{'regexp'};
	
	Carp::croak("new(): spec error: no regexp given for '$key'.")
		unless $regexp;
	
	Carp::croak("new(): spec error: regexp for '$key' not a regexp.")
		unless ref $regexp and ref $regexp eq 'Regexp';
		
	my $optional   = delete $s->{'optional'} ? 1 : 0;
	my $errors     = delete $s->{'errors'};
	
	my $filter     = delete $s->{'filter'};
	my $extra_test = delete $s->{'extra_test'};
	
	if (%{$s}) {
		Carp::croak("new(): spec error: invalid options for $key: @{[ keys %{$s} ]}");
	}
	
	my %spec = (
		optional     => $optional,
		regexp       => $regexp,		
	);
	
	if ($filter) {
		my @filters = (ref $filter and ref $filter eq 'ARRAY') ? @{$filter} : ($filter);
		
		foreach my $f (@filters) {
			if ($Filters{$f}) {
				push(@{$spec{'filter'}}, $Filters{$f});
			} elsif (ref $f and ref $f eq 'CODE') {
				push(@{$spec{'filter'}}, $f);
			} else {
				Carp::croak("new(): spec error: No such built in filter: $f");
			}
		}
	}
	
	if ($extra_test) {
		my @tests = (ref $extra_test and ref $extra_test eq 'ARRAY') ? @{$extra_test} : ($extra_test);
		
		foreach my $t (@tests) {
			if (ref $t and ref $t eq 'CODE') {
				push(@{$spec{'extra_test'}}, $t);
			} else {
				Carp::croak('new(): spec error: extra tests must be a code reference.');
			}
		}
	}
	
	if ($errors) {
		#
		# Make a copy just to be safe. (we use delete here too)
		#
		$errors = { %$errors };
		
		unless (ref $errors and ref $errors eq 'HASH') {
			Carp::croak('new(): spec error: errors not a hashref');
		}
		
		my %errors = (
			%DefaultErrors
		);
			
		foreach my $type (@ValidErrorFields) {
			my $msg = delete $errors->{$type} || next;
			$errors{$type} = $msg;
		}
		
		if (%{$errors}) {
			Carp::croak("new(): spec error: invalid error message types: @{[ keys %{$errors} ]}");
		}
		
		$spec{'errors'} = \%errors;
	} else {
		$spec{'errors'} = { %DefaultErrors };
	}
		
	
	$self->{'spec'}->{$key} = \%spec;
}


sub _insert_delayed_specs {
	my ($self) = @_;

	while (my ($key, $s) = each %{$self->{'delayed_specs'}}) {
		my $equal_to = delete $s->{'equal_to'} || Carp::confess("How did we get a delayed spec with no equal_to?!");
	
		unless ($self->{'spec'}->{$equal_to}) {
			Carp::croak("new(): spec error: equal_to set to unknown parameter: $equal_to.");
		}
	
		$s->{'regexp'}     = qr/^(.*)$/;
		$s->{'extra_test'} = sub {
			my ($textref, $form) = @_;
 		
			return unless my $value = $form->param($equal_to);
			
			if ($$textref eq $value) {
				return 1;
			} else {
				$form->param( $equal_to  => '');
				$form->param( $key => '');
				
				$self->errorf($key      => unequal => $$textref);
				$self->error( $equal_to => $self->error($key));
				
				return 0;
			}
		};
		
		$self->_insert_spec($key, $s);
	}
}

#
# $form->_populate_vars($datasource)
#
# Goes though the spec, grabbing data from the datasource for each var.	
#	
sub _populate_vars {
	my ($self, $data) = @_;
	
	$self->{'in_unstarted_mode'} = 1 if $self->{'start_param'} 
									and !$data->param($self->{'start_param'});
	
	if ($self->{'in_unstarted_mode'}) {
		foreach my $key (keys %{$self->{'spec'}}) {
			$self->{'data'}->{$key} = [''];
		}
	} else {
		foreach my $key (keys %{$self->{'spec'}}) {
			@{$self->{'data'}->{$key}} = $data->param($key);
		}
	}
}


#
# $form->_validate_params
#
# Runs though the spec, validating the data we got from the datastore.
# If the data is bad, we drop it to the floor, and set an error message.
#
sub _validate_params {
	my ($self) = @_;
	
	KEY: while (my ($key, $spec) = each %{$self->{'spec'}}) {

		my @new_data;
		
		unless (@{$self->{'data'}->{$key}}) {
			$self->errorf($key => 'empty', $_) unless $self->error($key) || $spec->{'optional'};
			next KEY;
		}
		
		
		MEMBER: for (@{$self->{'data'}->{$key}}) {
			next MEMBER if defined $_ and length $_;
						
			$self->errorf($key => 'empty', $_) unless $self->error($key) || $spec->{'optional'};
			next KEY;
		}
		
		DATA: foreach my $data (@{$self->{'data'}->{$key}}) {
			
			next DATA unless defined $data;
			
			if ($spec->{'filter'}) {
				$_->(\$data) for @{$spec->{'filter'}};
			}  
			
			unless ($data =~ $spec->{'regexp'}) {
				$self->errorf($key => 'invalid' =>  $data);
			} else {
				my $data = $1;
				
				if ($spec->{'extra_test'}) {
					foreach my $t (@{$spec->{'extra_test'}}) {
						unless ($t->(\$data, $self, $key)) {
							# Don't overide any error message that the test 
							# function set.
							$self->errorf($key => 'invalid', $data) 
								unless $self->{'errors'}->{$key};
							next DATA;
						}
					}
				}
				
				push(@new_data, $data);
			}		
		}
		
		if (@new_data) {
			$self->{'data'}->{$key} = [ @new_data ];
		} else {
			delete $self->{'data'}->{$key};
		}
	}
}

	


=head2 $form->params

Returns a list of all the parameters that were in the datasource that 
are called for in the spec.

=cut

sub params {
	my ($self) = @_;
	
	# Store it in an tmp array to force this into list context. 
	# (sort returns undef in non-list context.)
	my @params = sort keys %{$self->{'data'}};
	
	return @params;
}

=head2 $form->param($name => $new_value)

Returns the parameter for a given var.  If called in scalar context it returns
the first value fetched from the datasource, regardless of the number of values.

C<$new_value> should be a scalar or an array ref.

If C<$name> is not given then this method returns C<$form-E<gt>params>, just like 
CGI or Apache::Request.

=cut

sub param {
	my ($self, $name, $new_value) = @_;
	
	return $self->params unless $name;
	
	if (defined $new_value) {
		if (ref $new_value) {
			if (ref $new_value eq 'ARRAY') {
				$self->{'data'}->{$name} = $new_value;
			} else {
				Carp::croak("param(): new value is not data or an array reference.");
			}
		} else {
			$self->{'data'}->{$name} = [ $new_value ];
		}
	}
	
	return unless my $data = $self->{'data'}->{$name};
	
	return wantarray ? @{$data} : $data->[0];
}
	

=head2 $form->error($param_name => $new_error)

Returns the error string (if an error occcured) for the a given parameter.

If two arguments are passed, this can be used to set the error string.  

If no parameter is passed, than it returns boolean.  True if an error occured
in validating the data, false if no error occured.

=cut

sub error {
	my ($self, $name, $new_error) = @_;
	
	if ($name) {
		$self->{'errors'}->{$name} = $new_error if $new_error;
				
		return $self->{'errors'}->{$name};
	} else {
		return %{$self->{'errors'}} ? 1 : 0;
	}
}

=head2 $form->errorf($key, $type, $data) 

Sets the error for C<$key> to the format type C<$type>, using C<$data>
for the C<[% value %]> tag.

=cut

sub errorf {
	my ($self, $key, $type, $data) = @_;
		
	my $format;
	unless ($self->{'spec'}->{$key}) {
		Carp::croak("errorf(): Invalid key: $key");
	}
	unless ($format = $self->{'spec'}->{$key}->{'errors'}->{$type}) {
		Carp::croak("errorf(): Invalid error type: $type");
	}
	
	my %map = (
		key   => $key,
		value => $data,
	);


	$format =~ s{\[%\s*(\w+)\s*%\]}{ $map{$1} || '' }egs;
	
	return $self->error($key => $format);
}

=head1 AUTOLOAD

Data::CGIForm creates uses AUTOLOAD to create methods for the parameters 
in the spec.  These methods just call C<$form-E<gt>param($name)>, but it might prove
helpful/elegent.

=cut

sub AUTOLOAD {
	my $self = shift;

	our $AUTOLOAD;
	
	return if $AUTOLOAD =~ m/DESTROY/;
	$AUTOLOAD =~ m/^.*:(.*)$/;
	
	my $name = $1 || return;

	if ($self->{'spec'}->{$name}) {
		return $self->param($name, @_);
	} else {
		Carp::croak("Unknown method: $name");
	}
}

=head1 TODO

Do we want to test new values given to param() against the spec?

Make sure the user hasn't given dangerous equal_to pairs.

=head1 AUTHOR

Chris Reinhardt E<lt>ctriv@dyndns.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2002 Chris Reinhardt E<lt>ctriv@dyndns.orgE<gt>.  All rights 
reserved.  This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<perl(1)>, L<CGI(1)>.

=cut
	
	
1;
__END__

	
	
