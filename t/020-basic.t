#!/usr/bin/env raku

use Test;
use Cro::MQTT;
use Cro;


class Test::Client {

	has Supply $!supply;

    has @.topics = <hello-world another-world>;

   method connect( --> Promise ) {
        $!supply = supply {
            whenever Supply.interval(0.5) {
                emit { topic => @!topics.pick, message => Buf(DateTime.now.Str.encode) };
            }
        }
        Promise.kept: True;
    }

    method subscribe(Str $topic --> Supply) {
        $!supply.grep(*<topic> eq $topic).share
    }

}

my $mqtt-client = Test::Client.new;

my $broker-connection = Cro::MQTT::BrokerConnection.new(:$mqtt-client);

my $channel = Channel.new;

my $service = Cro.compose(
    $broker-connection,
    Cro::MQTT::Subscription.new(topic => 'hello-world'),
    Cro::MQTT::Consumer.new( consume => -> $m { $channel.send: $m }),
);

$service.start;

ok my $m = $channel.receive, "got a message in the consumer";
is $m.topic, 'hello-world', "and it is the right topic";

$service.stop;

done-testing();

# vim: ft=raku
