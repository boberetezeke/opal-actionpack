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
gem 'opal-actionpack'
```

### Application.js

Require these javascript files for the asset pipeline.

//= require opal
//= require opal_ujs
//= require active_record
//= require action_pack

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
  #store  :local_store, tables: [:widgets]
  #syncer :action_syncer, path: -> { widgets_path }, every: 10
  
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

Client side controllers are invoked from the application launch so that 
the application can setup event handlers after the page has been loaded.

The params passed to the client controller are the same params that would be
passed to the WidgetController and are taken from the url arguments.

```ruby
class WidgetClientController < ApplicationController
  class Index
    def initialize(params)
      @widgets = Widget.where(offset: params[:offset], limit: params[:limit]).all
    end
  end

  class Show
    def initialize(params)
      @widget = Widget.find(params[:id])
    end
  end
end
```

### From Start to Finish of Page Load

* look up the correct controller and action (WidgetsController#show) based on the url and the routes file
* create an WidgetController instance
* call its method of the same name 
* invoke the view (generally of the same name) - widgets/show.html.erb
* inside the view the instance variables set in the constructor are available within the view.
* the rendered view is sent back to the client with the HTTP headers appropriately set
* the javascript on the page launches the application with the json necessary for the application
* once the WidgetApplication is started the client side controller is created (e.g. WidgetClientController::Index)
* add_bindings is then called on that client controller to capture any client side events that it would like to capture. In this example the link to show the widget is captured
so that the widget show page can be rendered and displayed without hitting the server.

Once the page load is done, we want to be able to either do things on the current
page or transition to another page.

### add\_bindings

The add_bindings methods is where you would bind to DOM events and update your
models based on events firing. Also, you could bind to changes in objects to
change the DOM.

Below I illustrate the various things that you might do inside of add\_bindings.

#### Monitoring the an object for a change

Let's say that we want to have + / - buttons to adjust the price of a widget.
The proper way to achieve this would be handle the button click, update the
object and when the object change event fires then update the view.

```ruby
class WidgetClientController < ApplicationController
  class Show
    def add_bindings
      Element.find("#plus-price").first.on(:click) do
        @widget.price += 1
      end
      Element.find("#minus-price").first.on(:click) do
        @widget.price -= 1
      end

      @widget.on_change do
        Element.find("#widget_price").first.html = @widget.price
      end
    end
  end
end
```

#### Montoring an object collection for changes

When showing the list of widgets, if someone adds a widget to the catalog,
then it should show up on your list.

```ruby
class WidgetClientController < ApplicationController
  class Index
    def add_bindings
      Widget.on_change(:remote_only) do |action, widget|
        if action == :insert
          # find insert point
          # generate html for widget and insert it into the table
        end
      end
    end
  end
end
```

#### Updating the current page

Lets say that we didn't want to load the entire widget catalog on hitting the index
page. We could list just the first 20 and have a load more button. Within our 
add_bindings method, we could add the following:

```ruby
class WidgetClientController < ApplicationController
  class Index
    def add_bindings
      load_more = Element.find("#load-more").first
      load_more.on(:click) do
        objects = JSON.parse(HTTP.get(widgets_path(offset: @widgets.size))
        objects.each{|o| o.save}

        widgets = Element.find("#widgets").first
        widgets.html = widgets.html + render(partial: 'widgets')
      end
    end
  end
end 
```

#### Transitioning from one page to another

In a single page app, there are generally a set of divs that the pages live inside
and there is a transition from one div that is shown to another that will be
shown. In our case, we want to render the contents of the new "page" into a div, 
show it and hide the current "page" and update the history so the user can hit
the back button and go back to the last page.

```ruby
class WidgetClientController < ApplicationController
  class Index
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

### Methods to be called from a Client Controller

There are four methods available to be called from a client controller.

* session - this returns the session hash that was passed in when the application object was created. It acts like the session hash in rails and can be used to implement things like current_user.
* render - this method allow a partial view to be rendered with passed in locals
* go\_to\_route - this is intended to change from one "page" to another, where the route is a rails route. It will invoke a server side controller first and use it to render the view for that route, then invoke the client controller and in the end insert the generated view into a DOM node.
* bind\_event - bind an event to a DOM element. This simply calls Element.find(selector).first.on and saves the bound elements so they can be automatically unbound on go\_to\_route.

#### session

When the application is launched the second argument to it is an optional hash which is used to initialize the session hash.

```js
$(function() {
  Opal.widgetApplication.$instance().$launch('<%= @widget.to_json(root: true, include: :results).html_safe %>', '<%= {:current_user_id => current_user.id}.to_json.html_safe %>')
});

Then in my client side application controller, I can define current user based on this.

```ruby
class ApplicationController < ActionController::Base
  def current_user
    User.find(session[:current_user_id])
  end
end
```

You can of course also insert and delete from the session hash like any other hash.

#### render

signature: render(options)

arguments

* options - a hash specifying rendering options
** partial - specify name of partial to render
** locals - supply hash to be used to resolve references during rendering

#### go\_to\_route

signature: go_to_route(route, options)

arguments:

* options - hash of options
** selector - selector that indicates where to insert rendered HTML
** render_view(optional, default: true) - if true, the view is rendered. False value is used when for initial page load as view is already rendered by server.
** manual_unbind(optional, default: false) - if true, then unbinding DOM handlers is up to caller

#### bind\_event

signature: bind_event(selector, event_type) { |event }

arguments:

* selector - selector for DOM element(s) to bind to
* event_type - type of event to bind  (e.g. :click or :mousedown)

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
