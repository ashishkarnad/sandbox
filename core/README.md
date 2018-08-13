### Welcome to the Sensu Core sandbox!

This tutorial will get you up and running with Sensu.

- [Set up the sandbox](#set-up-the-sandbox)
- [Lesson \#1: Create a monitoring event](#lesson-1-create-a-monitoring-event)
- [Lesson \#2: Create an event pipeline](#lesson-2-create-an-event-pipeline)
- [Lesson \#3: Automate event production with the Sensu client](#lesson-3-automate-event-production-with-the-sensu-client)

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
sudo sensu-install -p sensu-plugins-slack
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

**4. Restart the Sensu server and API:**

We'll need to restart the Sensu server and API whenever making a change to Sensu's JSON configuration files.

```
sudo systemctl restart sensu-{server,api}
```

**5. Use the settings API to see our Slack handler:**

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
  "output": "Not great. The docs site took 1.721 seconds to load.",
  "status": 1,
  "handlers": ["slack"]
}' \
http://localhost:4567/results
```

Check out the Slack channel you configured when creating the webhook, and you should see a message from Sensu.

Let's send another event to resolve the warning:

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

**7. Add a filter to the pipeline**

This is great, but let's say we only really want to be notified by Slack when there's a critical alert.
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
      "filters": ["only-critical"],
      "command": "handler-slack.rb"
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
    "only-critical": {
      "attributes": {
        "check": {
          "status": 2
        }
      }
    }
  },
  "mutators": {},
  "handlers": {
    "slack": {
      "type": "pipe",
        "filters": [
          "only-critical"
        ],
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

If you don't get a response from the API here, check for invalid JSON in `/etc/sensu/conf.d/handlers/slack.json` and `/etc/sensu/conf.d/filters/only-critical.json`.

**10. Send events to the filtered pipeline**

Now Sensu will only pass critical events through to Slack.
Let's test it by sending a warning:

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check-load-time",
  "output": "Not great. The docs site took 1.990 seconds to load.",
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
  "output": "Something is up. The docs site took 4.272 seconds to load.",
  "status": 2,
  "handlers": ["slack"]
}' \
http://localhost:4567/results
```

And we should see it in Slack!
You can customize your Slack messages using the [Sensu Slack Plugin handler attributes](https://github.com/sensu-plugins/sensu-plugins-slack#usage-for-handler-slackrb).

Before we go, let's create a resolution event.
(It should not appear in Slack, but we should see the results in the [dashboard client view](http://172.28.128.3:3000/#/clients).)

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check-load-time",
  "output": "Nice! The docs site took 0.608 seconds to load.",
  "status": 0,
  "handlers": ["slack"]
}' \
http://localhost:4567/results
```

Great work. You've created your first Sensu pipeline!
In the next lesson, we'll tap into the power of Sensu by adding a Sensu client to automate event production.

---

## Lesson \#3: Automate event production with the Sensu client
So far we've used only the Sensu server and API, but in this lesson, we'll add the Sensu client and create a check to produce events automatically.
Instead of using Slack, we'll use [Graphite](http://graphite.readthedocs.io/en/latest/) to store event data.

**1. Create a Graphite pipeline**

This is review from the last lesson.
First, we'll install the Sensu Graphite Plugin:

```
sudo sensu-install -p sensu-plugins-graphite
```

Then we'll create the pipeline using a handler configuration file:

```
sudo nano /etc/sensu/conf.d/handlers/graphite_tcp.json
```

```
{
  "handlers": {
    "graphite_tcp": {
      "type": "tcp",
      "socket": {
        "host":"127.0.0.1",
        "port":2003
      }
    }
  }
}
```

Restart the Sensu server and API:

```
sudo systemctl restart sensu-{server,api}
```

And finally check out work using the settings API:

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
    "only-critical": {
      "attributes": {
        "check": {
          "status": 2
        }
      }
    }
  },
  "mutators": {},
  "handlers": {
    "slack": {
      "type": "pipe",
      "filters": [
        "only-critical"
      ],
      "command": "handler-slack.rb"
    },
    "graphite_tcp": {
      "type": "tcp",
      "socket": {
        "host": "127.0.0.1",
        "port": 2003
      }
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

**2. Start the Sensu client:**

Now that we have our Graphite pipeline set up, let's start the Sensu client:

```
sudo systemctl start sensu-client
```

We can see the client start up using the clients API:

```
curl -s http://localhost:4567/clients | jq .
```

```
[
  {
    "name": "sensu-core-sandbox",
    "address": "10.0.2.15",
    "subscriptions": [
      "client:sensu-core-sandbox"
    ],
    "version": "1.4.3",
    "timestamp": 1534100148
  },
  {
    "name": "docs.sensu.io",
    "address": "unknown",
    "environment": "production",
    "playbook": "https://github.com/sensu/success/wiki/How-to-Respond-to-a-Docs-Outage",
    "keepalives": false,
    "version": "1.4.3",
    "timestamp": 1534098558,
    "subscriptions": [
      "client:docs.sensu.io"
    ]
  }
]
```

In the [dashboard client view](http://172.28.128.3:3000/#/clients), note that the client running in the sandbox executes keepalive checks while the `docs.sensu.io` proxy client cannot.

_NOTE: The client gets its name from the `sensu.name` attributed configured as part of sandbox setup.
You can change the client name using `sudo nano /etc/sensu/uchiwa.json`_

**3. Add a client subscription**

Clients run the set of checks defined by their `subscriptions`.
Use a JSON configuration file to assign our new client to run checks with the `sandbox-testing` subscription using `"subscriptions": ["sandbox-testing"]`:

```
sudo nano /etc/sensu/conf.d/client.json
```

```
{
  "client": {
    "name": "sensu-core-sandbox",
    "subscriptions": ["sandbox-testing"]
  }
}
```

**4. Restart the Sensu client, server, and API:**

```
sudo systemctl restart sensu-{client,server,api}
```

**5. Use the clients API to make sure the subscription is assigned to the client:**

```
curl -s http://localhost:4567/clients | jq .
```

```
[
  {
    "name": "sensu-core-sandbox",
    "address": "10.0.2.15",
    "subscriptions": [
      "sandbox-testing",
      "client:sensu-core-sandbox"
    ],
    "version": "1.4.3",
    "timestamp": 1534100148
  },
  {
    "name": "docs.sensu.io",
    "address": "unknown",
    "environment": "production",
    "playbook": "https://github.com/sensu/success/wiki/How-to-Respond-to-a-Docs-Outage",
    "keepalives": false,
    "version": "1.4.3",
    "timestamp": 1534098558,
    "subscriptions": [
      "client:docs.sensu.io"
    ]
  }
]
```

If you don't see the new subscription, wait a few seconds and try the settings API again.

**6. Install the Sensu HTTP Plugin to check the load time for docs.sensu.io:**

Now we want to create a check that will automatically check the load time for the docs site in place of us creating events manually using the API.
To do this, we'll install the [Sensu HTTP Plugin](https://github.com/sensu-plugins/sensu-plugins-http).

```
sudo sensu-install -p sensu-plugins-http
```

From the Sensu HTTP Plugin, we'll be using the `metrics-curl.rb` script.
We can test its output using:

```
/opt/sensu/embedded/bin/metrics-curl.rb -u https://docs.sensu.io
```

```
sensu-core-sandbox.curl_timings.time_total 0.597 1534193106
sensu-core-sandbox.curl_timings.time_namelookup 0.065 1534193106
sensu-core-sandbox.curl_timings.time_connect 0.147 1534193106
sensu-core-sandbox.curl_timings.time_pretransfer 0.418 1534193106
sensu-core-sandbox.curl_timings.time_redirect 0.000 1534193106
sensu-core-sandbox.curl_timings.time_starttransfer 0.597 1534193106
sensu-core-sandbox.curl_timings.http_code 200 1534193106
```

**7. Create a check that gets the load time metrics for docs.sensu.io**

Use a JSON configuration file to create a check that runs `metrics-curl.rb` every 10 seconds on all clients with the `sandbox-testing` subscription:

```
sudo nano /etc/sensu/conf.d/checks/check-load-time.json
```

```
{
  "checks": {
    "check-load-time": {
      "source": "docs.sensu.io",
      "command": "metrics-curl.rb -u https://docs.sensu.io",
      "interval": 10,
      "subscribers": ["sandbox-testing"],
      "type": "metric",
      "handlers": ["graphite_tcp"]
    }
  }
}
```

Note that `"type": "metric"` ensures that Sensu will handle every event, not just warnings and critical alerts.

**8. Restart the Sensu client, server, and API**

```
sudo systemctl restart sensu-{client,server,api}
```

**9. Use the settings API to make sure the check has been created:**

```
curl -s http://localhost:4567/settings | jq .
```

```
{
  "client": {
    "name": "sensu-core-sandbox",
    "subscriptions": [
      "sandbox-testing"
    ]
  },
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
  "checks": {
    "check-load-time": {
      "source": "docs.sensu.io",
      "command": "metrics-curl.rb -u https://docs.sensu.io",
      "interval": 10,
      "subscribers": [
        "sandbox-testing"
      ],
      "type": "metric",
      "handlers": [
        "graphite_tcp"
      ]
    }
  },
  "filters": {
    "only-critical": {
      "attributes": {
        "check": {
          "status": 2
        }
      }
    }
  },
  "mutators": {},
  "handlers": {
    "slack": {
      "type": "pipe",
      "filters": [
        "only-critical"
      ],
      "command": "handler-slack.rb"
    },
    "graphite_tcp": {
      "type": "tcp",
      "socket": {
        "host": "127.0.0.1",
        "port": 2003
      }
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

**10. See the automated events in [Graphite](http://172.28.128.3/?width=944&height=308&target=sensu-core-sandbox.curl_timings.time_total&from=-10minutes) and the [dashboard client view](http://172.28.128.4:3000/#/clients):**

**11. Automate CPU usage events for the sandbox**

Now that we have a client and subscription set up, we can easily add more checks.
For example, let's say we want to monitor the disk usage on the sandbox.

First, install the plugin:

```
sudo sensu-install -p sensu-plugins-disk-checks
```

And test it:

```
/opt/sensu/embedded/bin/metrics-disk-usage.rb
```

```
sensu-core-sandbox.disk_usage.root.used 2235 1534191189
sensu-core-sandbox.disk_usage.root.avail 39714 1534191189
sensu-core-sandbox.disk_usage.root.used_percentage 6 1534191189
sensu-core-sandbox.disk_usage.root.dev.used 0 1534191189
sensu-core-sandbox.disk_usage.root.dev.avail 910 1534191189
sensu-core-sandbox.disk_usage.root.dev.used_percentage 0 1534191189
sensu-core-sandbox.disk_usage.root.run.used 9 1534191189
sensu-core-sandbox.disk_usage.root.run.avail 912 1534191189
sensu-core-sandbox.disk_usage.root.run.used_percentage 1 1534191189
sensu-core-sandbox.disk_usage.root.home.used 33 1534191189
sensu-core-sandbox.disk_usage.root.home.avail 20446 1534191189
sensu-core-sandbox.disk_usage.root.home.used_percentage 1 1534191189
sensu-core-sandbox.disk_usage.root.boot.used 171 1534191189
sensu-core-sandbox.disk_usage.root.boot.avail 844 1534191189
sensu-core-sandbox.disk_usage.root.boot.used_percentage 17 1534191189
sensu-core-sandbox.disk_usage.root.vagrant.used 51087 1534191189
sensu-core-sandbox.disk_usage.root.vagrant.avail 425716 1534191189
sensu-core-sandbox.disk_usage.root.vagrant.used_percentage 11 1534191189
```

Then create the check using a JSON configuration file, assigning it to the `sandbox-testing` subscription and the `graphite_tcp` pipeline:

```
sudo nano /etc/sensu/conf.d/checks/check-disk-usage.json
```

```
{
  "checks": {
    "check-disk-usage": {
      "command": "/opt/sensu/embedded/bin/metrics-disk-usage.rb",
      "interval": 10,
      "subscribers": ["sandbox-testing"],
      "type": "metric",
      "handlers": ["graphite_tcp"]
    }
  }
}
```

Finally, restart all the things:

```
sudo systemctl restart sensu-{client,server,api}
```

And you should see it working in the dashboard client view and via the settings API:

```
curl -s http://localhost:4567/settings | jq .
```

```
{
  "client": {
    "name": "sensu-core-sandbox",
    "subscriptions": [
      "sandbox-testing"
    ]
  },
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
  "checks": {
    "check-load-time": {
      "source": "docs.sensu.io",
      "command": "metrics-curl.rb -u https://docs.sensu.io",
      "interval": 10,
      "subscribers": [
        "sandbox-testing"
      ],
      "type": "metric",
      "handlers": [
        "graphite_tcp"
      ]
    },
    "check-disk-usage": {
      "command": "/opt/sensu/embedded/bin/metrics-disk-usage.rb",
      "interval": 10,
      "subscribers": [
        "sandbox-testing"
      ],
      "type": "metric",
      "handlers": [
        "graphite_tcp"
      ]
    }
  },
  "filters": {
    "only-critical": {
      "attributes": {
        "check": {
          "status": 2
        }
      }
    }
  },
  "mutators": {},
  "handlers": {
    "slack": {
      "type": "pipe",
      "command": "handler-slack.rb",
      "filters": [
        "only-critical"
      ]
    },
    "graphite_tcp": {
      "type": "tcp",
      "socket": {
        "host": "127.0.0.1",
        "port": 2003
      }
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

Now we should be able to see disk usage metrics in Graphite in addition to the docs site load times.

