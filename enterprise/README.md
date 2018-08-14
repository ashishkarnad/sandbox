### Welcome to the Sensu Enterprise sandbox!

This tutorial will get you up and running with Sensu Enterprise.

- [Set up the sandbox](#set-up-the-sandbox)
- [Lesson \#1: Create a monitoring event](#lesson-1-create-a-monitoring-event)
- [Lesson \#2: Create an event pipeline](#lesson-2-pipe-events-into-graphite)
- [Lesson \#3: Automate event production with the Sensu client](#lesson-3-automate-event-production-with-the-sensu-client)

We'd love to hear your feedback!
While this sandbox is internal to Sensu, please add feedback to this [GoogleDoc](https://docs.google.com/document/d/1HSIkd3wO6ulAiya3aWB6MjCReYwLdkKIrY4_d4BkFfo/edit#).

---

## Set up the sandbox

**1. Install Vagrant and VirtualBox:**

- [Download Vagrant](https://www.vagrantup.com/downloads.html)
- [Download VirtualBox](https://www.virtualbox.org/wiki/Downloads)

**2. Download the sandbox:**

[Download from GitHub](https://github.com/sensu/sandbox/archive/v1-wip.zip) or clone the repository:

```
git clone git@github.com:sensu/sandbox.git
cd sandbox
git checkout v1-wip
```

If you downloaded the zip file from GitHub, unzip the folder and move it into your Documents folder.
Then open Terminal and enter `cd Documents` followed by `cd sandbox-1-wip`.

**3. Add your Sensu Enterprise username and password**

[Sign up for a free trial of Sensu Enterprise](https://account.sensu.io/users/sign_up?plan=silver), and get your access credentials from the [Sensu account manager](https://account.sensu.io/).

Then add your Sensu Enterprise username and password to the sandbox:

```
cd enterprise
export SE_USER=REPLACEME
export SE_PASS=REPLACEME
```

**4. Start Vagrant:**

```
vagrant up
```

This will take around five minutes, so if you haven't already, [read about how Sensu works]().

**5. SSH into the sandbox:**

```
vagrant ssh
```

---

## Lesson \#1: Create a monitoring event

First off, we'll make sure everything is working correctly by creating a few events with the Sensu server and API.

**1. Use the settings API to see Sensu's configuration**

```
curl -s http://localhost:4567/settings | jq .
```

With our sandbox server, we can see that we have no active clients, and that Sensu is using RabbitMQ as the transport and Redis as the datastore.
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

**2. Create an event that warns us that docs.sensu.io is loading slowly (and resolve it)**

Let's say we have an application that can test the Sensu docs site and output a string with the response time.
We can use the results API to create an event that represents a warning from our pseudo-app that the docs site is getting slow.

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check_curl_timings",
  "output": "Not great. Total time: x.xxx seconds.",
  "status": 1
}' \
http://localhost:4567/results
```

Since we're creating this event using the API, Sensu doesn't know where this information is coming from, so we use the `source` attribute to tell Sensu that we're creating this event on behalf of a remote source.
The `status` attribute represents a warning-level event (0 = OK, 1 = warning, 2 = critical),

We can use the events API to see the resulting event:

```
curl -s http://localhost:4567/events | jq .
```

_NOTE: The events API returns only warning (`"status": 1`) and critical (`"status": 2`) events._

Event data contains information about the part of your system the event came from (the `client` or `source`), the result of the check (including a `history` of recent `status` results), and the event itself (including the number of `occurrences`).

This event's data tells us that this is a warning-level alert (`"status": 1`) created while monitoring curl times on `docs.sensu.io`.
We can also see the alert and the client in the [dashboard event view](http://172.28.128.3:3000/#/events) and [client view](http://172.28.128.3:3000/#/clients).

```json
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
      "name": "check_curl_timings",
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
Now let's remove the warning from the dashboard by creating a resolution event:

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check_curl_timings",
  "output": "Nice! Total time: x.xxx seconds.",
  "status": 0
}' \
http://localhost:4567/results
```

In the [dashboard client view](http://localhost:3000/#/clients), we can see that there are no active alerts and that the client is healthy.

_NOTE: The dashboard auto-refreshes every 10 seconds._

**3. Provide context about the systems we're monitoring with a discovery event**

This time, use the clients API to create an event that gives Sensu some extra information about docs.sensu.io:

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "name": "docs.sensu.io",
  "address": "unknown",
  "playbook": "https://github.com/sensu/success/wiki/How-to-Respond-to-a-Docs-Outage"
}' \
http://localhost:4567/clients
```

We can see the new `playbook` attribute in the [dashboard client view](http://localhost:3000/#/clients) or using the clients API:

```
curl -s http://localhost:4567/clients | jq .
```

```json
[
  {
    "name": "docs.sensu.io",
    "address": "unknown",
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
In the next lesson, we'll take action on these events by creating a pipeline.

---

## Lesson \#2: Pipe events into Graphite

Now that we know the sandbox is working properly, let's get to the fun stuff: creating a pipeline.
In this lesson, we'll create a pipeline to send event data to [Graphite](http://graphite.readthedocs.io/en/latest/).

**1. Configure the Sensu Enterprise Graphite integration**

Sensu Enterprise includes a built-in handler to send event data to Graphite.
Since we've already installed Graphite as part of the sandbox, all we need to do to create a Graphite pipeline is create a configuration file:

```
sudo nano /etc/sensu/conf.d/handlers/graphite.json
```

```json
{
  "graphite": {
    "host": "127.0.0.1",
    "port": 2003
  }
}
```

We'll need to restart Sensu Enterprise whenever making changes to Sensu's configuration files.

```
sudo systemctl reload sensu-enterprise
```

Then we can use the settings API to check that the Graphite pipeline is in place:

```
curl -s http://localhost:4567/settings | jq .
```

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
  },
  "graphite": {
    "host": "127.0.0.1",
    "port": 2003
  }
}
```

**2. Pipe event data into Graphite with the Sensu API**

Let's use the results API to create a few events that represent varying curl times for the docs site and assign them to the Graphite pipeline by adding `"handlers": ["graphite"]`.

_NOTE: Since the data from these events is going to Graphite, the `output` needs to be formatted as [Graphite plaintext](https://graphite.readthedocs.io/en/latest/feeding-carbon.html?highlight=plaintext#the-plaintext-protocol). Nevertheless, these example still contain random data, not actual response times from docs.sensu.io._

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check_curl_timings",
  "output": "sensu-enterprise-sandbox.curl_timings.time_total 0.594 '`date +%s`'",
  "status": 0,
  "type": "metric",
  "handlers": [
    "graphite"
  ]
}' \
http://localhost:4567/results && sleep 10s && curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check_curl_timings",
  "output": "sensu-enterprise-sandbox.curl_timings.time_total 2.358 '`date +%s`'",
  "status": 1,
  "type": "metric",
  "handlers": [
    "graphite"
  ]
}' \
http://localhost:4567/results && sleep 10s && curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check_curl_timings",
  "output": "sensu-enterprise-sandbox.curl_timings.time_total 3.041 '`date +%s`'",
  "status": 2,
  "type": "metric",
  "handlers": [
    "graphite"
  ]
}' \
http://localhost:4567/results && sleep 10s && curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check_curl_timings",
  "output": "sensu-enterprise-sandbox.curl_timings.time_total 0.712 '`date +%s`'",
  "status": 0,
  "type": "metric",
  "handlers": [
    "graphite"
  ]
}' \
http://localhost:4567/results
```

Note that `"type": "metric"` ensures that Sensu will handle every event, not just warnings and critical alerts.

After a few seconds, we'll be able to see the [event data in Graphite](http://172.28.128.3/?width=586&height=308&target=sensu-enterprise-sandbox.curl_timings.time_total&from=-10minutes) under Metrics/sensu-enterprise-sandbox/curl_timings/time_total.

(Not seeing anything? Try enabling Auto-Refresh and adjusting the time view to the last 10 minutes.)

**3. Add a production-only filter to the pipeline**

Let's say we've set up a development instance of docs.sensu.io that we also want to monitor, but we only want our Graphite graph to contain data from production.
To do this, we'll add a filter to our Graphite pipeline by creating a configuration file:

```
sudo nano /etc/sensu/conf.d/filters/only_production.json
```

```json
{
  "filters": {
    "only_production": {
      "attributes": {
        "check": {
          "environment": "production"
        }
      }
    }
  }
}
```

This tells Sensu to check the event data and only allow events with `"environment": "production"` to continue through the pipeline.

Now we'll hook up the `only_production` filter to the `graphite` handler by adding `"filters": ["only_production"]` to the handler configuration:

```
sudo nano /etc/sensu/conf.d/handlers/graphite.json
```

```json
{
  "graphite": {
    "filters": ["only_production"],
    "host": "127.0.0.1",
    "port": 2003
  }
}
```

Restart Sensu Enteprise:

```
sudo systemctl reload sensu-enterprise
```

Then use the settings API to see the only_production filter:

```
curl -s http://localhost:4567/settings | jq .
```

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
  "filters": {
    "only_production": {
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
    "filters": [
      "only_production"
    ],
    "host": "127.0.0.1",
    "port": 2003
  }
}
```

**4. Send events to the filtered pipeline**

Now any events we create must include `"environment": "production"` in order to be handled by the Graphite pipeline.
Let's test it out by creating an event from our hypothetical development site:

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check_curl_timings",
  "output": "sensu-enterprise-sandbox.curl_timings.time_total 1.762 '`date +%s`'",
  "status": 1,
  "type": "metric",
  "environment": "development",
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
  "name": "check_curl_timings",
  "output": "sensu-enterprise-sandbox.curl_timings.time_total 2.051 '`date +%s`'",
  "status": 1,
  "type": "metric",
  "environment": "production",
  "handlers": [
    "graphite"
  ]
}' \
http://localhost:4567/results
```

We should see it appear in Graphite.
Then we can send a resolution event:

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check_curl_timings",
  "output": "sensu-enterprise-sandbox.curl_timings.time_total 0.672 '`date +%s`'",
  "status": 0,
  "type": "metric",
  "environment": "development",
  "handlers": [
    "graphite"
  ]
}' \
http://localhost:4567/results
```

Great work. You've created your first Sensu pipeline!
In the next lesson, we'll tap into the power of Sensu by adding a Sensu client to automate event production.

---

## Lesson \#3: Automate event production with the Sensu client
So far we've used only the Sensu server and API, but in this lesson, we'll add the Sensu client and start producing events automatically.

**1. Install and start the Sensu client:**

```
sudo yum install -y sensu
sudo systemctl start sensu-client
```

We can see the client start up using the clients API:

```
curl -s http://localhost:4567/clients | jq .
```

```json
[
  {
    "name": "docs.sensu.io",
    "address": "unknown",
    "playbook": "https://github.com/sensu/success/wiki/How-to-Respond-to-a-Docs-Outage",
    "keepalives": false,
    "version": "1.4.3",
    "timestamp": 1534188871,
    "subscriptions": [
      "client:docs.sensu.io"
    ]
  },
  {
    "name": "sensu-enterprise-sandbox",
    "address": "10.0.2.15",
    "subscriptions": [
      "client:sensu-enterprise-sandbox"
    ],
    "version": "1.4.3",
    "timestamp": 1534190376
  }
]
```

In the [dashboard client view](http://172.28.128.3:3000/#/clients), note that the sandbox client running in the sandbox executes keepalive checks while the docs.sensu.io proxy client cannot.

_NOTE: The sandbox client gets its name from the `sensu.name` attributed configured as part of sandbox setup.
You can change the client name using `sudo nano /etc/sensu/dashboard.json`._

**2. Add a client subscription**

Clients run the set of checks defined by their `subscriptions`.
Create a configuration file to assign our new client to run checks with the `sandbox-testing` subscription using `"subscriptions": ["sandbox-testing"]`:

```
sudo nano /etc/sensu/conf.d/client.json
```

```json
{
  "client": {
    "name": "sensu-enterprise-sandbox",
    "subscriptions": ["sandbox-testing"]
  }
}
```

Restart the Sensu client:

```
sudo systemctl restart sensu-client
```

Then use the clients API to make sure the subscription is assigned to the client:

```
curl -s http://localhost:4567/clients | jq .
```

```json
[
  {
    "name": "docs.sensu.io",
    "address": "unknown",
    "playbook": "https://github.com/sensu/success/wiki/How-to-Respond-to-a-Docs-Outage",
    "keepalives": false,
    "version": "1.4.3",
    "timestamp": 1534188871,
    "subscriptions": [
      "client:docs.sensu.io"
    ]
  },
  {
    "name": "sensu-enterprise-sandbox",
    "address": "10.0.2.15",
    "subscriptions": [
      "sandbox-testing",
      "client:sensu-enterprise-sandbox"
    ],
    "version": "1.4.3",
    "timestamp": 1534190720
  }
]
```

**5. Install the Sensu HTTP Plugin**

Up until now we've been using random event data, but in this lesson, we'll use the [Sensu HTTP Plugin](https://github.com/sensu-plugins/sensu-plugins-http) to collect real curl times from the docs site.
Sensu Plugins are open-source collections of Sensu building blocks shared by the Sensu Community. 
You can find this and more [Sensu Plugins on GitHub](https://github.com/sensu-plugins).

First we'll install the plugin:

```
sudo sensu-install -p sensu-plugins-http
```

We can test its output using:

```
/opt/sensu/embedded/bin/metrics-curl.rb -u https://docs.sensu.io
```

```
sensu-enterprise-sandbox.curl_timings.time_total 0.635 1534190765
sensu-enterprise-sandbox.curl_timings.time_namelookup 0.069 1534190765
...
```

**6. Create a check that produces curl timing events for docs.sensu.io**

Use a configuration file to create a check that runs `metrics-curl.rb` every 10 seconds on all clients with the `sandbox-testing` subscription:

```
sudo nano /etc/sensu/conf.d/checks/check_curl_timings.json
```

```json
{
  "checks": {
    "check_curl_timings": {
      "source": "docs.sensu.io",
      "command": "metrics-curl.rb -u https://docs.sensu.io",
      "interval": 10,
      "subscribers": ["sandbox-testing"],
      "type": "metric",
      "environment": "production",
      "handlers": ["graphite"]
    }
  }
}
```

Reload Sensu Enterprise, and restart the Sensu client.

```
sudo systemctl reload sensu-enterprise
sudo systemctl restart sensu-client
```

Then use the settings API to make sure the check has been created:

```
curl -s http://localhost:4567/settings | jq .
```

```json
{
  "client": {
    "name": "sensu-enterprise-sandbox",
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
    "check_curl_timings": {
      "source": "docs.sensu.io",
      "command": "metrics-curl.rb -u https://docs.sensu.io",
      "interval": 10,
      "subscribers": [
        "sandbox-testing"
      ],
      "type": "metric",
      "environment": "production",
      "handlers": [
        "graphite"
      ]
    }
  },
  "filters": {
    "only_production": {
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
      "only_production"
    ]
  }
}
```

**7. See the automated events in [Graphite](http://172.28.128.4/?width=944&height=308&target=sensu-enterprise-sandbox.curl_timings.time_total&from=-10minutes) and the [dashboard client view](http://172.28.128.4:3000/#/clients)**

**8. Automate disk usage monitoring for the sandbox**

Now that we have a client and subscription set up, we can easily add more checks.
For example, let's say we want to monitor disk usage on the sandbox.

First, install the [Sensu Disk Checks Plugin](https://github.com/sensu-plugins/sensu-plugins-disk-checks):

```
sudo sensu-install -p sensu-plugins-disk-checks
```

And test it:

```
/opt/sensu/embedded/bin/metrics-disk-usage.rb
```

```
sensu-enterprise-sandbox.disk_usage.root.used 2235 1534191189
sensu-enterprise-sandbox.disk_usage.root.avail 39714 1534191189
...
```

Then create a disk usage check using a configuration file, assigning it to the `sandbox-testing` subscription and the `graphite` pipeline:

```
sudo nano /etc/sensu/conf.d/checks/check_disk_usage.json
```

```json
{
  "checks": {
    "check_disk_usage": {
      "command": "/opt/sensu/embedded/bin/metrics-disk-usage.rb",
      "interval": 10,
      "subscribers": ["sandbox-testing"],
      "type": "metric",
      "environment": "production",
      "handlers": ["graphite"]
    }
  }
}
```

Finally, restart all the things:

```
sudo systemctl reload sensu-enterprise
sudo systemctl restart sensu-client
```

Now we should be able to see disk usage metrics in Graphite in addition to the docs site load times.

You made it! You're ready for the next level of Sensu-ing.
Here are some resources to help continue your journey:

- [Install Sensu with configuration management]
- [Send Slack alerts with Sensu Enterprise]
- [Add teams and organizations to Sensu Enterprise]
