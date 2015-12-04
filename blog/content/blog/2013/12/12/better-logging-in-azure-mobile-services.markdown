---

title: "Better Logging in Azure Mobile Services"
date: 2013-12-12
comments: true
categories: [Azure,Azure Mobile Services, Node]
keywords: "azure, tracer,logging,debugging, node, node.js,nodejs" 

---

Debugging in azure mobile services can be frustrating,  it only runs on Azure servers and you can't run any debugging tools on it.  Logging is pretty much the only way to debug your services. The default logging using console.log is fairly limited.  You can't turn it on or off easily or change the logging level. It also doesn't include the line number which can make it harder to debug a large service.
<!--more-->

## Installing Tracer ##
Fortunately there are some excellent node modules for logging that work fairly well with Azure Mobile Services. I'm using the excellent [tracer](https://github.com/baryon/tracer) module. 

Installing the module is fairly straight forward, you will first need to [setup git access](http://www.windowsazure.com/en-us/develop/mobile/tutorials/store-scripts-in-source-control/). You then need to install the trace module.
{{< highlight javascript >}}
    npm install tracer
{{< /highlight >}}
Once you have the the module installed you can use it in your scripts.
{{< highlight javascript >}}
    var logger = require('tracer').console();
    logger.log('hello');
    logger.trace('hello', 'world');
    logger.debug('hello %s',  'world', 123);
    logger.info('hello %s %d',  'world', 123, {foo:'bar'});
    logger.warn('hello %s %d %j', 'world', 123, {foo:'bar'});
    logger.error('hello %s %d %j', 'world', 123, {foo:'bar'}, [1, 2, 3, 4], Object);
{{< /highlight >}}
When you use the the logger it will include the line number as well as the logging level.

## Setting the Logging Level ##

You can set the logging level fairly simply:
{{< highlight javascript >}}
    var logger = require('tracer').colorConsole({level:'warn'});
{{< /highlight >}}
An even better way to do it is to use an app setting to set the logging level.  That way you can use azure portal to set the logging level without having to change any of the scripts.
{{< highlight javascript >}}
    var logger = require('tracer').colorConsole({level:process.env.LoggerLevel});
{{< /highlight >}}
## Using Colour and Log Watcher ##
The web view of the logs isn't very useful for logging, instead I use a [node.js script](http://www.thejoyofcode.com/A_Mobile_Services_Log_Watcher_Day_6_.aspx) from Josh Twist that polls the logs from the api. This allows you to see the errors as they happened and stops you from having to refresh a web page manually.

As an additional bonus you can use colours when you are using the script. This makes it much easier to keep things organized.
{{< highlight javascript >}}
    var _ = require('lodash');
    var colors = require('colors');
    var logger = require('tracer').colorConsole({filters : {
	    log : colors.white,
	    trace : colors.grey,
	    debug : colors.magenta,
	    info : colors.green,
	    warn : colors.yellow,
	    error : [ colors.red, colors.bold ]
    },
    level:process.env.LoggerLevel //log,trace,debug,info,warn,error
    
    });
{{< /highlight >}}