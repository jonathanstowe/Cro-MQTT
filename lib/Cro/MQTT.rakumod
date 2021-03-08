use Cro::Service;

class Cro::MQTT does Cro::Service {
    use Cro::Message;
    use Cro::Source;
    use Cro::Types;
    use Cro::Connection;
    use Cro::Connector;
    use Cro::Transform;
    use Cro::Sink;
    use Cro;
    use MQTT::Client;


    subset MQTTClient of Mu where *.^can('connect') && *.^can('subscribe');

    class ClientConnection { ... }

    class ClientConnection does Cro::Connection {
        has MQTTClient $.mqtt-client is required handles <subscribe>;

        method produces() { }

        method incoming() {
            supply {
                emit self;
            }
        }
    }

    class BrokerConnection does Cro::Source {
        has Str        $.server            = 'localhost';
        has Cro::Port  $.port              = 1883;
        has Str        $.client-identifier = $*PROGRAM.basename ~ $*PID;
        has MQTTClient $.mqtt-client;

        submethod TWEAK {
            $!mqtt-client //= MQTT::Client.new(:$!server, :$!port, :$!client-identifier);
        }

        method produces() { ClientConnection }

        method incoming( ) {
            supply {
                whenever $!mqtt-client.connect {
                    emit ClientConnection.new(:$!mqtt-client);
                }
                whenever Promise.new {
                }
            }
        }
    }


    class Message does Cro::Message {
        has Str     $.topic;
        has Buf     $.message;
        has         $.retain;
    }

    class Subscription does Cro::Transform {
        has Str $.topic is required;

        method consumes() { ClientConnection }
        method produces() { Message }

        method transformer( Supply:D $incoming --> Supply ) {
            supply {
                whenever $incoming -> $connection {
                    whenever $connection.subscribe($!topic) -> %message {
                        emit Message.new(|%message);
                    }
                }
            }

        }
    }

    class SubscriptionList does Cro::Sink {
        has Cro::CompositeSink @.subscriptions;

        method consumes() { ClientConnection }

        method sinker ( Supply:D $incoming --> Supply ) {
            my @sinks = @!subscriptions>>.sinker($incoming.share);
            Supply.merge(@sinks);
        }
    }


    class Consumer does Cro::Sink {

        has &.consume is required;

        method consumes() { Message }

        method sinker ( Supply:D $messages ) {
            supply {
                whenever $messages -> $message {
                    &!consume.($message);
                }
            }
        }

    }

    class ConsumerList does Cro::Sink {
        has Consumer @.consumers;
        method consumes { Message }
        method sinker( Supply:D $messages ) {
            my @sinks = @!consumers>>.sinker($messages.share);
            Supply.merge(@sinks);
        }
    }

    submethod BUILD(SubscriptionList :$subscriptions!, BrokerConnection :$broker-connection, Str :$server = 'localhost', Cro::Port :$port = 1883, Str :$client-identifier = $*PROGRAM.basename ~ $*PID) {
        @!components.push: $broker-connection // BrokerConnection.new(:$server, :$port, :$client-identifier);
        say @!components;
        @!components.push: $subscriptions;
    }

    sub subscriptions(&subscriber-definition --> SubscriptionList) is export {
        my $*SUBSCRIPTION-LIST = SubscriptionList.new;
        subscriber-definition();
        $*SUBSCRIPTION-LIST;
    }

    sub subscribe( Str $topic, &consumer-definition) is export {
        my $subscription = Subscription.new(:$topic);
        my $*CONSUMER-LIST = ConsumerList.new;
        consumer-definition();
        $*SUBSCRIPTION-LIST.subscriptions.push: Cro.compose(
            $subscription,
            $*CONSUMER-LIST
        );
    }

    sub consume( &consume ) is export {
        $*CONSUMER-LIST.consumers.push: Consumer.new( :&consume );
    }
}
