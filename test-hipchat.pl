use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use MIME::Base64;
use URI::Escape;
my $credentials = encode_base64('USERNAME:PASSWORD');
my %params = (
        query => 'group:"GROUP NAME" status:new status:open status:pending order_by:updated_at sort:asc',
        sort_by => 'updated_at',
        sort_order => 'desc'        # from oldest to newest
);
my $url = URI->new('https://xxxx.zendesk.com/api/v2/search.json');
$url->query_form(%params);
while ($url) {
        my $ua = LWP::UserAgent->new(ssl_opts =>{ verify_hostname => 0 });
        my $response = $ua->get($url, 'Authorization' => "Basic $credentials");
        die 'Status: ' . $response->code . '  ' . $response->message
        unless ($response->is_success);
        # Print the subject of each ticket in the results
        my $data = decode_json($response->content);
        my @resul = @{ $data->{'results'} };
        foreach my $results ( @resul ) {
                my $filename = "cases.txt";
                        open(my $fh, '>>', "/home/rthomas/sas-case/$filename") or die "Could not open file '$filename' $!";
                        print $fh $results->{"id"};
                        print $fh "</br>";
                        print $fh " <b>Subject:</b> " . $results->{"subject"};
                 if (defined $results->{"assignee_id"}) {
                       if ($results->{"assignee_id"} == "xxxx") { 
                                print $fh " lelUser xxxx";
                                print $fh " lelGroup " . $results->{"group_id"};

                        }
                       elsif ($results->{"assignee_id"} == "xxxxx") {
                                print $fh " lelUser xxxxx";
                                print $fh " lelGroup " . $results->{"group_id"};

                        }
                       elsif ($results->{"assignee_id"} == "xxxxx") {
                                print $fh " lelUser xxxxx";
                                print $fh " lelGroup " . $results->{"group_id"};

                        }
                        elsif ($results->{"assignee_id"} == "xxxxx") {
                                print $fh " lelUser xxxxx";
                                print $fh " lelGroup " . $results->{"group_id"};


                        }
                        elsif ($results->{"assignee_id"} == "xxxxx") {
                                print $fh " lelUser xxxxx";
                                print $fh " lelGroup " . $results->{"group_id"};


                        }
                        elsif ($results->{"assignee_id"} == "xxxxx") {
                                print $fh " lelUser xxxxx";
                                print $fh " lelGroup " . $results->{"group_id"};


                        }
                        elsif ($results->{"assignee_id"} == "xxxxx") {
                                print $fh " lelUser xxxxx";
                                print $fh " lelGroup " . $results->{"group_id"};


                        }
                        elsif ($results->{"assignee_id"} == "xxxxxx") {
                                print $fh " lelUser xxxxx";
                                print $fh " lelGroup " . $results->{"group_id"};


                        }
                        elsif ($results->{"assignee_id"} == "xxxxx") {
                                print $fh " lelUser xxxxx";
                                print $fh " lelGroup " . $results->{"group_id"};


                        }
                        elsif ($results->{"assignee_id"} == "xxxxx") {                                                                            neth
                                print $fh " lelUser xxxxx";
                                print $fh " lelGroup " . $results->{"group_id"};


                        }
                        elsif ($results->{"assignee_id"} == "xxxxx") { 
                                print $fh " lelUser xxxxx";
                                print $fh " lelGroup " . $results->{"group_id"};


                        }
                        elsif ($results->{"assignee_id"} == "xxxxx") {
                                print $fh " lelUser xxxxx";
                                print $fh " lelGroup " . $results->{"group_id"};


                        }
                        elsif ($results->{"assignee_id"} == "xxxxx") {
                                print $fh " lelUser xxxxx";
                                print $fh " lelGroup " . $results->{"group_id"};

                        }
                        else {
                        print $fh " - SmolPeri";
                        print $fh " lelUser 0";
                        print $fh " lelGroup " . $results->{"group_id"};
                        }
                }
                else {
                        print $fh " - SmolPeri";
                        print $fh " lelUser 0";
                        print $fh " lelGroup " . $results->{"group_id"};

                      }
                        print $fh "\n";
                        close $fh;
                        #print "\n";

        }
          if (defined $data->{'next_page'}){
                                $url = $data->{'next_page'};}
                        else{
                                $url = '';}
                        #print "\n";
                }
