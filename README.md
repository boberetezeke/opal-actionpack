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

opal-actionpack is a subset of rails actionpack so that controllers and views written
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
