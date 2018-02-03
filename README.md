# Haxe Lua Bindings

Embed the Lua scripting engine into your Haxe application

## Supported targets

- c++ (tested on macOS)
- js (tested on Chrome)
- nodejs

## Install

### Target C++

1. Install haxelib: [linc_lua](https://github.com/kevinresol/linc_lua)
2. Add `-lib linc_lua` to your haxe build

### Target JS

1. Install haxelib: [hxjs-fengari](https://github.com/kevinresol/hxjs-fengari)

From here you can choose to either build a standalone js file or `require` it in your project.

##### For browser without bundlers

1. Git clone https://github.com/fengari-lua/fengari
1. Run `yarn && yarn run build`
1. Add the output file (`dist/fengari.js`) to your project using a `<script>` tag in html
1. Add `-lib hxjs-fengari -D fengari_global` to your haxe build

#### For Node.js or browser js with bundlers

1. Install haxelib: [hxjs-fengari](https://github.com/kevinresol/hxjs-fengari)
1. Add `-lib hxjs-fengari` to your haxe build
1. `yarn add https://github.com/fengari-lua/fengari`

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

# TODO

- [ ] Implement/test coroutines