# Opal: ActiveRecord
#

## Installation

Add this line to your application's Gemfile:

    gem 'opal-actionpack'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install opal-actionpack


## Usage

Inside your `application.js.rb`:

```ruby
require 'action_pack'                 # to require the whole action pack lib
```

## Overview

opal-actionpack is a subset of rails actionpack that I have written as a way to 
try and unify client and server ruby programming into one coherent model. It currently
requires opal-activerecord, but I would like to make that not so in the future. It is 
actually an avenue for me to explore what it would be like to have a full stack
web-framework to produce web-apps that are ruby from top to bottom. Decisions that
I have made may not be right and may not stay around for the long term. Building
more things with this will allow better decisions to be made in the future.

### Goals

* Be able to pass objects relatively seemlessly between server and client
* Simplify the mental model necessary to produce a web application with significant client side functionality
* Allow easy conversion of server side only (mostly) web applications to offline capable web applications easily
* Have simple development environment that keeps state in data objects, session values and urls so that a simple page refresh is all that is needed to develop/debug functionality.
* Respect good HTML conventions as to how web applications should operate with our without javascript enabled
* Speed of development is emphasized over performance or size of generated JS
* Allow a way to easily replace pure ruby code with custom coded javascript for better performance / code size
* Allow a way to incrementally integrate opal-actionpack into an existing web application
* Make the code faster / smaller over time

### Potential Upsides

* Be able to do significant client side programming without having to learn a whole other JS framework like Backbone, Ember, Angular, and so on.
* Be able to rapidly develop off-line web applications for quick testing of idea

### Potential Downsides

* OpalRB+opal-actionpack+opal-activerecord > 500K in size
* OpalRB can be slow at times (perhaps too slow)

### Application Structure

The structure of a rails application that uses opal-actionpack is very similar to 
a standard rails application. In fact I recommend writing your application as almost
all server-side only as a start. In the next few sections I will show what you need 
to add to your server side application to "opal-actionpackize" it. For the code
examples below, assume I have a simple catalog app that shows widgets (think
scaffold generated).

### Gemfile

Add in these gems.

```ruby
gem 'opal'
gem 'opal-sprockets'
gem 'opal-rspec'
gem 'opal-jquery'
gem 'opal-rails'
gem 'opal-activerecord'
gem 'opal-actionpack', path: '../opal-actionpack'
```

### Application.js

Require these javascript files for the asset pipeline.

//= require opal
//= require opal_ujs
//= require 'active_record'
//= require 'action_pack'

### Views

As you transition to using opal-actionpack, you
will move your top level views to partials and replace the partials with a single page
view that can accomodate the different types of views that you can get to in an application. An example for index.html.erb of this would look like:

```HTML+ERB
<div class="main">
  <div id="widgets">
    <%= render partial: 'index' %>
  </div>
  <div id="widget_show"></div>
</div>

<%= render partial: 'application/launch' %>
```

### Client Side Application Object

There is an application object on the client side just like there is one on the 
server side when using opal-actionpack. It is there that one defines what data store
will be used when the application is launched with json data. The current options
are ActiveRecord::MemoryStore and ActiveRecord::LocalStorageStore. The first stores
the objects in an in memory only database and the second uses good ol' browser
local storage. In the future it would be great to bring in IndexedDb support.

Below is an example application object

```ruby
class WidgetApplication < Application
  def initialize
    super

    @store.init_new_table("widgets")
  end

  def get_store
    ActiveRecord::LocalStorageStore.new(LocalStorage.new)
  end
end
```

In an application being developed using this I also set up listeners to the
data store to allow changes in the local data store to be written back to 
the server and to have the server automatically polled to get changes from
the server. I haven't worked out how this "should" work for all the 
different ways that people might want to sync data.

### Client Side Controller

so that controllers and views written
on the server side can potentially be used on the client side to generate the
same views. In order to be able to share views (if you want to share more than just
partials) between server and client it is necessary that they are invoked in 
roughly the same way on both server and client.

In a rails app, when an action is invoked (e.g. widgets/show/1), the standard path is to
have rails:

* look up the correct controller and action (WidgetsController#show) based on the url and the routes file
* create an WidgetController instance
* call its method of the same name 
* invoke the view (generally of the same name) - widgets/show.html.erb
* inside the view the instance variables set in the constructor are available within the view.
* the rendered view is sent back to the client with the HTTP headers appropriately set

Using opal-actionpack, all the same things happen on the server, except the page will
start a create a client side Application object and launch it. So once the page loads:

* the javascript on the page launches the application with the json necessary for the application

```js
$(function() {
  Opal.WidgetApplication.$instance().$launch('<%= @widgets.to_json(root: true).html_safe %>')
});
```

* once the WidgetApplication is started the client side controller is run (e.g. WidgetClientController)

```ruby
class WidgetClientController < ApplicationController
  class Index
    def initialize(params)
      # look up objects locally and set instance variable for it
      @widgets = Widget.all
    end

    def add_bindings
      Element.find(".show").each do |show_link_element|
        show_link.on_click do |event|
          go_to_route(widget_path(Widget.find(show_link_element.attr("data-id"))), selector: "#show")
          Element.find("#show").show
          Element.find("#index").hide
        end
      end
    end
  end
end
```
* add_bindings is then called on that client controller to capture any client side events that it would like to capture. In this example the link to show the widget is captured
so that the widget show page can be rendered and displayed without hitting the server.


### Generating views

As an example, consider that you are on the widgets index page and you want each link
to open a view of the widget's info without having to go back and hit the server.

```ruby
```

## Testing

There are two ways to run tests. You can run them inside of MRI
for ease of testing and better debuggability or you can run them
using Opal (as this is how it will actually be used).

* To run in Opal do - rake
* To run in MRI do - rspec spec


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

opal-activerecord is Copyright © 2014 Steve Tuckner. It is free software, and may be redistributed under the terms specified in the LICENSE file (an MIT License).
