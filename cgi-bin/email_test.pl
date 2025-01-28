use strict;
use warnings;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP qw();
use Email::Simple;
use Email::Simple::Creator; # For creating the email
print "1\n";
# Create the email
my $email = Email::Simple->create(
header => [
To => '"Recipient Name" <recipient@fredhutch.org>',
From => '"Sender Name" <sender@fredhutch.org>',
#To => 'wdeng2@fredhutch.org',
#From => 'integrationsites@fredhutch.org',
Subject => 'Test Email',
],
body => "This is a test email sent via SMTP using Perl.",
);
print "2\n";
# Configure the SMTP transport
my $transport = Email::Sender::Transport::SMTP->new({
host => 'mx.fhcrc.org', # Your SMTP server address
port => 25, # Common ports are 25, 465, or 587
ssl => 0, # Set to 1 if SSL is required
# sasl_username => 'your_username', # Your SMTP username
#sasl_password => 'your_password', # Your SMTP password
});
print "3\n";
# Send the email
eval {
sendmail($email, { transport => $transport });
print "Email sent successfully!\n";
};
if ($@) {
die "Failed to send email: $@\n";
}
print "4\n";
