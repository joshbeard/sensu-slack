## Sensu Slack Handler

This is a fork of [https://github.com/sensu/sensu-community-plugins/blob/master/handlers/notification/slack.rb](https://github.com/sensu/sensu-community-plugins/blob/master/handlers/notification/slack.rb)

This version is a bit more verbose.

## Screenshot

![Slack Handler](screenshot.png)

## Configuration

Take a look at [slack.json](slack.json) for example configuration options.

## Testing

You can test the plugin by piping event data to it.

Refer to [https://sensuapp.org/docs/0.12/events](https://sensuapp.org/docs/0.12/events)
for sample data.  Then do something like:

```shell
cat sample.json | slack.rb
```
