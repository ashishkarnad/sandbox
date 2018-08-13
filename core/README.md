### Welcome to the Sensu Core sandbox!

This tutorial will get you up and running with Sensu.

- Sandbox installation and setup
- Lesson 1: Creating monitoring events
- Lesson 2: Creating an event pipeline
- Lesson 3: Automating event production with the Sensu client

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

**3. Start Vagrant:**

```
cd core
vagrant up
```

This can take up to five minutes.

**4. SSH into the sandbox:**

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

This event data contains information about part of your system the event came from (the `client` or `source`), the result of the check (including a `history` of recent `status` results), and the event itself (including the number of `occurrences`).

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

This time, use the clients API to create an event that gives Sensu some extra information about docs.sensu.io

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

Nice work! You're now creating monitoring events with Sensu.
In the next lesson, we'll act on these events by creating a pipeline.
