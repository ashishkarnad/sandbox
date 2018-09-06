### Welcome to the Sensu Core sandbox!

This tutorial will get you up and running with Sensu.

- [Set up the sandbox](#set-up-the-sandbox)
- [Lesson \#1: Create a monitoring event](#lesson-1-create-a-monitoring-event)
- [Lesson \#2: Create an event pipeline](#lesson-2-pipe-events-into-slack)
- [Lesson \#3: Automate event production with the Sensu client](#lesson-3-automate-event-production-with-the-sensu-client)

We'd love to hear your feedback!
While this sandbox is internal to Sensu, please add feedback to this [GoogleDoc](https://docs.google.com/document/d/1HSIkd3wO6ulAiya3aWB6MjCReYwLdkKIrY4_d4BkFfo/edit#).

---

## Set up the sandbox

**1. Install Vagrant and VirtualBox:**

- [Download Vagrant](https://www.vagrantup.com/downloads.html)
- [Download VirtualBox](https://www.virtualbox.org/wiki/Downloads)

**2. Download the sandbox:**

[Download from GitHub](https://github.com/sensu/sandbox/archive/v2-wip.zip) or clone the repository:

```
git clone git@github.com:sensu/sandbox.git && cd sandbox && git checkout v2-wip
```

If you downloaded the zip file from GitHub, unzip the folder and move it into your Documents folder.
Then open Terminal and enter `cd Documents` followed by `cd sandbox-2-wip`.

**3. Start Vagrant:**

```
cd core && vagrant up
```

This will take around five minutes, so if you haven't already, [read about how Sensu works](https://docs.sensu.io/sensu-core/1.4/overview/architecture) or see the [appendix](#appendix) for details about the sandbox.

**4. SSH into the sandbox:**

Thanks for waiting! To start using the sandbox:

```
vagrant ssh
```

_NOTE: To exit out of the sandbox, use `CTRL`+`D`.
Use `vagrant destroy` then `vagrant up` to erase and restart the sandbox._

---

## Lesson \#1: Create a monitoring event

First off, we'll make sure everything is working correctly by creating a few events with the Sensu server and API.

**1. Use the settings API to see Sensu's configuration:**

```
curl -s http://localhost:4567/settings | jq .
```

With the Sensu server, we can see that we have no active clients, and that Sensu is using RabbitMQ as the transport and Redis as the datastore.
We can see a lot of this same information in the [dashboard datacenter view](http://172.31.255.4:3000/#/datacenters).

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

In this example, the event data tells us that this is a warning-level alert (`"status": 1`) created while monitoring curl times on `docs.sensu.io`.
We can also see the alert and the client in the [dashboard event view](http://172.31.255.4:3000/#/events) and [client view](http://172.31.255.4:3000/#/clients).

```json
$ curl -s http://localhost:4567/events | jq .
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
      "output": "Not great. Total time: x.xxx seconds.",
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

After a few seconds, we can check the [dashboard client view](http://172.31.255.4:3000/#/clients) and see that there are no active alerts and that the client is healthy.

_NOTE: The dashboard auto-refreshes every 10 seconds._

**3. Create a discovery event to provide context about the systems we're monitoring**

This time, use the clients API to create an event that gives Sensu some extra information about docs.sensu.io:

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "name": "docs.sensu.io",
  "address": "https://docs.sensu.io",
  "environment": "production",
  "playbook": "https://github.com/sensu/success/wiki/How-to-Respond-to-a-Docs-Outage"
}' \
http://localhost:4567/clients
```

You can see the new `environment` and `playbook` attributes in the [dashboard client view](http://172.31.255.4:3000/#/clients) or using the clients API:

```
curl -s http://localhost:4567/clients | jq .
```

```json
$ curl -s http://localhost:4567/clients | jq .
[
  {
    "name": "docs.sensu.io",
    "address": "https://docs.sensu.io",
    "environment": "production",
    "playbook": "https://github.com/sensu/success/wiki/How-to-Respond-to-a-Docs-Outage",
    "keepalives": false,
    "version": "1.4.3",
    "timestamp": 1534284314,
    "subscriptions": [
      "client:docs.sensu.io"
    ]
  }
]
```

Nice work! You're now creating monitoring events with Sensu.
In the next lesson, we'll act on these events by creating a pipeline.

---

## Lesson \#2: Pipe events into Slack

Now that we know the sandbox is working properly, let's get to the fun stuff: creating a pipeline.
In this lesson, we'll create a pipeline to send alerts to Slack.
(If you'd rather not create a Slack account, you can skip ahead to [lesson 3](#lesson-3-automate-event-production-with-the-sensu-client).)

**1. Install the Sensu Slack Plugins**

Sensu Plugins are open-source collections of Sensu building blocks shared by the Sensu Community.
In this lesson, we'll use the [Sensu Slack Plugins](https://github.com/sensu-plugins/sensu-plugins-slack) to create our pipeline.
You can find this and more [Sensu Plugins on GitHub](https://github.com/sensu-plugins), or check out [Sensu Enterprise's built-in integrations](https://docs.sensu.io/sensu-enterprise/3.1/built-in-handlers).

First we'll need to install the plugins:

```
sudo sensu-install -p sensu-plugins-slack
```

**2. Get your Slack webhook URL**

If you're already an admin of a Slack, visit `https://YOUR WORKSPACE NAME HERE.slack.com/services/new/incoming-webhook` and follow the steps to add the Incoming WebHooks integration, choose a channel, and save the settings.
(If you're not yet a Slack admin, start [here](https://slack.com/get-started#create) to create a new workspace.)
After saving, you'll see your webhook URL under Integration Settings.

**3. Create a handler to send event data to Slack**

To set up our Slack pipeline, we'll create a handler configuration file that points to the `handler-slack.rb` plugin and specifies your webhook URL:

```
sudo nano /etc/sensu/conf.d/handlers/slack.json
```

```json
{
  "handlers": {
    "slack": {
      "type": "pipe",
      "command": "handler-slack.rb"
    }
  },
  "slack": {
    "webhook_url": "YOUR WEBHOOK URL HERE"
  }
}
```

To save and exit nano, `CTRL`+`X` then `Y` then `ENTER`.

We'll need to restart the Sensu server and API whenever making changes to Sensu's configuration files.

```
sudo systemctl restart sensu-{server,api}
```

Then we can use the settings API to check that the Slack pipeline is in place:

```
curl -s http://localhost:4567/settings | jq .
```

```json
$ curl -s http://localhost:4567/settings | jq .
{
  "...": "...",
  "handlers": {
    "slack": {
      "type": "pipe",
      "command": "handler-slack.rb"
    }
  },
  "...": "...",
  "slack": {
    "webhook_url": "YOUR WEBHOOK URL HERE"
  }
}
```

**4. Pipe event data into Slack with the Sensu API**

Let's use the results API to create an event and send it to our pipeline by adding `"handlers": ["slack"]`.

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check_curl_timings",
  "output": "Not great. The docs site took x.xxx seconds to load.",
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
  "name": "check_curl_timings",
  "output": "Nice! The docs site took x.xxx seconds to load.",
  "status": 0,
  "handlers": ["slack"]
}' \
http://localhost:4567/results
```

**5. Add a critical-only filter to the pipeline**

This is great, but let's say we only really want to be notified by Slack when there's a critical alert.
To do this, we'll create a filter using a configuration file:

```
sudo nano /etc/sensu/conf.d/filters/only_critical.json
```

```
{
  "filters": {
    "only_critical": {
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
Now we need to hook up the `only_critical` filter to the pipeline.

Open the `slack.json` handler configuration:

```
sudo nano /etc/sensu/conf.d/handlers/slack.json
```

And add a line with `"filters": ["only_critical"],`, so it looks like:

```
{
  "handlers": {
    "slack": {
      "filters": ["only_critical"],
      "type": "pipe",
      "command": "handler-slack.rb"
    }
  },
  "slack": {
    "webhook_url": "https://hooks.slack.com/services/xxxxxxxx/xxxxxxxxxxx"
  }
}
```

Restart the Sensu server and API:

```
sudo systemctl restart sensu-{server,api}
```

Then we can use the settings API to see the filter we just created:

```
curl -s http://localhost:4567/settings | jq .
```

```
$ curl -s http://localhost:4567/settings | jq .
{
  "...": "...",
  "filters": {
    "only_critical": {
      "attributes": {
        "check": {
          "status": 2
        }
      }
    }
  },
  "...": "..."
}
```

If you don't get a response from the API here, check for invalid JSON in `/etc/sensu/conf.d/handlers/slack.json`.

**6. Send events to the filtered pipeline**

Now Sensu will only pass critical events through to Slack.
Let's test it by sending a warning:

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check_curl_timings",
  "output": "Not great. The docs site took x.xxx seconds to load.",
  "status": 1,
  "handlers": ["slack"]
}' \
http://localhost:4567/results
```

We shouldn't see anything in Slack, but we should see an alert in the [dashboard events view](http://172.31.255.4:3000/#/events).

Now let's create a critical alert:

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check_curl_timings",
  "output": "Something is up. The docs site took x.xxx seconds to load.",
  "status": 2,
  "handlers": ["slack"]
}' \
http://localhost:4567/results
```

And we should see it in Slack!
You can customize your Slack messages using the [Sensu Slack Plugin handler attributes](https://github.com/sensu-plugins/sensu-plugins-slack#usage-for-handler-slackrb).

Great work. You've created your first Sensu pipeline!
In the next lesson, we'll tap into the power of Sensu by adding a Sensu client to automate event production.

Before we go, let's create a resolution event.
(It should not appear in Slack, but we should see the results in the [dashboard client view](http://172.31.255.4:3000/#/clients).)

```
curl -s -XPOST -H 'Content-Type: application/json' \
-d '{
  "source": "docs.sensu.io",
  "name": "check_curl_timings",
  "output": "Nice! The docs site took x.xxx seconds to load.",
  "status": 0,
  "handlers": ["slack"]
}' \
http://localhost:4567/results
```

---

## Lesson \#3: Automate event production with the Sensu client
So far we've used only the Sensu server and API, but in this lesson, we'll add the Sensu client and create a check to produce events automatically.
Instead of sending alerts to Slack, we'll store event data with [InfluxDB](https://www.influxdata.com/) and visualize it with [Grafana](https://grafana.com/).

**1. Install Nginx and the Sensu HTTP Plugin**

Up until now we've used placeholder event data, but in this lesson, we'll use the [Sensu HTTP Plugin](https://github.com/sensu-plugins/sensu-plugins-http) to monitor an Nginx server running on the sandbox.

First, install and start Nginx:

```
sudo yum install -y nginx && sudo systemctl start nginx
```

And make sure it's working with:

```
curl -I http://localhost:80
```

Then install the Sensu HTTP Plugin:

```
sudo sensu-install -p sensu-plugins-http
```

We'll be using the `metrics-curl.rb` plugin.
We can test its output using:

```
/opt/sensu/embedded/bin/metrics-curl.rb localhost
```

```
$ /opt/sensu/embedded/bin/metrics-curl.rb locahost
...
sensu-core-sandbox.curl_timings.http_code 200 1535670975
```

**2. Create an InfluxDB pipeline**

Since we've already installed InfluxDB as part of the sandbox, all we need to do to create an InfluxDB pipeline is create a configuration file:

```
sudo nano /etc/sensu/conf.d/handlers/influx.json
```

```
{
  "handlers": {
    "influx": {
      "type": "tcp",
      "socket": {
        "host": "127.0.0.1",
        "port": 2003
      },
      "mutator": "only_check_output"
    }
  }
}
```

This tells Sensu to reduce event data to only the `output` and forward it a TCP socket.

Now restart the Sensu server and API:

```
sudo systemctl restart sensu-{server,api}
```

And confirm using the settings API:

```
curl -s http://localhost:4567/settings | jq .
```

```
$ curl -s http://localhost:4567/settings | jq .
{
  "...": "...",
  "handlers": {
    "slack": {
      "filters": [
        "only_critical"
      ],
      "type": "pipe",
      "command": "handler-slack.rb"
    },
    "influx": {
      "type": "tcp",
      "socket": {
        "host": "127.0.0.1",
        "port": 2003
      },
      "mutator": "only_check_output"
    }
  },
  "...": "..."
}
```

**3. Start the Sensu client**

Now that we have our InfluxDB pipeline set up, let's start the Sensu client:

```
sudo systemctl start sensu-client
```

We can see the sandbox client start up using the clients API:

```
curl -s http://localhost:4567/clients | jq .
```

```json
$ curl -s http://localhost:4567/clients | jq .
[
  {
    "name": "sensu-core-sandbox",
    "address": "10.0.2.15",
    "subscriptions": [
      "client:sensu-core-sandbox"
    ],
    "version": "1.4.3",
    "timestamp": 1534284788
  },
  {"...": "..."}
]
```

In the [dashboard client view](http://172.31.255.4:3000/#/clients), we can see that the client running in the sandbox is executing keepalive checks.

_NOTE: The client gets its name from the `sensu.name` attribute configured as part of sandbox setup.
You can change the client name using `sudo nano /etc/sensu/uchiwa.json`._

**3. Add a client subscription**

Clients run the set of checks defined by their `subscriptions`.
Use a configuration file to assign our new client to run checks with the `sandbox-testing` subscription using `"subscriptions": ["sandbox-testing"]`:

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

Restart the Sensu client, server, and API:

```
sudo systemctl restart sensu-{client,server,api}
```

Then use the clients API to make sure the subscription is assigned to the client:

```
curl -s http://localhost:4567/clients | jq .
```

```
$ curl -s http://localhost:4567/clients | jq .
[
  {
    "name": "sensu-core-sandbox",
    "address": "10.0.2.15",
    "subscriptions": [
      "client:sensu-core-sandbox",
      "sandbox-testing"
    ],
    "version": "1.4.3",
    "timestamp": 1534284788
  },
  {"...": "..."}
]
```

If you don't see the new subscription, wait a few seconds and try the settings API again.

**5. Create a check to monitor Nginx**

Use a configuration file to create a service check that runs `metrics-curl.rb` every 10 seconds on all clients with the `sandbox-testing` subscription and send it to the InfluxDB pipeline:

```
sudo nano /etc/sensu/conf.d/checks/check_curl_timings.json
```

```
{
  "checks": {
    "check_curl_timings": {
      "command": "/opt/sensu/embedded/bin/metrics-curl.rb localhost",
      "interval": 10,
      "subscribers": ["sandbox-testing"],
      "type": "metric",
      "handlers": ["influx"]
    }
  }
}
```

Note that `"type": "metric"` ensures that Sensu will handle every event, not just warning and critical alerts.

Restart the Sensu client, server, and API:

```
sudo systemctl restart sensu-{client,server,api}
```

Use the settings API to make sure the check has been created:

```
curl -s http://localhost:4567/settings | jq .
```

```
$ curl -s http://localhost:4567/settings | jq .
{
  "...": "...",
  "checks": {
    "check_curl_timings": {
      "command": "/opt/sensu/embedded/bin/metrics-curl.rb localhost",
      "interval": 10,
      "subscribers": [
        "sandbox-testing"
      ],
      "type": "metric",
      "handlers": [
        "influx"
      ]
    }
  },
  "...": "..."
}
```

**6. See the HTTP response code events for Nginx in [Grafana](http://172.31.255.4:4000/d/core01/sensu-core-sandbox).**

Log in to Grafana as username: `admin` password: `admin`.
We should see a graph of real HTTP response codes for Nginx.

Now if we turn Nginx off, we should see the impact in Grafana:

```
sudo systemctl stop nginx
```

Start Nginx:

```
sudo systemctl start nginx
```

**7. Automate disk usage monitoring for the sandbox**

Now that we have a client and subscription set up, we can easily add more checks.
For example, let's say we want to monitor disk usage on the sandbox.

First, install the plugin:

```
sudo sensu-install -p sensu-plugins-disk-checks
```

And test it:

```
/opt/sensu/embedded/bin/metrics-disk-usage.rb
```

```
$ /opt/sensu/embedded/bin/metrics-disk-usage.rb
sensu-core-sandbox.disk_usage.root.used 2235 1534191189
sensu-core-sandbox.disk_usage.root.avail 39714 1534191189
...
```

Then create the check using a configuration file, assigning it to the `sandbox-testing` subscription and the Graphite pipeline:

```
sudo nano /etc/sensu/conf.d/checks/check_disk_usage.json
```

```
{
  "checks": {
    "check_disk_usage": {
      "command": "/opt/sensu/embedded/bin/metrics-disk-usage.rb",
      "interval": 10,
      "subscribers": ["sandbox-testing"],
      "type": "metric",
      "handlers": ["influx"]
    }
  }
}
```

Finally, restart all the things:

```
sudo systemctl restart sensu-{client,server,api}
```

And we should see it working in the dashboard client view and via the settings API:

```
curl -s http://localhost:4567/settings | jq .
```

```
$ curl -s http://localhost:4567/settings | jq .
{
  "...": "...",
  "checks":
    {"...": "..."},
    "check_disk_usage": {
      "command": "/opt/sensu/embedded/bin/metrics-disk-usage.rb",
      "interval": 10,
      "subscribers": [
        "sandbox-testing"
      ],
      "type": "metric",
      "handlers": [
        "influx"
      ]
    }
  },
  "...": "..."
}
```

Now we should be able to see [disk usage metrics for the sandbox in Grafana](172.31.255.4:4000/d/core02/sensu-core-sandbox-combined).

You made it! You're ready for the next level of Sensu-ing.
Here are some resources to help continue your journey:

- [Install Sensu with configuration management](https://docs.sensu.io/sensu-core/latest/installation/configuration-management/)
- [Create application events using the client socket](https://docs.sensu.io/sensu-core/latest/reference/clients/#what-is-the-sensu-client-socket)

## Appendix: Sandbbox Architecture

The Sensu Core sandbox is a CentOS 7 virtual machine managed with Vagrant and VirtualBox.
It is intended for use as a learning tool. We do not recommend this tool as part of a production installation.
To install Sensu in production, please see the [installation guide](https://docs.sensu.io/sensu-core/1.4/installation/overview/).

### Sandbox contents

![sandbox-core 3](https://user-images.githubusercontent.com/11339965/45131333-557c4c00-b141-11e8-83db-6e1ba4edcf1e.png)
