### Welcome to the Sensu Go sandbox!

This tutorial will get you up and running with Sensu.

- [Set up the sandbox](#set-up-the-sandbox)
- [Lesson \#1: Create a monitoring event](#lesson-1-create-a-monitoring-event)
- [Lesson \#2: Create an event pipeline](#lesson-2-pipe-events-into-slack)
- [Lesson \#3: Automate event production with the Sensu client](#lesson-3-automate-event-production-with-the-sensu-client)

Report issues or share feedback by [opening an issue in this repo](https://github.com/sensu/sandbox/issues/new).

---

## Set up the sandbox

**1. Install Vagrant and VirtualBox:**

- [Download Vagrant](https://www.vagrantup.com/downloads.html)
- [Download VirtualBox](https://www.virtualbox.org/wiki/Downloads)

**2. Download the sandbox:**

[Download from GitHub](https://github.com/sensu/sandbox/archive/master.zip) then unzip and enter the sensu-go sandbox directory 

```
unzip sandbox-master.zip && cd sandbox-master/sensu-go/core/
```

or clone the repository:

```
git clone git@github.com:sensu/sandbox.git && cd sandbox/sensu-go/core
```

**3. Start Vagrant:**

```
ENABLE_SENSU_SANDBOX_PORT_FORWARDING=1 vagrant up
```

This will take around five minutes.

_NOTE: This will configure VirtualBox to forward a couple of tcp ports (3002 and 4002) from the sandbox VM machine to the localhost to make it easier for you to interact with Sensu. Dashboard links provided below assume port forwarding from the VM to the host is active and references http://localhost._

**4. SSH into the sandbox:**

Thanks for waiting! To start using the sandbox:

```
vagrant ssh
```

You should now have shell access to the sandbox and should be greeted with this sandbox prompt:  

```
[sensu_go_sandbox]$
```

_NOTE: To exit out of the sandbox, use `CTRL`+`D`. Use `vagrant destroy` then `vagrant up` to erase and restart the sandbox. Use `vagrant provision` to reset sandbox's sensu configuration to the beginning of this lesson_

---

## Lesson \#1: Create a monitoring event

First off, we'll make sure everything is working correctly by creating a few events with the Sensu backend and sensuctl command line tool.

**1. See the sensuctl settings**

Sensuctl is a helpful command-line tool for managing your Sensu workflows.
We can use the `--help` flag to learn more about any of sensuctl's commands and subcommands.

```
sensuctl --help
```

Let's start by seeing our current sensuctl configuration.

```
sensuctl config view
```

We can see that sensuctl is configured to connect to the backend at `http://127.0.0.1:8080` and our namespace is set to the default.

```
=== Active Configuration
API URL:       http://127.0.0.1:8080
Sensu Edition: core
Namespace:     default
Format:        tabular
```

**2. Create an event that warns us that docs.sensu.io is loading slowly (and resolve it)**

Let's say we have an application that can test the Sensu docs site and output a string with the response time.
We can use sensuctl and the Sensu event described in `event.json` to create an event that represents a warning from our pseudo-app that the docs site is getting slow.

```
cat event.json
```

Since we're creating this event using sensuctl, Sensu doesn't know where this information is coming from, so we use the `source` attribute to tell Sensu that we're creating this event on behalf of a remote source.
The `status` attribute represents a warning-level event (0 = OK, 1 = warning, 2 = critical).

```
sensuctl create --file event.json
```

Now we can use sensuctl to see the resulting event:

```
sensuctl event list
```

And get detailed information about the event using the entity and check name:

```
sensuctl event info docs.sensu.io check_curl_timings
```

Event data contains information about the part of your system the event came from (the `entity`), the result of the check (including the `output` and `status`), and whether the event was silenced.

In this example, the event data tells us that this is a warning-level alert (`"status": 1`) created while monitoring curl times on `docs.sensu.io`.

```
=== docs.sensu.io - check_curl_timings
Entity:    docs.sensu.io
Check:     check_curl_timings
Output:    Not great. Total time: x.xxx seconds.
Status:    1
History:   
Silenced:  false
```

To see this event in the Sensu dashboard, visit http://localhost:3000 and log in as the default admin user (username `admin`; password `P@ssw0rd!`).

We created our first event!
Now let's remove the warning by creating a resolution event:

```
sensuctl create --file resolve-event.json
```

We can use sensuctl to see that the event now has a status of `0`, indicating an ok event status.

```
sensuctl event list
```

We can re-check the details of the event using the same `sensuctl event info` command:

```
sensuctl event info docs.sensu.io check_curl_timings
```

We should now see that the status is `0` and the `output` indicates an ok check result:

```
=== docs.sensu.io - check_curl_timings
Entity:    docs.sensu.io
Check:     check_curl_timings
Output:    Nice! Total time: x.xxx seconds.
Status:    0
History:   0
Silenced:  false
```

After a few seconds, we can check the [dashboard entity view](http://localhost:3000/#/entities) and see that there are no active alerts and that the client is healthy.

_NOTE: The dashboard auto-refreshes every 10 seconds._

## Lesson \#2: Pipe keepalive events into Slack

Now that we know the sandbox is working properly, let's get to the fun stuff: creating a pipeline.
In this lesson, we'll create a pipeline to send alerts to Slack.
(If you'd rather not create a Slack account, you can skip ahead to [lesson 3](#lesson-3-automate-event-production-with-the-sensu-agent).)

In this lesson, we'll use the [Sensu Slack Handler](https://github.com/sensu/sensu-slack-handler) to create our pipeline. For convenience, this command was installed as part of sandbox provisioning. 

**1. Get your Slack webhook URL**

If you're already an admin of a Slack, visit `https://YOUR WORKSPACE NAME HERE.slack.com/services/new/incoming-webhook` and follow the steps to add the Incoming WebHooks integration, choose a channel, and save the settings.
(If you're not yet a Slack admin, start [here](https://slack.com/get-started#create) to create a new workspace.)
After saving, you'll see your webhook URL under Integration Settings.

In the sandbox, we've included a json handler resource definition in the sandbox for you to edit. Open the `sensu-slack-handler.json` file:

```
sudo nano sensu-slack-handler.json
```

And edit the configure to include your Slack channel and webhook url.

**4. Pipe event data into Slack with the Sensu API**

Let's use sensuctl to create an event and send it to our pipeline by adding `"handlers": ["slack"]`.
Open `event.json` and add `"handlers": ["slack"]` under the check scope so it looks like this:

```
{
  "type": "Event",
  "api_version": "core/v2",
  "metadata": {
    "name": "docs.sensu.io",
    "namespace": "default",
    "labels": null,
    "annotations": null
  },
  "spec": {
    "timestamp": 1543560349,
    "entity": {
      "metadata": {
        "name": "docs.sensu.io",
        "namespace": "default"
      },
      "entity_class": "agent"
    },
    "check": {
      "handlers": ["slack"],
      "command": "http_check.sh https://docs.sensu.io",
      "interval": 20,
      "publish": true,
      "proxy_entity_name": "docs.sensu.io",
      "output": "Not great. Total time: x.xxx seconds.",
      "state": "failing",
      "status": 1,
      "metadata": {
        "name": "check_curl_timings",
        "namespace": "default",
        "labels": null,
        "annotations": null
      }
    }
  }
}
```









**2. Test the Slack handler manually**
We can manually test the operation of the handler on the sandbox commandline. Let's encode the Slack webhook details into environment variables.  

n, and run the following commands:



Generate a manual Slack alert with:

```
sensuctl event info docs.sensu.io check_curl_timings --format json | /usr/local/bin/sensu-slack-handler -c "${KEEPALIVE_SLACK_CHANNEL}" -w "${KEEPALIVE_SLACK_WEBHOOK}"
```

You should now see a new message in Slack indicating that the docs site is loading quickly.







  

**2. Edit sensu-slack-handler.json**


**3. Create the handler definition using sensuctl**
```
sensuctl create -f sensu-slack-handler.json

```
We can confirm its creation with sensuctl  
```  
sensuctl handler list
```

**4. Test Slack handler pipeline**
Restart the sensu agent to start producing additional keepalive events.
```
sudo systemctl restart sensu-agent
```
Once the agent begins to send keepalive events, you should get message into your slack channel!  



**5. Filter keepalive events **
Typically we aren't interested in getting keepalive messages for entities until they enter a non-zero status state.  
Let's interactively add the built-in `is_incident` filter to the keepalive handler pipeline so we only get messages when the sandbox agent fails to send a keepalive event.  
```
sensuctl handler update 
```
Hit enter until you reach the filters selection.  
```
? Filters: [? for help] is_incident
```
Hit enter through the rest of the interactive update fields to keep current selection.

We can confirm the handler is updated with sensuctl
```
sensuctl handler info keepalive
```

Now with the filter in place we should no longer be receiving messages in the Slack channel every time the sandbox agent sends a keepalive event.

Let's stop the agent and confirm we still get the warning message.
```  
sudo systemctl stop sensu-agent

```
We will get the warning message after a couple of minutes informing you the sandbox agent is no longer sending keepalive events.




## Lesson \#3: Automate event production with the Sensu agent
So far we've used only the Sensu agent's keepalive check, but in this lesson, we'll create a check that can be scheduled on the agent to produce workload relevant events.
Instead of sending alerts to Slack, we'll store event data with [InfluxDB](https://www.influxdata.com/) and visualize it with [Grafana](https://grafana.com/).

**1. Install Nginx and the Sensu HTTP Plugin**

We'll use the [Sensu HTTP Plugin](https://github.com/sensu-plugins/sensu-plugins-http) to monitor an Nginx server running on the sandbox.

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
/opt/sensu-plugins-ruby/embedded/bin/check-http.rb -u "http://localhost"
```

```
$ /opt/sensu-plugins-ruby/embedded/bin/metrics-curl.rb -u "http://localhost"
...
sensu-go-sandbox.curl_timings.http_code 200 1535670975
```

**5. Create a check to monitor Nginx**

Use a configuration file to create a service check that runs `metrics-curl.rb` every 10 seconds on all clients with the `entity:sensu-go-sandbox` subscription and send it to the InfluxDB metrics handler pipeline:

```
sudo nano check_curl_timings.json
```
Notice how we are defining a metrics handler and metric format. In Sensu Go metrics are treated as first class citizens, and we can build pipelines to handle the metrics separate from the status!  

If we wanted to be alerted that the check failed for some reason, we could configure a separate handler to alert us of that failure condition.  

```
sensuctl create -f curl_timings-check.json
```
The check should now exists.

```
sensuctl check list
```  

After about 10 seconds the check should have been run on the agent and we should have an event.  
```
sensuctl event info sensu-go-sandbox curl_timings --format json |jq .
...
  "metrics": {
    "handlers": [
      "influx-db"
    ],
    "points": [
      {
        "name": "sensu-go-sandbox.curl_timings.time_total",
        "value": 0.005,
        "timestamp": 1543532948,
        "tags": []
      },
      {
        "name": "sensu-go-sandbox.curl_timings.time_namelookup",
        "value": 0.005,
        "timestamp": 1543532948,
        "tags": []
      },
      {
        "name": "sensu-go-sandbox.curl_timings.time_connect",
        "value": 0.005,
        "timestamp": 1543532948,
        "tags": []
      },
      {
        "name": "sensu-go-sandbox.curl_timings.time_pretransfer",
        "value": 0.005,
        "timestamp": 1543532948,
        "tags": []
      },
      {
        "name": "sensu-go-sandbox.curl_timings.time_redirect",
        "value": 0,
        "timestamp": 1543532948,
        "tags": []
      },
      {
        "name": "sensu-go-sandbox.curl_timings.time_starttransfer",
        "value": 0.005,
        "timestamp": 1543532948,
        "tags": []
      },
      {
        "name": "sensu-go-sandbox.curl_timings.http_code",
        "value": 200,
        "timestamp": 1543532948,
        "tags": []
      }
    ]
  }
```
Because we configured a metric-format, the Sensu agent was able to convert the graphite metrics provided by the check command into a set of metrics points, Sensu's internal representation of metrics. Metric support isn't limited to just Graphite, Sensu agent can extract metrics in multiple line protocol formats.  Now let's create the referenced influxdb handler and do something with these metrics.



**2. Create an InfluxDB pipeline**

Since we've already installed InfluxDB as part of the sandbox, all we need to do to create an InfluxDB pipeline is create a handler following the [Storing Metrics with InfluxDB Guide](https://docs.sensu.io/sensu-go/5.0/guides/influx-db-metric-handler/.) As part of sandbox provisioning a version of the sensu-influxdb-handler is installed for convenience. 

Take a look at the provided configuration file:
```
nano influx-handler.json
```

To create the handler from the config, just use the sensuctl create command:
```
sensuctl create -f influx-handler.json
```

Confirm the handler is created with sensuctl  
```
sensuctl handler list
```


**3. See the HTTP response code events for Nginx in [Grafana](http://localhost:4002/d/core01/sensu-go-sandbox).**

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
/opt/sensu-plugins-ruby/embedded/bin/metrics-disk-usage.rb
```

```
$ /opt/sensu-plugins-ruby/embedded/bin/metrics-disk-usage.rb
sensu-core-sandbox.disk_usage.root.used 2235 1534191189
sensu-core-sandbox.disk_usage.root.avail 39714 1534191189
...
```

Then create the check using a configuration file, assigning it to the `entity:sensu-go-sandbox` subscription and the InfluxDB pipeline:

```
sudo nano disk_usage-check.json
```
```
sensuctl create -f disk_usage-check.json
```


And we should see it working in the dashboard client view and via sensuctl:

```
sensuctl check list
```
```
sensuctl event list
```

Now we should be able to see disk usage metrics for the sandbox in [Grafana](http://localhost:4002/d/go02/sensu-go-sandbox-combined).

You made it! You're ready for the next level of Sensu-ing.
Here are some resources to help continue your journey:

- [Install Sensu Go with configuration management](https://docs.sensu.io/sensu-go/latest/)

