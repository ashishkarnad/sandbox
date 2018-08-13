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

**4. Provide context about the systems you're monitoring with a discovery event**

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

Nice work! You're now creating monitoring events with Sensu.
In the next lesson, we'll act on these events by creating a pipeline.

---

## Lesson \#2: Create an event pipeline

Now that we know the sandbox is working properly, let's get to the fun stuff: creating a pipeline.
In this lesson, we'll create a pipeline to send events to Slack.
If you'd rather not create a Slack account, check out the [Sensu Enterprise sandbox tutorial](../enterprise).

**1. Install the Sensu Slack Plugin**

Sensu Plugins are open-source collections of Sensu building blocks shared by the Sensu Community.
In this lesson, we'll be using the [Sensu Slack Plugin's](https://github.com/sensu-plugins/sensu-plugins-slack) `handler-slack.rb` script to create our pipeline.
You can find this and more [Sensu Plugins on GitHub](https://github.com/sensu-plugins).

First we'll need to install the plugin:

```
sudo sensu-install -p sensu-plugins-graphite
```

_PRO TIP: Check out Sensu Enterprise's [built-in integrations](https://docs.sensu.io/sensu-enterprise/3.1/built-in-handlers), including Slack, email, IRC, and more._

**2. Get your Slack webhook URL**

If you're already an admin of a Slack, visit https://{your workspace}.slack.com/services/new/incoming-webhook and follow the steps to add the Incoming WebHooks integration, choose a channel, and save the settings.
(If you're not yet a Slack admin, start [here](https://slack.com/get-started#create) to create a new workspace.)
You'll see your webhook URL under Integration Settings.

**3. Create a handler to send event data to Slack**

To set up our Slack pipeline, we'll create a handler configuration file that points to the Sensu Slack Plugin and specifies your webhook URL:

```
sudo nano /etc/sensu/conf.d/handlers/slack.json
```

```
{
  "handlers": {
    "slack": {
      "type": "pipe",
      "command": "handler-slack.rb"
    }
  },
  "slack": {
    "webhook_url": "REPLACEME"
  }
}
```

**4. Restart the Sensu server and API**

We'll need to restart the Sensu server and API whenever making a change to Sensu's JSON configuration files.

```
sudo systemctl restart sensu-{server,api}
```

**5. Use the settings API to see our Slack handler**

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
  "handlers": {
    "slack": {
      "type": "pipe",
      "command": "handler-slack.rb"
    }
  },
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
  "slack": {
    "webhook_url": "https://hooks.slack.com/services/xxxxxxxx/xxxxxxxxxxx"
  }
}
```

**6. Send an event to the pipeline:**

Let's use the results API to create an event and send it to our pipeline by adding `"handlers": ["slack"]`.

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check-load-time",
  "output": "Nice! The docs site took 0.516 seconds to load.",
  "status": 0,
  "handlers": ["slack"]
}' \
http://localhost:4567/results
```

Check out the Slack channel you configured when creating the webhook, and you should see a message from Sensu.

**7. Add a filter to the pipeline**

This is great, but we only really want to be notified by Slack when there's a critical alert.
To do this, we'll create a filter using a JSON configuration file:

```
sudo nano /etc/sensu/conf.d/filters/only-critical.json
```

```
{
  "filters": {
    "only-critical": {
      "attributes": {
        "check": {
          "status": 2
        }
      }
    }
  }
}
```

This tells Sensu to check the event data (within the `check` scope) and only allow events with `"status": 2` to continue through the pipeline.

But we're not done yet.
Now we need to hook up the `only-critical` filter to the pipeline by adding `"filters": ["only-critical"]` to the `slack.json` handler configuration.

```
sudo nano /etc/sensu/conf.d/handlers/slack.json
```

```
{
  "handlers": {
    "slack": {
      "type": "pipe",
      "command": "handler-slack.rb",
      "filters": ["only-critical"]
    }
  },
  "slack": {
    "webhook_url": "REPLACEME"
  }
}
```

**8. Restart the Sensu server and API:**

```
sudo systemctl restart sensu-{server,api}
```

**9. Use the settings API to see the filter we just created:**

```
curl -s http://localhost:4567/settings | jq .
```

```

```

If you don't get a response from the API here, check for invalid JSON in `/etc/sensu/conf.d/handlers/slack.json` and `/etc/sensu/conf.d/filters/only-critical.json`.

**10. Send events to the filtered pipeline**

Now Sensu will only pass critical events through to Slack.
Let's test it by sending a warning:

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check-load-time",
  "output": "Not great. The docs site took 1.780 seconds to load.",
  "status": 1,
  "handlers": ["slack"]
}' \
http://localhost:4567/results
```

We shouldn't see anything in Slack, but we should see an alert in the [dashboard events view](http://172.28.128.3:3000/#/events).

Now let's create a critical alert:

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check-load-time",
  "output": "Something's up. The docs site took 4.272 seconds to load.",
  "status": 2,
  "handlers": ["slack"]
}' \
http://localhost:4567/results
```

And we should see it in Slack!
You can customize your Slack messages using the [Sensu Slack Plugin handler attributes](https://github.com/sensu-plugins/sensu-plugins-slack#usage-for-handler-slackrb).

Great work. You've created your first Sensu pipeline!
In the next lesson, we'll tap into the power of Sensu by adding a Sensu client to automate event production.
