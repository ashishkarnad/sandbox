### Welcome to the Sensu Enterprise sandbox!

This tutorial will get you up and running with Sensu Enterprise.

- Sandbox installation and setup
- Lesson 1: Creating monitoring events
- Lesson 2: Creating an event pipeline
- Lesson 3: Automating event production with the Sensu client

We'd love to hear your feedback!
While this sandbox is internal to Sensu, please add feedback to this [GoogleDoc](https://docs.google.com/document/d/1HSIkd3wO6ulAiya3aWB6MjCReYwLdkKIrY4_d4BkFfo/edit#).

---

## Set up the sandbox

**1. Install Vagrant and VirtualBox:**

- [Download Vagrant](https://www.vagrantup.com/downloads.html)
- [Download VirtualBox](https://www.virtualbox.org/wiki/Downloads)

**2. Download the sandbox:**

[Download from GitHub](https://github.com/sensu/sandbox/archive/master.zip) or clone the repository:

```
git clone https://github.com/sensu/sandbox
cd sandbox
```

**3. Sign up for a free trial of Sensu Enterprise**

https://sensu.io/pricing

```
cd enterprise
export SE_USER=REPLACEME
export SE_PASS=REPLACEME
```

**4. Start Vagrant:**

```
cd core
vagrant up
```

This can take up to five minutes.

**5. SSH into the sandbox:**

```
vagrant ssh
```

---

## Lesson \#1: Create a monitoring event

**1. Use the settings API to see Sensu's configuration:**

```
curl -s http://localhost:4567/settings | jq .
```

We can see that we have no active clients, and that Sensu is using RabbitMQ as the transport and Redis as the datastore.
We can see a lot of this same information in the [dashboard datacenter view](http://172.28.128.3:3000/#/datacenters).

```json
$ curl -s http://localhost:4567/settings | jq .
{
  "client": {},
  "sensu": {
    "spawn": {
      "limit": 12
    },
    "keepalives": {
      "thresholds": {
        "warning": 120,
        "critical": 180
      }
    }
  },
  "transport": {
    "name": "rabbitmq",
    "reconnect_on_error": true
  },
  "checks": {},
  "filters": {},
  "mutators": {},
  "handlers": {},
  "extensions": {},
  "rabbitmq": {
    "host": "127.0.0.1",
    "port": 5672,
    "vhost": "/sensu",
    "user": "sensu",
    "password": "REDACTED",
    "heartbeat": 30,
    "prefetch": 50
  },
  "redis": {
    "host": "127.0.0.1",
    "port": 6379
  }
}
```

**2. Use the results API to create an event that warns us that docs.sensu.io is loading slowly:**

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check-load-time",
  "output": "The docs site took 2.142 seconds to load.",
  "status": 1
}' \
http://localhost:4567/results
```

Since we're creating this event using the API, Sensu doesn't know where this information is coming from, so we use `source` to tell Sensu that we're using a remote source (called a proxy client).
The `status` tells Sensu that it's a warning-level event.
(Event status: 0 = OK, 1 = warning, 2 = critical)

We can use the events API to see the resulting event:

```
curl -s http://localhost:4567/events | jq .
```

_NOTE: The events API returns only warning (`"status": 1`) and critical (`"status": 2`) events._

This event data contains information about the part of your system the event came from (the `client` or `source`), the result of the check (including a `history` of recent `status` results), and the event itself (including the number of `occurrences`).

This event data tells us that this is a warning-level alert (`"status": 1`) from `check-load-time` on `docs.sensu.io`.
We can also see the alert and the client in the [dashboard event view](http://172.28.128.3:3000/#/events) and [client view](http://172.28.128.3:3000/#/clients).

```
[
  {
    "id": "188add2a-66aa-4fd8-aeed-bd16775e5f2d",
    "client": {
      "name": "docs.sensu.io",
      "address": "unknown",
      "subscriptions": [
        "client:docs.sensu.io"
      ],
      "keepalives": false,
      "version": "1.4.3",
      "timestamp": 1533923797,
      "type": "proxy"
    },
    "check": {
      "source": "docs.sensu.io",
      "name": "check-load-time",
      "output": "The docs site took 2.142 seconds to load.",
      "status": 1,
      "issued": 1533923797,
      "executed": 1533923797,
      "type": "standard",
      "origin": "sensu-api",
      "history": [
        "1"
      ],
      "total_state_change": 0
    },
    "occurrences": 1,
    "occurrences_watermark": 1,
    "last_ok": null,
    "action": "create",
    "timestamp": 1533923797,
    "last_state_change": 1533923797,
    "silenced": false,
    "silenced_by": []
  }
]
```

We created our first event!
Now let's resolve it by creating another event to represent the docs site loading quickly again:

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check-load-time",
  "output": "The docs site took 0.673 seconds to load.",
  "status": 0
}' \
http://localhost:4567/results
```

In the [dashboard client view](http://localhost:3000/#/clients), we can see that there are no active alerts and that the client is healthy.

_NOTE: The dashboard auto-refreshes every 10 seconds._

**4. Provide context about the systems you're monitoring with a discovery event:**

This time, use the clients API to create an event that gives Sensu some extra information about docs.sensu.io:

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "name": "docs.sensu.io",
  "address": "unknown",
  "environment": "production",
  "playbook": "https://github.com/sensu/success/wiki/How-to-Respond-to-a-Docs-Outage"
}' \
http://localhost:4567/clients
```

You can see the new `environment` and `playbook` attributes in the [dashboard client view](http://localhost:3000/#/clients) or using the clients API:

```
curl -s http://localhost:4567/clients | jq .
```

```
[
  {
    "name": "docs.sensu.io",
    "address": "unknown",
    "environment": "production",
    "playbook": "https://github.com/sensu/success/wiki/How-to-Respond-to-a-Docs-Outage",
    "keepalives": false,
    "version": "1.4.3",
    "timestamp": 1533924570,
    "subscriptions": [
      "client:docs.sensu.io"
    ]
  }
]
```

Nice work! You're now creating monitoring events with Sensu Enterprise.
In the next lesson, we'll act on these events by creating a pipeline.

---

## Lesson \#2: Create an event pipeline

Now that we know the sandbox is working properly, let's get to the fun stuff: creating a pipeline.
In this lesson, we'll create a pipeline to send event data to [Graphite](http://graphite.readthedocs.io/en/latest/).

**1. Configure the Sensu Enterprise Graphite integration**

Sensu Enterprise includes a built-in handler to send event data to Graphite.
Since we've already installed Graphite as part of the sandbox, all we need to do to create a Graphite pipeline is create a JSON configuration file:

```
sudo nano /etc/sensu/conf.d/handlers/graphite.json
```

```
{
  "graphite": {
    "host": "127.0.0.1",
    "port": 2003
  }
}
```

**2. Restart Sensu Enterprise**
We'll need to restart Sensu Enterprise whenever making a change to Sensu's JSON configuration files.

```
sudo systemctl reload sensu-enterprise
```

**3. Use the settings API to see our Graphite handler**

```
curl -s http://localhost:4567/settings | jq .
```

```
{
  "client": {},
  "sensu": {
    "spawn": {
      "limit": 12
    },
    "keepalives": {
      "thresholds": {
        "warning": 120,
        "critical": 180
      }
    }
  },
  "transport": {
    "name": "rabbitmq",
    "reconnect_on_error": true
  },
  "checks": {},
  "filters": {},
  "mutators": {},
  "handlers": {},
  "extensions": {},
  "rabbitmq": {
    "host": "127.0.0.1",
    "port": 5672,
    "vhost": "/sensu",
    "user": "sensu",
    "password": "REDACTED",
    "heartbeat": 30,
    "prefetch": 50
  },
  "redis": {
    "host": "127.0.0.1",
    "port": 6379
  },
  "graphite": {
    "host": "127.0.0.1",
    "port": 2003
  }
}
```

**4. Send an event to the pipeline:**

Let's use the results API to create a few events that represent varying load times for the docs site and assign them to the pipeline we created by adding `"handlers": ["graphite"]`.

_NOTE: Since the data from this event is going to Graphite, the `output` needs to be formatted as [Graphite plaintext](https://graphite.readthedocs.io/en/latest/feeding-carbon.html?highlight=plaintext#the-plaintext-protocol).
And since we're creating this event using the API, we need to add `date +%s` to include a timestamp._

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check-load-time",
  "output": "sensu-core-sandbox.curl_timings.time_total 0.594 '`date +%s`'",
  "status": 0,
  "type": "metric",
  "handlers": [
    "graphite"
  ]
}' \
http://localhost:4567/results && sleep 10s && curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check-load-time",
  "output": "sensu-core-sandbox.curl_timings.time_total 2.35 '`date +%s`'",
  "status": 1,
  "type": "metric",
  "handlers": [
    "graphite"
  ]
}' \
http://localhost:4567/results && sleep 10s && curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check-load-time",
  "output": "sensu-core-sandbox.curl_timings.time_total 3.041 '`date +%s`'",
  "status": 2,
  "type": "metric",
  "handlers": [
    "graphite"
  ]
}' \
http://localhost:4567/results && sleep 10s && curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check-load-time",
  "output": "sensu-core-sandbox.curl_timings.time_total 0.712 '`date +%s`'",
  "status": 0,
  "type": "metric",
  "handlers": [
    "graphite"
  ]
}' \
http://localhost:4567/results
```

After a few seconds, we'll be able to see the [event data in Graphite](http://172.28.128.4/?width=944&height=308&target=sensu-core-sandbox.curl_timings.time_total&from=-10minutes).

**5. Add a filter to the pipeline**

Let's say we've set up a development instance of docs.sensu.io that we also want to monitor, but we only want our Graphite graph to contain data from production.
To do this, we'll add a filter to our Graphite pipeline by creating a JSON configuration file:

```
sudo nano /etc/sensu/conf.d/filters/only-production.json
```

```
{
  "filters": {
    "only-production": {
      "attributes": {
        "check": {
          "environment": "production"
        }
      }
    }
  }
}
```

This tells Sensu to check the event data (within the `check` scope) and only allow events with `"environment": "production"` to continue through the pipeline.

Now we'll hook up the `only-production` filter to the `graphite` handler by adding `"filters": ["only-production"]` to the handler configuration:

```
sudo nano /etc/sensu/conf.d/handlers/graphite.json
```

```
{
  "graphite": {
    "host": "127.0.0.1",
    "port": 2003,
    "filters": ["only-production"]
  }
}
```

**6. Restart Sensu Enteprirse**

```
sudo systemctl reload sensu-enterprise
```

**7. Use the settings API to see the only-production filter:**

```
curl -s http://localhost:4567/settings | jq .
```

```
{
  "client": {},
  "sensu": {
    "spawn": {
      "limit": 12
    },
    "keepalives": {
      "thresholds": {
        "warning": 120,
        "critical": 180
      }
    }
  },
  "transport": {
    "name": "rabbitmq",
    "reconnect_on_error": true
  },
  "checks": {},
  "filters": {
    "only-production": {
      "attributes": {
        "check": {
          "environment": "production"
        }
      }
    }
  },
  "mutators": {},
  "handlers": {},
  "extensions": {},
  "rabbitmq": {
    "host": "127.0.0.1",
    "port": 5672,
    "vhost": "/sensu",
    "user": "sensu",
    "password": "REDACTED",
    "heartbeat": 30,
    "prefetch": 50
  },
  "redis": {
    "host": "127.0.0.1",
    "port": 6379
  },
  "graphite": {
    "host": "127.0.0.1",
    "port": 2003,
    "filters": [
      "only-production"
    ]
  }
}
```

**8. Send events to the filtered pipeline**

Now any events we create must include `"environment": "production"` in order to be handled by the Graphite pipeline.
Let's test it out by creating an event without an `environment` attribute:

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check-load-time",
  "output": "sensu-core-sandbox.curl_timings.time_total 2.012 '`date +%s`'",
  "status": 1,
  "type": "metric",
  "handlers": [
    "graphite"
  ]
}' \
http://localhost:4567/results
```

We shouldn't see anything in Graphite, but we should see an alert in the dashboard events view.

Now let's create a production event:

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check-load-time",
  "output": "sensu-core-sandbox.curl_timings.time_total 0.551 '`date +%s`'",
  "status": 0,
  "environment": "production",
  "type": "metric",
  "handlers": [
    "graphite"
  ]
}' \
http://localhost:4567/results
```

And make sure it appears in Graphite.

Great work. You've created your first Sensu pipeline!
In the next lesson, we'll tap into the power of Sensu by adding a Sensu client to automate event production.
