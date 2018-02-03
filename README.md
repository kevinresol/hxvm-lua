# Haxe Lua Bindings

This allows you to embed the Lua scripting engine into your application

## Usage

```haxe
// create an instance
var lua = new vm.lua.Lua();

// set global variables
lua.setGlobalVar('square', function(v) return v * v);
lua.setGlobalVar('foo', 2);

// run a script
lua.run('return square(foo)'); // gives you Success(4)

// supply an object as second paramter to run() to set global vars
lua.run('return bar', {bar: 2}); // gives you Success(2)

// run function
lua.run('function add(a, b) \n return a + b \n end'); // first we create a lua function
lua.call('add', [1, 2]); // gives you Success(3)

// destroy when done with the instance
lua.destroy();
```