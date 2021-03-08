# Cro::MQTT

A Cro Service that consumes from MQTT topics


## Synopsis

```
use Cro::MQTT;

my $subscriptions = subscriptions {
    subscribe 'hello-world', {
        consume -> $m { say "GOT HELLO WORLD ", $m.message.decode }
    }
    subscribe 'another-world', {
        consume -> $m { say "GOT ANOTHER WORLD ", $m.message.decode }
    }
}

my $service = Cro::MQTT.new(
    port => 1883,
    :$subscriptions
);

$service.start;

react {
    whenever signal(SIGINT) {
        $service.stop;
        done;
    }
}
```

## Description

This provides a [Cro](https://cro.services/) Service that describes consumers of [MQTT](https://mqtt.org/) messages.  

The above is basically just a sugar coating of 

```
use Cro;
use Cro::MQTT;


my $service = Cro.compose(
    Cro::MQTT::BrokerConnection.new(port => 1883),
    Cro::MQTT::SubscriptionList.new( subscriptions => (
            Cro.compose(
                Cro::MQTT::Subscription.new(topic => 'hello-world'),
                    Cro::MQTT::ConsumerList.new( consumers => (
                        Cro::MQTT::Consumer.new( consume => -> $m { say "GOT HELLO WORLD ", $m.message.decode }),
                    )
                )
            ),
            Cro.compose(
                Cro::MQTT::Subscription.new(topic => 'another-world'),
                    Cro::MQTT::ConsumerList.new( consumers => (
                        Cro::MQTT::Consumer.new( consume => -> $m { say "GOT ANOTHER WORLD", $m.message.decode }),
                    )
                )
            )
        )
    ),
);

$service.start;

react {
		whenever signal(SIGINT) {
			$service.stop;
            done;
		}
}
```

And the very simplest long hand service might be :

```
use Cro::MQTT;


my $service = Cro.compose(
    Cro::MQTT::BrokerConnection.new(port => 1883),
    Cro::MQTT::Subscription.new(topic => 'hello-world'),
    Cro::MQTT::Consumer.new( consume => -> $m { say "GOT HELLO WORLD ", $m.message.decode }),
);

$service.start;

react {
		whenever signal(SIGINT) {
			$service.stop;
            done;
		}
}
```

In `Cro` terms the `BrokerConnection` is a `Source` producing `ClientConnection` objects corresponding to an established connection to a broker,
`Subscription` is a `Transform` that consumes a `ClientConnection` and produces `Message` objects corresponding to MQTT messages published to the
specified topic, and `Consumer` is a `Sink` which consumes `Message` objects and executes the specified code with the message as an argument. The
`SubscriptionList` and `ConsumerList` are sinks that aggregate the other components in order to faciliate having multiple subscriptions on a broker
connection and multiple consumers on a subscription respectively.

Because all of this is a standard `Cro` pipeline additional components can be composed to provide application specific functionality, such as a
`Transform` that may route messages based on their content or create different types of `Message` objects for example.

Currently no explicit provision is made for the publishing of messages to topics, but the underlying `MQTT::Client` object is exposed from the
`BrokerConnection` as `mqtt-client` and the `BrokerConnection` can be supplied to the constructor of the `Cro::MQTT` so you can do something like:

```
use Cro::MQTT;

my $broker-connection = Cro::MQTT::BrokerConnection.new;

my $subscriptions = subscriptions {
    subscribe 'hello-world', {
        consume -> $m { $broker-connection.mqtt-client.publish('another-world', $m.message }
    }
}

my $service = Cro::MQTT.new(
    :$broker-connection,
    :$subscriptions
);

```

If you already have a `MQTT:Client` object available then you can pass that to the `BrokerConnection` constructor, however as it currently stands
it should not have `connect` called on it as that will happen as soon as the `start` is called on the service and the `connect` isn't idempotent,
such a new attempt to connect will be made which may result in the previous connection being disconnected.


## Installation

Assuming that you have a working Rakudo installation you should be able to install this with *zef* :

   zef install Cro::MQTT

## Support

I wrote this mainly to explore how best to implement a `Cro` Service over an existing messaging API, and semi-randomly picked on MQTT because
there is an existing module supporting the protocol with a simple enough interface so as not get bogged down in the details.  Hopefully it will
prove useful to somebody else, if only as an illustration of how to do something similar for another messaging API.

I've tested against ActiveMQ and mosquitto and they seem to work, and I've tested against IBM MQ and it doesn't appear to work at all, but as
that is a relatively complex piece of software I may have totally failed to configure it correctly.

In theory you could use a different client library than [MQTT::Client](https://github.com/Juerd/p6-mqtt) as long as it provides a similar interface
(that is it has a `connect` method that returns a `Promise` and a `subscribe` method that returns a supply of `Hash` describing the messages,) the
actual value being _duck typed_ on those methods that are used.

If you have any suggestions or changes for the module please make an issue or pull request at [Github](https://github.com/jonathanstowe/Cro-MQTT/).
I've turned on "Discussions" if you want to discuss the design more generally.

# Licence & Copyright

This is free software, please see the [LICENCE](LICENCE) file in the distribution for details.

© Jonathan Stowe 2021
